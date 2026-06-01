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
                // 顶部左右悬浮条：左边是和弦指法图，右边是连接卡片
                HStack(alignment: .top) {
                    // 左上角：和弦指法图 (辅助指引，小比例融合)
                    ChordDiagramView(fretState: viewModel.fretState)
                        .scaleEffect(0.9)
                        .shadow(color: .black.opacity(0.2), radius: 8)
                    
                    Spacer()
                    
                    // 右上角：连接卡片及在其下方的设备列表
                    VStack(alignment: .trailing, spacing: 10) {
                        connectionCard
                        
                        // 补回被遗落的可用设备列表，支持点击连接
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
                                                .lineLimit(1)
                                            Spacer(minLength: 4)
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
                            .frame(width: 240) // 跟随卡片固定宽度
                            .shadow(color: .black.opacity(0.15), radius: 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 58) // 🚀 显著增加顶部间距，彻底消除 iPad 物理圆角、挖孔及系统状态栏的画面遮挡与裁剪
                
                Spacer()

                // 底部悬浮条：音量与混响效果毛玻璃控制栏
                ControlBarView(
                    volume: $viewModel.volume,
                    reverbAmount: $viewModel.reverbAmount,
                    guitarType: $viewModel.guitarType,
                    isMIDIModeEnabled: $viewModel.isMIDIModeEnabled,
                    loudness: viewModel.loudness
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 36) // 适应全面屏底部安全区与物理圆角
            }
        }
        .ignoresSafeArea() // 🚀 关键修复：忽略所有动态安全区变化，彻底解决由于系统通知横幅下拉导致整个界面集体下移再弹回的跳动问题
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
        HStack(spacing: 0) {
            // 1. 状态点 (固定宽度)
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: viewModel.isConnected ? .green : .orange, radius: 3)
                .frame(width: 30)
            
            // 2. 文本信息 (固定宽度，防止文字挤压布局)
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.isConnected ? "已连接" : viewModel.connectionStatusText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(viewModel.isConnected ? .green : .orange)
                    .lineLimit(1)
                
                Text(viewModel.isConnected ? viewModel.connectedDeviceName : "等待指板设备...")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(width: 110, alignment: .leading)
            
            Spacer()
            
            // 3. 操作按钮 (固定宽高)
            Button {
                if viewModel.isConnected {
                    viewModel.disconnect()
                } else {
                    viewModel.startScanning()
                }
            } label: {
                Text(viewModel.isConnected ? "断开" : "重搜")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(viewModel.isConnected ? .white : .cyan)
                    .frame(width: 56, height: 28)
                    .background(viewModel.isConnected ? Color.red.opacity(0.8) : Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(viewModel.isConnected ? Color.red : Color.cyan.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(width: 240, height: 56) // 整个卡片绝对固定的宽高，绝不因内容变化而跳动
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 拨弦区域

    private var strummingArea: some View {
        StringsViewRepresentable(viewModel: viewModel)
            .background(Color.clear)
    }
}
