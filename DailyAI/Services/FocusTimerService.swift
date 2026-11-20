import Foundation

// App-level (not view-level) so the timer survives switching tabs. A
// View's @State — and any Timer stored in it — is torn down whenever that
// View leaves the hierarchy (e.g. switching the mac sidebar destination),
// which made the focus timer look "frozen at 0" after navigating away and
// back. Elapsed time is computed from a wall-clock start time rather than
// an accumulated tick count, so it's correct even if ticks were missed.
@MainActor
final class FocusTimerService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds = 0

    private var startedAt: Date?
    private var tickTimer: Timer?

    func start() {
        guard !isRunning else { return }
        startedAt = Date()
        elapsedSeconds = 0
        isRunning = true
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func reset() {
        startedAt = Date()
        elapsedSeconds = 0
    }

    private func tick() {
        guard let startedAt else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
    }

    @discardableResult
    func stop() -> Int {
        let result = elapsedSeconds
        tickTimer?.invalidate()
        tickTimer = nil
        isRunning = false
        startedAt = nil
        elapsedSeconds = 0
        return result
    }
}
