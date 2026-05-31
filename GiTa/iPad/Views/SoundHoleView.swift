import SwiftUI

/// 音孔装饰视图 — 模拟吉他音孔的装饰性圆形
struct SoundHoleView: View {

    /// 是否有弦在振动（用于动画）
    var isPlaying: Bool = false

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 外圈装饰纹理（嵌花/Rosette）
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            .brown.opacity(0.6),
                            .orange.opacity(0.4),
                            .yellow.opacity(0.3),
                            .brown.opacity(0.5),
                            .orange.opacity(0.4),
                            .brown.opacity(0.6)
                        ],
                        center: .center,
                        startAngle: .degrees(rotation),
                        endAngle: .degrees(rotation + 360)
                    ),
                    lineWidth: 12
                )
                .frame(width: 180, height: 180)

            // 中间装饰圈
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 160, height: 160)

            // 音孔（深色圆形）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.05),
                            Color(red: 0.05, green: 0.03, blue: 0.08)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)

            // 内圈高光
            Circle()
                .strokeBorder(
                    Color.white.opacity(0.08),
                    lineWidth: 1
                )
                .frame(width: 140, height: 140)
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    pulseScale = 1.02
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    pulseScale = 1.0
                }
            }
        }
    }
}
