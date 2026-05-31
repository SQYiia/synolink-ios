import SwiftUI

struct AddServerView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var proto: ServerConfig.Proto = .https
    @State private var host = ""
    @State private var port = "5001"
    @State private var remark = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("服务器信息") {
                TextField("服务器名称（例如：我的 NAS）", text: $name)
                Picker("协议", selection: $proto) {
                    ForEach(ServerConfig.Proto.allCases, id: \.self) { p in
                        Text(p.rawValue.uppercased()).tag(p)
                    }
                }
                TextField("主机地址（IP 或域名）", text: $host)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                TextField("端口", text: $port)
                    .keyboardType(.numberPad)
                    .onChange(of: proto) { _, new in
                        if port == "5000" || port == "5001" {
                            port = new == .https ? "5001" : "5000"
                        }
                    }
            }
            Section("备注（可选）") {
                TextField("备注信息", text: $remark, axis: .vertical)
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
            Section {
                Button(action: submit) {
                    HStack {
                        if loading { ProgressView() }
                        Text("添加并登录")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(loading || name.isEmpty || host.isEmpty || port.isEmpty)
            }
        }
        .navigationTitle("添加服务器")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        loading = true
        error = nil
        Task {
            do {
                let server = ServerConfig(name: name, proto: proto, host: host, port: Int(port) ?? 5001, remark: remark.isEmpty ? nil : remark)
                let client = DsmClient.shared
                client.configure(baseURL: server.baseURL)
                try await client.loadApiInfo()
                await MainActor.run {
                    appStore.addServer(server)
                    loading = false
                }
            } catch let e {
                await MainActor.run {
                    self.error = "无法连接服务器：\(e.localizedDescription)"
                    loading = false
                }
            }
        }
    }
}
