import SwiftUI

struct FolderPickerView: View {
    @Binding var currentFolder: String
    @Environment(\.dismiss) private var dismiss
    @State private var shares: [DsmShare] = []
    @State private var folders: [DsmFile] = []
    @State private var path: String? = nil
    @State private var pathStack: [String] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                if path == nil {
                    Section("共享文件夹") {
                        if loading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            ForEach(shares) { share in
                                Button { drill(into: share.path) } label: {
                                    HStack {
                                        Image(systemName: "folder.fill").foregroundStyle(.blue)
                                        Text(share.name)
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(.blue)
                            Text(path!).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Button("返回上级") { goUp() }
                                .font(.caption)
                        }
                    }
                    if loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if folders.isEmpty {
                        Text("无子目录").foregroundStyle(.secondary)
                    } else {
                        ForEach(folders) { folder in
                            Button { drill(into: folder.path) } label: {
                                HStack {
                                    Image(systemName: "folder.fill").foregroundStyle(.blue)
                                    Text(folder.name)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择扫描目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("选择此目录") {
                        currentFolder = path ?? "/"
                        dismiss()
                    }
                }
            }
            .task { await loadRoot() }
        }
    }

    private func drill(into folderPath: String) {
        if let current = path { pathStack.append(current) }
        else { pathStack.append("__ROOT__") }
        path = folderPath
        Task { await loadFolders() }
    }

    private func goUp() {
        if let prev = pathStack.popLast() {
            path = (prev == "__ROOT__") ? nil : prev
            Task {
                if path == nil { await loadRoot() }
                else { await loadFolders() }
            }
        }
    }

    private func loadRoot() async {
        loading = true
        defer { loading = false }
        do {
            let res = try await DsmClient.shared.listShare()
            if res.success, let data = res.data {
                shares = data.shares ?? []
            }
        } catch {}
    }

    private func loadFolders() async {
        guard let path else { return }
        loading = true
        defer { loading = false }
        do {
            let res = try await DsmClient.shared.listFolders(folderPath: path)
            if res.success, let data = res.data {
                folders = data.files ?? []
            }
        } catch {}
    }
}
