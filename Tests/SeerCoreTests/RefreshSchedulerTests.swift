@testable import SeerCore
import XCTest

@MainActor
final class RefreshSchedulerTests: XCTestCase {
    func testStart_invokesActionAfterIntervalElapses() async {
        let clock = ManualRefreshClock()
        let scheduler = RefreshScheduler(interval: 30, clock: clock)
        let counter = TickCounter()

        scheduler.start { await counter.increment() }
        XCTAssertTrue(scheduler.isRunning)

        // Wait until the scheduler has registered the first sleep request.
        await clock.waitForSleeper()
        await clock.advance()
        await counter.waitForCount(1)

        let count = await counter.count
        XCTAssertEqual(count, 1)
        scheduler.stop()
    }

    func testStart_repeatsActionOnEachTick() async {
        let clock = ManualRefreshClock()
        let scheduler = RefreshScheduler(interval: 60, clock: clock)
        let counter = TickCounter()

        scheduler.start { await counter.increment() }

        for expected in 1 ... 3 {
            await clock.waitForSleeper()
            await clock.advance()
            await counter.waitForCount(expected)
        }

        let count = await counter.count
        XCTAssertEqual(count, 3)
        scheduler.stop()
    }

    func testStop_haltsTheLoop() async {
        let clock = ManualRefreshClock()
        let scheduler = RefreshScheduler(interval: 10, clock: clock)
        let counter = TickCounter()

        scheduler.start { await counter.increment() }
        await clock.waitForSleeper()
        await clock.advance()
        await counter.waitForCount(1)

        scheduler.stop()
        XCTAssertFalse(scheduler.isRunning)

        // Failing the next sleep shouldn't trigger any further increments.
        await clock.failPendingSleep()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let count = await counter.count
        XCTAssertEqual(count, 1)
    }

    func testStart_isIdempotentWhileRunning() async {
        let clock = ManualRefreshClock()
        let scheduler = RefreshScheduler(interval: 5, clock: clock)
        let counter = TickCounter()

        scheduler.start { await counter.increment() }
        scheduler.start { await counter.increment() }

        await clock.waitForSleeper()
        await clock.advance()
        await counter.waitForCount(1)

        // Both calls share the same loop -> one tick yields one increment.
        let count = await counter.count
        XCTAssertEqual(count, 1)
        scheduler.stop()
    }

    func testInit_acceptsPositiveInterval() async {
        // Forced async satisfies @MainActor test-discovery on Linux while
        // documenting that the init shape stays callable. Precondition
        // failure on a non-positive interval is intentional and not
        // exercised here.
        await Task.yield()
        let scheduler = RefreshScheduler(interval: 0.1)
        XCTAssertFalse(scheduler.isRunning)
    }
}

// MARK: - Test doubles

private actor TickCounter {
    private(set) var count: Int = 0
    private var continuations: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func increment() {
        count += 1
        let waiters = continuations.filter { $0.key <= count }
        for (key, list) in waiters {
            list.forEach { $0.resume() }
            continuations[key] = nil
        }
    }

    func waitForCount(_ target: Int) async {
        if count >= target { return }
        await withCheckedContinuation { continuation in
            continuations[target, default: []].append(continuation)
        }
    }
}

private actor ManualRefreshClock: RefreshClock {
    private var pending: [CheckedContinuation<Void, Error>] = []
    private var sleepWaiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for _: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            let waiters = sleepWaiters
            sleepWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitForSleeper() async {
        if !pending.isEmpty { return }
        await withCheckedContinuation { sleepWaiters.append($0) }
    }

    func advance() {
        guard !pending.isEmpty else { return }
        let continuation = pending.removeFirst()
        continuation.resume()
    }

    func failPendingSleep() {
        guard !pending.isEmpty else { return }
        let continuation = pending.removeFirst()
        continuation.resume(throwing: CancellationError())
    }
}
