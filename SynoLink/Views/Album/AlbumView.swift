import SwiftUI

struct AlbumView: View {
    @State private var photos: [DsmFile] = []
    @State private var loading = false
    @State private var selectedPhoto: DsmFile?
    @State private var showFolderPicker = false
    @AppStorage("album.scanFolder") private var scanFolder = "/"

    private let dsm = DsmClient.shared
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photos) { photo in
                        Button { selectedPhoto = photo } label: {
                            AsyncImage(url: dsm.thumbURL(path: photo.path, size: "small")) { phase in
                                switch phase {
                                case .empty: ProgressView().frame(width: 100, height: 100)
                                case .success(let img): img.resizable().aspectRatio(1, contentMode: .fill).clipped()
                                case .failure: Image(systemName: "photo").frame(width: 100, height: 100).foregroundStyle(.secondary)
                                @unknown default: EmptyView()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(scanFolder == "/" ? "相册" : (scanFolder as NSString).lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFolderPicker = true } label: {
                        Image(systemName: "folder")
                    }
                }
            }
            .refreshable { await scanPhotos() }
            .task { await scanPhotos() }
            .onChange(of: scanFolder) { _, _ in Task { await scanPhotos() } }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(currentFolder: $scanFolder)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
        }
    }

    private func scanPhotos() async {
        loading = true
        defer { loading = false }
        do {
            let res = try await dsm.searchStart(folderPath: scanFolder, extension: "jpg,jpeg,png,heic,gif,webp", filetype: "file")
            guard res.success, let taskid = res.data?.taskid else { return }
            var all: [DsmFile] = []
            var offset = 0
            while true {
                let listRes = try await dsm.searchList(taskid: taskid, offset: offset, limit: 500)
                guard listRes.success, let files = listRes.data?.files, !files.isEmpty else { break }
                all.append(contentsOf: files)
                offset += files.count
                if offset >= (listRes.data?.total ?? 0) { break }
            }
            try? await dsm.searchStop(taskid: taskid)
            photos = all
        } catch {}
    }
}

struct PhotoDetailView: View {
    let photo: DsmFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AsyncImage(url: DsmClient.shared.thumbURL(path: photo.path, size: "large")) { phase in
                switch phase {
                case .empty: ProgressView()
                case .success(let img): img.resizable().aspectRatio(contentMode: .fit)
                case .failure: Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                @unknown default: EmptyView()
                }
            }
            .navigationTitle(photo.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
