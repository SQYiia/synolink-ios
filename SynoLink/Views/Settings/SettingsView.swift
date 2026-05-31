import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var appStore
    @AppStorage("themeMode") private var themeMode = "system"

    var body: some View {
        @Bindable var store = appStore
        NavigationStack {
            List {
                Section("账号") {
                    if let acc = store.currentAccount {
                        LabeledContent("账号", value: acc.account)
                        LabeledContent("状态", value: DsmClient.shared.synoToken.isEmpty ? "未连接" : "已连接")
                    }
                }

                Section("外观") {
                    Picker("主题", selection: $themeMode) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                }

                Section {
                    NavigationLink("切换服务器") {
                        ServerListView()
                    }
                    Button("退出登录", role: .destructive) {
                        Task {
                            try? await DsmClient.shared.logout()
                            store.logout()
                        }
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                }
            }
            .navigationTitle("设置")
        }
    }
}
