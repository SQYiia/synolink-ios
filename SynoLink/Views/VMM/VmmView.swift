import SwiftUI

struct VmmView: View {
    @State private var store = VmmStore()

    var body: some View {
        NavigationStack {
            List {
                if !store.available {
                    ContentUnavailableView("VMM 不可用", systemImage: "server.rack", description: Text("未安装 Virtual Machine Manager"))
                } else {
                    if !store.hosts.isEmpty {
                        Section("主机") {
                            ForEach(store.hosts) { host in
                                VStack(alignment: .leading) {
                                    Text(host.host_name ?? host.host_id).font(.headline)
                                    HStack {
                                        Text("CPU: \(host.total_cpu_core ?? 0) 核")
                                        Spacer()
                                        Text("RAM: \(Format.bytes(Int64(host.total_ram_size ?? 0)))")
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !store.guests.isEmpty {
                        Section("虚拟机") {
                            ForEach(store.guests) { guest in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(guest.guest_name ?? guest.guest_id).font(.subheadline)
                                        Spacer()
                                        Text(guest.status ?? "unknown")
                                            .font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(statusColor(guest.status).opacity(0.15), in: Capsule())
                                            .foregroundStyle(statusColor(guest.status))
                                    }
                                    Text("\(guest.vcpu_num ?? 0) vCPU / \(Format.bytes(Int64(guest.vram_size ?? 0)))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .contextMenu {
                                    if guest.status == "shutdown" {
                                        Button("开机") { Task { try? await store.powerOn(guest.guest_id) } }
                                    }
                                    if guest.status == "running" {
                                        Button("关机") { Task { try? await store.shutdown(guest.guest_id) } }
                                        Button("强制关机", role: .destructive) { Task { try? await store.powerOff(guest.guest_id) } }
                                    }
                                }
                            }
                        }
                    }

                    if !store.storages.isEmpty {
                        Section("存储") {
                            ForEach(store.storages) { s in
                                VStack(alignment: .leading) {
                                    Text(s.storage_name ?? s.storage_id).font(.subheadline)
                                    Text("\(Format.bytes(s.used ?? 0)) / \(Format.bytes(s.size ?? 0))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("虚拟机")
            .refreshable { await store.refresh() }
            .task { await store.refresh(); store.startPolling() }
            .onDisappear { store.stopPolling() }
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "running": return .green
        case "shutdown": return .gray
        case "booting", "shutting_down": return .orange
        case "crashed", "inaccessible": return .red
        default: return .gray
        }
    }
}
