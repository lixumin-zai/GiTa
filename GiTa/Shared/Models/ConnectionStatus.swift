import Foundation

/// 统一的物理连接状态，消除魔术字符串，确保双端状态机的高度稳定与类型安全
enum ConnectionStatus: String, CaseIterable, Codable {
    case searching = "正在搜索..."
    case connecting = "连接中..."
    case handshaking = "正在握手..."
    case connected = "已连接"
    case disconnected = "连接已断开"
    case failed = "连接失败"
    
    /// iPhone 端的特定文本显示适配
    var iphoneDisplay: String {
        switch self {
        case .disconnected, .searching:
            return "等待连接..."
        default:
            return self.rawValue
        }
    }
}
