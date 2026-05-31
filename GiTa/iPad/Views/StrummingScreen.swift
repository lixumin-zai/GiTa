import SwiftUI

/// iPad 端主屏幕 — 拨弦 + 音箱 (极奢横屏 ZStack 沉浸式悬浮布局)
struct StrummingScreen: View {

    @State private var viewModel = StrummingViewModel()

    var body: some View {
        ZStack {
            // 1. 拟真深色花梨木纹理背景
            backgroundGradient

            // 2. 🚀 背景音孔装饰：将旋转音孔作为精致的背景，正好置于中央琴弦下方，完美贴合真实吉他物理结构！
            SoundHoleView(isPlaying: viewModel.isConnected)
                .scaleEffect(1.4)
                .opacity(0.12) // 低调且优雅地融入背景木纹
                .offset(y: -10)

            // 3. 🚀 核心主体：水平拨弦琴弦区 (占满全屏，占据绝对主体地位)
            strummingArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 4. 🚀 悬浮辅助控制系统 (玻璃层叠 ZStack)
            VStack(spacing: 0) {
                // 顶部左右悬浮条：左边是连接卡片，右边是按弦和弦图
                HStack(alignment: .top) {
                    // 左上角：连接卡片及在其下方的设备列表
                    VStack(alignment: .leading, spacing: 10) {
                        connectionCard
                            .frame(width: 240)
                        
                        // 🚀 补回被遗落的可用设备列表，支持点击连接
                        if !viewModel.isConnected && !viewModel.discoveredDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("发现的指板设备：")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                ForEach(viewModel.discoveredDevices) { device in
                                    Button {
                                        viewModel.connectTo(device: device)
                                    } label: {
                                        HStack {
                                            Image(systemName: "iphone")
                                                .foregroundColor(.cyan)
                                            Text(device.name)
                                                .font(.system(size: 12))
                                            Spacer()
                                            Text("连接")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.cyan)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(10)
                            .background(.ultraThinMaterial.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(width: 240)
                            .shadow(color: .black.opacity(0.15), radius: 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    Spacer()
                    
                    // 右上角：和弦指法图 (辅助指引，小比例融合)
                    ChordDiagramView(fretState: viewModel.fretState)
                        .scaleEffect(0.9)
                        .shadow(color: .black.opacity(0.2), radius: 8)
                }
                .padding(.horizontal, 40)
                .padding(.top, 36) // 适应全面屏顶部安全区与物理圆角

                Spacer()

                // 底部悬浮条：音量与混响效果毛玻璃控制栏
                ControlBarView(
                    volume: $viewModel.volume,
                    reverbAmount: $viewModel.reverbAmount,
                    guitarType: $viewModel.guitarType,
                    loudness: viewModel.loudness
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 36) // 适应全面屏底部安全区与物理圆角
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
        .shadow(color: .black.opacity(0.15), radius: 6)
    }

    // MARK: - 拨弦区域

    private var strummingArea: some View {
        StringsViewRepresentable(viewModel: viewModel)
            .background(Color.clear)
    }
}
