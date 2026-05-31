import Foundation

struct DSTask: Codable, Identifiable {
    let id: String
    let type: String?
    let title: String?
    let size: Int64?
    let status: String?
    let additional: DSAdditional?

    var speedDownload: Int64 { additional?.transfer?.speed_download ?? 0 }
    var speedUpload: Int64 { additional?.transfer?.speed_upload ?? 0 }
    var sizeDownloaded: Int64 { additional?.transfer?.size_downloaded ?? 0 }
    var sizeUploaded: Int64 { additional?.transfer?.size_uploaded ?? 0 }
    var destination: String { additional?.detail?.destination ?? "" }
    var uri: String { additional?.detail?.uri ?? "" }
}

struct DSAdditional: Codable {
    let transfer: DSTransfer?
    let detail: DSDetail?
}

struct DSTransfer: Codable {
    let size_downloaded: Int64?
    let size_uploaded: Int64?
    let speed_download: Int64?
    let speed_upload: Int64?
}

struct DSDetail: Codable {
    let destination: String?
    let uri: String?
    let create_time: Int?
}

struct DSTaskListData: Codable { let tasks: [DSTask]?; let total: Int?; let offset: Int? }
struct DSStatistic: Codable { let speed_download: Int64?; let speed_upload: Int64? }

extension DsmClient {
    func dsInfo() async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.DownloadStation.Info", method: "getinfo", as: DsmResponse<EmptyData>.self)
    }

    func dsGetConfig() async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.DownloadStation.Info", method: "getconfig", as: DsmResponse<EmptyData>.self)
    }

    func dsTaskList(offset: Int = 0, limit: Int = -1, additional: String = "detail,transfer") async throws -> DsmResponse<DSTaskListData> {
        return try await entry(api: "SYNO.DownloadStation.Task", method: "list", params: [
            "offset": String(offset), "limit": String(limit), "additional": additional
        ], as: DsmResponse<DSTaskListData>.self)
    }

    func dsTaskGetInfo(ids: [String], additional: String = "detail,transfer,file") async throws -> DsmResponse<DSTaskListData> {
        return try await entry(api: "SYNO.DownloadStation.Task", method: "getinfo", params: [
            "id": ids.joined(separator: ","), "additional": additional
        ], as: DsmResponse<DSTaskListData>.self)
    }

    func dsTaskCreate(uri: String, destination: String? = nil) async throws -> DsmResponse<EmptyData> {
        var params: [String: String] = ["uri": uri]
        if let dest = destination { params["destination"] = normalizeDestination(dest) }
        return try await entry(api: "SYNO.DownloadStation.Task", method: "create", post: true, params: params, as: DsmResponse<EmptyData>.self)
    }

    func dsTaskDelete(ids: [String], forceComplete: Bool = false) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.DownloadStation.Task", method: "delete", params: [
            "id": ids.joined(separator: ","), "force_complete": forceComplete ? "true" : "false"
        ], as: DsmResponse<EmptyData>.self)
    }

    func dsTaskPause(ids: [String]) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.DownloadStation.Task", method: "pause", params: [
            "id": ids.joined(separator: ",")
        ], as: DsmResponse<EmptyData>.self)
    }

    func dsTaskResume(ids: [String]) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.DownloadStation.Task", method: "resume", params: [
            "id": ids.joined(separator: ",")
        ], as: DsmResponse<EmptyData>.self)
    }

    func dsStatistic() async throws -> DsmResponse<DSStatistic> {
        return try await entry(api: "SYNO.DownloadStation.Statistic", method: "getinfo", as: DsmResponse<DSStatistic>.self)
    }

    private func normalizeDestination(_ p: String) -> String {
        var s = p.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\", with: "/")
        while s.hasPrefix("/") { s = String(s.dropFirst()) }
        if let range = s.range(of: #"^volume\d+/"#, options: .regularExpression) { s = String(s[range.upperBound...]) }
        while s.hasSuffix("/") { s = String(s.dropLast()) }
        return s
    }
}
