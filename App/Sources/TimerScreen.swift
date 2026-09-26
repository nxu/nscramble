import ScrambleKit
import StatsKit
import Storage
import SwiftUI

struct TimerScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: Bool
    @State private var touching = false
    @State private var layoutWidth: CGFloat = 0
    #if os(macOS)
    @State private var windowController = MiniWindowController()
    #endif

    private var isTiming: Bool {
        switch model.timer.state {
        case .holding, .running: true
        case .idle, .stopped: false
        }
    }

    private var isMini: Bool {
        #if os(macOS)
        model.isMiniMode
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if isMini {
                miniLayout
            } else {
                normalLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        #if os(macOS)
        // The Mac timer is keyboard-driven; the mouse moves the window (mini mode has no title bar row).
        .gesture(WindowDragGesture())
        #endif
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .repeat, .up], action: handleKey)
        .onAppear { focused = true }
        .onChange(of: scenePhase) { if scenePhase != .active { model.cancelHold() } }
        .animation(.easeOut(duration: 0.15), value: isTiming)
        #if os(macOS)
        .background(WindowAccessor { window in
            windowController.window = window
            windowController.apply(mini: model.isMiniMode, animate: false)
        })
        .onChange(of: model.isMiniMode) {
            windowController.apply(mini: model.isMiniMode)
            focused = true
        }
        #endif
    }

    // MARK: Layouts

    /// Timer area plus the stats table, shown when there's room for both.
    static let statsPanelWidth: CGFloat = 280
    static let minTimerWidthWithStats: CGFloat = 480

    private var normalLayout: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                scrambleButton(fontSize: 26, lineSpacing: 6)
                    .frame(maxHeight: .infinity)
                timeView(fontSize: 120, showsPenaltyInTime: true)
                footer
                    .frame(maxHeight: .infinity)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            #if os(iOS)
            // Touch timer; only on the timer area so the stats table can scroll.
            .gesture(touchTimerGesture)
            #endif

            if showsStats {
                Divider()
                    .ignoresSafeArea()
                    .opacity(isTiming ? 0 : 1)
                statsPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: MiniWindowController.normalMinSize.width, minHeight: MiniWindowController.normalMinSize.height)
        #endif
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { layoutWidth = $0 }
        .overlay(alignment: .topTrailing) { appearanceButton }
    }

    private var showsStats: Bool {
        layoutWidth >= Self.statsPanelWidth + Self.minTimerWidthWithStats
    }

    #if os(iOS)
    private var touchTimerGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !touching {
                    touching = true
                    model.press()
                }
            }
            .onEnded { _ in
                touching = false
                model.release()
            }
    }
    #endif

    /// Scrollable stats with the sync card pinned below.
    private var statsPanel: some View {
        VStack(spacing: 0) {
            TimelineView(.everyMinute) { context in
                StatsPanel(stats: model.stats, recentSolves: model.todaysRecentSolves, date: context.date)
                    // Recompute when the day changes (and on first appearance).
                    .task(id: Solve.day(of: context.date)) { model.refreshStats() }
            }
            SyncCard()
        }
        .frame(width: Self.statsPanelWidth)
        .opacity(isTiming ? 0 : 1)
    }

    /// Cycles System -> Light -> Dark.
    private var appearanceButton: some View {
        Button {
            model.appearance = model.appearance.next
            focused = true
        } label: {
            Image(systemName: model.appearance.symbol)
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Appearance: \(model.appearance.title)")
        .padding(.trailing, 10)  // vertically centered on the traffic lights
        .opacity(isTiming ? 0 : 1)
    }

    /// Fixed 400 x 200 window. The scramble is centered between the traffic lights and the top of the
    /// time's digits; the badge is centered between the bottom of the digits and the window bottom.
    private var miniLayout: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let timeFontSize: CGFloat = 72
            // Digits are ~0.735 em tall and centered in the text's line box.
            let digitsHalfHeight = timeFontSize * 0.735 / 2
            // Low enough that two centered scramble lines clear the traffic lights.
            let timeCenter = height * 0.59
            let digitsTop = timeCenter - digitsHalfHeight
            let digitsBottom = timeCenter + digitsHalfHeight
            let trafficLightsBottom: CGFloat = 26

            ZStack {
                scrambleButton(fontSize: 18, lineSpacing: 0)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .frame(width: width - 16, height: digitsTop - trafficLightsBottom)
                    .position(x: width / 2, y: (trafficLightsBottom + digitsTop) / 2)
                timeView(fontSize: timeFontSize, showsPenaltyInTime: false)
                    .position(x: width / 2, y: timeCenter)
                statusBadge
                    .position(x: width / 2, y: (digitsBottom + height) / 2)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Parts

    private func scrambleButton(fontSize: CGFloat, lineSpacing: CGFloat) -> some View {
        Button {
            model.skipScramble()
            focused = true
        } label: {
            Text(model.scramble?.description ?? "…")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(lineSpacing)
        }
        .buttonStyle(.plain)
        .help("New scramble")
        .opacity(isTiming ? 0 : 1)
    }

    /// `showsPenaltyInTime`: render `14.34+` / `DNF` in the time itself (normal layout) instead of a badge.
    private func timeView(fontSize: CGFloat, showsPenaltyInTime: Bool) -> some View {
        TimelineView(.animation(paused: !isTiming)) { _ in
            let now = model.now
            Text(displayedTime(now: now, showsPenalty: showsPenaltyInTime))
                .font(.system(size: fontSize, weight: .light, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(timeColor(now: now))
                .strikethrough(showsDeletedSolve)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let solve = model.lastSolve, model.timer.state == .idle {
            let (title, color) = badge(for: solve)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1))
        }
    }

    private func badge(for solve: Solve) -> (String, Color) {
        if solve.isDeleted {
            return ("DELETED", .secondary)
        }
        switch solve.penalty {
        case .none: return ("OK", .green)
        case .plusTwo: return ("+2", .orange)
        case .dnf: return ("DNF", .red)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 16) {
            if let solve = model.lastSolve, model.timer.state == .idle {
                HStack(spacing: 28) {
                    footerButton("OK", active: solve.penalty == .none && !solve.isDeleted) {
                        model.markLastSolveOK()
                    }
                    footerButton("+2", active: solve.penalty == .plusTwo && !solve.isDeleted) {
                        model.togglePenalty(.plusTwo)
                    }
                    footerButton("DNF", active: solve.penalty == .dnf && !solve.isDeleted) {
                        model.togglePenalty(.dnf)
                    }
                    footerButton("Delete", active: solve.isDeleted) {
                        model.deleteLastSolve()
                    }
                }
                .font(.system(size: 17, design: .monospaced))
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 24)
        .opacity(isTiming ? 0 : 1)
    }

    private func footerButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(title) {
            action()
            focused = true
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
    }

    // MARK: Display

    private func displayedTime(now: TimeInterval, showsPenalty: Bool) -> String {
        if let elapsed = model.timer.elapsedMilliseconds(at: now) {
            return TimeFormat.string(ms: elapsed)
        }
        if case .holding = model.timer.state {
            return TimeFormat.string(ms: 0)
        }
        guard let result = model.lastSolve?.result else { return TimeFormat.string(ms: 0) }
        if showsPenalty {
            return result.formatted
        }
        // The badge shows the status; show the time itself (including +2).
        return TimeFormat.string(ms: result.timeMs + (result.penalty == .plusTwo ? 2000 : 0))
    }

    private var showsDeletedSolve: Bool {
        model.timer.state == .idle && model.lastSolve?.isDeleted == true
    }

    private func timeColor(now: TimeInterval) -> Color {
        if showsDeletedSolve {
            return .secondary
        }
        guard case .holding = model.timer.state else { return .primary }
        return model.timer.isReady(at: now) ? .green : .red
    }

    // MARK: Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let isSpace = press.key == .space
        switch press.phase {
        case .down:
            if model.timer.isRunning {
                // Any key stops the timer; Esc records a DNF.
                model.press(penalty: press.key == .escape ? .dnf : .none)
                return .handled
            }
            if press.key == .escape, case .holding = model.timer.state {
                model.cancelHold()
                return .handled
            }
            guard isSpace else { return .ignored }
            model.press()
            return .handled
        case .repeat:
            return isSpace || model.timer.isRunning ? .handled : .ignored
        case .up:
            guard isSpace || model.timer.state == .stopped else { return .ignored }
            model.release()
            return .handled
        default:
            return .ignored
        }
    }
}

#Preview {
    TimerScreen()
        .environment(AppModel())
}
