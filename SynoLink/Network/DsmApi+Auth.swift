import Foundation

extension DsmClient {
    func loadApiInfo() async throws {
        let res: DsmResponse<[String: ApiInfo]> = try await request(
            path: "/webapi/query.cgi",
            query: ["api": "SYNO.API.Info", "version": "1", "method": "query", "query": "all"]
        )
        if res.success, let data = res.data { self.apiInfo = data }
    }

    func login(account: String, passwd: String, otpCode: String = "", deviceId: String? = nil) async throws -> DsmResponse<AuthResult> {
        var params: [String: String] = [
            "session": "FileStation",
            "format": "sid",
            "enable_syno_token": "yes",
            "enable_device_token": "no",
            "account": account,
            "passwd": passwd,
            "otp_code": otpCode,
        ]
        if let did = deviceId { params["device_id"] = did }

        let res: DsmResponse<AuthResult> = try await entry(api: "SYNO.API.Auth", method: "login", post: true, params: params, as: AuthResult.self)
        if res.success, let data = res.data {
            self.sid = data.sid ?? ""
            self.synoToken = data.synotoken ?? ""
            try? await dsLogin(account: account, passwd: passwd, otpCode: otpCode, deviceId: deviceId)
        }
        return res
    }

    private func dsLogin(account: String, passwd: String, otpCode: String, deviceId: String?) async throws {
        var params: [String: String] = [
            "session": "DownloadStation",
            "format": "sid",
            "account": account,
            "passwd": passwd,
            "otp_code": otpCode,
        ]
        if let did = deviceId { params["device_id"] = did }
        let res: DsmResponse<AuthResult> = try await entry(api: "SYNO.API.Auth", method: "login", post: true, params: params, as: AuthResult.self)
        if res.success, let sid = res.data?.sid { self.dsSid = sid }
    }

    func logout() async throws {
        let _: DsmResponse<EmptyData> = try await entry(api: "SYNO.API.Auth", method: "logout", params: ["session": "FileStation"], as: EmptyData.self)
        if !dsSid.isEmpty {
            let _: DsmResponse<EmptyData> = try await entry(api: "SYNO.API.Auth", method: "logout", params: ["session": "DownloadStation"], as: EmptyData.self)
            dsSid = ""
        }
    }

    func setCredentials(sid: String, synoToken: String, dsSid: String = "") {
        self.sid = sid
        self.synoToken = synoToken
        self.dsSid = dsSid
    }
}
