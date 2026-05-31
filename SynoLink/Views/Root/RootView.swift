import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        if appStore.currentServer != nil && appStore.currentAccount != nil {
            MainTabView()
        } else {
            NavigationStack {
                ServerListView()
            }
        }
    }
}
