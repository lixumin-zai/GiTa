import AVFoundation

/// 6 弦吉他音频引擎 (SF2 SoundFont 采样版)
/// 使用 6 个独立的 AVAudioUnitSampler 节点来对应 6 根物理弦，模拟真实的吉他切音/余音特性，同时通过汇聚 Mixer 节点的 Tap 进行响度测算
final class GuitarAudioEngine {

    // MARK: - 音频组件

    private let engine = AVAudioEngine()
    private let samplers: [AVAudioUnitSampler]
    private let percussionSampler = AVAudioUnitSampler()
    private let samplerMixerNode = AVAudioMixerNode()
    private let effectsChain: EffectsChain

    /// 音频采样率
    private let sampleRate: Double

    /// 每一根弦最后一次播放的 MIDI 音符，用于重复拨弦时精准断音
    private var lastMidiNotes: [UInt8?] = Array(repeating: nil, count: GuitarConstants.stringCount)

    /// 6 根琴弦对应的开弦 MIDI 音符 (E2, A2, D3, G3, B3, E4)
    private let openStringMidiNotes: [Int] = [40, 45, 50, 55, 59, 64]

    /// 指向音量和响度的裸指针，彻底消除 Swift ARC 造成的实时音频线程开销，并与视图状态和定时器无缝兼容
    private let volumePointer: UnsafeMutablePointer<Float>
    private let loudnessPointer: UnsafeMutablePointer<Float>

    /// 主音量 (0.0 ~ 1.0)
    var volume: Float {
        get { volumePointer.pointee }
        set {
            volumePointer.pointee = newValue
            // 同步调整 AVAudioEngine 主混音器的输出音量
            engine.mainMixerNode.outputVolume = newValue
        }
    }

    /// 实时声音响度 (0.0 ~ 1.0)
    var currentLoudness: Float {
        loudnessPointer.pointee
    }

    /// 当前按弦状态（从网络接收）
    private(set) var currentFretState = FretState.empty

    // MARK: - 初始化

