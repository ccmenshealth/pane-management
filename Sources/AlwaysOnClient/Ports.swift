import Foundation
import AlwaysOnIPC

@MainActor public protocol ClientTimer: AnyObject { func cancel() }
@MainActor public protocol ClientScheduler: AnyObject {
    var now: TimeInterval { get }
    func schedule(after: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ClientTimer
}
@MainActor public protocol ClientChannel: AnyObject {
    /// Must fence both native loss callbacks synchronously, before actor delivery.
    var isOpen: Bool { get }
    func send(_ data: Data, completion: @escaping @MainActor (Result<Data, Error>) -> Void)
    func close()
    /// Synchronous admission fence; body must start work without waiting.
    func whileOpen(_ action: () -> Void) -> Bool
}
@MainActor public protocol ClientTransport: AnyObject {
    func connect(lost: @escaping @MainActor () -> Void) throws -> ClientChannel
}
public enum ClientFailure: Error { case unavailable, timeout, invalidReply, connectionLost, removal }
public enum ClientState: Equatable, Sendable { case off, active, removalRequired, unknown(String) }
public struct ClientObservation: Equatable, Sendable {
    public let revision: UInt64
    public let state: ClientState
    public let removalPending: Bool
}
@MainActor public final class SystemClientScheduler: ClientScheduler {
    public init() {}
    public var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    public func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ClientTimer {
        let timer = SystemTimer()
        timer.task = Task { try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000)); if !Task.isCancelled { action() } }
        return timer
    }
}
@MainActor private final class SystemTimer: ClientTimer { var task: Task<Void, Never>?; func cancel() { task?.cancel() } }
