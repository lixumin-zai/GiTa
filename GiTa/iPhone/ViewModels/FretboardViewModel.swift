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
    var widthMultiplier: Double = 1.5 // 默认 1.5 倍拉宽

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
            // 带有动画的向右平移（滑向高把位）
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                self?.panRight()
            }
        }
        
        volumeObserver.onVolumeDown = { [weak self] in
            // 带有动画的向左平移（滑向琴枕）
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                self?.panLeft()
            }
        }
        
        volumeObserver.start()
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
    private var volumeView: MPVolumeView!
    private var observer: NSKeyValueObservation?
    private let targetVolume: Float = 0.5 // 固定将系统音量维持在 50%，防止按到极限值失效
    
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    
    func start() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        
        volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        volumeView.isHidden = false 
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                window.addSubview(self.volumeView)
            }
            self.resetSystemVolume()
        }
        
        observer = audioSession.observe(\.outputVolume, options: [.old, .new]) { [weak self] (session, change) in
            guard let self = self,
                  let newVol = change.newValue,
                  let oldVol = change.oldValue else { return }
            
            if abs(newVol - self.targetVolume) < 0.05 { return }
            
            if newVol > oldVol {
                DispatchQueue.main.async { self.onVolumeUp?() }
            } else if newVol < oldVol {
                DispatchQueue.main.async { self.onVolumeDown?() }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.resetSystemVolume()
            }
        }
    }
    
    func stop() {
        observer?.invalidate()
        observer = nil
        DispatchQueue.main.async {
            self.volumeView?.removeFromSuperview()
        }
    }
    
    private func resetSystemVolume() {
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            slider.value = targetVolume
        }
    }
}
