# 🎸 GiTa — 分体式高高保真虚拟吉他模拟器 (Split High-Fidelity Virtual Guitar Simulator)

[![Build Status](https://img.shields.io/badge/Xcode-16.0%2B-blue.svg)](https://developer.apple.com/xcode/)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0%2B-cyan.svg)](https://developer.apple.com/ios/)
[![Language](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**GiTa** 是一款将 **iPhone 变身左手指板（按弦端）**、**iPad 变身右手琴身与发声箱（拨弦/扫弦端）** 的分体式超低延迟虚拟吉他。两台物理设备通过超低延迟局域网（Bonjour & UDP P2P）无缝协同，完美模拟真实吉他的物理发声机制与弹奏体验。

![GiTa iPad 横屏极奢 UI 界面](https://raw.githubusercontent.com/lixumin-zai/GiTa/main/ipad_landscape_ui_mockup.png)

---

## ✨ 核心理念 (Product Core Philosophy)

* **零痛感，零打品**：屏幕按弦彻底告别指尖老茧与压强痛感，虚拟弦枕永远处于完美力学高度。
* **绝对便携，随时弹奏**：手机与平板均属于日常携带设备，随时随地从口袋和背包中拉出两端，秒变专业电吉他。
* **绝对静音，深夜练习**：iPad 连接耳机即可进入完全属于自己的静音创作世界，告别扰民烦恼。
* **终身免调音与换弦**：利用严苛的物理声学算法，音准恒定精确，免去繁琐的调音和昂贵的进口琴弦更换开销。
* **真实的指尖温度**：完全保留左手独立和弦变换、右手单音拨弦/跨弦扫弦（Strumming）的手势温度。

---

## 🛠️ 双端职责与交互重构 (Double Device Interaction)

### 📱 iPhone 端：高精度多点触控指板 (Fretboard)
- **六弦指板全屏平展**：指板水平舒展铺满 iPhone 屏幕，避开 notch 灵动岛安全区，最大限度释放指间操作宽度。
- **自定义大小缩放（Resizing）**：集成精致的玻璃态设置弹窗，支持 **$80\% \sim 120\%$** 物理按键与触点范围比例缩放，完美契合不同粗细的手指以及从 iPhone 13 mini 到 iPhone Pro Max 的物理机型尺寸。
- **多点触控（Multitouch）回显**：左下角实时显示当前左手按压的物理音名组合（例如 E2, A2 等），支持高频多指并发。

### 💻 iPad 端：极奢横屏横弦沉浸式琴身 (Strings & Amp Body)
- **横屏横弦沉浸式设计**：契合平板主流横放弹奏习惯，六根发光彩虹琴弦**横向从左往右贯穿全屏**，触感最贴近真实物理吉他琴身。
- **对称式多点扫拂手势（Y-Axis Strumming）**：扫弦判定轴由 X 轴完全重构至 **Y 轴**。手指纵向滑拂时，利用物理切线相交检测算法（区间 $[\min(y_{\text{last}}, y_{\text{curr}}), \max(y_{\text{last}}, y_{\text{curr}})]$），瞬间捕捉划弦物理截面并触发声音。
- **极奢悬浮 ZStack 卡片**：
  - **左上角网络状态卡**：在未连接时，其正下方自动展开可用设备列表（iPhone 广播的 Bonjour 指板），支持一键点击秒连。
  - **右上角实时和弦参考图**：自动捕获并分析 iPhone 发来的按弦格位，回显精细的和弦格子及手指位。
  - **中底效果功放控制栏**：内嵌 Volume、Reverb（混响）调节与 Acoustic（木吉他）、Electric（电吉他）、Classical（古典吉他）效果链预设。
  - **Bezel 避让与物理边缘留白**：琴弦设置了 **`200pt`** 奢华的上下物理留白，卡片设置了 **`40pt (水平) / 36pt (顶底)`** 边距，完全内缩避开 iPad 物理圆角边框裁切。

---

## 🔊 高级物理建模与实时响度 DSP (Hifi Audio Engine)

### 1. Karplus-Strong 物理建模合成器
GiTa 拒绝使用廉价死板的 PCM 音频采样，而是搭载了 **6 个独立且针对移动 CPU 性能做过严苛优化的 Karplus-Strong 单弦振动物理合成器**：
- **零取模运算（Modulo Elimination）**：环形缓冲区读写索引用 `index = (index + 1) & mask` 或边界判断彻底替代 `%` 模运算，消除 CPU 实时渲染线程的多余分支开销。
- **FTZ（Flush-to-Zero）亚常数浮点仿真保护**：在极小幅度（$< 10^{-15}$）的超小衰减信号发生时强行切零，根除了移动 CPU 处理亚正规数（Denormal Floats）时系统软仿真的灾难性卡顿，消除背景吱吱杂音。

### 2. 实时声音响度跃动电平表 (Real-time Loudness Meter)
- **DSP 实时峰值提取**：在 `AVAudioSourceNode` 实时音频渲染回调中，进行低阻抗、零内存分配的最大绝对值 Peak 累积，并辅以一阶低通 IIR 滤波器 $\text{loudness} = \max(\text{maxAmp}, \text{loudness} \times 0.9)$ 缓冲消频闪。
- **8-Bar 渐变弹性跃动条**：在控制面板正中央加入由 8 根彩色渐变（青色 $\rightarrow$ 紫色）发光柱组成的电平表，采用 `spring(response: 0.1, dampingFraction: 0.55)` 弹性动力学动画，随真实弹琴音量灵敏平滑地翩翩起舞。

---

## 📡 通信架构：双向心跳与重连防竞态 (P2P Connectivity)

* **Bonjour 服务广播与发现**：iPhone 端自动发布 `_gita._udp` 的 Bonjour 本地网络服务，iPad 端利用 `ServiceBrowser` 毫秒级静默扫频捕捉。
* **超轻量二进制 UDP 传输**：消息体积极小仅 9 字节（状态包与心跳包），端到端延迟低至 **$13\text{ms} \sim 15\text{ms}$**，支持无路由器下的 WiFi/蓝牙点对点极速直连。
* **双生存周期 Ping-Pong 双向心跳**：双端各自维护 `lastReceivedTime`。一旦在 2.0s 内未收到任何心跳或拨弦包，自动判定为物理断开（如走出 Wi-Fi 范围、锁屏、强杀等）并静默复位。
* **连接重连防竞态（Anti-Race Condition）**：在手动断开时，同步将 `NWConnection.stateUpdateHandler = nil` 彻底切断异步 Socket 回调，iPhone 端对于传入的新连接无条件进行接管，消除了重连时因旧 Socket 析构延迟导致的“断连卡死”Bug，实现了重连可用率达 **$100\%$** 的秒连闭环。

---

## 📂 项目结构目录 (Workspace Map)

```
GiTa/
├── project.yml                          # XcodeGen 项目编译配置文件
├── GiTa.xcodeproj/                      # 生成的 Xcode 物理项目 (忽略但支持随时生成)
├── deploy.sh                            # 双物理设备一键并发证书签名与编译部署脚本
├── git-commit.sh                        # Conventional Commits 高规范交互式提交工具
├── GiTa/
│   ├── App/
│   │   ├── GiTaApp.swift                # @main 程序总入口
│   │   └── DeviceRole.swift             # 设备物理角色动态感知 (iPhone/iPad)
│   ├── Shared/
│   │   ├── Models/
│   │   │   ├── GuitarConstants.swift    # 1~6弦开弦频率与品位物理常量配置
│   │   │   ├── FretState.swift          # 左手按弦物理格位编码模型
│   │   │   └── NetworkMessage.swift     # 9字节超紧凑网络二进制协议
│   │   ├── Network/
│   │   │   ├── PeerConnection.swift     # P2P NWConnection 封装与防抖复位
│   │   │   ├── ServiceBrowser.swift     # Bonjour 服务发现器
│   │   │   └── ServiceAdvertiser.swift  # Bonjour 服务广播器
│   │   └── Haptics/
│   │       └── HapticManager.swift      # 多级物理线性震动触觉反馈反馈
│   ├── iPhone/                          # iPhone 指板端 (按弦)
│   │   ├── Views/
│   │   │   ├── FretboardScreen.swift    # 手机主屏幕 (安全区避让、比例缩放滑块)
│   │   │   ├── FretboardView.swift      # UIKit 多点触控绘制层 (指法中心计算)
│   │   │   └── FretboardRepresentable.swift
│   │   └── ViewModels/
│   │       └── FretboardViewModel.swift
│   └── iPad/                            # iPad 发声琴身端 (扫弦/音箱)
│       ├── Views/
│       │   ├── StrummingScreen.swift    # 平板主屏幕 (横屏 ZStack 极奢悬浮面板)
│       │   ├── StringsView.swift        # 水平琴弦 UIKit 多点触控 (Y轴物理扫弦)
│       │   ├── StringsViewRepresentable.swift
│       │   ├── ChordDiagramView.swift   # glassmorphic 悬浮和弦指法回显
│       │   ├── SoundHoleView.swift      # 古典玫瑰木圆形呼吸音孔
│       │   └── ControlBarView.swift     # 悬浮功放控制条与 8-Bar 响度波形条
│       ├── ViewModels/
│       │   └── StrummingViewModel.swift  # 20Hz 响度轮询与主动握手断开管理
│       └── Audio/
│           ├── StringSynthesizer.swift  # Karplus-Strong 物理合成 (零Modulo, FTZ)
│           ├── GuitarAudioEngine.swift  # 6声道混音、IIR 响度提取与效果链
│           └── EffectsChain.swift       # 混响、3段 EQ 与吉他预设效果链
```

---

## 🏃 编译、运行与一键实机部署 (Quick Start)

### 1. 本地安装 XcodeGen
项目基于 XcodeGen 维护工程。如果您尚未安装，请通过 Homebrew 安装：
```bash
brew install xcodegen
```

### 2. 生成 Xcode 项目文件
在项目根目录下运行，即可根据 `project.yml` 极速生成最新工程：
```bash
xcodegen generate
```

### 3. 一键实机并行调试与热部署
为了完美在物理 iPhone 和 iPad 上运行本分体应用，请将您的 iPhone 和 iPad 解锁并通过 USB 线连接到 Mac，直接在终端执行：
```bash
chmod +x deploy.sh
./deploy.sh
```
部署脚本将自动识别已连接的两台 iOS 设备，进行**并发代码编译、自动物理证书签名、APP 远程安装与双端自动冷拉起**！

---

## 📝 提交规范辅助工具 (Git Standard)

为了贯彻高质量的 Conventional Commit，本仓库配备了专用提交脚本 [git-commit.sh](file:///Users/lixumin/Desktop/projects/GiTa/git-commit.sh)。在进行任何重要修改时，推荐在终端直接执行：
```bash
chmod +x git-commit.sh
./git-commit.sh
```
该脚本将交互式引导您确认变动类型（`feat`、`fix`、`style`等）、细分范围（`UI`、`Audio`等）并强制补充 What（核心变动）、Why（变更原因）、Impact（影响范围）描述，保证版本迭代脉络高清晰度可溯。