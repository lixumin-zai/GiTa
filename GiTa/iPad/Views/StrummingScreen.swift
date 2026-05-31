import SwiftUI

/// iPad 端主屏幕 — 拨弦 + 音箱
struct StrummingScreen: View {

    @State private var viewModel = StrummingViewModel()

    var body: some View {
        ZStack {
            // 背景
            backgroundGradient

            // 主内容
            VStack(spacing: 0) {
                // 主区域：左面板 + 右拨弦区
                HStack(spacing: 0) {
                    // 左面板
                    leftPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 分隔线
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)

                    // 右侧拨弦区
                    strummingArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // 底部控制栏
                ControlBarView(
                    volume: $viewModel.volume,
                    reverbAmount: $viewModel.reverbAmount,
                    guitarType: $viewModel.guitarType
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - 背景

    private var backgroundGradient: some View {
        ZStack {
            // 深色木纹背景
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.04),
                    Color(red: 0.12, green: 0.08, blue: 0.05),
                    Color(red: 0.10, green: 0.07, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 纹理叠加
            Canvas { context, size in
                for _ in 0..<200 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let width = CGFloat.random(in: 20...100)
                    context.opacity = Double.random(in: 0.01...0.03)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: width, height: 0.5)),
                        with: .color(.white)
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - 左面板

    private var leftPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            // 🚀 稳定区域：音孔与和弦图示，保持居中不动
            VStack(spacing: 24) {
                SoundHoleView(isPlaying: viewModel.isConnected)
                    .scaleEffect(0.9)

                ChordDiagramView(fretState: viewModel.fretState)
            }

            Spacer()

            // 🚀 动态连接区域：固定容器高度，彻底解决由于设备列表显示/隐藏导致的布局上下抖动跳跃问题
            VStack(spacing: 12) {
                connectionCard
                
                // 发现的设备列表与提示区域（固定高度，支持设备显示）
                Group {
                    if !viewModel.isConnected && !viewModel.discoveredDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("发现的指板设备：")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            
                            ForEach(viewModel.discoveredDevices) { device in
                                Button {
                                    viewModel.connectTo(device: device)
                                } label: {
                                    HStack {
                                        Image(systemName: "iphone")
                                        Text(device.name)
                                            .font(.system(size: 13))
                                        Spacer()
                                        Text("点击连接")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.cyan)
                                    }
                                    .padding(8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if !viewModel.isConnected {
                        // 没有找到设备时显示提示
                        Text(viewModel.connectionStatusText == "连接已断开" ? "请点击右上角“重新搜索”开始连接" : "等待局域网权限或正在搜索...")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    } else {
                        // 已连接状态，留出空白占位保持布局稳定
                        Color.clear.frame(height: 1)
                    }
                }
                .frame(height: 86, alignment: .top) // 固定提示与列表高度为 86pt
            }
            .frame(height: 150, alignment: .top) // 整个连接卡片区固定 150pt
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 连接状态卡片

    private var connectionCard: some View {
        HStack(spacing: 10) {
            // 连接指示灯
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
                .shadow(color: viewModel.isConnected ? .green.opacity(0.5) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.connectionStatusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .id("conn_status_\(viewModel.connectionStatusText)")

                // 🚀 保持高度恒定：即使未连接，也渲染一个固定高度占位，彻底消除上下撑开布局的抖动！
                Text(viewModel.isConnected ? viewModel.connectedDeviceName : " ")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(height: 14)
            }

            Spacer()

            if viewModel.isConnected {
                Button {
                    viewModel.disconnect()
                } label: {
                    Text("断开")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 76, height: 22) // 🚀 固定宽高
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.startScanning()
                } label: {
                    Text("重新搜索")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                        .frame(width: 76, height: 22) // 🚀 固定与 "断开" 相同的宽高
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Image(systemName: viewModel.isConnected ? "wifi" : "wifi.slash")
                .font(.system(size: 14))
                .foregroundColor(viewModel.isConnected ? .green : .orange)
        }
        .padding(.horizontal, 12)
        .frame(height: 52) // 🚀 固定整个卡片高度为 52pt
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 拨弦区域

    private var strummingArea: some View {
        StringsViewRepresentable(viewModel: viewModel)
            .background(Color.clear)
    }
}
