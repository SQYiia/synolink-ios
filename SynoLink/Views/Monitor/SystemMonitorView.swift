import SwiftUI

struct SystemMonitorView: View {
    @State private var monitor = SystemMonitorStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsCard
                    if !monitor.volumes.isEmpty { volumesCard }
                    if !monitor.disks.isEmpty { disksCard }
                }
                .padding()
            }
            .navigationTitle("性能监控")
            .refreshable { await monitor.refreshAll() }
            .task { await monitor.refreshAll(); monitor.startPolling() }
            .onDisappear { monitor.stopPolling() }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("实时状态").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(label: "CPU", value: "\(monitor.cpuPct)%")
                StatItem(label: "内存", value: "\(monitor.memPct)%", sub: "\(Format.bytes(monitor.memUsed)) / \(Format.bytes(monitor.memTotal))")
                StatItem(label: "网络", value: "↑ \(Format.speed(monitor.netSend))", sub: "↓ \(Format.speed(monitor.netRecv))")
                StatItem(label: "磁盘", value: "R \(Format.speed(monitor.diskRead))", sub: "W \(Format.speed(monitor.diskWrite))")
            }
            if !monitor.cpuHistory.isEmpty {
                SparklineChart(data: monitor.cpuHistory.map(Double.init), color: .blue)
                    .frame(height: 40)
            }
        }
        .cardStyle()
    }

    private var volumesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("存储卷").font(.headline)
            ForEach(monitor.volumes) { vol in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(vol.display_name ?? vol.volume_path ?? "—").font(.subheadline)
                        Spacer()
                        let total = vol.size_total ?? 0
                        let used = vol.size_used ?? 0
                        Text("\(Format.bytes(used)) / \(Format.bytes(total))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let total = vol.size_total, total > 0 {
                        ProgressView(value: Double(vol.size_used ?? 0), total: Double(total))
                    }
                }
            }
        }
        .cardStyle()
    }

    private var disksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("磁盘").font(.headline)
            ForEach(monitor.disks) { disk in
                HStack {
                    VStack(alignment: .leading) {
                        Text(disk.name ?? disk.disk_id ?? "—").font(.subheadline)
                        if let model = disk.model { Text(model).font(.caption2).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(disk.status ?? "—").font(.caption).foregroundStyle(disk.status == "normal" ? .green : .orange)
                        if let temp = disk.temp { Text("\(temp)°C").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct SparklineChart: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = data.max() ?? 1
            let step = geo.size.width / CGFloat(max(data.count - 1, 1))
            Path { path in
                for (i, v) in data.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height * (1 - CGFloat(v / max(maxVal, 1)))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}
