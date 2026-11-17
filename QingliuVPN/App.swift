import SwiftUI

@main
struct QingliuApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // qingliu://import?url=<percent-encoded subscribe url>
                    guard url.scheme == "qingliu", url.host == "import",
                          let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let raw = comps.queryItems?.first(where: { $0.name == "url" })?.value,
                          let sub = URL(string: raw) else { return }
                    Task { await store.load(subscribeURL: sub.absoluteString) }
                }
        }
    }
}
