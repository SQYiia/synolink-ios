import SwiftUI
import UniformTypeIdentifiers

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
    @State private var showUploadPicker = false
    @State private var shareFile: ShareFileItem?
    @State private var activityMessage: String?

    private let dsm = DsmClient.shared
    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "webp"]

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
            ToolbarItem(placement: .topBarLeading) {
                Button { showUploadPicker = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
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
        .fileImporter(isPresented: $showUploadPicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            Task { await handleUpload(result) }
        }
        .sheet(item: $shareFile) { item in
            ShareSheet(items: [item.url])
        }
        .overlay(alignment: .bottom) {
            if let activityMessage {
                Text(activityMessage)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func isImageFile(_ name: String) -> Bool {
        imageExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    private func fileRow(_ file: DsmFile) -> some View {
        HStack(spacing: 10) {
            if !file.isDir && isImageFile(file.name), let thumbURL = dsm.thumbURL(path: file.path, size: "small") {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: file.isDir ? "folder.fill" : iconForFile(file.name))
                    .foregroundStyle(file.isDir ? .blue : .secondary)
                    .frame(width: 40, height: 40)
            }
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
            if !file.isDir {
                Button {
                    Task { await downloadAndShare(file) }
                } label: {
                    Label("下载", systemImage: "arrow.down.circle")
                }
            }
            Button("重命名") { }
            Button("删除", role: .destructive) {
                Task { try? await dsm.deletePath(file.path); await loadFiles() }
            }
        }
    }

    private func downloadAndShare(_ file: DsmFile) async {
        guard let url = dsm.downloadURL(path: file.path) else { return }
        withAnimation { activityMessage = "正在下载 \(file.name)..." }
        do {
            let data = try await dsm.fetchBytes(url: url)
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(file.name)
            try data.write(to: tempFile)
            await MainActor.run {
                activityMessage = nil
                shareFile = ShareFileItem(url: tempFile)
            }
        } catch {
            await MainActor.run { activityMessage = "下载失败: \(error.localizedDescription)" }
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { activityMessage = nil }
        }
    }

    private func handleUpload(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            let fileName = url.lastPathComponent
            await MainActor.run { activityMessage = "正在上传 \(fileName)..." }
            do {
                let res = try await dsm.upload(folderPath: path, fileData: data, fileName: fileName)
                if !res.success {
                    await MainActor.run { activityMessage = "上传失败: \(fileName)" }
                }
            } catch {
                await MainActor.run { activityMessage = "上传失败: \(error.localizedDescription)" }
            }
        }
        await MainActor.run { activityMessage = nil }
        await loadFiles()
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

struct ShareFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
