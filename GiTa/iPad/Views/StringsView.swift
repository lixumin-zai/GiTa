import UIKit

/// 拨弦触控视图 — 6 根垂直弦，支持单弦拨弦和扫弦
final class StringsStrumsView: UIView {

    // MARK: - 回调

    /// 拨弦回调：(弦索引, 力度)
    var onStringPlucked: ((Int, Float) -> Void)?

    /// 扫弦回调：(起始弦, 结束弦, 速度)
    var onStrum: ((Int, Int, Double) -> Void)?

    /// 敲击面板回调
    var onKnock: (() -> Void)?

    // MARK: - 状态

    /// 当前每根弦的发声音名（用于显示）
    var currentNotes: [String] = GuitarConstants.openStringNames

    /// 弦振动动画状态
    private var stringAnimations: [Int: CADisplayLink] = [:]
    private var stringVibrationAmplitudes: [CGFloat] = Array(repeating: 0, count: GuitarConstants.stringCount)
    private var stringVibrationPhases: [CGFloat] = Array(repeating: 0, count: GuitarConstants.stringCount)

    /// 触控跟踪（用于扫弦检测）
    private var touchStartString: [UITouch: Int] = [:]
    private var touchStartTime: [UITouch: TimeInterval] = [:]
    private var touchLastString: [UITouch: Int] = [:]
    private var touchLastY: [UITouch: CGFloat] = [:]

    /// 显示链接（统一刷新振动动画）
    private var displayLink: CADisplayLink?

    // MARK: - 外观

