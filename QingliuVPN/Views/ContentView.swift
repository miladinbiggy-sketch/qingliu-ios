import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            List {
                Section("订阅") {
                    HStack {
                        Text("地址").foregroundStyle(.secondary)
                        Spacer()
                        Text(store.subscribeURL.isEmpty ? "未设置" : hostOf(store.subscribeURL))
                            .lineLimit(1).truncationMode(.middle)
                    }
                    HStack {
                        Text("格式").foregroundStyle(.secondary)
                        Spacer()
                        Text(store.format.rawValue)
                    }
                    HStack {
                        Text("节点").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(store.nodes.count)")
                    }
                    if let at = store.lastLoaded {
                        HStack {
                            Text("上次拉取").foregroundStyle(.secondary)
                            Spacer()
                            Text(at.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    Button {
                        Task { await store.load() }
                    } label: {
                        HStack {
                            if store.isLoading { ProgressView().padding(.trailing, 6) }
                            Text(store.isLoading ? "拉取中…" : "拉取 / 刷新")
                        }
                    }
                    .disabled(store.isLoading)
                }

                if let err = store.error {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section("导入到代理客户端") {
                    ForEach(ImportService.Target.allCases) { t in
                        Button {
                            _ = ImportService.open(t, sub: store.subscribeURL)
                        } label: {
                            HStack {
                                Text(t.rawValue)
                                Spacer()
                                Image(systemName: ImportService.isInstalled(t)
                                      ? "checkmark.circle.fill" : "arrow.up.right.square")
                                    .foregroundStyle(ImportService.isInstalled(t) ? .green : .secondary)
                            }
                        }
                        .disabled(store.subscribeURL.isEmpty)
                    }
                    Button("复制订阅链接") {
                        UIPasteboard.general.string = store.subscribeURL
                    }
                }

                Section("节点（\(store.nodes.count)）") {
                    if store.nodes.isEmpty {
                        Text("还没有节点。先设订阅地址再拉取。").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.nodes) { n in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.name).font(.callout)
                                Text("\(n.kind)  \(n.summary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("清流")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("设置") { showSetup = true }
                }
            }
            .sheet(isPresented: $showSetup) {
                SetupView().environmentObject(store)
            }
            .task {
                if !store.subscribeURL.isEmpty && store.nodes.isEmpty {
                    await store.load()
                }
            }
        }
    }

    private func hostOf(_ s: String) -> String {
        URL(string: s)?.host ?? s
    }
}

struct SetupView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("订阅地址") {
                    TextField("https://你的面板/api/v1/client/subscribe?token=…", text: $text, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .lineLimit(2...4)
                }
                Section {
                    Button("保存并拉取") {
                        store.save(url: text)
                        dismiss()
                        Task { await store.load() }
                    }
                    .disabled(text.isEmpty)
                } footer: {
                    Text("面板里「一键订阅 → 复制订阅链接」拿到的地址；token 只存在本机 UserDefaults。")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { text = store.subscribeURL }
        }
    }
}
