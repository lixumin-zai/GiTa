import Foundation
import UIKit
import Network

/// Bonjour 服务广播 — iPhone 端广播自己作为指板设备
final class ServiceAdvertiser: @unchecked Sendable {

    // MARK: - 属性

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.gita.advertiser", qos: .userInitiated)

    /// 新连接回调
    var onConnectionReceived: ((NWConnection) -> Void)?

    /// 广播状态变化
    var onStateChanged: ((Bool) -> Void)?

    // MARK: - 控制

    /// 开始广播服务
    func startAdvertising() {
        do {
            let parameters = NWParameters.udp
            parameters.includePeerToPeer = true
            parameters.serviceClass = .interactiveVideo

            listener = try NWListener(using: parameters)

            // 设置 Bonjour 服务
            listener?.service = NWListener.Service(
                name: UIDevice.current.name,
                type: ServiceBrowser.serviceType
            )

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("[ServiceAdvertiser] Advertising as: \(UIDevice.current.name)")
                    self?.onStateChanged?(true)
                case .failed(let error):
                    print("[ServiceAdvertiser] Failed: \(error)")
                    self?.onStateChanged?(false)
                case .cancelled:
                    print("[ServiceAdvertiser] Cancelled")
                    self?.onStateChanged?(false)
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                print("[ServiceAdvertiser] Received connection from peer")
                self?.onConnectionReceived?(connection)
            }

            listener?.start(queue: queue)
        } catch {
            print("[ServiceAdvertiser] Failed to create listener: \(error)")
        }
    }

    /// 停止广播
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
    }
}
