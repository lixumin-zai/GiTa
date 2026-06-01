import AVFoundation

/// 音频效果链：Delay(残留/共鸣) + 混响 + EQ
/// 不同吉他类型有不同的效果预设
/// 与琴体共振配合使用时，EQ 更多扮演"后期润色"角色
final class EffectsChain {

    // MARK: - 效果节点

    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay() // 🚀 新增：模拟物理琴箱的声音残留和反射
    private let eq = AVAudioUnitEQ(numberOfBands: 3)

    /// 信号链入口
    var inputNode: AVAudioNode { eq }

    // MARK: - 初始化

    init() {
        setupDefaultPreset()
    }

    // MARK: - 引擎集成

    /// 将效果节点附加到音频引擎
    func attach(to engine: AVAudioEngine) {
        engine.attach(eq)
        engine.attach(delay)
        engine.attach(reverb)
    }

    /// 连接效果链到目标节点
    /// 信号流：输入 → EQ → Delay(残响) → 混响 → 输出
    func connect(to outputNode: AVAudioNode, format: AVAudioFormat) {
        let engine = reverb.engine!
        engine.connect(eq, to: delay, format: format)
        engine.connect(delay, to: reverb, format: format)
        engine.connect(reverb, to: outputNode, format: format)
    }

    // MARK: - 效果控制

    /// 设置混响混合量 (0.0 ~ 1.0)
    func setReverbMix(_ mix: Float) {
        reverb.wetDryMix = mix * 60 // 增大最大混响范围 (0-60)
        delay.wetDryMix = mix * 40  // 声音残留量也随之动态放大
    }

    /// 应用吉他类型预设
    func applyPreset(_ type: GuitarType) {
        switch type {
        case .acoustic:
            applyAcousticPreset()
        case .electric:
            applyElectricPreset()
        case .classical:
            applyClassicalPreset()
        }
    }

    // MARK: - 预设

    private func setupDefaultPreset() {
        applyAcousticPreset()
    }

    /// 木吉他：温暖自然混响，琴体共振已提供大部分低频温暖度
    /// EQ 主要做微调润色
    private func applyAcousticPreset() {
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 20  // 提升默认混响
        
        // 🚀 物理琴箱的残响模拟
        delay.delayTime = 0.035 // 35ms反射，模拟大尺寸木质琴箱
        delay.feedback = 35     // 较高反馈，让拨弦后声音能“绕梁”残留更久
        delay.lowPassCutoff = 3000 // 残响要沉稳、温暖，去除刺耳的高频
        delay.wetDryMix = 20

        // 低频微增（补充琴体共振之外的温暖底噪）
        let band0 = eq.bands[0]
        band0.filterType = .lowShelf
        band0.frequency = 150
        band0.gain = 2.5
        band0.bypass = false

        // 中频：吉他的"木头"质感
        let band1 = eq.bands[1]
        band1.filterType = .parametric
        band1.frequency = 1200
        band1.bandwidth = 1.5
        band1.gain = 1.5
        band1.bypass = false

        // 高频：自然的高频滚降，消除合成器的金属光泽
        let band2 = eq.bands[2]
        band2.filterType = .highShelf
        band2.frequency = 4500
        band2.gain = -4.0
        band2.bypass = false
    }

    /// 电吉他：短混响，中高频增强，轻微过载感
    private func applyElectricPreset() {
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 15
        
        // 🚀 模拟音箱弹簧混响的金属残留
        delay.delayTime = 0.12
        delay.feedback = 20
        delay.lowPassCutoff = 5500
        delay.wetDryMix = 15

        let band0 = eq.bands[0]
        band0.filterType = .lowShelf
        band0.frequency = 150
        band0.gain = -2.0
        band0.bypass = false

        let band1 = eq.bands[1]
        band1.filterType = .parametric
        band1.frequency = 2000
        band1.bandwidth = 2.0
        band1.gain = 4.0
        band1.bypass = false

        let band2 = eq.bands[2]
        band2.filterType = .highShelf
        band2.frequency = 6000
        band2.gain = 3.0
        band2.bypass = false
    }

    /// 古典吉他：丰富混响，自然均衡，更多琴体共振
    private func applyClassicalPreset() {
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 30  // 极强的音乐厅空间感
        
        // 🚀 尼龙弦特有的宽大箱体低频残留
        delay.delayTime = 0.045
        delay.feedback = 40     // 尼龙弦残留时间更长
        delay.lowPassCutoff = 2500 // 非常温暖的暗色调残响
        delay.wetDryMix = 25

        let band0 = eq.bands[0]
        band0.filterType = .lowShelf
        band0.frequency = 200
        band0.gain = 3.0    // 增强古典吉他尼龙弦的温暖度
        band0.bypass = false

        let band1 = eq.bands[1]
        band1.filterType = .parametric
        band1.frequency = 800
        band1.bandwidth = 1.0
        band1.gain = 1.5
        band1.bypass = false

        // 古典吉他高频更暗，尼龙弦缺少金属光泽
        let band2 = eq.bands[2]
        band2.filterType = .highShelf
        band2.frequency = 4000
        band2.gain = -4.0   // 更多高频衰减
        band2.bypass = false
    }
}
