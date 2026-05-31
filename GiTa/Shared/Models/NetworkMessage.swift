import Foundation

/// 网络消息类型
enum MessageType: UInt8, Codable {
    case fretUpdate  = 1   // 按弦状态更新
    case heartbeat   = 2   // 心跳包（含完整状态）
    case handshake   = 3   // 握手确认
    case disconnect  = 4   // 断开通知
}

/// 网络消息：紧凑二进制格式
/// 总共 ~9 字节：[type(1)] [seq_hi(1)] [seq_lo(1)] [frets(6)]
struct NetworkMessage {
    let type: MessageType
    let sequence: UInt16
    let fretState: FretState

    // MARK: - 序列化

    /// 编码为 Data（9 字节）
    func encode() -> Data {
        var data = Data(capacity: 9)
        data.append(type.rawValue)
        data.append(UInt8(sequence >> 8))    // 高字节
        data.append(UInt8(sequence & 0xFF))  // 低字节
        data.append(fretState.toData())
        return data
    }

    /// 从 Data 解码
    static func decode(from data: Data) -> NetworkMessage? {
        guard data.count >= 9 else { return nil }
        guard let type = MessageType(rawValue: data[0]) else { return nil }
        let sequence = (UInt16(data[1]) << 8) | UInt16(data[2])
        guard let fretState = FretState.from(data: data.dropFirst(3)) else { return nil }
        return NetworkMessage(type: type, sequence: sequence, fretState: fretState)
    }
}

/// 握手消息
struct HandshakeMessage {
    static let magic: [UInt8] = [0x47, 0x54] // "GT"

    static func create() -> Data {
        var data = Data(capacity: 3)
        data.append(MessageType.handshake.rawValue)
        data.append(contentsOf: magic)
        return data
    }

    static func validate(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return data[0] == MessageType.handshake.rawValue
            && data[1] == magic[0]
            && data[2] == magic[1]
    }
}
