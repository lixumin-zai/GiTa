import UIKit

/// UIKit 指板视图 — 处理多点触控、绘制品丝/弦/按弦指示器
/// 通过 UIViewRepresentable 桥接到 SwiftUI
final class FretboardView: UIView {

    // MARK: - 回调

    /// 按弦回调：(弦索引, 品位)
    var onStringPressed: ((Int, Int) -> Void)?

    /// 松弦回调：(弦索引)
    var onStringReleased: ((Int) -> Void)?

    // MARK: - 状态

    /// 当前所有活跃触点 → (弦, 品)
    private var activeTouches: [UITouch: (string: Int, fret: Int)] = [:]

    /// 每根弦当前按下的品位（用于绘制指示器）
    private var pressedFrets: [Int: Int] = [:] // [弦索引: 品位]

    /// 指板尺寸整体缩放比例 (0.8 ~ 1.2)
    private var fretboardScale: CGFloat = 1.0

    /// 指板宽度拉伸倍数 (1.0 ~ 3.0) - 用于分离品距
    private var fretWidthMultiplier: CGFloat = 1.0

    /// 指板横向滚动偏移量 (用于音量键平移)
    private var fretboardOffsetX: CGFloat = 0.0

    // MARK: - 控制

    func updateSettings(scale: CGFloat, widthMultiplier: CGFloat, offsetX: CGFloat) {
        var changed = false
        if fretboardScale != scale {
            fretboardScale = scale
            changed = true
        }
        if fretWidthMultiplier != widthMultiplier {
            fretWidthMultiplier = widthMultiplier
            changed = true
        }
        if fretboardOffsetX != offsetX {
            fretboardOffsetX = offsetX
            changed = true
        }
        if changed { setNeedsDisplay() }
    }

    // MARK: - 外观常量

    /// 弦的颜色（从 6 弦到 1 弦，由金铜渐变到银白）
    private let stringColors: [UIColor] = [
        UIColor(red: 0.75, green: 0.60, blue: 0.35, alpha: 1.0), // 6 弦 - 金铜
        UIColor(red: 0.78, green: 0.65, blue: 0.40, alpha: 1.0), // 5 弦
        UIColor(red: 0.80, green: 0.72, blue: 0.50, alpha: 1.0), // 4 弦
        UIColor(red: 0.82, green: 0.78, blue: 0.65, alpha: 1.0), // 3 弦
        UIColor(red: 0.85, green: 0.83, blue: 0.78, alpha: 1.0), // 2 弦
        UIColor(red: 0.88, green: 0.87, blue: 0.85, alpha: 1.0), // 1 弦 - 银白
    ]

    /// 弦的粗细（从粗到细）
    private let stringWidths: [CGFloat] = [3.5, 3.0, 2.5, 2.0, 1.5, 1.2]

    /// 品丝颜色
    private let fretWireColor = UIColor(white: 0.75, alpha: 0.9)

