import Foundation

/// Tiny thread-safe holder used by intent tests to capture values
/// from closures that run on non-main concurrent contexts.
/// Avoids the Swift 6 "mutation of captured var in concurrently-
/// executing code" diagnostic without pulling in `actor` boilerplate.
final class AtomicValue<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T?

    init() {}

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func set(_ newValue: T?) {
        lock.lock()
        defer { lock.unlock() }
        stored = newValue
    }
}

final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Bool = false

    init() {}

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        stored = newValue
    }
}
