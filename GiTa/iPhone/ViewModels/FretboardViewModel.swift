import Foundation
import Combine

/// 指板状态管理 — iPhone 端核心 ViewModel
@Observable
final class FretboardViewModel {

    // MARK: - 状态

    /// 当前按弦状态
    var fretState = FretState.empty

    /// 连接状态
    var isConnected = false

    /// 连接状态文字
    var connectionStatusText = "等待连接..."

    // MARK: - 私有

    private let advertiser = ServiceAdvertiser()
    private let connection = PeerConnection()
    private var sequenceNumber: UInt16 = 0
    private var heartbeatTimer: Timer?
    private var lastReceivedTime = Date()
    private var timeoutTimer: Timer?

    // MARK: - 生命周期

    init() {
        setupNetwork()
    }

    deinit {
        heartbeatTimer?.invalidate()
        timeoutTimer?.invalidate()
        advertiser.stopAdvertising()
        connection.disconnect()
    }

    // MARK: - 网络设置

    private func setupNetwork() {
        // 连接状态变化
        connection.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .connected:
                    self.isConnected = true
                    self.connectionStatusText = "已连接"
                    self.lastReceivedTime = Date() // 重置接收时间
                    self.startHeartbeat()
                    self.startTimeoutTimer()
                    HapticManager.shared.connectionSuccess()
                case .connecting:
                    self.isConnected = false
                    self.connectionStatusText = "连接中..."
                case .disconnected:
                    self.isConnected = false
                    self.connectionStatusText = "等待连接..."
                    self.stopHeartbeat()
                    self.stopTimeoutTimer()
                case .failed:
                    self.isConnected = false
                    self.connectionStatusText = "连接失败"
                    self.stopHeartbeat()
                    self.stopTimeoutTimer()
                }
            }
        }

        // 接收来自 iPad 的数据
        connection.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }

        // 有新连接进来时（iPad 连入）
        advertiser.onConnectionReceived = { [weak self] conn in
            guard let self else { return }
            print("[FretboardViewModel] Received incoming connection request. Accepting and resetting any previous session...")
            self.connection.accept(conn)
        }

        // 开始广播
        advertiser.startAdvertising()
    }

    // MARK: - 按弦操作

    /// 按弦事件
    func pressString(_ stringIndex: Int, fret: Int) {
        let oldFret = fretState.fret(for: stringIndex)
        fretState.press(string: stringIndex, fret: fret)

        if oldFret != fret {
            print("[FretboardViewModel] String \(stringIndex) pressed at fret \(fret). State: \(fretState.frets)")
            HapticManager.shared.fretPress()
            sendFretUpdate()
        }
    }

    /// 松弦事件
    func releaseString(_ stringIndex: Int) {
        let oldFret = fretState.fret(for: stringIndex)
        fretState.release(string: stringIndex)

        if oldFret != 0 {
            print("[FretboardViewModel] String \(stringIndex) released. State: \(fretState.frets)")
            HapticManager.shared.fretRelease()
            sendFretUpdate()
        }
    }

    // MARK: - 网络发送

    /// 发送按弦状态更新
    private func sendFretUpdate() {
        sequenceNumber &+= 1
        let message = NetworkMessage(
            type: .fretUpdate,
            sequence: sequenceNumber,
            fretState: fretState
        )
        connection.send(message: message)
    }

    /// 发送心跳（完整状态，防丢包）
    private func sendHeartbeat() {
        sequenceNumber &+= 1
        let message = NetworkMessage(
            type: .heartbeat,
            sequence: sequenceNumber,
            fretState: fretState
        )
        connection.send(message: message)
    }

    // MARK: - 心跳定时器

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - 数据接收处理

    private func handleReceivedData(_ data: Data) {
        lastReceivedTime = Date() // 收到任意数据都重置超时计时

        // 1. 检查握手
        if HandshakeMessage.validate(data) {
            connection.send(HandshakeMessage.create())
            return
        }

        // 2. 解析消息
        guard let message = NetworkMessage.decode(from: data) else { return }

        switch message.type {
        case .disconnect:
            print("[FretboardViewModel] Received explicit disconnect from iPad")
            connection.disconnect()
        case .heartbeat:
            // 收到 iPad 端心跳
            print("[FretboardViewModel] Received ping heartbeat from iPad")
        default:
            break
        }
    }

    // MARK: - 超时监控定时器

    private func startTimeoutTimer() {
        stopTimeoutTimer()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(self.lastReceivedTime)
            if elapsed > 2.0 {
                print("[FretboardViewModel] Timeout! No data from iPad for \(elapsed)s. Disconnecting...")
                self.connection.disconnect()
            }
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}
