import Foundation
import Network

/// iPad 拨弦端核心 ViewModel
@Observable
final class StrummingViewModel {

    // MARK: - 状态

    /// 从 iPhone 接收到的按弦状态
    var fretState = FretState.empty

    /// 连接状态
    var isConnected = false
    var connectionStatusText = "搜索指板..."
    var connectedDeviceName = ""

    /// 音频参数
    var volume: Float = 0.8 {
        didSet { audioEngine.volume = volume }
    }
    var reverbAmount: Float = 0.3 {
        didSet { audioEngine.setReverb(reverbAmount) }
    }
    var guitarType: GuitarType = .acoustic {
        didSet { audioEngine.setGuitarType(guitarType) }
    }

    // MARK: - 私有

    let audioEngine = GuitarAudioEngine()
    private let browser = ServiceBrowser()
    private let connection = PeerConnection()
    private var lastSequence: UInt16 = 0
    private var handshakeTimer: Timer?
    private var lastReceivedTime = Date()
    private var timeoutTimer: Timer?
    private var pingTimer: Timer?

    // MARK: - 生命周期

    init() {
        setupNetwork()
        audioEngine.start()
    }

    deinit {
        handshakeTimer?.invalidate()
        timeoutTimer?.invalidate()
        pingTimer?.invalidate()
        browser.stopBrowsing()
        connection.disconnect()
        audioEngine.stop()
    }

    // MARK: - 发现的设备

