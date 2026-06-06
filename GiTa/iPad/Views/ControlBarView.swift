import SwiftUI

/// 底部控制栏 — 音量、混响、吉他类型和实时声音响度跃动条
struct ControlBarView: View {

    @Binding var volume: Float
    @Binding var reverbAmount: Float
    @Binding var guitarType: GuitarType
    @Binding var isMIDIModeEnabled: Bool
    @Binding var metronomeIsPlaying: Bool
    @Binding var metronomeBPM: Double
    let loudness: Float // 实时声音响度

    var body: some View {
        HStack(spacing: 24) {
            // 音量控制
            volumeControl

            Divider()
                .frame(height: 30)
                .overlay(Color.white.opacity(0.15))

            // 实时声音响度跃动条 (位于黄金正中央)
            loudnessIndicator

            Divider()
                .frame(height: 30)
                .overlay(Color.white.opacity(0.15))

            // 混响控制
            reverbControl

            Divider()
                .frame(height: 30)
                .overlay(Color.white.opacity(0.15))

            // 吉他类型选择
            guitarTypeSelector

            Divider()
                .frame(height: 30)
                .overlay(Color.white.opacity(0.15))
                
            // MIDI 联动切换
            midiModeToggle

            Divider()
                .frame(height: 30)
                .overlay(Color.white.opacity(0.15))

            // 节拍器
            metronomeControl
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 10, y: -2)
    }

    // MARK: - 子视图

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)

            Slider(value: Binding(
                get: { Double(volume) },
                set: { volume = Float($0) }
            ), in: 0...1)
            .tint(.cyan)
            .frame(width: 100)

            Text("\(Int(volume * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 35)
        }
    }

    private var loudnessIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<8) { index in
                // 钟形包络因子，使波形中间高两边低，呈现更高级的电平表效果
                let barHeightFactor: CGFloat = [0.4, 0.7, 1.0, 1.2, 1.2, 1.0, 0.7, 0.4][index]
                let barHeight = max(4, CGFloat(loudness) * 36.0 * barHeightFactor)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.8, blue: 1.0),
                                Color(red: 0.8, green: 0.3, blue: 1.0)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: barHeight)
                    .opacity(loudness > 0.01 ? 1.0 : 0.25)
                    .animation(.spring(response: 0.1, dampingFraction: 0.55), value: loudness)
            }
        }
        .frame(width: 60, height: 36)
        .padding(.horizontal, 8)
    }

    private var reverbControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            Text("混响")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))

            Slider(value: Binding(
                get: { Double(reverbAmount) },
                set: { reverbAmount = Float($0) }
            ), in: 0...1)
            .tint(.purple.opacity(0.8))
            .frame(width: 80)

            Text("\(Int(reverbAmount * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 35)
        }
    }

    private var guitarTypeSelector: some View {
        HStack(spacing: 4) {
            ForEach(GuitarType.allCases) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        guitarType = type
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 16))
                        Text(type.rawValue)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(guitarType == type ? .cyan : .white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        guitarType == type
                            ? Color.cyan.opacity(0.15)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var midiModeToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isMIDIModeEnabled.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isMIDIModeEnabled ? "pianokeys.inverse" : "pianokeys")
                    .font(.system(size: 14))
                Text("MIDI 联动")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isMIDIModeEnabled ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isMIDIModeEnabled
                    ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isMIDIModeEnabled ? Color.white.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: isMIDIModeEnabled ? .purple.opacity(0.5) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var metronomeControl: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { metronomeIsPlaying.toggle() }
            } label: {
                Image(systemName: metronomeIsPlaying ? "metronome.fill" : "metronome")
                    .font(.system(size: 16))
                    .foregroundColor(metronomeIsPlaying ? .cyan : .white.opacity(0.7))
                    .frame(width: 24)
            }
            .buttonStyle(.plain)
            
            Text("\(Int(metronomeBPM))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 26)
            
            HStack(spacing: 4) {
                ForEach([60, 120, 180], id: \.self) { bpm in
                    Button {
                        withAnimation { metronomeBPM = Double(bpm) }
                    } label: {
                        Text("\(bpm)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(metronomeBPM == Double(bpm) ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundColor(metronomeBPM == Double(bpm) ? .cyan : .white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Slider(value: $metronomeBPM, in: 40...240, step: 1)
                .tint(.cyan)
                .frame(width: 80)
        }
    }
}
