import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedTab = 0

    var body: some View {
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
        .task { await restoreSession() }
    }

    private func restoreSession() async {
        guard let server = appStore.currentServer,
              let account = appStore.currentAccount else { return }
        let dsm = DsmClient.shared
        dsm.configure(baseURL: server.baseURL)
        try? await dsm.loadApiInfo()
        _ = try? await dsm.login(account: account.account, passwd: account.password)
        dsm.setSessionRecoverer {
            guard let acc = await MainActor.run(body: { self.appStore.currentAccount }) else { return false }
            let res = try? await dsm.login(account: acc.account, passwd: acc.password)
            return res?.success ?? false
        }
    }
}
