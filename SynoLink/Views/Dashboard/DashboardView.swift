import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var appStore
    @State private var monitor = SystemMonitorStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    userInfoCard
                    systemStatusCard
                    appsGrid
                }
                .padding()
            }
            .navigationTitle("SynoLink")
            .refreshable { await monitor.refreshAll() }
            .task {
                await monitor.refreshAll()
                monitor.startPolling()
            }
            .onDisappear { monitor.stopPolling() }
        }
    }

    private var userInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(appStore.currentAccount?.account ?? "未登录")
                    .font(.headline)
                Text(DsmClient.shared.baseURL.isEmpty ? "—" : DsmClient.shared.baseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统状态").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(label: "CPU", value: "\(monitor.cpuPct)%")
                StatItem(label: "内存", value: Format.bytes(monitor.memUsed), sub: "/ \(Format.bytes(monitor.memTotal))")
                StatItem(label: "网络", value: "↑ \(Format.speed(monitor.netSend))", sub: "↓ \(Format.speed(monitor.netRecv))")
                StatItem(label: "磁盘", value: "R \(Format.speed(monitor.diskRead))", sub: "W \(Format.speed(monitor.diskWrite))")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var appsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            AppTile(title: "文件", icon: "folder.fill", color: .blue)
            AppTile(title: "相册", icon: "photo.fill", color: .pink)
            AppTile(title: "视频", icon: "video.fill", color: .purple)
            AppTile(title: "下载", icon: "arrow.down.circle.fill", color: .green)
            AppTile(title: "性能", icon: "speedometer", color: .cyan)
            AppTile(title: "虚拟机", icon: "server.rack", color: .orange)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StatItem: View {
    let label: String
    let value: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline).fontWeight(.semibold)
            if let sub { Text(sub).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppTile: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            Text(title).font(.caption)
        }
    }
}
