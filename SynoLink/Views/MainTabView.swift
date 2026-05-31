import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedTab = 0
    @State private var sessionReady = false
    @State private var sessionError: String?

    var body: some View {
        Group {
            if !sessionReady {
                VStack(spacing: 16) {
                    ProgressView()
                    if let sessionError {
                        Text(sessionError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重试") {
                            Task { await restoreSession() }
                        }
                    } else {
                        Text("正在连接服务器...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView(selectedTab: $selectedTab)
                        .tabItem { Label("首页", systemImage: "house") }
                        .tag(0)

                    FilesView()
                        .tabItem { Label("文件", systemImage: "folder") }
                        .tag(1)

                    AlbumView()
                        .tabItem { Label("相册", systemImage: "photo.on.rectangle") }
                        .tag(2)

                    DownloadsView()
                        .tabItem { Label("下载", systemImage: "arrow.down.circle") }
                        .tag(3)

                    SettingsView()
                        .tabItem { Label("设置", systemImage: "gearshape") }
                        .tag(4)
                }
            }
        }
        .task { await restoreSession() }
    }

    private func restoreSession() async {
        guard let server = appStore.currentServer,
              let account = appStore.currentAccount else {
            sessionError = "未找到服务器或账号配置"
            return
        }
        let dsm = DsmClient.shared
        dsm.configure(baseURL: server.baseURL)
        do {
            try await dsm.loadApiInfo()
        } catch {
            sessionError = "加载 API 信息失败: \(error.localizedDescription)"
            return
        }
        do {
            let res = try await dsm.login(account: account.account, passwd: account.password)
            if !res.success {
                let code = res.error?.code ?? -1
                sessionError = "登录失败 (code=\(code))，请检查账号密码"
                return
            }
        } catch {
            sessionError = "登录失败: \(error.localizedDescription)"
            return
        }
        dsm.setSessionRecoverer {
            guard let acc = await MainActor.run(body: { self.appStore.currentAccount }) else { return false }
            let res = try? await dsm.login(account: acc.account, passwd: acc.password)
            return res?.success ?? false
        }
        sessionReady = true
    }
}
