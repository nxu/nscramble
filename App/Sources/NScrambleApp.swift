import SwiftUI

@main
struct NScrambleApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            TimerScreen()
                .environment(model)
                .appearance(model.appearance)
        }
        .commands { AppCommands(model: model) }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 640)
        #endif
    }
}
