import SwiftUI

/// Menu commands; their shortcuts work in both the normal and the mini layout.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Solve") {
            Button("OK") { model.markLastSolveOK() }
                .keyboardShortcut("1", modifiers: .command)
            Button("+2") { model.togglePenalty(.plusTwo) }
                .keyboardShortcut("2", modifiers: .command)
            Button("DNF") { model.togglePenalty(.dnf) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Delete") { model.deleteLastSolve() }
                .keyboardShortcut(.delete, modifiers: .command)
        }
        CommandGroup(after: .sidebar) {
            Picker("Appearance", selection: Binding(get: { model.appearance }, set: { model.appearance = $0 })) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
            }
            Divider()
        }
        #if os(macOS)
        CommandGroup(after: .sidebar) {
            Button("Normal View") { model.isMiniMode = false }
                .keyboardShortcut("o", modifiers: .command)
            Button("Mini View") { model.isMiniMode = true }
                .keyboardShortcut("i", modifiers: .command)
            Divider()
        }
        #endif
    }
}
