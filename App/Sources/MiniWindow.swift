#if os(macOS)
import AppKit
import SwiftUI

/// Resizes the window between the normal layout and the fixed-size mini layout.
@MainActor
final class MiniWindowController {
    static let miniSize = NSSize(width: 400, height: 200)
    static let normalMinSize = NSSize(width: 640, height: 420)
    static let normalDefaultSize = NSSize(width: 900, height: 600)

    weak var window: NSWindow?
    private var normalFrame: NSRect?

    func apply(mini: Bool, animate: Bool = true) {
        guard let window else { return }
        if mini {
            guard window.styleMask.contains(.resizable) else { return }
            normalFrame = window.frame
            window.styleMask.remove(.resizable)
            window.contentMinSize = Self.miniSize
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.miniSize))
            // Keep the top-left corner in place.
            frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
            window.setFrame(frame, display: true, animate: animate)
        } else {
            window.styleMask.insert(.resizable)
            window.contentMinSize = Self.normalMinSize
            if let normalFrame {
                window.setFrame(normalFrame, display: true, animate: animate)
                self.normalFrame = nil
            } else if window.frame.width < Self.normalMinSize.width || window.frame.height < Self.normalMinSize.height {
                // E.g. relaunched in normal mode after quitting in mini mode.
                var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.normalDefaultSize))
                frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
                window.setFrame(frame, display: true, animate: animate)
            }
        }
    }
}

/// Hands the hosting `NSWindow` to `onWindow` once the view is attached to it.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowReportingView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowReportingView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                onWindow?(window)
            }
        }
    }
}
#endif
