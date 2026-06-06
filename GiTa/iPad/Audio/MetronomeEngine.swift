import Foundation
import AVFoundation

/// 节拍器引擎
@Observable
final class MetronomeEngine {
    
    // MARK: - 状态
    
    var isPlaying = false {
        didSet {
            if isPlaying {
                frameCount = 0.0
                currentPhase = 0.0
                // 确保引擎运行
                if !engine.isRunning {
                    try? engine.start()
                }
            }
        }
    }
    
    var bpm: Double = 120.0
    
    // MARK: - 内部组件
    
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    
    // 渲染循环状态（在音频线程访问）
    private var currentPhase: Float = 0.0
    private var frameCount: Double = 0.0
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100.0
        
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            if !self.isPlaying {
                // 静音
                for buffer in buffers {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }
            
            // 计算 BPM
            let framesPerBeat = sampleRate * 60.0 / self.bpm
            let clickDurationFrames = sampleRate * 0.05 // 50ms 脉冲
            
            // 发声频率 1500Hz 比较清脆
            let frequency: Float = 1500.0
            let phaseIncrement = (frequency * 2.0 * Float.pi) / Float(sampleRate)
            
            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0
                
                // 仅在节拍前 50ms 内发声
                if self.frameCount < clickDurationFrames {
                    // 指数衰减包络
                    let envelope = exp(-Float(self.frameCount) / (Float(sampleRate) * 0.01))
                    sample = sin(self.currentPhase) * envelope * 0.5 // 限制最大音量
                    self.currentPhase += phaseIncrement
                } else {
                    self.currentPhase = 0.0
                }
                
                // 写入声道
                for channel in 0..<buffers.count {
                    if let ptr = buffers[channel].mData?.assumingMemoryBound(to: Float.self) {
                        ptr[frame] = sample
                    }
                }
                
                self.frameCount += 1.0
                if self.frameCount >= framesPerBeat {
                    self.frameCount -= framesPerBeat
                }
            }
            return noErr
        }
        
        self.sourceNode = sourceNode
        engine.attach(sourceNode)
        
        // 直连输出
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("[MetronomeEngine] Failed to start engine: \(error)")
        }
    }
    
    deinit {
        engine.stop()
    }
}
