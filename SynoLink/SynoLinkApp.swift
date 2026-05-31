import SwiftUI

@main
struct SynoLinkApp: App {
    @State private var appStore = AppStore()
    @AppStorage("themeMode") private var themeMode = "system"

    private var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appStore)
                .preferredColorScheme(colorScheme)
                .onAppear { appStore.load() }
        }
    }
}
