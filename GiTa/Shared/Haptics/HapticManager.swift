import UIKit

/// 触觉反馈管理器
final class HapticManager {

    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        // 预热引擎以减少首次触发延迟
        lightImpact.prepare()
        mediumImpact.prepare()
        rigidImpact.prepare()
    }

    /// 按弦反馈（轻触感）
    func fretPress() {
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }

    /// 松弦反馈
    func fretRelease() {
        lightImpact.impactOccurred(intensity: 0.3)
        lightImpact.prepare()
    }

    /// 拨弦反馈
    func stringPluck() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }

    /// 扫弦反馈
    func strum() {
        rigidImpact.impactOccurred(intensity: 0.5)
        rigidImpact.prepare()
    }

    /// 连接成功反馈
    func connectionSuccess() {
        let notif = UINotificationFeedbackGenerator()
        notif.notificationOccurred(.success)
    }
}
