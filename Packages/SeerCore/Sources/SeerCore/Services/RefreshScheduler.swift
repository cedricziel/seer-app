import Foundation

/// Drives periodic background refreshes for a screen.
///
/// Used by views that want to poll an API while visible (e.g. Requests tab
/// polling for status changes). Owners call `start(action:)` in `.task`/
/// `onAppear` and `stop()` in `onDisappear` so we don't burn cycles or
/// network when the user isn't looking.
@MainActor
public final class RefreshScheduler {
    public private(set) var isRunning: Bool = false

    private let interval: TimeInterval
    private let clock: any RefreshClock
    private var task: Task<Void, Never>?
    private(set) var tickCount: Int = 0

    public init(interval: TimeInterval, clock: (any RefreshClock)? = nil) {
        precondition(interval > 0, "RefreshScheduler interval must be positive")
        self.interval = interval
        self.clock = clock ?? SystemRefreshClock()
    }

    /// Starts the loop. The first tick fires after `interval` seconds — the
    /// initial load is the caller's responsibility. Calling `start` again
    /// while running is a no-op.
    public func start(action: @MainActor @escaping () async -> Void) {
        guard !isRunning else { return }
        isRunning = true
        let clock = clock
        let interval = interval
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: interval)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                tickCount += 1
                await action()
            }
        }
    }

    /// Cancels the loop. Safe to call when not running.
    public func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    deinit {
        task?.cancel()
    }
}

/// Clock abstraction so tests can drive `RefreshScheduler` without real time.
public protocol RefreshClock: Sendable {
    func sleep(for seconds: TimeInterval) async throws
}

private struct SystemRefreshClock: RefreshClock {
    func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
