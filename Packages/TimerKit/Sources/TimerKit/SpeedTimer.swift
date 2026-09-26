import Foundation

/// Stackmat-style timer: hold to arm, release to start, press to stop.
///
/// Timestamps are seconds on a monotonic clock (e.g. `ProcessInfo.systemUptime`, which is also the
/// time base of `NSEvent` and `UITouch` timestamps). The caller feeds in input events; the timer
/// has no clock of its own, which keeps it deterministic and testable.
public struct SpeedTimer: Sendable {
    public enum State: Equatable, Sendable {
        case idle
        /// Pressed; becomes ready to start once held for `holdDuration`.
        case holding(since: TimeInterval)
        case running(since: TimeInterval)
        /// Just stopped; waiting for the key or touch to be released.
        case stopped
    }

    public private(set) var state: State = .idle
    public var holdDuration: TimeInterval

    public init(holdDuration: TimeInterval = 0.3) {
        self.holdDuration = holdDuration
    }

    /// Key or touch down. Returns the solve time in milliseconds if this stopped the timer.
    public mutating func press(at time: TimeInterval) -> Int? {
        switch state {
        case .idle:
            state = .holding(since: time)
            return nil
        case .running(let start):
            state = .stopped
            return Self.milliseconds(from: start, to: time)
        case .holding, .stopped:
            return nil
        }
    }

    /// Key or touch up. Returns true if this started the timer.
    @discardableResult
    public mutating func release(at time: TimeInterval) -> Bool {
        switch state {
        case .holding(let since) where time - since >= holdDuration:
            state = .running(since: time)
            return true
        case .holding, .stopped:
            state = .idle
            return false
        case .idle, .running:
            return false
        }
    }

    /// Abandons a hold, e.g. when the window loses focus. A running timer keeps running.
    public mutating func cancelHold() {
        if case .holding = state {
            state = .idle
        }
    }

    public func isReady(at time: TimeInterval) -> Bool {
        if case .holding(let since) = state {
            return time - since >= holdDuration
        }
        return false
    }

    public func elapsedMilliseconds(at time: TimeInterval) -> Int? {
        if case .running(let start) = state {
            return Self.milliseconds(from: start, to: time)
        }
        return nil
    }

    public var isRunning: Bool {
        if case .running = state {
            return true
        }
        return false
    }

    static func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
        max(0, Int(((end - start) * 1000).rounded(.down)))
    }
}
