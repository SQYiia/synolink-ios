import Foundation
import Observation

@Observable
class SystemMonitorStore {
    var cpuPct: Int = 0
    var memPct: Int = 0
    var memTotal: Int64 = 0
    var memUsed: Int64 = 0
    var netSend: Int64 = 0
    var netRecv: Int64 = 0
    var diskRead: Int64 = 0
    var diskWrite: Int64 = 0
    var volumes: [Volume] = []
    var disks: [Disk] = []
    var sharesCount: Int = 0
    var loading = false

    var cpuHistory: [Int] = []
    var memHistory: [Int] = []
    var netSendHistory: [Int64] = []
    var netRecvHistory: [Int64] = []

    private let historyMax = 60
    private var pollTask: Task<Void, Never>?
    private let dsm = DsmClient.shared

    func startPolling(interval: Duration = .seconds(5)) {
        stopPolling()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await refreshUtil()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pushHistory<T>(_ arr: inout [T], _ val: T) {
        arr.append(val)
        if arr.count > historyMax { arr.removeFirst() }
    }

    @MainActor
    func refreshAll() async {
        loading = true
        defer { loading = false }
        async let util = refreshUtil()
        async let stor = refreshStorage()
        async let disk = refreshDisks()
        async let shares = refreshShares()
        _ = await (util, stor, disk, shares)
    }

    @MainActor
    func refreshUtil() async {
        do {
            let res = try await dsm.systemUtilization()
            guard res.success, let d = res.data else { return }
            let cpuUser = d.cpu?.user_load ?? 0
            let cpuSys = d.cpu?.system_load ?? 0
            cpuPct = min(100, cpuUser + cpuSys)
            let totalReal = Int64(d.memory?.total_real ?? 0) * 1024
            let avail = Int64(d.memory?.avail_real ?? d.memory?.avail ?? 0) * 1024
            memTotal = totalReal
            memUsed = max(0, totalReal - avail)
            memPct = totalReal > 0 ? Int(Double(memUsed) / Double(totalReal) * 100) : 0
            let nets = d.network ?? []
            let total = nets.first { $0.device == "total" } ?? nets.first
            netSend = total?.tx ?? 0
            netRecv = total?.rx ?? 0
            let diskTotal = d.disk?.total
            diskRead = diskTotal?.read_byte ?? 0
            diskWrite = diskTotal?.write_byte ?? 0

            pushHistory(&cpuHistory, cpuPct)
            pushHistory(&memHistory, memPct)
            pushHistory(&netSendHistory, netSend)
            pushHistory(&netRecvHistory, netRecv)
        } catch {}
    }

    @MainActor
    func refreshStorage() async {
        do {
            let res = try await dsm.storageInfo()
            if res.success, let data = res.data { volumes = data.volumes ?? [] }
        } catch {}
    }

    @MainActor
    func refreshDisks() async {
        do {
            let res = try await dsm.diskInfo()
            if res.success, let data = res.data { disks = data.disks ?? [] }
        } catch {}
    }

    @MainActor
    func refreshShares() async {
        do {
            let res = try await dsm.listShare(limit: 100)
            if res.success, let data = res.data { sharesCount = data.shares?.count ?? 0 }
        } catch {}
    }
}
