import Foundation

struct SystemUtilization: Codable {
    let cpu: CpuInfo?
    let memory: MemoryInfo?
    let network: [NetworkInfo]?
    let disk: DiskUtilInfo?
}

struct CpuInfo: Codable { let user_load: Int?; let system_load: Int? }
struct MemoryInfo: Codable { let total_real: Int?; let avail_real: Int?; let avail: Int? }
struct NetworkInfo: Codable { let device: String?; let tx: Int64?; let rx: Int64? }
struct DiskUtilInfo: Codable { let total: DiskTotal? }
struct DiskTotal: Codable { let read_byte: Int64?; let write_byte: Int64? }

struct Volume: Codable, Identifiable {
    var id: String { display_name ?? volume_path ?? "vol" }
    let display_name: String?
    let volume_path: String?
    let status: String?
    let size_total: Int64?
    let size_used: Int64?
    let size_free_user: Int64?
}

struct Disk: Codable, Identifiable {
    var id: String { name ?? disk_id ?? "disk" }
    let name: String?
    let disk_id: String?
    let model: String?
    let vendor: String?
    let temp: Int?
    let status: String?
    let size_total: Int64?
    let capacity: String?
}

struct VolumeListData: Codable { let volumes: [Volume]? }
struct DiskListData: Codable { let disks: [Disk]? }

extension DsmClient {
    func systemInfo() async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.Core.System", method: "info", params: ["type": "storage"], as: EmptyData.self)
    }

    func systemUtilization() async throws -> DsmResponse<SystemUtilization> {
        return try await entry(api: "SYNO.Core.System.Utilization", method: "get", params: ["type": "current"], as: SystemUtilization.self)
    }

    func storageInfo() async throws -> DsmResponse<VolumeListData> {
        return try await entry(api: "SYNO.Core.Storage.Volume", method: "list", params: [
            "limit": "-1", "offset": "0", "location": "internal", "option": "none"
        ], as: VolumeListData.self)
    }

    func diskInfo() async throws -> DsmResponse<DiskListData> {
        return try await entry(api: "SYNO.Core.Storage.Disk", method: "list", params: [
            "limit": "-1", "offset": "0"
        ], as: DiskListData.self)
    }
}