    struct DiscoveredDevice: Identifiable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
    }

    var discoveredDevices: [DiscoveredDevice] = []

    // MARK: - 网络设置

    private func setupNetwork() {
        // 连接状态
        connection.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .connected:
                    // 仅代表 socket 建立，不代表物理握手成功。开启定时器尝试握手。
                    self.connectionStatusText = "正在握手..."
                    self.startHandshakeTimer()
                case .connecting:
                    self.isConnected = false
                    self.connectionStatusText = "连接中..."
                case .disconnected:
                    self.isConnected = false
                    self.connectionStatusText = "连接已断开"
                    self.stopHandshakeTimer()
                    self.stopTimeoutTimer()
                    self.stopPingTimer()
                case .failed(let msg):
                    self.isConnected = false
                    self.connectionStatusText = "连接失败"
                    self.stopHandshakeTimer()
                    self.stopTimeoutTimer()
                    self.stopPingTimer()
                }
            }
        }

        // 数据接收
        connection.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }

        // 发现设备
        browser.onPeerFound = { [weak self] endpoint in
            guard let self else { return }
            if case .service(let name, _, _, _) = endpoint {
                DispatchQueue.main.async {
                    // 避免重复添加
                    if !self.discoveredDevices.contains(where: { $0.name == name }) {
                        self.discoveredDevices.append(DiscoveredDevice(name: name, endpoint: endpoint))
                    }
                    
                    // 自动连接第一个（仍保留自动连接逻辑，但 UI 上现在能看到了）
                    if !self.isConnected && self.connection.state == .disconnected {
                        self.connectTo(device: self.discoveredDevices.last!)
                    }
                }
            }
        }

        // 丢失设备
        browser.onPeerLost = { [weak self] endpoint in
            guard let self else { return }
            if case .service(let name, _, _, _) = endpoint {
                DispatchQueue.main.async {
                    self.discoveredDevices.removeAll { $0.name == name }
                }
            }
        }

        // 开始浏览
        browser.startBrowsing()
    }

    // MARK: - 手动连接与断开

    func connectTo(device: DiscoveredDevice) {
        connectedDeviceName = device.name
        connection.connect(to: device.endpoint)
    }

    /// 手动断开连接
    func disconnect() {
        // 1. 发送显式断开数据包，通知 iPhone 立即释放连接
        if isConnected {
            print("[StrummingViewModel] Sending explicit disconnect message to iPhone...")
            let message = NetworkMessage(type: .disconnect, sequence: 0, fretState: .empty)
            connection.send(message: message)
        }
        
        stopHandshakeTimer()
        stopTimeoutTimer()
        stopPingTimer()
        browser.stopBrowsing()
        
        // 2. 延迟 50 毫秒断开本地 Socket，以保证 UDP 断开数据包能够顺利飞出网卡
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.connection.disconnect()
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionStatusText = "连接已断开"
                self.discoveredDevices.removeAll()
            }
        }
    }

    /// 重新开始搜索设备
    func startScanning() {
        disconnect()
        connectionStatusText = "正在搜索..."
        browser.startBrowsing()
    }

    // MARK: - 数据处理

    private func handleReceivedData(_ data: Data) {
        lastReceivedTime = Date() // 收到任何数据，刷新超时计时
        
        // 收到任何数据，说明物理上真正的连通了
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isConnected {
                self.isConnected = true
                self.connectionStatusText = "已连接"
                self.stopHandshakeTimer()
                self.startTimeoutTimer()
                self.startPingTimer() // 启动发送给 iPhone 的心跳，实现双向超时检测
                HapticManager.shared.connectionSuccess()
            }
        }

        // 检查握手
        if HandshakeMessage.validate(data) {
            connection.send(HandshakeMessage.create())
            return
        }

        // 解析消息
        guard let message = NetworkMessage.decode(from: data) else { return }

        if message.type == .fretUpdate {
            print("[StrummingViewModel] Received fret update: \(message.fretState.frets), sequence: \(message.sequence)")
        } else if message.type == .heartbeat {
            print("[StrummingViewModel] Received heartbeat. State: \(message.fretState.frets)")
        }

        // 序列号检查（允许乱序，但丢弃过旧的包）
        // UDP 可能乱序，但我们只关心最新状态
        let seqDiff = Int16(bitPattern: message.sequence &- lastSequence)
        if seqDiff < 0 && seqDiff > -100 {
            print("[StrummingViewModel] Dropping out-of-order sequence packet: \(message.sequence), last: \(lastSequence)")
            return // 丢弃旧包（但允许序列号回绕）
        }
        lastSequence = message.sequence

        // 更新按弦状态
        DispatchQueue.main.async { [weak self] in
            self?.fretState = message.fretState
            self?.audioEngine.updateFretState(message.fretState)
        }
    }

    // MARK: - 拨弦接口

    /// 拨单弦
    func pluckString(_ index: Int, amplitude: Float = 0.8) {
        audioEngine.pluckString(index, amplitude: amplitude)
        HapticManager.shared.stringPluck()
    }

    /// 扫弦
    func strum(from: Int, to: Int, velocity: Double) {
        audioEngine.strum(from: from, to: to, velocity: velocity, amplitude: 0.7)
        HapticManager.shared.strum()
    }

    /// 静音
    func muteAll() {
        audioEngine.muteAll()
    }

    // MARK: - 握手定时器

    private func startHandshakeTimer() {
        stopHandshakeTimer()
        // 每 0.5 秒发一次握手包，直到对方接收并响应我们
        handshakeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            print("[StrummingViewModel] Sending handshake ping...")
            self?.connection.send(HandshakeMessage.create())
        }
    }

    private func stopHandshakeTimer() {
        handshakeTimer?.invalidate()
        handshakeTimer = nil
    }

    // MARK: - 超时监控与心跳 Ping 定时器

    private func startTimeoutTimer() {
        stopTimeoutTimer()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(self.lastReceivedTime)
            if elapsed > 2.0 {
                print("[StrummingViewModel] Timeout! No heartbeats from iPhone for \(elapsed)s. Disconnecting...")
                self.disconnect()
            }
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    private func startPingTimer() {
        stopPingTimer()
        // 开启 0.5 秒一次的心跳发送，向 iPhone 证明我们依然在线，维护 iPhone 侧的生存时间
        pingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let message = NetworkMessage(type: .heartbeat, sequence: 0, fretState: .empty)
            self.connection.send(message: message)
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}
