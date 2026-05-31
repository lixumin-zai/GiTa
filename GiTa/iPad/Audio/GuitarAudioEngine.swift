import AVFoundation

/// 6 弦吉他音频引擎
/// 管理 6 个独立的 StringSynthesizer + 效果链
final class GuitarAudioEngine {

    // MARK: - 音频组件

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let strings: [StringSynthesizer]
    private let effectsChain: EffectsChain

    /// 混合缓冲区（预分配，避免实时线程分配）
    private let mixBuffer: UnsafeMutablePointer<Float>
    private let tempBuffer: UnsafeMutablePointer<Float>
    private let maxFrames = 1024

    /// 音频采样率
    private let sampleRate: Double

    /// 主音量 (0.0 ~ 1.0)
    var volume: Float = 0.8

    /// 实时声音响度 (0.0 ~ 1.0)
    var currentLoudness: Float = 0.0

    /// 当前按弦状态（从网络接收）
    private(set) var currentFretState = FretState.empty

    // MARK: - 初始化

    init() {
        // 获取设备采样率
        let sr = AVAudioSession.sharedInstance().sampleRate > 0
            ? AVAudioSession.sharedInstance().sampleRate
            : 48000
        sampleRate = sr

        // 创建 6 个弦合成器
        strings = (0..<GuitarConstants.stringCount).map { _ in
            StringSynthesizer(sampleRate: sr)
        }

        // 创建效果链
        effectsChain = EffectsChain()

        // 预分配缓冲区
        mixBuffer = UnsafeMutablePointer<Float>.allocate(capacity: maxFrames)
        mixBuffer.initialize(repeating: 0, count: maxFrames)
        tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: maxFrames)
        tempBuffer.initialize(repeating: 0, count: maxFrames)

        // sourceNode 先置为 nil（由 setupEngine 赋值）
        sourceNode = nil

        setupAudioSession()
        setupEngine()
    }

    deinit {
        engine.stop()
        mixBuffer.deallocate()
        tempBuffer.deallocate()
    }

    // MARK: - 音频会话配置

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setPreferredSampleRate(sampleRate)
            // 设置低延迟缓冲区（128 帧 ≈ 2.7ms @ 48kHz）
            try session.setPreferredIOBufferDuration(128.0 / sampleRate)
            try session.setActive(true)
        } catch {
            print("[GuitarAudioEngine] Audio session error: \(error)")
        }
    }

    // MARK: - 引擎设置

    private func setupEngine() {
        let localStrings = strings
        let localMixBuf = mixBuffer
        let localTempBuf = tempBuffer
        let localMaxFrames = maxFrames

        // 创建源节点（实时音频回调）
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)
            let vol = self?.volume ?? 0.8

            // 清空混合缓冲区
            for i in 0..<min(frames, localMaxFrames) {
                localMixBuf[i] = 0
            }

            // 渲染每根弦并混合
            for string in localStrings {
                if string.isActive {
                    string.render(frameCount: min(frames, localMaxFrames), output: localTempBuf)
                    for i in 0..<min(frames, localMaxFrames) {
                        localMixBuf[i] += localTempBuf[i]
                    }
                }
            }

            // 写入输出缓冲区（所有声道）
            var maxAmp: Float = 0.0
            for buffer in ablPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<min(frames, Int(buffer.mDataByteSize) / MemoryLayout<Float>.size) {
                    // 混音后的信号 × 主音量，并做简单软限幅
                    let sample = localMixBuf[i] * vol
                    let absSample = abs(sample)
                    if absSample > maxAmp {
                        maxAmp = absSample
                    }
                    data[i] = max(-1.0, min(1.0, sample))
                }
            }

            if let self = self {
                let current = self.currentLoudness
                self.currentLoudness = max(maxAmp, current * 0.9)
            }

            return noErr
        }
        sourceNode = node

        // 组装信号链：源节点 → 效果链 → 输出
        engine.attach(node)
        effectsChain.attach(to: engine)

        // 创建标准音频格式
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // 源节点 → 效果链入口
        engine.connect(node, to: effectsChain.inputNode, format: format)

        // 效果链出口 → 主输出
        effectsChain.connect(to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
    }

    // MARK: - 启动/停止

    func start() {
        do {
            try engine.start()
            print("[GuitarAudioEngine] Started (sample rate: \(sampleRate))")
        } catch {
            print("[GuitarAudioEngine] Failed to start: \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    // MARK: - 按弦状态更新

    /// 更新按弦状态（从网络接收）
    func updateFretState(_ state: FretState) {
        currentFretState = state
    }

    // MARK: - 拨弦接口

    /// 拨单弦
    /// - Parameters:
    ///   - stringIndex: 弦索引 (0=6弦, 5=1弦)
    ///   - amplitude: 力度 (0.0 ~ 1.0)
    func pluckString(_ stringIndex: Int, amplitude: Float = 0.8) {
        guard stringIndex >= 0, stringIndex < GuitarConstants.stringCount else { return }
        let freq = currentFretState.frequency(for: stringIndex)
        strings[stringIndex].pluck(frequency: freq, amplitude: amplitude)
    }

    /// 扫弦
    /// - Parameters:
    ///   - fromString: 起始弦
    ///   - toString: 结束弦
    ///   - velocity: 扫弦速度 (影响间隔时间和力度)
    ///   - amplitude: 基础力度
    func strum(from fromString: Int, to toString: Int, velocity: Double = 1.0, amplitude: Float = 0.7) {
        let start = min(fromString, toString)
        let end = max(fromString, toString)
        let direction = fromString < toString ? 1 : -1

        // 扫弦间隔：速度越快，间隔越短（10ms ~ 50ms）
        let intervalMs = max(10, min(50, 30.0 / velocity))

        for i in 0...(end - start) {
            let stringIdx = direction > 0 ? start + i : end - i
            let delay = Double(i) * intervalMs / 1000.0
            let amp = amplitude * Float.random(in: 0.85...1.0) // 轻微随机化

            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.pluckString(stringIdx, amplitude: amp)
            }
        }
    }

    /// 静音所有弦
    func muteAll() {
        for string in strings {
            string.mute()
        }
    }

    // MARK: - 效果控制

    /// 设置混响量 (0.0 ~ 1.0)
    func setReverb(_ amount: Float) {
        effectsChain.setReverbMix(amount)
    }

    /// 设置吉他类型预设
    func setGuitarType(_ type: GuitarType) {
        effectsChain.applyPreset(type)
    }
}

/// 吉他类型
enum GuitarType: String, CaseIterable, Identifiable {
    case acoustic  = "木吉他"
    case electric  = "电吉他"
    case classical = "古典吉他"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .acoustic:  return "guitars"
        case .electric:  return "bolt"
        case .classical: return "music.note"
        }
    }
}
