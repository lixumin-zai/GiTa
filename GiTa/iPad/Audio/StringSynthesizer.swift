import Foundation
import AVFoundation
import Accelerate

/// Karplus-Strong 单弦合成器
/// 使用环形缓冲区 + 低通滤波实现物理建模弦振动
/// ⚠️ render() 方法在实时音频线程调用，不可有内存分配、锁、ObjC/Swift ARC 操作
final class StringSynthesizer {

    // MARK: - 参数

    private let sampleRate: Double

    /// 环形缓冲区（预分配最大尺寸）
    private var buffer: UnsafeMutablePointer<Float>
    private let maxBufferSize: Int

    /// 当前有效缓冲区长度（决定音高）
    private var bufferSize: Int = 0

    /// 读取位置（浮点数，支持分数延迟）
    private var readIndex: Double = 0

    /// 写入位置
    private var writeIndex: Int = 0

    /// 衰减系数（控制声音持续时间）
    private var decay: Float = 0.996

    /// 当前是否在发声
    private(set) var isActive: Bool = false

    /// 当前振幅
    private var amplitude: Float = 0

    /// 连续静音样本计数（用于 O(1) 静音检测，避免实时线程循环）
    private var quietSamplesCount: Int = 0

    // MARK: - 初始化

    /// - Parameter sampleRate: 音频采样率 (通常 44100 或 48000)
    init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
        // 最大缓冲区：足够容纳最低音 E2 (82.41Hz) 的波长
        // 48000 / 82.41 ≈ 583 samples，留 2 倍余量
        self.maxBufferSize = Int(sampleRate / 60.0) // ~800 samples
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: maxBufferSize)
        self.buffer.initialize(repeating: 0, count: maxBufferSize)
    }

    deinit {
        buffer.deallocate()
    }

    // MARK: - 拨弦（Pluck）

    /// 触发拨弦
    /// - Parameters:
    ///   - frequency: 目标频率 (Hz)
    ///   - amplitude: 振幅 (0.0 ~ 1.0)
    func pluck(frequency: Double, amplitude: Float = 0.8) {
        guard frequency > 0, frequency < sampleRate / 2 else { return }

        // 计算缓冲区大小
        let exactSize = sampleRate / frequency
        bufferSize = max(2, Int(exactSize))

        // 填充白噪声脉冲（初始激励）
        for i in 0..<bufferSize {
            buffer[i] = Float.random(in: -amplitude...amplitude)
        }

        // 重置读写位置与静音计数
        readIndex = 0
        writeIndex = 0
        quietSamplesCount = 0
        self.amplitude = amplitude
        self.isActive = true
    }

    /// 静音/停止发声
    func mute() {
        isActive = false
        amplitude = 0
    }

    // MARK: - 渲染（实时音频线程）

    /// 渲染音频帧到缓冲区
    /// ⚠️ 此方法在实时音频线程调用，绝对不可：
    ///   - 分配内存 (malloc/new/Array.append)
    ///   - 使用锁 (NSLock/DispatchSemaphore)
    ///   - 触发 ARC (引用计数操作)
    ///   - 进行 I/O (print/文件读写)
    /// - Parameters:
    ///   - frameCount: 需要渲染的帧数
    ///   - output: 输出缓冲区指针
    func render(frameCount: Int, output: UnsafeMutablePointer<Float>) {
        guard isActive, bufferSize > 1 else {
            // 静音：填零
            for i in 0..<frameCount {
                output[i] = 0
            }
            return
        }

        for i in 0..<frameCount {
            // 优化 1：手动计算索引以避免极其缓慢的取模 (%) 运算
            let index0 = writeIndex
            var index1 = writeIndex + 1
            if index1 >= bufferSize {
                index1 = 0
            }

            let sample = buffer[index0]

            // Karplus-Strong 低通滤波：相邻样本取平均 × 衰减
            var filtered = (sample + buffer[index1]) * 0.5 * decay

            // 优化 2：消除亚正规数（Denormal），防止 CPU 陷入微码计算造成 100 倍以上的耗时突增
            if abs(filtered) < 1e-15 {
                filtered = 0
            }

            // 写回缓冲区（反馈）
            buffer[index0] = filtered

            // 输出
            output[i] = sample

            // 优化 1 推进：避免二次取模
            writeIndex += 1
            if writeIndex >= bufferSize {
                writeIndex = 0
            }

            // 优化 3：O(1) 连续静音样本计数检测，彻底消除原先 O(N) 循环导致实时线程卡顿挂起的灾难性设计
            if abs(filtered) < 0.00005 {
                quietSamplesCount += 1
                if quietSamplesCount >= bufferSize {
                    isActive = false
                    // 填充剩余帧为零并直接退出
                    for remaining in (i + 1)..<frameCount {
                        output[remaining] = 0
                    }
                    break
                }
            } else {
                quietSamplesCount = 0
            }
        }
    }
}
