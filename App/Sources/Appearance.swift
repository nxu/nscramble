import SwiftUI

/// Light/dark preference. `system` follows the OS setting.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var next: AppearanceMode {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension View {
    /// Applies the appearance app-wide. On macOS `NSApp.appearance` is used because
    /// `preferredColorScheme(nil)` doesn't reliably switch back to following the system.
    func appearance(_ mode: AppearanceMode) -> some View {
        #if os(macOS)
        onChange(of: mode, initial: true) {
            NSApp.appearance = switch mode {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        }
        #else
        preferredColorScheme(mode.colorScheme)
        #endif
    }
}
