import SwiftUI

/// 和弦图示 — 显示 iPhone 端当前按弦状态的小型指板图
struct ChordDiagramView: View {

    let fretState: FretState

    /// 图示中显示的品位范围
    private var displayRange: ClosedRange<Int> {
        let activeFrets = (0..<GuitarConstants.stringCount)
            .map { fretState.fret(for: $0) }
            .filter { $0 > 0 }

        if activeFrets.isEmpty { return 0...4 }

        let minFret = max(1, activeFrets.min()!)
        let maxFret = activeFrets.max()!
        let range = max(4, maxFret - minFret + 1)
        return minFret...min(minFret + range, GuitarConstants.fretCount)
    }

    var body: some View {
        VStack(spacing: 4) {
            // 和弦名称
            Text(chordName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(isRecognizedChord ? .cyan : .white)
                .shadow(color: isRecognizedChord ? .cyan.opacity(0.5) : .clear, radius: 6)
                .id("chord_name_\(chordName)")
                .animation(.easeInOut(duration: 0.2), value: chordName)

            // 指板图
            Canvas { context, size in
                drawChordDiagram(context: context, size: size)
            }
            .frame(width: 120, height: 140)
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 和弦识别

    /// 是否匹配到了已知和弦
    private var isRecognizedChord: Bool {
        ChordRecognizer.recognize(fretState) != nil
    }

    private var chordName: String {
        // 优先尝试和弦识别
        if let name = ChordRecognizer.recognize(fretState) {
            return name
        }
        // 全空弦
        let activeFrets = (0..<GuitarConstants.stringCount).map { fretState.fret(for: $0) }
        if activeFrets.allSatisfy({ $0 == 0 }) { return "Open" }
        // 无法识别，显示按弦音名
        let notes = (0..<GuitarConstants.stringCount)
            .filter { fretState.fret(for: $0) > 0 }
            .map { fretState.noteName(for: $0) }
        if notes.isEmpty { return "Open" }
        return notes.joined(separator: " ")
    }

    // MARK: - 绘制

    private func drawChordDiagram(context: GraphicsContext, size: CGSize) {
        let range = displayRange
        let fretCount = range.upperBound - range.lowerBound + 1
        let stringCount = GuitarConstants.stringCount

        let leftMargin: CGFloat = 22  // 给品位号留空间
        let rightMargin: CGFloat = 10
        let topMargin: CGFloat = 20
        let bottomMargin: CGFloat = 10
        let width = size.width - leftMargin - rightMargin
        let height = size.height - topMargin - bottomMargin
        let stringSpacing = width / CGFloat(stringCount - 1)
        let fretSpacing = height / CGFloat(fretCount)

        // 画品丝（水平线）+ 品位号
        for i in 0...fretCount {
            let y = topMargin + CGFloat(i) * fretSpacing
            var path = Path()
            path.move(to: CGPoint(x: leftMargin, y: y))
            path.addLine(to: CGPoint(x: leftMargin + width, y: y))

            let isNut = (i == 0 && range.lowerBound <= 1)
            context.stroke(path, with: .color(.white.opacity(isNut ? 0.8 : 0.3)),
                          lineWidth: isNut ? 3 : 1)

            // 每一品的品位号，绘制在品丝之间的左侧
            if i < fretCount {
                let fretNumber = range.lowerBound + i
                let labelY = topMargin + (CGFloat(i) + 0.5) * fretSpacing
                context.draw(
                    Text("\(fretNumber)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45)),
                    at: CGPoint(x: leftMargin - 10, y: labelY)
                )
            }
        }

        // 画弦（垂直线）
        for i in 0..<stringCount {
            let x = leftMargin + CGFloat(i) * stringSpacing
            var path = Path()
            path.move(to: CGPoint(x: x, y: topMargin))
            path.addLine(to: CGPoint(x: x, y: topMargin + height))
            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1)
        }

        // 画按弦位置
        for i in 0..<stringCount {
            let fret = fretState.fret(for: i)
            let x = leftMargin + CGFloat(i) * stringSpacing

            if fret == 0 {
                // 空弦：画 O
                context.draw(
                    Text("○")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5)),
                    at: CGPoint(x: x, y: topMargin - 10)
                )
            } else if fret >= range.lowerBound && fret <= range.upperBound {
                // 按弦：画实心圆
                let fretOffset = CGFloat(fret - range.lowerBound)
                let y = topMargin + (fretOffset + 0.5) * fretSpacing
                let radius: CGFloat = 6

                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(.cyan)
                )
            }
        }
    }
}

// MARK: - 和弦识别器

/// 基于品位指法匹配常见吉他和弦
enum ChordRecognizer {

