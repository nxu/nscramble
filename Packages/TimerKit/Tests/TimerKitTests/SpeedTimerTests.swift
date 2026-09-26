import Testing
@testable import TimerKit

@Test func fullSolve() {
    var timer = SpeedTimer(holdDuration: 0.3)
    let pressed = timer.press(at: 10.0)
    #expect(pressed == nil)
    #expect(!timer.isReady(at: 10.2))
    #expect(timer.isReady(at: 10.3))
    let started = timer.release(at: 10.5)
    #expect(started)
    #expect(timer.elapsedMilliseconds(at: 12.0) == 1500)
    let time = timer.press(at: 22.3456)
    #expect(time == 11845)
    #expect(timer.state == .stopped)
    let restarted = timer.release(at: 22.5)
    #expect(!restarted)
    #expect(timer.state == .idle)
}

@Test func releasingTooEarlyDoesNotStart() {
    var timer = SpeedTimer(holdDuration: 0.3)
    _ = timer.press(at: 1.0)
    let started = timer.release(at: 1.29)
    #expect(!started)
    #expect(timer.state == .idle)
}

@Test func repeatedPressesAreIgnored() {
    var timer = SpeedTimer()
    _ = timer.press(at: 1.0)
    let second = timer.press(at: 1.1)
    #expect(second == nil)
    #expect(timer.state == .holding(since: 1.0))
}

@Test func cancelHoldKeepsRunningTimer() {
    var timer = SpeedTimer()
    _ = timer.press(at: 1.0)
    timer.cancelHold()
    #expect(timer.state == .idle)
    _ = timer.press(at: 2.0)
    timer.release(at: 3.0)
    timer.cancelHold()
    #expect(timer.isRunning)
}
