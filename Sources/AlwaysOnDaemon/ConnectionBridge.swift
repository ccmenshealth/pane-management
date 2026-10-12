import Foundation
import AlwaysOnCore
import AlwaysOnService

@objc public protocol AlwaysOnXPC {
    func request(_ payload: Data, reply: @escaping (Data) -> Void)
}
/// Thread-safe ingress bound, also closes the race before MainActor admission.
public final class ConnectionFence: @unchecked Sendable {
    private let lock = NSLock()
    private var closed = false, busy = false
    public init() {}
    public func begin() -> Bool { lock.lock(); defer { lock.unlock() }; guard !closed && !busy else { return false }; busy = true; return true }
    public func finish() { lock.lock(); busy = false; lock.unlock() }
    public func close() -> Bool { lock.lock(); defer { lock.unlock() }; guard !closed else { return false }; closed = true; return true }
    public func whileOpen<T>(_ body: () -> T) -> T? { lock.lock(); defer { lock.unlock() }; return closed ? nil : body() }
}
/// One bridge per kernel-authenticated connection; identity is never decoded.
/// Both loss callbacks share the same fence and opaque coordinator key.
@MainActor public final class ManagedConnection {
    public nonisolated let fence = ConnectionFence()
    private let service: ServiceCoordinator
    private let session: ConsoleSession
    private var key: ConnectionKey?
    public nonisolated init(service: ServiceCoordinator, session: ConsoleSession) { self.service = service; self.session = session }
    public func handle(_ data: Data) async -> ServiceReply {
        guard let request = try? BoundaryPolicy.decode(data) else { return .init(state: .checking, outcome: .invalidRequest) }
        // Holding this short fence through admission makes a synchronous loss
        // before admission decisive, regardless of MainActor task ordering.
        guard let admitted: ConnectionKey = fence.whileOpen({
            if key == nil { key = service.accept(session) }
            return key
        }) ?? nil else { return .init(state: .checking, outcome: .rejected) }
        let reply = await service.handle(request, from: admitted)
        guard fence.whileOpen({ true }) == true else {
            await service.disconnected(admitted)
            return .init(state: .checking, outcome: .rejected)
        }
        return reply
    }
    public func lost() async { if let key { await service.disconnected(key) } }
}
public final class DaemonRequestBridge: NSObject, AlwaysOnXPC, @unchecked Sendable {
    let managed: ManagedConnection
    public init(_ managed: ManagedConnection) { self.managed = managed }
    public func request(_ payload: Data, reply: @escaping (Data) -> Void) {
        guard payload.count <= 1024, managed.fence.begin() else {
            reply(Self.failure); return
        }
        Task { @MainActor [managed] in
            defer { managed.fence.finish() }
            let result = await managed.handle(payload)
            reply((try? BoundaryPolicy.encode(result)) ?? Self.failure)
        }
    }
    static var failure: Data { (try? BoundaryPolicy.encode(ServiceReply(state: .checking, outcome: .rejected))) ?? Data() }
}
/// NSXPC invalidation is thread-safe. This narrow wrapper only reads an immutable
/// weak reference and invalidates; it exposes no mutable connection configuration.
private final class ConnectionInvalidator: @unchecked Sendable {
    private weak var connection: NSXPCConnection?
    init(_ connection: NSXPCConnection) { self.connection = connection }
    func invalidate() { connection?.invalidate() }
}
public final class DaemonListener: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let service: ServiceCoordinator
    private let telemetry: NativeTelemetry
    private let requirement: String
    private let listener: NSXPCListener
    public init(service: ServiceCoordinator, telemetry: NativeTelemetry, requirement: String) {
        self.service = service; self.telemetry = telemetry; self.requirement = requirement
        listener = NSXPCListener(machServiceName: BoundaryPolicy.daemonID)
        super.init()
        listener.delegate = self
        listener.setConnectionCodeSigningRequirement(requirement)
    }
    public func activate() { listener.activate() }
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let session = ConsoleSession(uid: connection.effectiveUserIdentifier, auditSession: UInt32(bitPattern: connection.auditSessionIdentifier))
        guard session.uid != 0, session.uid != UInt32.max, session.auditSession != 0, session.auditSession != UInt32.max,
              let registration = telemetry.track(session) else { return false }
        let managed = ManagedConnection(service: service, session: session)
        let bridge = DaemonRequestBridge(managed)
        let invalidator = ConnectionInvalidator(connection)
        let lost: @Sendable () -> Void = { [telemetry, invalidator] in
            guard managed.fence.close() else { return }
            telemetry.untrack(registration)
            invalidator.invalidate()
            Task { @MainActor in await managed.lost() }
        }
        connection.interruptionHandler = lost; connection.invalidationHandler = lost
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: AlwaysOnXPC.self)
        connection.exportedObject = bridge
        telemetry.tick()
        connection.activate()
        return true
    }
}
