import SwiftUI

/// 底部控制栏 — 沉浸式毛玻璃浮岛布局，分组清晰、视觉高级
struct ControlBarView: View {

    @Binding var volume: Float
    @Binding var reverbAmount: Float
    @Binding var guitarType: GuitarType
    @Binding var isMIDIModeEnabled: Bool
    @Binding var metronomeIsPlaying: Bool
    @Binding var metronomeBPM: Double
    let loudness: Float

    var body: some View {
        HStack(spacing: 12) {
            // ═══════════════════════════════════════════
            // 第1组：音量 + 响度表
            // ═══════════════════════════════════════════
            controlGroup {
                HStack(spacing: 10) {
                    // 音量
                    volumeControl
                    
                    // 微型分割线
                    thinDivider
                    
                    // 响度
                    loudnessIndicator
                }
            }
            
            // ═══════════════════════════════════════════
            // 第2组：混响 + 吉他类型
            // ═══════════════════════════════════════════
            controlGroup {
                HStack(spacing: 10) {
                    reverbControl
                    
                    thinDivider
                    
                    guitarTypeSelector
                }
            }
            
            // ═══════════════════════════════════════════
            // 第3组：节拍器
            // ═══════════════════════════════════════════
            controlGroup {
                metronomeControl
            }
            
            // ═══════════════════════════════════════════
            // 第4组：MIDI 联动
            // ═══════════════════════════════════════════
            midiModeToggle
        }
    }
    
    // MARK: - 容器包装器
    
    /// 每个分组的毛玻璃胶囊容器
    private func controlGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }
    
    /// 分组内的细分割线
    private var thinDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.0), Color.white.opacity(0.12), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1, height: 28)
    }
    
    // MARK: - 音量

    private var volumeControl: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation { volume = volume > 0 ? 0 : 0.8 }
            } label: {
                Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        volume > 0
                            ? AnyShapeStyle(LinearGradient(colors: [.cyan, .cyan.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.white.opacity(0.35))
                    )
                    .frame(width: 18)
            }
            .buttonStyle(.plain)

            Slider(value: Binding(
                get: { Double(volume) },
                set: { volume = Float($0) }
            ), in: 0...1)
            .tint(.cyan)
            .frame(width: 80)

            Text("\(Int(volume * 100))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - 响度

    private var loudnessIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<10) { index in
                let barHeightFactor: CGFloat = [0.3, 0.5, 0.7, 0.9, 1.0, 1.0, 0.9, 0.7, 0.5, 0.3][index]
                let barHeight = max(3, CGFloat(loudness) * 30.0 * barHeightFactor)
                let normalizedLevel = CGFloat(loudness) * barHeightFactor
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        normalizedLevel > 0.7
                            ? LinearGradient(colors: [.orange, .red], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [.cyan.opacity(0.8), .purple.opacity(0.9)], startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: 3, height: barHeight)
                    .opacity(loudness > 0.01 ? 1.0 : 0.2)
                    .animation(.spring(response: 0.08, dampingFraction: 0.5), value: loudness)
            }
        }
        .frame(width: 54, height: 30)
    }

    // MARK: - 混响

    private var reverbControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 18)

            Slider(value: Binding(
                get: { Double(reverbAmount) },
                set: { reverbAmount = Float($0) }
            ), in: 0...1)
            .tint(.purple.opacity(0.7))
            .frame(width: 70)

            Text("\(Int(reverbAmount * 100))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - 吉他类型

    private var guitarTypeSelector: some View {
        HStack(spacing: 3) {
            ForEach(GuitarType.allCases) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        guitarType = type
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 14, weight: .medium))
                        Text(type.rawValue)
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(guitarType == type ? .white : .white.opacity(0.35))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Group {
                            if guitarType == type {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.cyan.opacity(0.4), lineWidth: 0.5)
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 节拍器
    
    private var metronomeControl: some View {
        HStack(spacing: 8) {
            // 播放/暂停按钮
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    metronomeIsPlaying.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            metronomeIsPlaying
                                ? LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(
                                    metronomeIsPlaying ? Color.orange.opacity(0.5) : Color.white.opacity(0.15),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: metronomeIsPlaying ? .orange.opacity(0.4) : .clear, radius: 8)
                    
                    Image(systemName: metronomeIsPlaying ? "metronome.fill" : "metronome")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(metronomeIsPlaying ? .white : .white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            
            // BPM 数字显示
            Text("\(Int(metronomeBPM))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(metronomeIsPlaying ? .orange : .white.opacity(0.7))
                .frame(width: 34, alignment: .center)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: metronomeBPM)
            
            // 预设按钮
            HStack(spacing: 4) {
                ForEach([60, 120, 180], id: \.self) { bpm in
                    let isSelected = Int(metronomeBPM) == bpm
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            metronomeBPM = Double(bpm)
                        }
                    } label: {
                        Text("\(bpm)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                            .frame(width: 32, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected
                                          ? LinearGradient(colors: [.orange.opacity(0.5), .red.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                                          : LinearGradient(colors: [Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 微调滑条
            Slider(value: $metronomeBPM, in: 40...240, step: 1)
                .tint(.orange.opacity(0.6))
                .frame(width: 70)
        }
    }

    // MARK: - MIDI 联动
    
    private var midiModeToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isMIDIModeEnabled.toggle()
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isMIDIModeEnabled ? "pianokeys.inverse" : "pianokeys")
                    .font(.system(size: 15, weight: .medium))
                Text("MIDI")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(isMIDIModeEnabled ? .white : .white.opacity(0.4))
            .frame(width: 44, height: 44)
            .background(
                ZStack {
                    if isMIDIModeEnabled {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
                }
            )
            .shadow(color: isMIDIModeEnabled ? .purple.opacity(0.5) : .black.opacity(0.35), radius: isMIDIModeEnabled ? 10 : 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
