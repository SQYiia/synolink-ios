import SwiftUI

struct DownloadsView: View {
    @State private var store = DownloadStationStore()

    var body: some View {
        NavigationStack {
            List {
                if !store.available {
                    ContentUnavailableView("Download Station 不可用", systemImage: "exclamationmark.triangle", description: Text(store.reason))
                } else if store.tasks.isEmpty && !store.loading {
                    ContentUnavailableView("暂无下载任务", systemImage: "arrow.down.circle")
                } else {
                    Section {
                        HStack {
                            Label("↓ \(Format.speed(store.speedDownload))", systemImage: "arrow.down")
                            Spacer()
                            Label("↑ \(Format.speed(store.speedUpload))", systemImage: "arrow.up")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    ForEach(store.tasks) { task in
                        DownloadTaskRow(task: task)
                            .contextMenu {
                                if task.status == "downloading" || task.status == "seeding" {
                                    Button("暂停") { Task { try? await store.pauseTasks([task.id]) } }
                                }
                                if task.status == "paused" || task.status == "error" {
                                    Button("恢复") { Task { try? await store.resumeTasks([task.id]) } }
                                }
                                Button("删除", role: .destructive) {
                                    Task { try? await store.deleteTasks([task.id]) }
                                }
                            }
                    }
                }
            }
            .navigationTitle("下载站")
            .refreshable { await store.refresh() }
            .task {
                await store.refresh()
                store.startPolling()
            }
            .onDisappear { store.stopPolling() }
        }
    }
}

struct DownloadTaskRow: View {
    let task: DSTask

    var progress: Double {
        guard task.size ?? 0 > 0 else { return 0 }
        return Double(task.sizeDownloaded) / Double(task.size ?? 1)
    }

    var statusColor: Color {
        switch task.status {
        case "downloading", "seeding": return .blue
        case "paused", "filehosting_waiting": return .orange
        case "finished", "finishing": return .green
        case "error": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title ?? "未知任务")
                .font(.subheadline)
                .lineLimit(2)
            ProgressView(value: progress)
                .tint(statusColor)
            HStack {
                Text(task.status ?? "unknown")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
                Spacer()
                Text(Format.bytes(task.sizeDownloaded))
                    .font(.caption2).foregroundStyle(.secondary)
                Text("/ \(Format.bytes(task.size ?? 0))")
                    .font(.caption2).foregroundStyle(.secondary)
                if task.speedDownload > 0 {
                    Text(Format.speed(task.speedDownload))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