    /// 和弦数据库：(名称, 品位指法 [6弦→1弦], -1 表示不弹该弦，忽略不弹的弦)
    private static let chordDatabase: [(name: String, frets: [Int])] = [
        // ═══════════════════════════════════════════
        // 开放大三和弦 (Major)
        // ═══════════════════════════════════════════
        ("C",       [0, 3, 2, 0, 1, 0]),
        ("D",       [0, 0, 0, 2, 3, 2]),
        ("E",       [0, 2, 2, 1, 0, 0]),
        ("G",       [3, 2, 0, 0, 0, 3]),
        ("G",       [3, 2, 0, 0, 3, 3]),   // 常见变体
        ("A",       [0, 0, 2, 2, 2, 0]),
        ("F",       [1, 3, 3, 2, 1, 1]),

        // ═══════════════════════════════════════════
        // 开放小三和弦 (Minor)
        // ═══════════════════════════════════════════
        ("Am",      [0, 0, 2, 2, 1, 0]),
        ("Dm",      [0, 0, 0, 2, 3, 1]),
        ("Em",      [0, 2, 2, 0, 0, 0]),

        // ═══════════════════════════════════════════
        // 七和弦 (7th)
        // ═══════════════════════════════════════════
        ("A7",      [0, 0, 2, 0, 2, 0]),
        ("B7",      [0, 2, 1, 2, 0, 2]),
        ("C7",      [0, 3, 2, 3, 1, 0]),
        ("D7",      [0, 0, 0, 2, 1, 2]),
        ("E7",      [0, 2, 0, 1, 0, 0]),
        ("G7",      [3, 2, 0, 0, 0, 1]),

        // ═══════════════════════════════════════════
        // 小七和弦 (Minor 7th)
        // ═══════════════════════════════════════════
        ("Am7",     [0, 0, 2, 0, 1, 0]),
        ("Dm7",     [0, 0, 0, 2, 1, 1]),
        ("Em7",     [0, 2, 0, 0, 0, 0]),
        ("Em7",     [0, 2, 2, 0, 3, 0]),   // 变体

        // ═══════════════════════════════════════════
        // 大七和弦 (Major 7th)
        // ═══════════════════════════════════════════
        ("Cmaj7",   [0, 3, 2, 0, 0, 0]),
        ("Dmaj7",   [0, 0, 0, 2, 2, 2]),
        ("Fmaj7",   [1, 3, 3, 2, 1, 0]),
        ("Gmaj7",   [3, 2, 0, 0, 0, 2]),

        // ═══════════════════════════════════════════
        // 挂留和弦 (Suspended)
        // ═══════════════════════════════════════════
        ("Dsus2",   [0, 0, 0, 2, 3, 0]),
        ("Dsus4",   [0, 0, 0, 2, 3, 3]),
        ("Asus2",   [0, 0, 2, 2, 0, 0]),
        ("Asus4",   [0, 0, 2, 2, 3, 0]),
        ("Esus4",   [0, 2, 2, 2, 0, 0]),

        // ═══════════════════════════════════════════
        // 增/减和弦
        // ═══════════════════════════════════════════
        ("Bdim",    [0, 2, 0, 1, 0, 1]),

        // ═══════════════════════════════════════════
        // 横按和弦 (Barre) — F 型
        // ═══════════════════════════════════════════
        ("F",       [1, 3, 3, 2, 1, 1]),
        ("F#/Gb",   [2, 4, 4, 3, 2, 2]),
        ("B",       [2, 4, 4, 4, 2, 2]),    // A 型横按
        ("Bm",      [2, 4, 4, 3, 2, 2]),    // Am 型横按 (实际上是 F#m 型)

        // ═══════════════════════════════════════════
        // 加音和弦
        // ═══════════════════════════════════════════
        ("Cadd9",   [0, 3, 2, 0, 3, 0]),
    ]

    /// 尝试识别当前按弦状态对应的和弦名称
    static func recognize(_ state: FretState) -> String? {
        let current = (0..<GuitarConstants.stringCount).map { state.fret(for: $0) }

        // 全空弦不算和弦
        if current.allSatisfy({ $0 == 0 }) { return nil }

        // 精确匹配
        for chord in chordDatabase {
            if matches(current: current, pattern: chord.frets) {
                return chord.name
            }
        }

        return nil
    }

    /// 匹配逻辑：忽略 pattern 中为 -1 的弦，其余弦必须精确匹配
    private static func matches(current: [Int], pattern: [Int]) -> Bool {
        guard current.count == pattern.count else { return false }
        for i in 0..<current.count {
            if pattern[i] == -1 { continue }
            if current[i] != pattern[i] { return false }
        }
        return true
    }
}
