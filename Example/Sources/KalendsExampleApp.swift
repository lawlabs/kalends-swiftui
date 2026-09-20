import SwiftUI

@main
struct KalendsExampleApp: App {
    /// Launch with `-colorScheme dark` or `-colorScheme light` to pin the
    /// appearance, e.g. for screenshots; otherwise the system setting applies.
    private var pinnedColorScheme: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "colorScheme") {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(pinnedColorScheme)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 800)
        #endif
    }
}
