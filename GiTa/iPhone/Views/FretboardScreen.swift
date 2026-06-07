import SwiftUI

/// iPhone 端主屏幕 — 指板界面
struct FretboardScreen: View {

    @State private var viewModel = FretboardViewModel()
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 彻底屏蔽系统音量 HUD 并拦截按键的终极方案：
                // 使用 SwiftUI 的 UIViewRepresentable 容器确保 MPVolumeView 正确加载到激活的视图树。
                // 通过将其放置在 ZStack 的最底部（首位渲染），让上层完全不透明的指板遮盖，实现“物理隐形但逻辑活跃”。
                HiddenVolumeView { volumeView in
                    viewModel.registerVolumeView(volumeView)
                }
                .frame(width: 100, height: 30)
                .opacity(0.01) // 保持极微弱透明度避免被 iOS 引擎禁用，实际已被指板完全遮挡
                
                // 指板（全屏）
                FretboardRepresentable(viewModel: viewModel)
                    .ignoresSafeArea()

                // 连接状态指示器（右上角，自适应安全区，彻底防止灵动岛/刘海遮挡）
                VStack {
                    HStack {
                        Spacer()
                        ConnectionBadge(
                            isConnected: viewModel.isConnected,
                            text: viewModel.connectionStatusText
                        )
                        .padding(.trailing, max(16, geometry.safeAreaInsets.trailing))
                        .padding(.top, max(12, geometry.safeAreaInsets.top))
                    }
                    Spacer()
                }

                // 悬浮设置齿轮按钮 (位于连接状态徽章下方)
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showSettings.toggle()
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(8)
                                .background(.ultraThinMaterial.opacity(0.65))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, max(16, geometry.safeAreaInsets.trailing))
                        .padding(.top, max(52, geometry.safeAreaInsets.top + 40))
                    }
                    Spacer()
                }

                // 指板缩放控制面板 (顶部中央悬浮，带毛玻璃与弹簧动画)
                if showSettings {
                    VStack {
                        VStack(spacing: 12) {
                            // 整体大小缩放
                            HStack(spacing: 12) {
                                Image(systemName: "hand.point.up.left.and.text.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cyan)

                                Text("整体缩放")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))

                                Slider(value: $viewModel.scale, in: 0.8...1.2)
                                    .tint(.cyan)
                                    .frame(width: 130)

                                Text("\(Int(viewModel.scale * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            
                            // 品丝间距拉伸
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)

                                Text("品丝间距")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))

                                Slider(value: $viewModel.widthMultiplier, in: 1.0...3.0)
                                    .tint(.purple)
                                    .frame(width: 130)

                                Text(String(format: "%.1fx", viewModel.widthMultiplier))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                        .padding(.top, max(12, geometry.safeAreaInsets.top))
                        .transition(.move(edge: .top).combined(with: .opacity))

                        Spacer()
                    }
                }

                // 当前按弦信息（左下角，自适应安全区，防圆角/扬声器开孔遮挡）
                VStack {
                    Spacer()
                    HStack {
                        FretInfoOverlay(fretState: viewModel.fretState)
                            .padding(.leading, max(16, geometry.safeAreaInsets.leading))
                            .padding(.bottom, max(12, geometry.safeAreaInsets.bottom))
                        Spacer()
                    }
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - 连接状态徽章

private struct ConnectionBadge: View {
    let isConnected: Bool
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: isConnected ? .green.opacity(0.6) : .clear, radius: 4)

            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial.opacity(0.6))
        .clipShape(Capsule())
    }
}

// MARK: - 按弦信息覆盖层

private struct FretInfoOverlay: View {
    let fretState: FretState

    var body: some View {
        let activeStrings = (0..<GuitarConstants.stringCount).filter { fretState.fret(for: $0) > 0 }

        if !activeStrings.isEmpty {
            HStack(spacing: 8) {
                ForEach(activeStrings, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(GuitarConstants.openStringNames[i])
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Text(fretState.noteName(for: i))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .transition(.opacity)
        }
    }
}

// MARK: - HiddenVolumeView Wrapper
import MediaPlayer

struct HiddenVolumeView: UIViewRepresentable {
    let onVolumeViewCreated: (MPVolumeView) -> Void
    
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        onVolumeViewCreated(volumeView)
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
