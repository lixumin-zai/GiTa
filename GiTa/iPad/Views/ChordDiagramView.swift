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
            // 标题
            Text(chordName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

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

    // MARK: - 和弦名称推断

    private var chordName: String {
        let activeFrets = (0..<GuitarConstants.stringCount).map { fretState.fret(for: $0) }
        if activeFrets.allSatisfy({ $0 == 0 }) { return "Open" }
        // 简单显示按弦音名
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

        let margin: CGFloat = 15
        let topMargin: CGFloat = 20
        let width = size.width - margin * 2
        let height = size.height - topMargin - 10
        let stringSpacing = width / CGFloat(stringCount - 1)
        let fretSpacing = height / CGFloat(fretCount)

        // 品位标号
        if range.lowerBound > 1 {
            context.draw(
                Text("\(range.lowerBound)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6)),
                at: CGPoint(x: margin - 12, y: topMargin + fretSpacing * 0.5)
            )
        }

        // 画品丝（水平线）
        for i in 0...fretCount {
            let y = topMargin + CGFloat(i) * fretSpacing
            var path = Path()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: margin + width, y: y))
            context.stroke(path, with: .color(.white.opacity(i == 0 && range.lowerBound <= 1 ? 0.8 : 0.3)),
                          lineWidth: i == 0 && range.lowerBound <= 1 ? 3 : 1)
        }

        // 画弦（垂直线）
        for i in 0..<stringCount {
            let x = margin + CGFloat(i) * stringSpacing
            var path = Path()
            path.move(to: CGPoint(x: x, y: topMargin))
            path.addLine(to: CGPoint(x: x, y: topMargin + height))
            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1)
        }

        // 画按弦位置
        for i in 0..<stringCount {
            let fret = fretState.fret(for: i)
            let x = margin + CGFloat(i) * stringSpacing

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
