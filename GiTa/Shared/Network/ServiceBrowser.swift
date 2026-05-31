import Foundation
import Network

/// Bonjour 服务发现 — iPad 端用于发现 iPhone 指板
final class ServiceBrowser: @unchecked Sendable {

    // MARK: - 常量

    /// Bonjour 服务类型
    static let serviceType = "_gita._udp"

    // MARK: - 属性

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.gita.browser", qos: .userInitiated)

    /// 发现设备回调
    var onPeerFound: ((NWEndpoint) -> Void)?

    /// 设备消失回调
    var onPeerLost: ((NWEndpoint) -> Void)?

    /// 已发现的端点列表
    private(set) var discoveredPeers: [NWEndpoint] = []

    // MARK: - 控制

    /// 开始浏览
    func startBrowsing() {
        let parameters = NWParameters.udp
        parameters.includePeerToPeer = true
        parameters.serviceClass = .interactiveVideo

        browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: parameters)

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[ServiceBrowser] Browsing for peers...")
            case .failed(let error):
                print("[ServiceBrowser] Failed: \(error)")
            case .cancelled:
                print("[ServiceBrowser] Cancelled")
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self else { return }

            for change in changes {
                switch change {
                case .added(let result):
                    let endpoint = result.endpoint
                    self.discoveredPeers.append(endpoint)
                    print("[ServiceBrowser] Found peer: \(endpoint)")
                    self.onPeerFound?(endpoint)

                case .removed(let result):
                    let endpoint = result.endpoint
                    self.discoveredPeers.removeAll { $0 == endpoint }
                    print("[ServiceBrowser] Lost peer: \(endpoint)")
                    self.onPeerLost?(endpoint)

                default:
                    break
                }
            }
        }

        browser?.start(queue: queue)
    }

    /// 停止浏览
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discoveredPeers.removeAll()
    }
}
