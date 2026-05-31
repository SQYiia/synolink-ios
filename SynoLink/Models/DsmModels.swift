import Foundation

struct DsmResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: DsmApiError?
}

struct DsmApiError: Decodable {
    let code: Int?
    let errors: AnyCodable?
}

struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = NSNull() }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v.mapValues { $0.value } }
        else if let v = try? container.decode([AnyCodable].self) { value = v.map { $0.value } }
        else { value = NSNull() }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let s as String: try container.encode(s)
        case let i as Int: try container.encode(i)
        case let b as Bool: try container.encode(b)
        case let d as Double: try container.encode(d)
        default: try container.encodeNil()
        }
    }
}

struct AuthResult: Codable {
    let sid: String?
    let synotoken: String?
    let did: String?
    let account: String?
    let device_id: String?
}

struct ApiInfo: Codable {
    let path: String?
    let minVersion: Int?
    let maxVersion: Int?
    let requestFormat: String?
}

struct EmptyData: Codable {}
