import SwiftUI

/// GiTa 应用入口
/// 根据设备类型自动加载对应界面：
/// - iPhone → 指板界面（FretboardScreen）
/// - iPad → 拨弦+音箱界面（StrummingScreen）
@main
struct GiTaApp: App {

    var body: some Scene {
        WindowGroup {
            Group {
                switch DeviceRole.current {
                case .fretboard:
                    FretboardScreen()
                case .strumming:
                    StrummingScreen()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
