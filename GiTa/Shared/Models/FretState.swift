import Foundation

/// 6 根弦的按弦状态
/// 整个结构设计为紧凑二进制序列化，用于网络传输
struct FretState: Equatable, Codable {

    /// 每根弦的品位（0 = 空弦，1~19 = 按弦品位）
    /// 索引 0 = 6弦(低E)，索引 5 = 1弦(高E)
    var frets: [UInt8]

    /// 默认状态：全部空弦
    static let empty = FretState(frets: [0, 0, 0, 0, 0, 0])

    init(frets: [UInt8] = [0, 0, 0, 0, 0, 0]) {
        precondition(frets.count == GuitarConstants.stringCount)
        self.frets = frets
    }

    // MARK: - 单弦操作

    /// 按弦
    mutating func press(string: Int, fret: Int) {
        guard string >= 0, string < GuitarConstants.stringCount else { return }
        frets[string] = UInt8(max(0, min(fret, GuitarConstants.fretCount)))
    }

    /// 松弦（恢复空弦）
    mutating func release(string: Int) {
        guard string >= 0, string < GuitarConstants.stringCount else { return }
        frets[string] = 0
    }

    /// 获取指定弦的品位
    func fret(for string: Int) -> Int {
        guard string >= 0, string < GuitarConstants.stringCount else { return 0 }
        return Int(frets[string])
    }

    /// 获取指定弦当前的频率
    func frequency(for string: Int) -> Double {
        GuitarConstants.frequency(stringIndex: string, fret: fret(for: string))
    }

    /// 获取指定弦当前的音名
    func noteName(for string: Int) -> String {
        GuitarConstants.noteName(stringIndex: string, fret: fret(for: string))
    }

    // MARK: - 二进制序列化（极致轻量，用于 UDP 传输）

    /// 序列化为 Data（仅 6 字节）
    func toData() -> Data {
        Data(frets)
    }

    /// 从 Data 反序列化
    static func from(data: Data) -> FretState? {
        guard data.count >= GuitarConstants.stringCount else { return nil }
        let bytes = Array(data.prefix(GuitarConstants.stringCount))
        return FretState(frets: bytes)
    }
}
