import Foundation
import UIKit

/// 把订阅交给已装好的代理客户端。
/// iOS 上没有 NetworkExtension 权限就做不了真 VPN，
/// 所以正路是：本 App 负责登录/拉订阅/换节点，隧道交给 Shadowrocket / Stash / sing-box 这类已签名客户端。
enum ImportService {

    enum Target: String, CaseIterable, Identifiable {
        case shadowrocket = "Shadowrocket"
        case stash = "Stash"
        case clash = "ClashX/iOS Clash"
        case singbox = "sing-box"
        var id: String { rawValue }

        var scheme: String {
            switch self {
            case .shadowrocket: return "shadowrocket"
            case .stash:        return "stash"
            case .clash:        return "clash"
            case .singbox:      return "sing-box"
            }
        }
    }

    static func isInstalled(_ t: Target) -> Bool {
        guard let url = URL(string: "\(t.scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// 各客户端的「添加订阅」深链
    static func addSubscriptionURL(_ target: Target, sub: String) -> URL? {
        let encoded = sub.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sub
        switch target {
        case .shadowrocket:
            return URL(string: "shadowrocket://add/sub://\(b64(sub))?remark=Qingliu")
        case .stash:
            return URL(string: "stash://install-config?url=\(encoded)")
        case .clash:
            return URL(string: "clash://install-config?url=\(encoded)")
        case .singbox:
            return URL(string: "sing-box://import-remote-profile?url=\(encoded)")
        }
    }

    static func b64(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    @MainActor
    static func open(_ target: Target, sub: String) -> Bool {
        guard let url = addSubscriptionURL(target, sub: sub) else { return false }
        guard isInstalled(target) else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
