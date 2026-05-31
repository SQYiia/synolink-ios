import Foundation
import Observation

@Observable
class DownloadStationStore {
    var tasks: [DSTask] = []
    var speedDownload: Int64 = 0
    var speedUpload: Int64 = 0
    var loading = false
    var available = true
    var reason = ""

    private var pollTask: Task<Void, Never>?
    private let dsm = DsmClient.shared

    func startPolling(interval: Duration = .seconds(3)) {
        stopPolling()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    @MainActor
    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let probeRes = try await dsm.dsInfo()
            if !probeRes.success {
                let code = probeRes.error?.code ?? 0
                if [102, 103, 104, 105].contains(code) {
                    available = false
                    reason = "Download Station 不可用 (code=\(code))"
                    return
                }
            }
            available = true
            reason = ""

            async let taskRes = dsm.dsTaskList()
            async let statRes = dsm.dsStatistic()
            let (tasks, stats) = try await (taskRes, statRes)
            if tasks.success, let data = tasks.data { self.tasks = data.tasks ?? [] }
            if stats.success, let data = stats.data {
                speedDownload = data.speed_download ?? 0
                speedUpload = data.speed_upload ?? 0
            }
        } catch {
            // network error, keep last state
        }
    }

    func createTask(uri: String, destination: String? = nil) async throws {
        _ = try await dsm.dsTaskCreate(uri: uri, destination: destination)
        await refresh()
    }

    func pauseTasks(_ ids: [String]) async throws {
        _ = try await dsm.dsTaskPause(ids: ids)
        await refresh()
    }

    func resumeTasks(_ ids: [String]) async throws {
        _ = try await dsm.dsTaskResume(ids: ids)
        await refresh()
    }

    func deleteTasks(_ ids: [String], forceComplete: Bool = false) async throws {
        _ = try await dsm.dsTaskDelete(ids: ids, forceComplete: forceComplete)
        await refresh()
    }
}