    init() {
        // 获取设备采样率
        let sr = AVAudioSession.sharedInstance().sampleRate > 0
            ? AVAudioSession.sharedInstance().sampleRate
            : 48000
        sampleRate = sr

        // 创建 6 个采样器（对应 6 根弦）
        samplers = (0..<GuitarConstants.stringCount).map { _ in
            AVAudioUnitSampler()
        }

        // 创建效果链
        effectsChain = EffectsChain()

        // 初始化裸指针，供实时音频处理和外部定时器安全、零锁、无 ARC 访问
        volumePointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        volumePointer.initialize(to: 0.8)

        loudnessPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        loudnessPointer.initialize(to: 0.0)

        setupAudioSession()
        setupEngine()

        // 异步加载默认的原声木吉他音色，防止任何可能的主线程冷启动卡顿
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.loadGuitarPreset(type: .acoustic)
        }
    }

    deinit {
        engine.stop()
        volumePointer.deallocate()
        loudnessPointer.deallocate()
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
        // 1. 挂载 6 个琴弦采样器节点、打击乐节点和琴弦混音器节点
        engine.attach(samplerMixerNode)
        engine.attach(percussionSampler)
        for sampler in samplers {
            engine.attach(sampler)
        }

        // 2. 挂载效果链节点
        effectsChain.attach(to: engine)

        // 创建立体声音频格式
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // 3. 将每个采样器连接至琴弦混音器
        engine.connect(percussionSampler, to: samplerMixerNode, format: format)
        for sampler in samplers {
            engine.connect(sampler, to: samplerMixerNode, format: format)
        }

        // 4. 组装信号流：琴弦混音器 -> 效果链入口 (EQ) -> 混响 -> 主混音节点 -> 输出
        engine.connect(samplerMixerNode, to: effectsChain.inputNode, format: format)
        effectsChain.connect(to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        // 5. 初始化主混音节点音量
        engine.mainMixerNode.outputVolume = volumePointer.pointee

        // 6. 安装音频 Tap 测算混音响度，反馈给 UI 作为律动特效
        setupLoudnessTap()
    }

    // MARK: - 响度测算 Tap

    private func setupLoudnessTap() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let localLoudnessPtr = loudnessPointer

        // 在 samplerMixerNode 的输出上挂载 Tap (256 帧极高响应率)
        samplerMixerNode.installTap(onBus: 0, bufferSize: 256, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)

            var maxAmp: Float = 0.0
            for i in 0..<frameCount {
                let sample = abs(channelData[i])
                if sample > maxAmp {
                    maxAmp = sample
                }
            }

            // 动态追踪绝对值峰值，并做 10% 的指数滤波平滑衰减，保持律动动画自然顺滑
            let current = localLoudnessPtr.pointee
            localLoudnessPtr.pointee = max(maxAmp, current * 0.9)
        }
    }

    // MARK: - SoundFont 加载

    /// 根据吉他类型加载对应的 SoundFont Instrument 预设
    private func loadGuitarPreset(type: GuitarType) {
        let program: UInt8
        switch type {
        case .acoustic:
            program = 25 // General MIDI #26: Acoustic Guitar (steel)
        case .classical:
            program = 24 // General MIDI #25: Acoustic Guitar (nylon)
        case .electric:
            program = 27 // General MIDI #28: Electric Guitar (clean)
        }

        // 获取 bundle 中的 SoundFont 路径
        guard let sf2URL = Bundle.main.url(forResource: "GeneralUserGS", withExtension: "sf2") else {
            print("[GuitarAudioEngine] Error: SoundFont file 'GeneralUserGS.sf2' not found in Bundle!")
            return
        }

        // 加载乐器到 6 个独立采样器中。Apple 系统底层会自动对同 URL 的采样样本数据进行内存共享
        for i in 0..<GuitarConstants.stringCount {
            do {
                try samplers[i].loadSoundBankInstrument(
                    at: sf2URL,
                    program: program,
                    bankMSB: 121, // GM 旋律默认 MSB
                    bankLSB: 0
                )
                print("[GuitarAudioEngine] Successfully loaded string \(i) preset \(type.rawValue) (program: \(program))")
            } catch {
                print("[GuitarAudioEngine] Failed to load instrument on string \(i): \(error)")
            }
        }
        
        // 异步加载打击乐组（用于敲击面板声音），GM Standard Drum Kit
        do {
            try percussionSampler.loadSoundBankInstrument(
                at: sf2URL,
                program: 0,
                bankMSB: 120, // GM Percussion Bank
                bankLSB: 0
            )
            print("[GuitarAudioEngine] Successfully loaded percussion kit")
        } catch {
            print("[GuitarAudioEngine] Failed to load percussion kit: \(error)")
        }
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

    // MARK: - 拨弦与敲击接口
    
    /// 敲击面板 (模拟拍打吉他木箱)
    func playKnock(amplitude: Float = 1.0) {
        let velocity = UInt8(max(0, min(127, Int(amplitude * 127.0))))
        // 采用双层音频合成极度拟真的吉他打板音色：
        // 1. Note 77 (Low Wood Block): 提供木材清脆的"嗒"声
        // 2. Note 35 (Acoustic Bass Drum): 提供极轻的木箱低频共鸣空腔"咚"声
        
        let woodBlockNote: UInt8 = 77
        let bassDrumNote: UInt8 = 35
        
        percussionSampler.startNote(woodBlockNote, withVelocity: velocity, onChannel: 0)
        // 低频箱体共振的音量给轻一点，避免像敲鼓
        percussionSampler.startNote(bassDrumNote, withVelocity: UInt8(Float(velocity) * 0.35), onChannel: 0)
    }

    /// 拨单弦
    /// - Parameters:
    ///   - stringIndex: 弦索引 (0=6弦/低E, 5=1弦/高E)
    ///   - amplitude: 力度 (0.0 ~ 1.0)
    ///   - pickPosition: 拨弦位置 (采样器不使用，但为了兼容旧接口必须保留)
    func pluckString(_ stringIndex: Int, amplitude: Float = 0.8, pickPosition: Float = 0.13) {
        guard stringIndex >= 0, stringIndex < GuitarConstants.stringCount else { return }

        // 1. 计算当前的 MIDI 音符号
        let fret = currentFretState.fret(for: stringIndex)
        let midiNote = openStringMidiNotes[stringIndex] + fret

        // 2. 将力度大小转换为 MIDI 键盘的 Velocity (0 ~ 127)
        let velocity = UInt8(max(0, min(127, Int(amplitude * 127.0))))

        // 3. 🎸 物理断音：如果在该琴弦上有正在发声的音符，立刻停掉它以模拟物理重拨打断，实现极佳的琴弦断音体验
        if let prevNote = lastMidiNotes[stringIndex] {
            samplers[stringIndex].stopNote(prevNote, onChannel: 0)
        }

        // 4. 发送 MIDI Note On 事件触发采样回放
        samplers[stringIndex].startNote(UInt8(midiNote), withVelocity: velocity, onChannel: 0)
        lastMidiNotes[stringIndex] = UInt8(midiNote)
    }

    /// 扫弦
    /// - Parameters:
    ///   - fromString: 起始弦
    ///   - toString: 结束弦
    ///   - velocity: 扫弦速度 (影响间隔时间)
    ///   - amplitude: 基础力度
    func strum(from fromString: Int, to toString: Int, velocity: Double = 1.0, amplitude: Float = 0.7) {
        let start = min(fromString, toString)
        let end = max(fromString, toString)
        let direction = fromString < toString ? 1 : -1

        // 扫弦间隔：速度越快，各弦拨响的间隔越短（10ms ~ 50ms）
        let intervalMs = max(10, min(50, 30.0 / velocity))

        for i in 0...(end - start) {
            let stringIdx = direction > 0 ? start + i : end - i
            let delay = Double(i) * intervalMs / 1000.0
            let amp = amplitude * Float.random(in: 0.85...1.0) // 动态微小随机化

            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.pluckString(stringIdx, amplitude: amp)
            }
        }
    }

    /// 静音所有弦
    func muteAll() {
        for i in 0..<GuitarConstants.stringCount {
            if let prevNote = lastMidiNotes[i] {
                samplers[i].stopNote(prevNote, onChannel: 0)
                lastMidiNotes[i] = nil
            }
        }
    }

    // MARK: - 效果控制

    /// 设置混响量 (0.0 ~ 1.0)
    func setReverb(_ amount: Float) {
        effectsChain.setReverbMix(amount)
    }

    /// 设置吉他类型并动态重载 SoundFont 音色 Program
    func setGuitarType(_ type: GuitarType) {
        effectsChain.applyPreset(type)
        
        // 动态加载对应音色 Preset，由于是后台执行且系统会自动缓存共享，切换体验极其丝滑
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.loadGuitarPreset(type: type)
        }
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
