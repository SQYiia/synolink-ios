import SwiftUI

@main
struct SynoLinkApp: App {
    @State private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appStore)
                .onAppear { appStore.load() }
        }
    }
}
