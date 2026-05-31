import Foundation

struct DsmShare: Codable, Identifiable {
    var id: String { path }
    let path: String
    let name: String
    let isDir: Bool?
    let additional: ShareAdditional?
}

struct ShareAdditional: Codable {
    let real_path: String?
    let owner: OwnerInfo?
    let time: TimeInfo?
    let perm: PermInfo?
}

struct OwnerInfo: Codable { let user: String?; let uid: Int?; let group: String?; let gid: Int? }
struct TimeInfo: Codable { let atime: Int?; let mtime: Int?; let crtime: Int?; let ctime: Int? }
struct PermInfo: Codable { let posix: Int?; let is_acl_mode: Bool?; let acl: AclInfo? }
struct AclInfo: Codable { let append: Bool?; let del: Bool?; let exec: Bool?; let read: Bool?; let write: Bool? }

struct DsmFile: Codable, Identifiable {
    var id: String { path }
    let path: String
    let name: String
    let isDir: Bool
    let additional: FileAdditional?
}

struct FileAdditional: Codable {
    let size: Int64?
    let time: TimeInfo?
    let type: String?
    let perm: PermInfo?
    let real_path: String?
    let owner: OwnerInfo?
}

struct ShareListData: Codable { let shares: [DsmShare]?; let total: Int? }
struct FileListData: Codable { let files: [DsmFile]?; let total: Int? }

extension DsmClient {
    func listShare(offset: Int = 0, limit: Int = 0, additional: String = "") async throws -> DsmResponse<ShareListData> {
        return try await entry(api: "SYNO.FileStation.List", method: "list_share", params: [
            "offset": String(offset), "limit": String(limit), "additional": additional
        ], as: ShareListData.self)
    }

    func listFiles(folderPath: String, offset: Int = 0, limit: Int = 0, additional: String = "", filetype: String = "all") async throws -> DsmResponse<FileListData> {
        return try await entry(api: "SYNO.FileStation.List", method: "list", params: [
            "folder_path": folderPath, "offset": String(offset), "limit": String(limit),
            "additional": additional, "filetype": filetype
        ], as: FileListData.self)
    }

    func listFolders(folderPath: String) async throws -> DsmResponse<FileListData> {
        return try await listFiles(folderPath: folderPath, limit: 0, filetype: "dir")
    }

    func createFolder(folderPath: String, name: String, forceParent: Bool = false) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.FileStation.CreateFolder", method: "create", post: true, params: [
            "folder_path": folderPath, "name": name, "force_parent": forceParent ? "true" : "false"
        ], as: EmptyData.self)
    }

    func rename(path: String, name: String) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.FileStation.Rename", method: "rename", post: true, params: [
            "path": path, "name": name
        ], as: EmptyData.self)
    }

    func deletePath(_ path: String, recursive: Bool = true) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.FileStation.Delete", method: "delete", post: true, params: [
            "path": path, "recursive": recursive ? "true" : "false"
        ], as: EmptyData.self)
    }

    func deletePaths(_ paths: [String], recursive: Bool = true) async throws -> DsmResponse<EmptyData> {
        return try await deletePath(paths.joined(separator: ","), recursive: recursive)
    }

    struct TaskIdResult: Codable { let taskid: String }

    func copyMove(paths: [String], destFolder: String, overwrite: Bool = false, removeSource: Bool = false) async throws -> DsmResponse<TaskIdResult> {
        return try await entry(api: "SYNO.FileStation.CopyMove", method: "start", post: true, params: [
            "path": paths.joined(separator: ","), "dest_folder_path": destFolder,
            "overwrite": overwrite ? "true" : "false", "remove_src": removeSource ? "true" : "false"
        ], as: TaskIdResult.self)
    }

    struct CopyMoveStatus: Codable { let finished: Bool; let progress: Int? }

    func copyMoveStatus(taskid: String) async throws -> DsmResponse<CopyMoveStatus> {
        return try await entry(api: "SYNO.FileStation.CopyMove", method: "status", params: ["taskid": taskid], as: CopyMoveStatus.self)
    }

    func searchStart(folderPath: String, pattern: String = "", recursive: Bool = true, extension ext: String? = nil, filetype: String? = nil) async throws -> DsmResponse<TaskIdResult> {
        var params: [String: String] = [
            "folder_path": folderPath, "pattern": pattern, "recursive": recursive ? "true" : "false"
        ]
        if let ext { params["extension"] = ext }
        if let filetype { params["filetype"] = filetype }
        return try await entry(api: "SYNO.FileStation.Search", method: "start", post: true, params: params, as: TaskIdResult.self)
    }

    struct SearchListData: Codable { let files: [DsmFile]?; let total: Int? }

    func searchList(taskid: String, offset: Int = 0, limit: Int = 100, additional: String = "[\"real_path\",\"size\",\"time\",\"type\",\"perm\"]", sortBy: String? = nil, sortDirection: String? = nil) async throws -> DsmResponse<SearchListData> {
        var params: [String: String] = [
            "taskid": taskid, "offset": String(offset), "limit": String(limit), "additional": additional
        ]
        if let sortBy { params["sort_by"] = sortBy }
        if let sortDirection { params["sort_direction"] = sortDirection }
        return try await entry(api: "SYNO.FileStation.Search", method: "list", params: params, as: SearchListData.self)
    }

    func searchStop(taskid: String) async throws -> DsmResponse<EmptyData> {
        return try await entry(api: "SYNO.FileStation.Search", method: "stop", post: true, params: ["taskid": taskid], as: EmptyData.self)
    }

    func upload(folderPath: String, fileData: Data, fileName: String, overwrite: Bool = true) async throws -> DsmResponse<EmptyData> {
        let info = apiInfo["SYNO.FileStation.Upload"]
        let cgi = info?.path ?? "entry.cgi"
        let version = info?.maxVersion ?? 2

        let boundary = UUID().uuidString
        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        addField("api", "SYNO.FileStation.Upload")
        addField("version", String(version))
        addField("method", "upload")
        addField("path", folderPath)
        addField("create_parents", "true")
        addField("overwrite", overwrite ? "true" : "false")
        if !sid.isEmpty { addField("_sid", sid) }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        guard let url = URL(string: baseURL + "/webapi/\(cgi)") else { throw DsmError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        for (k, v) in authHeaders() { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body

        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder()
        return try decoder.decode(DsmResponse<EmptyData>.self, from: data)
    }
}