    /// 指板背景色（深色花梨木）
    private let boardColor = UIColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 1.0)

    /// 按弦指示器颜色
    private let indicatorColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)

    /// 品位标记点颜色
    private let dotColor = UIColor(white: 0.6, alpha: 0.7)

    // MARK: - 初始化

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        backgroundColor = boardColor
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 布局计算

    /// 获取经过拉伸归一化后的品丝相对位置 (0.0 ~ 0.95)，消除右侧大段留白
    private func stretchedFretPosition(_ fret: Int) -> CGFloat {
        guard fret > 0 else { return 0 }
        let maxFretPos = GuitarConstants.fretPosition(GuitarConstants.fretCount) // 约 0.666
        let originalPos = GuitarConstants.fretPosition(fret)
        let rightPadding: CGFloat = 0.96 // 留出 4% 的右侧边距，饱满且美观
        return CGFloat(originalPos / maxFretPos) * rightPadding
    }

    /// 获取经过拉伸归一化后的品位中心相对位置 (0.0 ~ 0.95)
    private func stretchedFretCenterPosition(_ fret: Int) -> CGFloat {
        guard fret > 0 else { return 0 }
        let maxFretPos = GuitarConstants.fretPosition(GuitarConstants.fretCount)
        let originalPos = GuitarConstants.fretCenterPosition(fret)
        let rightPadding: CGFloat = 0.96
        return CGFloat(originalPos / maxFretPos) * rightPadding
    }

    /// 弦的 Y 坐标
    private func stringY(_ index: Int) -> CGFloat {
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 50
        let usableHeight = (bounds.height - topMargin - bottomMargin) * fretboardScale
        let yStart = topMargin + (bounds.height - topMargin - bottomMargin) * (1 - fretboardScale) / 2
        let spacing = usableHeight / CGFloat(GuitarConstants.stringCount - 1)
        // 将弦的顺序翻转，使 6 弦(index=0) 位于最下方
        let invertedIndex = GuitarConstants.stringCount - 1 - index
        return yStart + CGFloat(invertedIndex) * spacing
    }

    /// 品丝的 X 坐标
    private func fretX(_ fret: Int) -> CGFloat {
        let leftMargin: CGFloat = 70
        let rightMargin: CGFloat = 70
        let nutWidth: CGFloat = 12 // 琴枕宽度
        let usableWidth = (bounds.width - leftMargin - rightMargin - nutWidth) * fretboardScale * fretWidthMultiplier
        let xStart = leftMargin + (bounds.width - leftMargin - rightMargin - nutWidth) * (1 - fretboardScale) / 2
        let position = stretchedFretPosition(fret)
        return xStart + nutWidth + position * usableWidth - fretboardOffsetX
    }

    /// 品位中心 X 坐标
    private func fretCenterX(_ fret: Int) -> CGFloat {
        let leftMargin: CGFloat = 70
        let rightMargin: CGFloat = 70
        let nutWidth: CGFloat = 12
        let usableWidth = (bounds.width - leftMargin - rightMargin - nutWidth) * fretboardScale * fretWidthMultiplier
        let xStart = leftMargin + (bounds.width - leftMargin - rightMargin - nutWidth) * (1 - fretboardScale) / 2
        if fret == 0 { return xStart - 18 - fretboardOffsetX } // 琴枕前方（空弦区中心）
        let position = stretchedFretCenterPosition(fret)
        return xStart + nutWidth + position * usableWidth - fretboardOffsetX
    }

    // MARK: - 触控 → 弦/品映射

    /// 将触控坐标映射到 (弦索引, 品位)
    private func mapToStringAndFret(_ point: CGPoint) -> (string: Int, fret: Int) {
        // 弦：按 Y 坐标找最近 of 弦
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 50
        let usableHeight = (bounds.height - topMargin - bottomMargin) * fretboardScale
        let yStart = topMargin + (bounds.height - topMargin - bottomMargin) * (1 - fretboardScale) / 2
        let spacing = usableHeight / CGFloat(GuitarConstants.stringCount - 1)
        var stringIndex = Int(round((point.y - yStart) / spacing))
        stringIndex = max(0, min(stringIndex, GuitarConstants.stringCount - 1))
        // 翻转 index 与 stringY 的改动相匹配
        stringIndex = GuitarConstants.stringCount - 1 - stringIndex

        // 品：按 X 坐标找品位
        let leftMargin: CGFloat = 70
        let rightMargin: CGFloat = 70
        let nutWidth: CGFloat = 12
        let usableWidth = (bounds.width - leftMargin - rightMargin - nutWidth) * fretboardScale * fretWidthMultiplier
        let xStart = leftMargin + (bounds.width - leftMargin - rightMargin - nutWidth) * (1 - fretboardScale) / 2

        // 添加 offsetX 还原真实的点击位置
        let virtualX = point.x + fretboardOffsetX

        if virtualX <= xStart + nutWidth {
            return (stringIndex, 0) // 空弦区域
        }

        let relativeX = (virtualX - (xStart + nutWidth)) / usableWidth

        // 遍历品位找到触点所在的品位区间
        var fret = 0
        for f in 1...GuitarConstants.fretCount {
            let fretPos = stretchedFretPosition(f)
            if relativeX <= fretPos {
                fret = f
                break
            }
        }
        if fret == 0 && relativeX > 0 {
            fret = GuitarConstants.fretCount // 超过最后一品
        }

        return (stringIndex, fret)
    }

    // MARK: - 触控事件

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)
            let (string, fret) = mapToStringAndFret(pos)
            activeTouches[touch] = (string, fret)
            pressedFrets[string] = fret
            onStringPressed?(string, fret)
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)
            let (newString, newFret) = mapToStringAndFret(pos)

            if let old = activeTouches[touch] {
                if old.string != newString || old.fret != newFret {
                    // 从旧弦松开
                    if old.string != newString {
                        pressedFrets.removeValue(forKey: old.string)
                        onStringReleased?(old.string)
                    }
                    // 更新到新位置
                    activeTouches[touch] = (newString, newFret)
                    pressedFrets[newString] = newFret
                    onStringPressed?(newString, newFret)
                }
            }
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let old = activeTouches.removeValue(forKey: touch) {
                // 检查该弦是否还有其他手指按着
                let stillPressed = activeTouches.values.contains { $0.string == old.string }
                if !stillPressed {
                    pressedFrets.removeValue(forKey: old.string)
                    onStringReleased?(old.string)
                }
            }
        }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - 绘制

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 1. 绘制背景木纹效果
        drawWoodTexture(ctx)

        // 2. 绘制琴枕（nut）
        drawNut(ctx)

        // 3. 绘制品丝
        drawFretWires(ctx)

        // 4. 绘制品位标记点
        drawFretDots(ctx)

        // 5. 绘制琴弦
        drawStrings(ctx)

        // 6. 绘制按弦指示器
        drawPressIndicators(ctx)

        // 7. 绘制品位数字
        drawFretNumbers(ctx)
    }

    private func drawWoodTexture(_ ctx: CGContext) {
        // 简洁的深色指板背景
        ctx.setFillColor(boardColor.cgColor)
        ctx.fill(bounds)

        // 模拟木纹：绘制半透明水平线
        ctx.setStrokeColor(UIColor(white: 0.15, alpha: 0.3).cgColor)
        ctx.setLineWidth(0.5)
        for y in stride(from: 0, through: bounds.height, by: 3) {
            let offset = CGFloat.random(in: -0.5...0.5)
            ctx.move(to: CGPoint(x: 0, y: y + offset))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y + offset))
        }
        ctx.strokePath()
    }

    private func drawNut(_ ctx: CGContext) {
        let leftMargin: CGFloat = 70
        let xStart = leftMargin + (bounds.width - leftMargin - 70 - 12) * (1 - fretboardScale) / 2 - fretboardOffsetX
        let nutRect = CGRect(x: xStart, y: 0, width: 12, height: bounds.height)
        ctx.setFillColor(UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0).cgColor)
        ctx.fill(nutRect)

        // 琴枕右边缘阴影
        ctx.setStrokeColor(UIColor(white: 0.3, alpha: 0.5).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: xStart + 12, y: 0))
        ctx.addLine(to: CGPoint(x: xStart + 12, y: bounds.height))
        ctx.strokePath()
    }

    private func drawFretWires(_ ctx: CGContext) {
        ctx.setStrokeColor(fretWireColor.cgColor)
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 50
        
        let yStart = topMargin + (bounds.height - topMargin - bottomMargin) * (1 - fretboardScale) / 2
        let usableHeight = (bounds.height - topMargin - bottomMargin) * fretboardScale

        for fret in 1...GuitarConstants.fretCount {
            let x = fretX(fret)
            ctx.setLineWidth(fret == 12 ? 2.5 : 1.5) // 12 品加粗
            ctx.move(to: CGPoint(x: x, y: yStart - 15))
            ctx.addLine(to: CGPoint(x: x, y: yStart + usableHeight + 15))
            ctx.strokePath()
        }
    }

    private func drawFretDots(_ ctx: CGContext) {
        let dotRadius: CGFloat = 4
        ctx.setFillColor(dotColor.cgColor)

        for fret in 1...GuitarConstants.fretCount {
            let x = fretCenterX(fret)

            if GuitarConstants.singleDotFrets.contains(fret) {
                // 单点：放在第 3、4 弦的中间（物理吉他完美复刻）
                let y = (stringY(2) + stringY(3)) / 2
                ctx.fillEllipse(in: CGRect(
                    x: x - dotRadius, y: y - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
            } else if GuitarConstants.doubleDotFrets.contains(fret) {
                // 双点：分别放在第 2、3 弦之间，以及 4、5 弦之间
                let y1 = (stringY(1) + stringY(2)) / 2
                let y2 = (stringY(3) + stringY(4)) / 2
                ctx.fillEllipse(in: CGRect(
                    x: x - dotRadius, y: y1 - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
                ctx.fillEllipse(in: CGRect(
                    x: x - dotRadius, y: y2 - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
            }
        }
    }

    private func drawStrings(_ ctx: CGContext) {
        for i in 0..<GuitarConstants.stringCount {
            let y = stringY(i)
            ctx.setStrokeColor(stringColors[i].cgColor)
            ctx.setLineWidth(stringWidths[i])
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y))
            ctx.strokePath()
        }
    }

    private func drawPressIndicators(_ ctx: CGContext) {
        let radius: CGFloat = 14

        for (stringIndex, fret) in pressedFrets {
            guard fret > 0 else { continue }
            let x = fretCenterX(fret)
            let y = stringY(stringIndex)

            // 发光效果（外圈模糊）
            let glowRadius: CGFloat = radius + 8
            let glowColor = indicatorColor.withAlphaComponent(0.25).cgColor
            ctx.setFillColor(glowColor)
            ctx.fillEllipse(in: CGRect(
                x: x - glowRadius, y: y - glowRadius,
                width: glowRadius * 2, height: glowRadius * 2
            ))

            // 内圈实心
            ctx.setFillColor(indicatorColor.withAlphaComponent(0.8).cgColor)
            ctx.fillEllipse(in: CGRect(
                x: x - radius, y: y - radius,
                width: radius * 2, height: radius * 2
            ))

            // 中心高亮
            let innerRadius: CGFloat = radius * 0.4
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            ctx.fillEllipse(in: CGRect(
                x: x - innerRadius, y: y - innerRadius,
                width: innerRadius * 2, height: innerRadius * 2
            ))
        }
    }

    private func drawFretNumbers(_ ctx: CGContext) {
        // 放置在最下方（现在 6 弦/index=0 位于最下方）
        let y = stringY(0) + 20

        let font = UIFont.systemFont(ofSize: 12, weight: .bold)
        let textColor = UIColor(white: 0.6, alpha: 0.7)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        for fret in 1...GuitarConstants.fretCount {
            let x = fretCenterX(fret)
            let text = "\(fret)" as NSString
            let size = text.size(withAttributes: attributes)

            let rect = CGRect(
                x: x - size.width / 2,
                y: y,
                width: size.width,
                height: size.height
            )

            UIGraphicsPushContext(ctx)
            text.draw(in: rect, withAttributes: attributes)
            UIGraphicsPopContext()
        }
    }
}
