import SwiftUI

struct DashboardTile: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let icon: String
    let colorName: String

    var color: Color {
        switch colorName {
        case "blue": return .blue
        case "pink": return .pink
        case "purple": return .purple
        case "green": return .green
        case "cyan": return .cyan
        case "orange": return .orange
        default: return .gray
        }
    }
}

struct DashboardView: View {
    @Environment(AppStore.self) private var appStore
    @Binding var selectedTab: Int
    @State private var monitor = SystemMonitorStore()
    @State private var isEditing = false
    @State private var showSystemMonitor = false
    @State private var showVmm = false
    @AppStorage("dashboard.hiddenTiles") private var hiddenTilesData: String = "[]"

    private static let allTiles: [DashboardTile] = [
        .init(id: "files", title: "文件", icon: "folder.fill", colorName: "blue"),
        .init(id: "album", title: "相册", icon: "photo.fill", colorName: "pink"),
        .init(id: "video", title: "视频", icon: "video.fill", colorName: "purple"),
        .init(id: "downloads", title: "下载", icon: "arrow.down.circle.fill", colorName: "green"),
        .init(id: "performance", title: "性能", icon: "speedometer", colorName: "cyan"),
        .init(id: "vmm", title: "虚拟机", icon: "server.rack", colorName: "orange"),
    ]

    private var hiddenTiles: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: Data(hiddenTilesData.utf8))) ?? []
    }

    private var visibleTiles: [DashboardTile] {
        let hidden = hiddenTiles
        return Self.allTiles.filter { isEditing || !hidden.contains($0.id) }
    }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "完成" : "编辑") {
                        withAnimation(.easeInOut) { isEditing.toggle() }
                    }
                }
            }
            .refreshable { await monitor.refreshAll() }
            .task {
                await monitor.refreshAll()
                monitor.startPolling()
            }
            .onDisappear { monitor.stopPolling() }
            .sheet(isPresented: $showSystemMonitor) {
                NavigationStack { SystemMonitorView() }
            }
            .sheet(isPresented: $showVmm) {
                NavigationStack { VmmView() }
            }
        }
    }

    private func tileAction(_ tile: DashboardTile) {
        switch tile.id {
        case "files": selectedTab = 1
        case "album": selectedTab = 2
        case "downloads": selectedTab = 3
        case "performance": showSystemMonitor = true
        case "vmm": showVmm = true
        default: break
        }
    }

    private func toggleVisibility(_ tile: DashboardTile) {
        var hidden = hiddenTiles
        if hidden.contains(tile.id) { hidden.remove(tile.id) }
        else { hidden.insert(tile.id) }
        if let data = try? JSONEncoder().encode(hidden), let str = String(data: data, encoding: .utf8) {
            hiddenTilesData = str
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
            ForEach(visibleTiles) { tile in
                AppTile(
                    title: tile.title,
                    icon: tile.icon,
                    color: tile.color,
                    isEditing: isEditing,
                    isHidden: hiddenTiles.contains(tile.id)
                ) {
                    if isEditing {
                        toggleVisibility(tile)
                    } else {
                        tileAction(tile)
                    }
                }
            }
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
    var isEditing: Bool = false
    var isHidden: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(isHidden ? .secondary : color)
                        .frame(width: 48, height: 48)
                        .background((isHidden ? Color.gray : color).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    if isEditing {
                        Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(isHidden ? Color.red : Color.green, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                Text(title).font(.caption).foregroundStyle(isHidden ? .secondary : .primary)
            }
            .opacity(isHidden ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
