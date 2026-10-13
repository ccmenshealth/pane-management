import Foundation
import AlwaysOnIPC

/// No registration or launch policy: connecting requires the calling binary's
/// validated fixed app identity and certificate before any NSXPC connection is constructed.
@MainActor public final class NativeClientTransport: ClientTransport {
    public init() {}
    public func connect(lost: @escaping @MainActor () -> Void) throws -> ClientChannel {
        let requirement = try TrustedIdentity.peerRequirement(own: .app)
        return NativeChannel(requirement: requirement, lost: lost)
    }
}
private final class NativeFence: @unchecked Sendable {
    private let lock = NSLock()
    private var open = true
    func close() -> Bool { lock.lock(); defer { lock.unlock() }; guard open else { return false }; open = false; return true }
    func whileOpen(_ body: () -> Void) -> Bool { lock.lock(); defer { lock.unlock() }; guard open else { return false }; body(); return true }
    var isOpen: Bool { lock.lock(); defer { lock.unlock() }; return open }
}
@MainActor private final class NativeChannel: ClientChannel {
    private let connection: NSXPCConnection
    private let fence = NativeFence()
    var isOpen: Bool { fence.isOpen }
    init(requirement: String, lost: @escaping @MainActor () -> Void) {
        connection = NSXPCConnection(machServiceName: BoundaryPolicy.daemonID, options: .privileged)
        let loss: @Sendable () -> Void = { [fence] in
            guard fence.close() else { return }
            Task { @MainActor in lost() }
        }
        connection.interruptionHandler = loss
        connection.invalidationHandler = loss
        connection.remoteObjectInterface = NSXPCInterface(with: AlwaysOnXPC.self)
        connection.setCodeSigningRequirement(requirement)
        connection.activate()
    }
    func send(_ data: Data, completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        guard isOpen else { completion(.failure(ClientFailure.connectionLost)); return }
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
            Task { @MainActor in completion(.failure(ClientFailure.connectionLost)) }
        } as? AlwaysOnXPC
        guard let proxy else { completion(.failure(ClientFailure.connectionLost)); return }
        proxy.request(data) { data in Task { @MainActor in completion(.success(data)) } }
    }
    func whileOpen(_ action: () -> Void) -> Bool { fence.whileOpen(action) }
    func close() { _ = fence.close(); connection.invalidate() }
}
