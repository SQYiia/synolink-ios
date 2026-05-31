import SwiftUI

struct ServerListView: View {
    @Environment(AppStore.self) private var appStore
    @State private var serverStatus: [UUID: Bool] = [:]

    var body: some View {
        @Bindable var store = appStore
        List {
            if store.servers.isEmpty {
                ContentUnavailableView("暂无服务器", systemImage: "server.rack", description: Text("点击右上角 + 添加 NAS 服务器"))
            } else {
                ForEach(store.servers) { server in
                    NavigationLink(value: server) {
                        HStack {
                            Circle()
                                .fill(serverStatus[server.id] == true ? .green : .gray)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading) {
                                Text(server.name).font(.headline)
                                Text(server.baseURL).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        let server = store.servers[idx]
                        store.removeServer(id: server.id)
                    }
                }
            }
        }
        .navigationTitle("SynoLink")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AddServerView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: ServerConfig.self) { server in
            LoginView(server: server)
        }
        .refreshable { await checkAllStatus() }
        .task { await checkAllStatus() }
    }

    private func checkAllStatus() async {
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for server in appStore.servers {
                group.addTask {
                    let ok = await probeServer(server)
                    return (server.id, ok)
                }
            }
            for await (id, ok) in group {
                await MainActor.run { serverStatus[id] = ok }
            }
        }
    }

    private func probeServer(_ server: ServerConfig) async -> Bool {
        let url = URL(string: "\(server.baseURL)/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query")
        guard let url else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
