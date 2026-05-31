import AVFoundation

/// 音频效果链：混响 + EQ
/// 不同吉他类型有不同的效果预设
/// 与琴体共振配合使用时，EQ 更多扮演"后期润色"角色
final class EffectsChain {

    // MARK: - 效果节点

    private let reverb = AVAudioUnitReverb()
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
        engine.attach(reverb)
    }

    /// 连接效果链到目标节点
    /// 信号流：输入 → EQ → 混响 → 输出
    func connect(to outputNode: AVAudioNode, format: AVAudioFormat) {
        let engine = reverb.engine!
        engine.connect(eq, to: reverb, format: format)
        engine.connect(reverb, to: outputNode, format: format)
    }

    // MARK: - 效果控制

    /// 设置混响混合量 (0.0 ~ 1.0)
    func setReverbMix(_ mix: Float) {
        reverb.wetDryMix = mix * 50 // AVAudioUnitReverb 范围是 0-100
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
        reverb.wetDryMix = 15  // 适度混响，不掩盖琴体共振的自然感

        // 低频微增（补充琴体共振之外的温暖底噪）
        let band0 = eq.bands[0]
        band0.filterType = .lowShelf
        band0.frequency = 150
        band0.gain = 2.0    // 轻微增强，琴体共振已覆盖主要低频
        band0.bypass = false

        // 中频：吉他的"木头"质感
        let band1 = eq.bands[1]
        band1.filterType = .parametric
        band1.frequency = 1200
        band1.bandwidth = 1.5
        band1.gain = 1.5    // 轻微提升中高频存在感
        band1.bypass = false

        // 高频：自然的高频滚降，消除合成器的金属光泽
        let band2 = eq.bands[2]
        band2.filterType = .highShelf
        band2.frequency = 4500
        band2.gain = -4.0   // 大幅衰减高频，让音色温暖柔和
        band2.bypass = false
    }

    /// 电吉他：短混响，中高频增强，轻微过载感
    private func applyElectricPreset() {
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 10

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
        reverb.wetDryMix = 25  // 古典吉他需要更多厅堂感

        let band0 = eq.bands[0]
        band0.filterType = .lowShelf
        band0.frequency = 200
        band0.gain = 2.5    // 古典吉他尼龙弦的温暖度
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
        band2.gain = -3.0   // 更多高频衰减
        band2.bypass = false
    }
}
