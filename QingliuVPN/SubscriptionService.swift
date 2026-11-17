import Foundation

struct Node: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let kind: String     // ss / vmess / trojan / vless / hysteria2 / unknown
    let summary: String  // 服务器:端口
}

enum SubFormat: String {
    case clashYAML = "Clash YAML"
    case base64List = "Base64 链接列表"
    case plainLinks = "明文链接"
    case unknown = "未知"
}

struct Subscription: Codable {
    var url: String
    var loadedAt: Date
    var nodeCount: Int
    var format: String
}

@MainActor
final class Store: ObservableObject {
    @Published var subscribeURL: String = UserDefaults.standard.string(forKey: "sub.url") ?? ""
    @Published var nodes: [Node] = []
    @Published var format: SubFormat = .unknown
    @Published var lastLoaded: Date? = UserDefaults.standard.object(forKey: "sub.at") as? Date
    @Published var isLoading = false
    @Published var error: String?
    @Published var raw: String = ""

    var importedOnce: Bool { lastLoaded != nil }

    func save(url: String) {
        subscribeURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(subscribeURL, forKey: "sub.url")
    }

    func load(subscribeURL url: String? = nil) async {
        if let url { save(url: url) }
        guard let target = URL(string: subscribeURL), !subscribeURL.isEmpty else {
            error = "先填订阅地址"
            return
        }
        isLoading = true; error = nil
        defer { isLoading = false }

        var req = URLRequest(url: target)
        // 多数面板按 UA 返回不同格式，Clash 系 UA 最稳
        req.setValue("clash-verge/v1.7.7", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                error = "订阅返回 \( (resp as? HTTPURLResponse)?.statusCode ?? -1 )"
                return
            }
            let text = String(data: data, encoding: .utf8) ?? ""
            raw = text
            let (parsed, fmt) = Parser.parse(text)
            nodes = parsed
            format = fmt
            lastLoaded = Date()
            UserDefaults.standard.set(lastLoaded, forKey: "sub.at")
            if parsed.isEmpty { error = "解析到 0 个节点，检查订阅链接或 UA" }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

enum Parser {
    static func parse(_ text: String) -> ([Node], SubFormat) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("proxies:") || trimmed.contains("Proxy:") {
            return (parseClash(trimmed), .clashYAML)
        }
        if let decoded = base64Decode(trimmed), decoded.contains("://") {
            return (parseLinks(decoded), .base64List)
        }
        if trimmed.contains("://") {
            return (parseLinks(trimmed), .plainLinks)
        }
        return ([], .unknown)
    }

    static func parseClash(_ yaml: String) -> [Node] {
        var out: [Node] = []
        var name: String?
        var type: String?
        var server: String?
        var port: String?

        func flush() {
            if let name { out.append(Node(name: name,
                                           kind: type ?? "unknown",
                                           summary: [server, port].compactMap { $0 }.joined(separator: ":"))) }
            name = nil; type = nil; server = nil; port = nil
        }

        for rawLine in yaml.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- name:") {
                flush()
                name = value(of: line, key: "name")
            } else if line.hasPrefix("name:") {
                flush()
                name = value(of: line, key: "name")
            } else if line.hasPrefix("type:") {
                type = value(of: line, key: "type")
            } else if line.hasPrefix("server:") {
                server = value(of: line, key: "server")
            } else if line.hasPrefix("port:") {
                port = value(of: line, key: "port")
            }
        }
        flush()
        return out
    }

    static func parseLinks(_ text: String) -> [Node] {
        var out: [Node] = []
        for line in text.split(separator: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            guard let schemeEnd = s.range(of: "://") else { continue }
            let scheme = String(s[s.startIndex..<schemeEnd.lowerBound]).lowercased()
            var name = "\(scheme)-\(out.count + 1)"
            if let hash = s.range(of: "#", options: .backwards) {
                let frag = String(s[hash.upperBound...])
                if let decoded = frag.removingPercentEncoding, !decoded.isEmpty { name = decoded }
            }
            out.append(Node(name: name, kind: scheme, summary: ""))
        }
        return out
    }

    static func value(of line: String, key: String) -> String {
        line.replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "\(key):", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
    }

    static func base64Decode(_ s: String) -> String? {
        var t = s.replacingOccurrences(of: "\n", with: "")
        while t.count % 4 != 0 { t += "=" }
        guard let data = Data(base64Encoded: t) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
