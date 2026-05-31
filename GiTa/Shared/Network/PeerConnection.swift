import Foundation
import Network

/// P2P 连接管理器 — 基于 Network.framework + UDP
/// 封装 NWConnection 的创建、数据发送/接收、状态监控
final class PeerConnection: @unchecked Sendable {

    // MARK: - 属性

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.gita.peerconnection", qos: .userInteractive)

    /// 连接状态变化回调
    var onStateChanged: ((ConnectionState) -> Void)?

    /// 数据接收回调
    var onDataReceived: ((Data) -> Void)?

    /// 当前连接状态
    private(set) var state: ConnectionState = .disconnected {
        didSet {
            if state != oldValue {
                onStateChanged?(state)
            }
        }
    }

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    // MARK: - 连接管理

    /// 使用已发现的端点创建连接（iPad 端调用）
    func connect(to endpoint: NWEndpoint) {
        let parameters = NWParameters.udp
        parameters.includePeerToPeer = true
        parameters.serviceClass = .interactiveVideo

        let conn = NWConnection(to: endpoint, using: parameters)
        setupConnection(conn)
    }

    /// 使用入站连接（iPhone 端接收到的连接）
    func accept(_ connection: NWConnection) {
        setupConnection(connection)
    }

    /// 发送数据（fire-and-forget，UDP 不保证送达）
    func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[PeerConnection] Send error: \(error)")
            }
        })
    }

    /// 发送网络消息
    func send(message: NetworkMessage) {
        send(message.encode())
    }

    /// 断开连接
    func disconnect() {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        state = .disconnected
    }

    // MARK: - 私有方法

    private func setupConnection(_ conn: NWConnection) {
        // 取消旧连接
        connection?.stateUpdateHandler = nil
        connection?.cancel()

        connection = conn
        state = .connecting

        // 监听连接状态
        conn.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                self.state = .connected
                self.startReceiving()
                print("[PeerConnection] Connected!")
            case .failed(let error):
                self.state = .failed(error.localizedDescription)
                print("[PeerConnection] Failed: \(error)")
                // 自动重连：延迟 1 秒
                self.queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.connection?.restart()
                }
            case .cancelled:
                self.state = .disconnected
                print("[PeerConnection] Cancelled")
            case .preparing:
                self.state = .connecting
            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    /// 开始接收数据（递归调用，持续监听）
    private func startReceiving() {
        connection?.receiveMessage { [weak self] content, _, isComplete, error in
            guard let self else { return }

            if let data = content, !data.isEmpty {
                self.onDataReceived?(data)
            }

            if let error = error {
                print("[PeerConnection] Receive error: \(error)")
                return
            }

            // 继续监听下一条消息
            self.startReceiving()
        }
    }
}
