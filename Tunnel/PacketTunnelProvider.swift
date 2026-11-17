import NetworkExtension

/// 可选 target：真 VPN 隧道。需要付费开发者账号 + Network Extension entitlement。
/// 用法：把 sing-box / WireGuard 的 Go/C 库按各自文档接进来，在 startTunnel 里启动，
/// 再把 `Self.subscribeURL` 拉到的配置交给内核。
final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var tunnel: Any?

    override func startTunnel(options: [String: NSObject]?) async throws {
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let cfg = proto.providerConfiguration else {
            throw NSError(domain: "Qingliu", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "缺少隧道配置"])
        }

        // 1. 取出 App 侧写入的订阅 / 节点信息
        let subscribeURL = cfg["subscribeURL"] as? String ?? ""

        // 2. 起内核（示例：sing-box 的 Start 接口）
        //    let box = try Box(config: configJSON)
        //    try box.start()
        //    self.tunnel = box

        // 3. 设置虚拟网卡
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        settings.mtu = 1400

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dns

        try await setTunnelNetworkSettings(settings)

        _ = subscribeURL // 生产里在这里把订阅转换成内核配置
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        // 收尾：停内核、关连接
        tunnel = nil
    }
}
