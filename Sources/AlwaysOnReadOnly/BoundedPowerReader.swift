import Foundation
import AlwaysOnCore

private final class ReadCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PowerReceipt, Error>?
    init(_ continuation: CheckedContinuation<PowerReceipt, Error>) { self.continuation = continuation }
    func finish(_ result: Result<PowerReceipt, Error>) {
        lock.lock(); let target = continuation; continuation = nil; lock.unlock()
        target?.resume(with: result)
    }
}
/// A stuck nonmutating read may be abandoned, but never accumulates queued work.
/// Late results are discarded; the native worker remains single-flight until exit.
public final class BoundedPowerReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.snapbridge.power-readback")
    private let lock = NSLock()
    private var busy = false
    private let sample: () throws -> PowerReceipt
    private let timeout: TimeInterval
    private let now: () -> TimeInterval
    public init() { sample = StrictPowerValues.readSystem; timeout = 1; now = { ProcessInfo.processInfo.systemUptime } }
    public init(fixtureRead: @escaping () throws -> PowerReceipt, timeout: TimeInterval = 1,
                fixtureUptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        sample = fixtureRead; self.timeout = timeout.isFinite ? max(0.01, min(1, timeout)) : 1; now = fixtureUptime
    }
    public func read() async throws -> PowerReceipt {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard !busy else { lock.unlock(); continuation.resume(throwing: NativeIOError.busy); return }
            busy = true; lock.unlock()
            let completion = ReadCompletion(continuation)
            let deadline = now() + timeout
            // Dispatch deadlines use monotonic uptime. The worker itself may be
            // stuck in a system call, so its queue cannot host this deadline.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                completion.finish(.failure(NativeIOError.readback))
            }
            queue.async {
                let result = Result { try self.sample() }
                self.lock.lock(); self.busy = false; self.lock.unlock()
                completion.finish(self.now() >= deadline ? .failure(NativeIOError.readback) : result)
            }
        }
    }
}
