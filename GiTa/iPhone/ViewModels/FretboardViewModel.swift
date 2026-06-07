import Foundation
import Combine
import UIKit
import MediaPlayer
import AVFoundation
import Combine
import UIKit
import SwiftUI

/// 指板状态管理 — iPhone 端核心 ViewModel
@Observable
final class FretboardViewModel {

    // MARK: - 状态

    /// 当前按弦状态
    var fretState = FretState.empty

    /// 连接状态
    var isConnected = false
    var connectionStatus = ConnectionStatus.disconnected
    var connectionStatusText: String { connectionStatus.iphoneDisplay }

    /// 指板大小整体缩放比例 (0.8 ~ 1.2)
    var scale: Double = 1.0

    /// 指板横向品距拉伸倍率 (1.0 ~ 3.0)
    var widthMultiplier: Double = 2.2 // 默认 2.2 倍拉宽（品丝间隔更大）

    /// 指板横向滚动偏移量
    var offsetX: Double = 0.0

    // MARK: - 私有

    private let advertiser = ServiceAdvertiser()
    private let connection = PeerConnection()
    private let volumeObserver = VolumeKeyObserver()
    private var sequenceNumber: UInt16 = 0
    private var heartbeatTimer: Timer?
    private var lastReceivedTime = Date()
    private var timeoutTimer: Timer?

    // MARK: - 生命周期

    init() {
        setupNetwork()
        setupLifecycleObservers()
        setupVolumeObserver()
    }

    deinit {
        heartbeatTimer?.invalidate()
        timeoutTimer?.invalidate()
        advertiser.stopAdvertising()
        connection.disconnect()
        volumeObserver.stop()
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
                    self.connectionStatus = .connected
                    self.lastReceivedTime = Date() // 重置接收时间
                    self.startHeartbeat()
                    self.startTimeoutTimer()
                    HapticManager.shared.connectionSuccess()
                case .connecting:
                    self.isConnected = false
                    self.connectionStatus = .connecting
                case .disconnected:
                    self.isConnected = false
                    self.connectionStatus = .disconnected
                    self.stopHeartbeat()
                    self.stopTimeoutTimer()
                case .failed:
                    self.isConnected = false
                    self.connectionStatus = .failed
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

    // MARK: - 音量键拦截与平移

    private func setupVolumeObserver() {
        volumeObserver.onVolumeUp = { [weak self] in
            // 带有动画的向左平移（滑向琴枕 / 低把位）
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                self?.panLeft()
            }
        }
        
        volumeObserver.onVolumeDown = { [weak self] in
            // 带有动画的向右平移（滑向高把位）
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                self?.panRight()
            }
        }
    }
    
    /// 当 SwiftUI 视图挂载好 MPVolumeView 后注册进来启动监听
    func registerVolumeView(_ volumeView: MPVolumeView) {
        volumeObserver.start(with: volumeView)
    }
    
    private func panRight() {
        let step: Double = 80.0 // 固定步长
        // 估算最大偏移量
        let screenWidth = UIScreen.main.bounds.width
        let usableWidth = screenWidth * scale * widthMultiplier
        let maxOffset = max(usableWidth - screenWidth, 0.0) + 150.0 // 允许末尾多滑出一点空间
        offsetX = min(offsetX + step, maxOffset)
    }
    
    private func panLeft() {
        let step: Double = 80.0
        offsetX = max(offsetX - step, 0.0)
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

    // MARK: - 生命周期监控

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[FretboardViewModel] App entered background. Suspending network...")
            self?.advertiser.stopAdvertising()
            self?.connection.disconnect()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[FretboardViewModel] App became active. Restarting advertiser...")
            self?.advertiser.stopAdvertising()
            self?.advertiser.startAdvertising()
        }
    }
}

// MARK: - VolumeKeyObserver

/// 极客魔法：拦截硬件音量键进行自定义操作
final class VolumeKeyObserver {
    private var volumeView: MPVolumeView?
    private var observer: NSKeyValueObservation?
    private let targetVolume: Float = 0.5 // 固定将系统音量维持在 50%，防止按到极限值失效
    private var isResetting: Bool = false
    
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    
    func start(with volumeView: MPVolumeView) {
        self.volumeView = volumeView
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, options: .mixWithOthers)
        try? audioSession.setActive(true)
        
        // 延迟重置，确保 SwiftUI 渲染完成且 Slider 子控件完全加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.resetSystemVolume()
        }
        
        observer = audioSession.observe(\.outputVolume, options: [.old, .new]) { [weak self] (session, change) in
            guard let self = self,
                  let newVol = change.newValue,
                  let oldVol = change.oldValue else { return }
            
            // 过滤代码重置触发的 KVO
            if self.isResetting {
                if abs(newVol - self.targetVolume) < 0.05 {
                    self.isResetting = false
                    return
                }
                self.isResetting = false
            }
            
            DispatchQueue.main.async {
                if newVol > oldVol {
                    self.onVolumeUp?()
                } else if newVol < oldVol {
                    self.onVolumeDown?()
                }
            }
            
            // 稍微延迟重置，确保物理按键的系统回调连续性不被吃掉
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.resetSystemVolume()
            }
        }
    }
    func stop() {
        observer?.invalidate()
        observer = nil
        volumeView = nil
    }
    
    private func resetSystemVolume() {
        guard let volumeView = volumeView else { return }
        if let slider = volumeView.findSliderRecursively() {
            if abs(slider.value - targetVolume) > 0.02 {
                isResetting = true
                slider.value = targetVolume
                
                // 防御性超时：防止因为某种原因 KVO 没回调导致永久卡死
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.isResetting = false
                }
            }
        }
    }
}

// MARK: - UIView Extension for finding Slider
private extension UIView {
    func findSliderRecursively() -> UISlider? {
        if let slider = self as? UISlider {
            return slider
        }
        for subview in subviews {
            if let slider = subview.findSliderRecursively() {
                return slider
            }
        }
        return nil
    }
}
