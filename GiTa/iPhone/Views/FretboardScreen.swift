import SwiftUI

/// iPhone 端主屏幕 — 指板界面
struct FretboardScreen: View {

    @State private var viewModel = FretboardViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
