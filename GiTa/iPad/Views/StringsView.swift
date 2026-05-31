import UIKit

/// 拨弦触控视图 — 6 根垂直弦，支持单弦拨弦和扫弦
final class StringsStrumsView: UIView {

    // MARK: - 回调

    /// 拨弦回调：(弦索引, 力度)
    var onStringPlucked: ((Int, Float) -> Void)?

    /// 扫弦回调：(起始弦, 结束弦, 速度)
    var onStrum: ((Int, Int, Double) -> Void)?

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

    /// 弦的 X 坐标
    private func stringX(_ index: Int) -> CGFloat {
        let margin: CGFloat = 30
        let usableWidth = bounds.width - margin * 2
        let spacing = usableWidth / CGFloat(GuitarConstants.stringCount - 1)
        return margin + CGFloat(index) * spacing
    }

    /// 根据 X 坐标找到最近的弦
    private func nearestString(for x: CGFloat) -> Int {
        let margin: CGFloat = 30
        let usableWidth = bounds.width - margin * 2
        let spacing = usableWidth / CGFloat(GuitarConstants.stringCount - 1)
        var index = Int(round((x - margin) / spacing))
        index = max(0, min(index, GuitarConstants.stringCount - 1))
        return index
    }

    // MARK: - 触控

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)
            let string = nearestString(for: pos.x)
            touchStartString[touch] = string
            touchStartTime[touch] = touch.timestamp
            touchLastString[touch] = string

            // 立即触发拨弦
            triggerPluck(string)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pos = touch.location(in: self)
            let currentString = nearestString(for: pos.x)

            if let lastString = touchLastString[touch], currentString != lastString {
                // 扫过了新的弦 → 触发拨弦
                triggerPluck(currentString)
                touchLastString[touch] = currentString
            }
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

        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 95
        let stringTop = topMargin
        let stringBottom = bounds.height - bottomMargin

        for i in 0..<GuitarConstants.stringCount {
            let x = stringX(i)
            let color = stringColors[i]
            let width = stringWidths[i]
            let amplitude = stringVibrationAmplitudes[i]
            let phase = stringVibrationPhases[i]

            if amplitude > 0.1 {
                // 振动中：画正弦波形弦
                drawVibratingString(ctx, x: x, top: stringTop, bottom: stringBottom,
                                    color: color, width: width,
                                    amplitude: amplitude, phase: phase)
            } else {
                // 静止：画直线弦
                drawStaticString(ctx, x: x, top: stringTop, bottom: stringBottom,
                                 color: color, width: width)
            }

            // 弦顶部音名标签
            drawStringLabel(ctx, index: i, x: x, y: stringTop - 25)

            // 弦底部当前音名
            drawCurrentNote(ctx, index: i, x: x, y: stringBottom + 15)
        }
    }

    private func drawStaticString(_ ctx: CGContext, x: CGFloat, top: CGFloat, bottom: CGFloat,
                                   color: UIColor, width: CGFloat) {
        // 发光效果
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 6, color: color.withAlphaComponent(0.4).cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.move(to: CGPoint(x: x, y: top))
        ctx.addLine(to: CGPoint(x: x, y: bottom))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawVibratingString(_ ctx: CGContext, x: CGFloat, top: CGFloat, bottom: CGFloat,
                                      color: UIColor, width: CGFloat,
                                      amplitude: CGFloat, phase: CGFloat) {
        let path = CGMutablePath()
        let length = bottom - top
        let segments = 50

        path.move(to: CGPoint(x: x, y: top))

        for s in 1...segments {
            let t = CGFloat(s) / CGFloat(segments)
            let y = top + t * length
            // 两端固定，中间最大振幅的正弦包络
            let envelope = sin(.pi * t)
            let vibration = sin(phase + t * .pi * 6) * amplitude * envelope
            path.addLine(to: CGPoint(x: x + vibration, y: y))
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
        nsString.draw(at: CGPoint(x: x - size.width / 2, y: y), withAttributes: attributes)
    }

    private func drawCurrentNote(_ ctx: CGContext, index: Int, x: CGFloat, y: CGFloat) {
        guard index < currentNotes.count else { return }
        let name = currentNotes[index]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        let nsString = name as NSString
        let size = nsString.size(withAttributes: attributes)
        nsString.draw(at: CGPoint(x: x - size.width / 2, y: y), withAttributes: attributes)
    }

    /// 更新当前音名显示
    func updateNotes(_ fretState: FretState) {
        for i in 0..<GuitarConstants.stringCount {
            currentNotes[i] = fretState.noteName(for: i)
        }
        setNeedsDisplay()
    }
}
