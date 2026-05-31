import Foundation
import Observation

@Observable
class VmmStore {
    var guests: [VmmGuest] = []
    var hosts: [VmmHost] = []
    var storages: [VmmStorage] = []
    var loading = false
    var available = true

    private var pollTask: Task<Void, Never>?
    private let dsm = DsmClient.shared

    func startPolling(interval: Duration = .seconds(5)) {
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
            async let guestRes = dsm.vmmGuestList()
            async let hostRes = dsm.vmmHostList()
            async let storageRes = dsm.vmmStorageList()
            let (g, h, s) = try await (guestRes, hostRes, storageRes)
            if g.success, let data = g.data { guests = data.guests ?? []; available = true }
            else if let code = g.error?.code, [102, 103].contains(code) { available = false }
            if h.success, let data = h.data { hosts = data.hosts ?? [] }
            if s.success, let data = s.data { storages = data.storages ?? [] }
        } catch {}
    }

    func powerOn(_ guestId: String) async throws {
        _ = try await dsm.vmmGuestPowerOn(guestId)
        await refresh()
    }

    func shutdown(_ guestId: String) async throws {
        _ = try await dsm.vmmGuestShutdown(guestId)
        await refresh()
    }

    func powerOff(_ guestId: String) async throws {
        _ = try await dsm.vmmGuestPowerOff(guestId)
        await refresh()
    }
}
