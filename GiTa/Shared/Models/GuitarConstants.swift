import Foundation

/// 吉他常量 — 标准调弦、频率表、品位数量
enum GuitarConstants {

    // MARK: - 基本参数

    /// 总弦数
    static let stringCount = 6

    /// 可用品位数（0 = 空弦，1~19 品，适配手机屏幕）
    static let fretCount = 19

    /// 标准调弦开弦频率 (E2, A2, D3, G3, B3, E4)
    /// 索引 0 = 第 6 弦（最粗，低音 E），索引 5 = 第 1 弦（最细，高音 E）
    static let openStringFrequencies: [Double] = [
        82.41,   // E2 — 6 弦
        110.00,  // A2 — 5 弦
        146.83,  // D3 — 4 弦
        196.00,  // G3 — 3 弦
        246.94,  // B3 — 2 弦
        329.63   // E4 — 1 弦
    ]

    /// 开弦音名
    static let openStringNames: [String] = ["E2", "A2", "D3", "G3", "B3", "E4"]

    /// 12 个半音的音名（用于显示）
    static let noteNames: [String] = [
        "C", "C♯", "D", "D♯", "E", "F",
        "F♯", "G", "G♯", "A", "A♯", "B"
    ]

    // MARK: - 品位标记位置（用于绘制 inlay dots）

    /// 单点品位标记
    static let singleDotFrets: Set<Int> = [3, 5, 7, 9, 15, 17]

    /// 双点品位标记
    static let doubleDotFrets: Set<Int> = [12]

    // MARK: - 频率计算

    /// 计算指定弦和品位的频率
    /// - Parameters:
    ///   - stringIndex: 弦索引 (0=6弦/低E, 5=1弦/高E)
    ///   - fret: 品位 (0=空弦, 1-19)
    /// - Returns: 频率 (Hz)
    static func frequency(stringIndex: Int, fret: Int) -> Double {
        guard stringIndex >= 0, stringIndex < stringCount else { return 0 }
        let baseFret = max(0, min(fret, fretCount))
        return openStringFrequencies[stringIndex] * pow(2.0, Double(baseFret) / 12.0)
    }

    /// 获取指定弦和品位的音名
    /// - Parameters:
    ///   - stringIndex: 弦索引
    ///   - fret: 品位
    /// - Returns: 音名字符串 (如 "C4", "G♯3")
    static func noteName(stringIndex: Int, fret: Int) -> String {
        guard stringIndex >= 0, stringIndex < stringCount else { return "?" }
        // 根据开弦的 MIDI 编号推算
        let openMidi = midiNote(for: openStringFrequencies[stringIndex])
        let midi = openMidi + fret
        let name = noteNames[midi % 12]
        let octave = midi / 12 - 1
        return "\(name)\(octave)"
    }

    /// 频率转 MIDI 音符号
    private static func midiNote(for frequency: Double) -> Int {
        Int(round(69.0 + 12.0 * log2(frequency / 440.0)))
    }

    // MARK: - 品位位置比例（用于 UI 绘制）

    /// 计算品位在指板上的相对位置（0.0 ~ 1.0）
    /// 真实吉他品丝间距按 2^(1/12) 等比递减
    /// - Parameter fret: 品位号 (1-19)
    /// - Returns: 该品丝距离琴枕的比例位置
    static func fretPosition(_ fret: Int) -> Double {
        guard fret > 0, fret <= fretCount else { return 0 }
        return 1.0 - 1.0 / pow(2.0, Double(fret) / 12.0)
    }

    /// 计算品位中心位置（手指按弦的中心点）
    /// - Parameter fret: 品位号 (1-19)
    /// - Returns: 该品位中心的比例位置
    static func fretCenterPosition(_ fret: Int) -> Double {
        guard fret > 0, fret <= fretCount else { return 0 }
        let left = fret == 1 ? 0.0 : fretPosition(fret - 1)
        let right = fretPosition(fret)
        return (left + right) / 2.0
    }
}
