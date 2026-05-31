import Foundation

struct ServerConfig: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var proto: Proto
    var host: String
    var port: Int
    var remark: String?
    let createTime: Date

    enum Proto: String, Codable, CaseIterable {
        case http, https
    }

    init(id: UUID = UUID(), name: String, proto: Proto, host: String, port: Int, remark: String? = nil, createTime: Date = Date()) {
        self.id = id; self.name = name; self.proto = proto; self.host = host; self.port = port
        self.remark = remark; self.createTime = createTime
    }

    var baseURL: String { "\(proto.rawValue)://\(host):\(port)" }
}

struct AccountConfig: Codable, Identifiable, Hashable {
    let id: UUID
    var serverId: UUID
    var account: String
    var password: String
    var isDefault: Bool?
    var lastLoginTime: Date?

    init(id: UUID = UUID(), serverId: UUID, account: String, password: String, isDefault: Bool? = nil, lastLoginTime: Date? = nil) {
        self.id = id; self.serverId = serverId; self.account = account; self.password = password
        self.isDefault = isDefault; self.lastLoginTime = lastLoginTime
    }
}
