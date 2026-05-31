import SwiftUI

struct FolderPickerView: View {
    @Binding var currentFolder: String
    @Environment(\.dismiss) private var dismiss
    @State private var path: String = "/"
    @State private var folders: [DsmFile] = []
    @State private var pathStack: [String] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "folder.fill").foregroundStyle(.blue)
                        Text(path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if path != "/" {
                            Button {
                                goUp()
                            } label: {
                                Label("返回上级", systemImage: "arrow.uturn.up")
                                    .font(.caption)
                            }
                        }
                    }
                }
                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if folders.isEmpty {
                    Text("无子目录").foregroundStyle(.secondary)
                } else {
                    ForEach(folders) { folder in
                        Button {
                            drill(into: folder.path)
                        } label: {
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
            .navigationTitle("选择扫描目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("选择此目录") {
                        currentFolder = path
                        dismiss()
                    }
                }
            }
            .task { await loadFolders() }
        }
    }

    private func drill(into folderPath: String) {
        pathStack.append(path)
        path = folderPath
        Task { await loadFolders() }
    }

    private func goUp() {
        if let prev = pathStack.popLast() {
            path = prev
            Task { await loadFolders() }
        }
    }

    private func loadFolders() async {
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
