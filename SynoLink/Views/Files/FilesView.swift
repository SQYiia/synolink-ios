import SwiftUI

struct FilesView: View {
    @State private var navPath = NavigationPath()
    @State private var shares: [DsmShare] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private let dsm = DsmClient.shared

    enum SortOption: String, CaseIterable { case name = "名称", size = "大小", time = "时间" }

    var body: some View {
        NavigationStack(path: $navPath) {
            shareListView
                .navigationTitle("文件")
                .navigationDestination(for: String.self) { path in
                    FolderContentsView(path: path)
                }
                .task { await loadShares() }
        }
    }

    private var shareListView: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView {
                    Label("加载失败", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重试") { Task { await loadShares() } }
                }
            } else if shares.isEmpty && !loading {
                ContentUnavailableView("暂无共享文件夹", systemImage: "folder")
            } else {
                List {
                    if shares.isEmpty && loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        ForEach(shares) { share in
                            NavigationLink(value: share.path) {
                                HStack {
                                    Image(systemName: "folder.fill").foregroundStyle(.blue)
                                    Text(share.name)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable { await loadShares() }
    }

    private func loadShares() async {
        loading = true
        defer { loading = false }
        do {
            let res = try await dsm.listShare(additional: "[\"real_path\",\"owner\",\"time\"]")
            if res.success, let data = res.data {
                shares = data.shares ?? []
                errorMessage = nil
            } else {
                let code = res.error?.code ?? -1
                errorMessage = "加载共享列表失败 (code=\(code))"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FolderContentsView: View {
    let path: String
    @State private var files: [DsmFile] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var sortBy: FilesView.SortOption = .name
    @State private var sortAsc = true

    private let dsm = DsmClient.shared

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView {
                    Label("加载失败", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重试") { Task { await loadFiles() } }
                }
            } else if files.isEmpty && !loading {
                ContentUnavailableView("文件夹为空", systemImage: "folder.badge.questionmark")
            } else {
                List {
                    if files.isEmpty && loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        ForEach(files) { file in
                            if file.isDir {
                                NavigationLink(value: file.path) {
                                    fileRow(file)
                                }
                            } else {
                                fileRow(file)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(path.components(separatedBy: "/").last ?? path)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(FilesView.SortOption.allCases, id: \.self) { opt in
                        Button {
                            sortBy = opt
                            sortFiles()
                        } label: {
                            HStack {
                                Text(opt.rawValue)
                                if sortBy == opt { Image(systemName: sortAsc ? "arrow.up" : "arrow.down") }
                            }
                        }
                    }
                } label: { Image(systemName: "arrow.up.arrow.down") }
            }
        }
        .refreshable { await loadFiles() }
        .task { await loadFiles() }
    }

    private func fileRow(_ file: DsmFile) -> some View {
        HStack {
            Image(systemName: file.isDir ? "folder.fill" : iconForFile(file.name))
                .foregroundStyle(file.isDir ? .blue : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(file.name).lineLimit(1)
                if let size = file.additional?.size, !file.isDir {
                    Text(Format.bytes(size)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if file.isDir {
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button("重命名") { }
            Button("删除", role: .destructive) {
                Task { try? await dsm.deletePath(file.path); await loadFiles() }
            }
        }
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv": return "video"
        case "mp3", "flac", "wav", "aac": return "music.note"
        case "pdf": return "doc.richtext"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox"
        default: return "doc"
        }
    }

    private func loadFiles() async {
        loading = true
        defer { loading = false }
        do {
            let res = try await dsm.listFiles(folderPath: path, additional: "[\"size\",\"time\",\"type\"]")
            if res.success, let data = res.data {
                files = data.files ?? []
                errorMessage = nil
            } else {
                let code = res.error?.code ?? -1
                errorMessage = "加载文件列表失败 (code=\(code))"
            }
            sortFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sortFiles() {
        files.sort { a, b in
            if a.isDir != b.isDir { return a.isDir }
            switch sortBy {
            case .name: return sortAsc ? a.name < b.name : a.name > b.name
            case .size:
                let sa = a.additional?.size ?? 0, sb = b.additional?.size ?? 0
                return sortAsc ? sa < sb : sa > sb
            case .time:
                let ta = a.additional?.time?.mtime ?? 0, tb = b.additional?.time?.mtime ?? 0
                return sortAsc ? ta < tb : ta > tb
            }
        }
    }
}
