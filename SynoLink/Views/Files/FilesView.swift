import SwiftUI

struct FilesView: View {
    @State private var currentPath: String? = nil
    @State private var shares: [DsmShare] = []
    @State private var files: [DsmFile] = []
    @State private var loading = false
    @State private var pathStack: [String] = []
    @State private var sortBy: SortOption = .name
    @State private var sortAsc = true

    enum SortOption: String, CaseIterable { case name = "名称", size = "大小", time = "时间" }

    private let dsm = DsmClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if let path = currentPath {
                    fileList
                        .navigationTitle(path.components(separatedBy: "/").last ?? path)
                } else {
                    shareList
                        .navigationTitle("文件")
                }
            }
            .toolbar {
                if currentPath != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { goUp() } label: { Image(systemName: "chevron.left") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { opt in
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
            }
            .refreshable { await refresh() }
            .task { await loadShares() }
        }
    }

    private var shareList: some View {
        List {
            if shares.isEmpty && loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                ForEach(shares) { share in
                    Button { navigate(to: share.path) } label: {
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
    }

    private var fileList: some View {
        List {
            if files.isEmpty && loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                ForEach(files) { file in
                    Button {
                        if file.isDir { navigate(to: file.path) }
                    } label: {
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
                    }
                    .contextMenu {
                        Button("重命名") { /* TODO */ }
                        Button("删除", role: .destructive) {
                            Task { try? await dsm.deletePath(file.path); await refresh() }
                        }
                    }
                }
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

    private func loadShares() async {
        loading = true
        defer { loading = false }
        do {
            let res = try await dsm.listShare(additional: "[\"real_path\",\"owner\",\"time\"]")
            if res.success, let data = res.data { shares = data.shares ?? [] }
        } catch {}
    }

    private func loadFiles(path: String) async {
        loading = true
        defer { loading = false }
        do {
            let res = try await dsm.listFiles(folderPath: path, additional: "[\"size\",\"time\",\"type\"]")
            if res.success, let data = res.data { files = data.files ?? [] }
            sortFiles()
        } catch {}
    }

    private func navigate(to path: String) {
        if currentPath != nil { pathStack.append(currentPath!) }
        currentPath = path
        Task { await loadFiles(path: path) }
    }

    private func goUp() {
        if let prev = pathStack.popLast() {
            currentPath = prev
            Task { await loadFiles(path: prev) }
        } else {
            currentPath = nil
            files = []
        }
    }

    private func refresh() async {
        if let path = currentPath { await loadFiles(path: path) }
        else { await loadShares() }
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
