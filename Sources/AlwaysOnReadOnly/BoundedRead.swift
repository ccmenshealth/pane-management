import Foundation

private final class Completion<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    init(_ value: CheckedContinuation<Value, Error>) { continuation = value }
    func finish(_ result: Result<Value, Error>) {
        lock.lock(); let target = continuation; continuation = nil; lock.unlock()
        target?.resume(with: result)
    }
}
/// Reporting can time out; the single worker slot survives until the read exits.
public final class BoundedRead<Value>: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.snapbridge.setup-read")
    private let lock = NSLock()
    private var busy = false
    private let sample: () throws -> Value
    private let timeout: Double
    public init(sample: @escaping () throws -> Value, timeout: Double = 1) {
        self.sample = sample; self.timeout = timeout.isFinite ? max(0.01, min(1, timeout)) : 1
    }
    public func read() async throws -> Value {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard !busy else { lock.unlock(); continuation.resume(throwing: NativeIOError.busy); return }
            busy = true; lock.unlock()
            let completion = Completion(continuation), deadline = ProcessInfo.processInfo.systemUptime + timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { completion.finish(.failure(NativeIOError.timeout)) }
            queue.async {
                let result = Result { try self.sample() }
                self.lock.lock(); self.busy = false; self.lock.unlock()
                completion.finish(ProcessInfo.processInfo.systemUptime >= deadline ? .failure(NativeIOError.timeout) : result)
            }
        }
    }
}
