import Foundation
import UIKit

/// 设备角色
enum DeviceRole {
    /// iPhone → 指板（左手按弦）
    case fretboard

    /// iPad → 拨弦 + 音箱（右手）
    case strumming

    /// 根据当前设备自动判断角色
    static var current: DeviceRole {
        UIDevice.current.userInterfaceIdiom == .pad ? .strumming : .fretboard
    }
}
