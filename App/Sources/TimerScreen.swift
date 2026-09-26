import ScrambleKit
import StatsKit
import SwiftUI

struct TimerScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: Bool
    @State private var touching = false

    private var isTiming: Bool {
        switch model.timer.state {
        case .holding, .running: true
        case .idle, .stopped: false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            scrambleView
                .frame(maxHeight: .infinity)
            timeView
            footer
                .frame(maxHeight: .infinity)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
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
        )
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .repeat, .up], action: handleKey)
        .onAppear { focused = true }
        .onChange(of: scenePhase) { if scenePhase != .active { model.cancelHold() } }
        .animation(.easeOut(duration: 0.15), value: isTiming)
    }

    // MARK: Parts

    private var scrambleView: some View {
        Button {
            model.skipScramble()
            focused = true
        } label: {
            Text(model.scramble?.description ?? "…")
                .font(.system(size: 26, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .buttonStyle(.plain)
        .help("New scramble")
        .opacity(isTiming ? 0 : 1)
    }

    private var timeView: some View {
        TimelineView(.animation(paused: !isTiming)) { _ in
            let now = model.now
            Text(displayedTime(now: now))
                .font(.system(size: 120, weight: .light, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(timeColor(now: now))
                .strikethrough(showsDeletedSolve)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 16) {
            if let solve = model.lastSolve, model.timer.state == .idle {
                HStack(spacing: 28) {
                    footerButton("OK", key: "1", active: solve.penalty == .none && !solve.isDeleted) {
                        model.markLastSolveOK()
                    }
                    footerButton("+2", key: "2", active: solve.penalty == .plusTwo && !solve.isDeleted) {
                        model.togglePenalty(.plusTwo)
                    }
                    footerButton("DNF", key: "3", active: solve.penalty == .dnf && !solve.isDeleted) {
                        model.togglePenalty(.dnf)
                    }
                    footerButton("Delete", key: .delete, active: solve.isDeleted) {
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

    private func footerButton(
        _ title: String, key: KeyEquivalent, active: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(title) {
            action()
            focused = true
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: .command)
        .foregroundStyle(active ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
    }

    // MARK: Display

    private func displayedTime(now: TimeInterval) -> String {
        if let elapsed = model.timer.elapsedMilliseconds(at: now) {
            return TimeFormat.string(ms: elapsed)
        }
        if case .holding = model.timer.state {
            return TimeFormat.string(ms: 0)
        }
        return model.lastSolve?.result.formatted ?? TimeFormat.string(ms: 0)
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
            // Any key stops a running timer; only space arms it.
            guard isSpace || model.timer.isRunning else { return .ignored }
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
