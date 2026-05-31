import Foundation

struct VmmGuest: Codable, Identifiable {
    var id: String { guest_id }
    let guest_id: String
    let guest_name: String?
    let status: String?
    let vcpu_num: Int?
    let vram_size: Int?
    let autorun: Int?
    let description: String?
    let storage_name: String?
}

struct VmmHost: Codable, Identifiable {
    var id: String { host_id }
    let host_id: String
    let host_name: String?
    let status: String?
    let total_cpu_core: Int?
    let free_cpu_core: Int?
    let total_ram_size: Int?
    let free_ram_size: Int?
}

struct VmmStorage: Codable, Identifiable {
    var id: String { storage_id }
    let storage_id: String
    let storage_name: String?
    let host_name: String?
    let status: String?
    let size: Int64?
    let used: Int64?
    let volume_path: String?
}

struct VmmGuestListData: Codable { let guests: [VmmGuest]? }
struct VmmHostListData: Codable { let hosts: [VmmHost]? }
struct VmmStorageListData: Codable { let storages: [VmmStorage]? }

extension DsmClient {
    func vmmHostList() async throws -> DsmResponse<VmmHostListData> {
        return try await entry(api: "SYNO.Virtualization.API.Host", method: "list", as: VmmHostListData.self)
    }

    func vmmGuestList() async throws -> DsmResponse<VmmGuestListData> {
        return try await entry(api: "SYNO.Virtualization.API.Guest", method: "list", params: ["additional": "true"], as: VmmGuestListData.self)
    }

    func vmmStorageList() async throws -> DsmResponse<VmmStorageListData> {
        return try await entry(api: "SYNO.Virtualization.API.Storage", method: "list", as: VmmStorageListData.self)
    }

    func vmmGuestPowerOn(_ guestId: String) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.Virtualization.API.Guest.Action", method: "poweron", params: ["guest_id": guestId], as: EmptyData.self)
    }

    func vmmGuestShutdown(_ guestId: String) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.Virtualization.API.Guest.Action", method: "shutdown", params: ["guest_id": guestId], as: EmptyData.self)
    }

    func vmmGuestPowerOff(_ guestId: String) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.Virtualization.API.Guest.Action", method: "poweroff", params: ["guest_id": guestId], as: EmptyData.self)
    }
}
