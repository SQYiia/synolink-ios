import SwiftUI

struct LoginView: View {
    let server: ServerConfig
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    @State private var account = ""
    @State private var passwd = ""
    @State private var loading = false
    @State private var error: String?
    @State private var showOtpAlert = false
    @State private var otpCode = ""

    private let dsm = DsmClient.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 40)
                    VStack(alignment: .leading) {
                        Text(server.name).font(.headline)
                        Text(server.baseURL).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("账号信息") {
                TextField("DSM 账号", text: $account)
                    .textContentType(.username)
                    .autocapitalization(.none)
                SecureField("DSM 密码", text: $passwd)
                    .textContentType(.password)
            }

            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        if loading { ProgressView() }
                        Text("登录")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(loading || account.isEmpty || passwd.isEmpty)
            }
        }
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dsm.configure(baseURL: server.baseURL)
            loadLastAccount()
            Task { try? await dsm.loadApiInfo() }
        }
        .alert("两步验证", isPresented: $showOtpAlert) {
            TextField("请输入 OTP 验证码", text: $otpCode)
                .keyboardType(.numberPad)
            Button("确定") {
                Task { await doLogin(otpCode: otpCode) }
            }
            Button("取消", role: .cancel) { otpCode = "" }
        } message: {
            Text("需要输入两步验证 OTP 码")
        }
    }

    private func loadLastAccount() {
        let last = appStore.accountsForServer(server.id).first
        if let last {
            account = last.account
            passwd = last.password
        }
    }

    private func submit() {
        Task { await doLogin(otpCode: "") }
    }

    private func doLogin(otpCode: String) async {
        loading = true
        error = nil
        do {
            let res = try await dsm.login(account: account, passwd: passwd, otpCode: otpCode)
            if res.success {
                await MainActor.run {
                    let existing = appStore.accounts.first { $0.serverId == server.id && $0.account == account }
                    if var acc = existing {
                        acc.password = passwd
                        acc.lastLoginTime = Date()
                        appStore.updateAccount(acc)
                        appStore.setCurrent(serverId: server.id, accountId: acc.id)
                    } else {
                        let acc = AccountConfig(serverId: server.id, account: account, password: passwd, lastLoginTime: Date())
                        appStore.addAccount(acc)
                        appStore.setCurrent(serverId: server.id, accountId: acc.id)
                    }
                    loading = false
                }
            } else {
                let code = res.error?.code ?? 0
                if code == 400 {
                    await MainActor.run { error = "账号或密码错误"; loading = false }
                } else if code == 403 || code == 404 {
                    await MainActor.run { loading = false; showOtpAlert = true }
                } else {
                    await MainActor.run { error = "登录失败 (code=\(code))"; loading = false }
                }
            }
        } catch let e {
            await MainActor.run { self.error = "请求异常：\(e.localizedDescription)"; loading = false }
        }
    }
}
