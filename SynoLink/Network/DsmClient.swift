import Foundation

actor DsmClient {
    static let shared = DsmClient()

    var baseURL: String = ""
    var apiInfo: [String: ApiInfo] = [:]
    var synoToken: String = ""
    var sid: String = ""
    var dsSid: String = ""

    let session: URLSession
    private var sessionRecoverer: (() async -> Bool)?
    private var reloginInflight: Task<Bool, Never>?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        let delegate = SelfSignedCertDelegate()
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    func configure(baseURL: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }

    func setSessionRecoverer(_ fn: @escaping () async -> Bool) {
        self.sessionRecoverer = fn
    }

    // MARK: - Core Request

    private func buildURL(path: String, query: [String: String]) -> URL? {
        var components = URLComponents(string: baseURL + path)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components?.url
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: String] = [:],
        form: [String: String]? = nil,
        headers: [String: String] = [:],
        as: T.Type = T.self,
        retried: Bool = false
    ) async throws -> DsmResponse<T> {
        let apiName = form?["api"] ?? query["api"] ?? ""
        let useDsSid = apiName.hasPrefix("SYNO.DownloadStation.") && !dsSid.isEmpty
        let effectiveSid = useDsSid ? dsSid : sid

        var finalQuery = query
        var finalForm = form
        if !effectiveSid.isEmpty {
            if finalForm != nil { finalForm!["_sid"] = effectiveSid }
            else { finalQuery["_sid"] = effectiveSid }
        }

        guard let url = buildURL(path: path, query: finalQuery) else {
            throw DsmError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if !synoToken.isEmpty { req.setValue(synoToken, forHTTPHeaderField: "X-SYNO-TOKEN") }

        if let form = finalForm {
            let body = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
            req.httpBody = body.data(using: .utf8)
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: req)
        guard let httpResp = response as? HTTPURLResponse else { throw DsmError.invalidResponse }

        let parsed: DsmResponse<T>
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            parsed = try decoder.decode(DsmResponse<T>.self, from: data)
        } catch {
            throw DsmError.decodeFailed(error)
        }

        if !parsed.success, let code = parsed.error?.code, !retried {
            let sessionLost = [119, 105, 106, 107].contains(code)
            let isAuthCall = apiName == "SYNO.API.Auth" || path.hasSuffix("/auth.cgi")
            if sessionLost && !isAuthCall, let recoverer = sessionRecoverer {
                if reloginInflight == nil {
                    reloginInflight = Task {
                        let ok = await recoverer()
                        reloginInflight = nil
                        return ok
                    }
                }
                let ok = await reloginInflight!.value
                if ok {
                    return try await request(path: path, method: method, query: query, form: form, headers: headers, as: T.self, retried: true)
                }
            }
        }

        return parsed
    }

    // MARK: - API Entry Point

    func entry<T: Decodable>(api: String, method: String, post: Bool = false, params: [String: String] = [:], as: T.Type = T.self) async throws -> DsmResponse<T> {
        let version = apiInfo[api]?.maxVersion ?? 1
        var full = params
        full["api"] = api
        full["version"] = String(version)
        full["method"] = method
        let cgiPath = apiInfo[api]?.path ?? "entry.cgi"
        let path = "/webapi/\(cgiPath)"
        if post {
            return try await request(path: path, method: "POST", form: full, as: T.self)
        }
        return try await request(path: path, query: full, as: T.self)
    }

    // MARK: - Helpers

    func downloadURL(path: String, mode: String = "open") -> URL? {
        let info = apiInfo["SYNO.FileStation.Download"]
        let version = info?.maxVersion ?? 2
        let params: [String: String] = [
            "api": "SYNO.FileStation.Download",
            "version": String(version),
            "method": "download",
            "path": "[\"\(path)\"]",
            "mode": mode,
            "_sid": sid,
        ]
        var components = URLComponents(string: baseURL + "/webapi/entry.cgi")
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url
    }

    func thumbURL(path: String, size: String = "medium") -> URL? {
        let info = apiInfo["SYNO.FileStation.Thumb"]
        let cgi = info?.path ?? "entry.cgi"
        let version = info?.maxVersion ?? 2
        let params: [String: String] = [
            "api": "SYNO.FileStation.Thumb",
            "version": String(version),
            "method": "get",
            "path": path,
            "size": size,
            "_sid": sid,
        ]
        var components = URLComponents(string: baseURL + "/webapi/\(cgi)")
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url
    }

    func authHeaders() -> [String: String] {
        var h: [String: String] = [:]
        if !synoToken.isEmpty { h["X-SYNO-TOKEN"] = synoToken }
        return h
    }

    func fetchBytes(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        for (k, v) in authHeaders() { req.setValue(v, forHTTPHeaderField: k) }
        let (data, _) = try await session.data(for: req)
        return data
    }
}

// MARK: - Self-Signed Cert Support

private class SelfSignedCertDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

enum DsmError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodeFailed(Error)
    case apiError(code: Int, message: String?)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的响应"
        case .decodeFailed(let e): return "解析失败: \(e.localizedDescription)"
        case .apiError(let code, let msg): return "API 错误 \(code): \(msg ?? "未知")"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        }
    }
}