    /// 弦的颜色（彩虹色系，与 iPad 界面匹配）
    private let stringColors: [UIColor] = [
        UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0),   // 青色 E2
        UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0),   // 橙色 A2
        UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1.0),   // 绿色 D3
        UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0),   // 蓝色 G3
        UIColor(red: 0.8, green: 0.3, blue: 1.0, alpha: 1.0),   // 紫色 B3
        UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0),  // 金色 E4
    ]

    /// 弦的粗细
    private let stringWidths: [CGFloat] = [4.0, 3.5, 3.0, 2.5, 2.0, 1.5]

    // MARK: - 初始化

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        backgroundColor = .clear
        contentMode = .redraw
        clipsToBounds = true
        setupDisplayLink()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - 显示链接

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(animationTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func animationTick() {
        var needsRedraw = false
        for i in 0..<GuitarConstants.stringCount {
            if stringVibrationAmplitudes[i] > 0.001 {
                stringVibrationAmplitudes[i] *= 0.97  // 衰减
                stringVibrationPhases[i] += 0.3       // 频率
                needsRedraw = true
            } else {
                stringVibrationAmplitudes[i] = 0
            }
        }
        if needsRedraw {
            setNeedsDisplay()
        }
    }

    // MARK: - 布局

    /// 弦的 Y 坐标
    private func stringY(_ index: Int) -> CGFloat {
        let topMargin: CGFloat = 240
        let bottomMargin: CGFloat = 240
        let usableHeight = bounds.height - topMargin - bottomMargin
        let spacing = usableHeight / CGFloat(GuitarConstants.stringCount - 1)
        return topMargin + CGFloat(index) * spacing
    }

    /// 根据 Y 坐标找到最近的弦
    private func nearestString(for y: CGFloat) -> Int {
        let topMargin: CGFloat = 240
        let bottomMargin: CGFloat = 240
        let usableHeight = bounds.height - topMargin - bottomMargin
        let spacing = usableHeight / CGFloat(GuitarConstants.stringCount - 1)
        var index = Int(round((y - topMargin) / spacing))
        index = max(0, min(index, GuitarConstants.stringCount - 1))
        return index
    }

    // MARK: - 触控

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)
            
            let topMargin: CGFloat = 240
            let bottomMargin: CGFloat = 240
            
            // 🚀 判断是否在琴弦区之外的留白（留 40pt 余量给第1/6弦防误触）
            if pos.y < topMargin - 40 || pos.y > bounds.height - bottomMargin + 40 {
                onKnock?()
                continue // 敲击事件，不再记录为拨弦
            }
            
            let string = nearestString(for: pos.y)
            touchStartString[touch] = string
            touchStartTime[touch] = touch.timestamp
            touchLastString[touch] = string
            touchLastY[touch] = pos.y

            // 立即触发当前触摸位置最近弦的拨片
            triggerPluck(string)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)
            guard let lastY = touchLastY[touch] else {
                touchLastY[touch] = pos.y
                continue
            }

            // 🚀 物理跨越检测：如果手指本次移动横穿了任何一根弦的实际 Y 坐标，立即触发拨弦！
            let minY = min(lastY, pos.y)
            let maxY = max(lastY, pos.y)

            for i in 0..<GuitarConstants.stringCount {
                let yCoord = stringY(i)
                if yCoord >= minY && yCoord <= maxY {
                    // 跨越了该弦的实际坐标 → 完美触发拨片！
                    triggerPluck(i)
                }
            }

            // 更新上一次的 Y 坐标
            touchLastY[touch] = pos.y

            // 保持对扫弦方向和范围的跟踪（用于 touchesEnded 判定扫弦）
            let currentString = nearestString(for: pos.y)
            touchLastString[touch] = currentString
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // 检查是否是扫弦（跨越了多根弦）
            if let startString = touchStartString[touch],
               let lastString = touchLastString[touch],
               let startTime = touchStartTime[touch],
               startString != lastString {
                let duration = touch.timestamp - startTime
                let velocity = Double(abs(lastString - startString)) / max(duration, 0.01)
                onStrum?(startString, lastString, velocity)
            }

            touchStartString.removeValue(forKey: touch)
            touchStartTime.removeValue(forKey: touch)
            touchLastString.removeValue(forKey: touch)
            touchLastY.removeValue(forKey: touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - 拨弦触发

    private func triggerPluck(_ stringIndex: Int) {
        // 触发振动动画
        stringVibrationAmplitudes[stringIndex] = 8.0
        stringVibrationPhases[stringIndex] = 0

        // 回调
        onStringPlucked?(stringIndex, 0.8)
        setNeedsDisplay()
    }

    // MARK: - 绘制

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let leftMargin: CGFloat = 60
        let rightMargin: CGFloat = bounds.width - 60

        for i in 0..<GuitarConstants.stringCount {
            let y = stringY(i)
            let color = stringColors[i]
            let width = stringWidths[i]
            let amplitude = stringVibrationAmplitudes[i]
            let phase = stringVibrationPhases[i]

            if amplitude > 0.1 {
                // 振动中：画水平正弦波形弦
                drawVibratingString(ctx, y: y, left: leftMargin, right: rightMargin,
                                    color: color, width: width,
                                    amplitude: amplitude, phase: phase)
            } else {
                // 静止：画水平直线弦
                drawStaticString(ctx, y: y, left: leftMargin, right: rightMargin,
                                 color: color, width: width)
            }

            // 弦左侧开弦音名标签
            drawStringLabel(ctx, index: i, x: leftMargin - 25, y: y)

            // 弦右侧当前发声音名
            drawCurrentNote(ctx, index: i, x: rightMargin + 15, y: y)
        }
    }

    private func drawStaticString(_ ctx: CGContext, y: CGFloat, left: CGFloat, right: CGFloat,
                                   color: UIColor, width: CGFloat) {
        // 发光效果
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 6, color: color.withAlphaComponent(0.4).cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.move(to: CGPoint(x: left, y: y))
        ctx.addLine(to: CGPoint(x: right, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawVibratingString(_ ctx: CGContext, y: CGFloat, left: CGFloat, right: CGFloat,
                                      color: UIColor, width: CGFloat,
                                      amplitude: CGFloat, phase: CGFloat) {
        let path = CGMutablePath()
        let length = right - left
        let segments = 50

        path.move(to: CGPoint(x: left, y: y))

        for s in 1...segments {
            let t = CGFloat(s) / CGFloat(segments)
            let x = left + t * length
            // 两端固定，中间最大振幅的正弦包络
            let envelope = sin(.pi * t)
            let vibration = sin(phase + t * .pi * 6) * amplitude * envelope
            path.addLine(to: CGPoint(x: x, y: y + vibration))
        }

        // 发光效果
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 10, color: color.withAlphaComponent(0.6).cgColor)
        ctx.setStrokeColor(color.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(width * 1.2)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawStringLabel(_ ctx: CGContext, index: Int, x: CGFloat, y: CGFloat) {
        let name = GuitarConstants.openStringNames[index]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: stringColors[index]
        ]
        let nsString = name as NSString
        let size = nsString.size(withAttributes: attributes)
        nsString.draw(at: CGPoint(x: x - size.width / 2, y: y - size.height / 2), withAttributes: attributes)
    }

    private func drawCurrentNote(_ ctx: CGContext, index: Int, x: CGFloat, y: CGFloat) {
        guard index < currentNotes.count else { return }
        let name = currentNotes[index]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        let nsString = name as NSString
        let size = nsString.size(withAttributes: attributes)
        nsString.draw(at: CGPoint(x: x - size.width / 2, y: y - size.height / 2), withAttributes: attributes)
    }

    /// 更新当前音名显示
    func updateNotes(_ fretState: FretState) {
        for i in 0..<GuitarConstants.stringCount {
            currentNotes[i] = fretState.noteName(for: i)
        }
        setNeedsDisplay()
    }
}
