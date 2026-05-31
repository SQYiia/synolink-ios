import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("首页", systemImage: "house") }

            FilesView()
                .tabItem { Label("文件", systemImage: "folder") }

            AlbumView()
                .tabItem { Label("相册", systemImage: "photo.on.rectangle") }

            DownloadsView()
                .tabItem { Label("下载", systemImage: "arrow.down.circle") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
