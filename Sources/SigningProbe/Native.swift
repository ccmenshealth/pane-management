import Foundation
import ServiceManagement
import AlwaysOnIPC

@MainActor public final class NativeProbeChannel: ProbeChannel {
    private let connection: NSXPCConnection
    public init(requirement: String) {
        connection = NSXPCConnection(machServiceName: Probe.helperID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: ProbeXPC.self)
        connection.setCodeSigningRequirement(requirement)
        connection.activate()
    }
    public func send(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        let fail: @Sendable () -> Void = { Task { @MainActor in completion(.failure(ProbeFailure.unavailable)) } }
        connection.interruptionHandler = fail; connection.invalidationHandler = fail
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in fail() }) as? ProbeXPC else { fail(); return }
        proxy.ping(data) { reply in Task { @MainActor in completion(.success(reply)) } }
    }
    public func close() { connection.invalidate() }
}
@MainActor public final class NativeProbeService: ProbeService {
    private let service = SMAppService.daemon(plistName: Probe.helperID + ".plist")
    private let request = ProbePing()
    public init() {}
    public var status: String {
        guard (try? Probe.peer(daemon: false)) != nil else {
            return "Dedicated certificate signature missing or invalid. Stage the signed probe before Register or Ping. Quit is available."
        }
        switch service.status {
        case .enabled: return "Helper enabled. Ping verifies authenticated communication; Remove uninstalls the probe."
        case .requiresApproval: return "Approval required. Open Login Items, approve this probe, then Check status."
        case .notRegistered: return "Not registered. Register probe to request installation."
        case .notFound: return "Helper not found. Remove if registered, restore the signed bundle, then Register."
        @unknown default: return "Unknown service status. Check status or Remove probe."
        }
    }
    public func register() async throws {
        _ = try Probe.peer(daemon: false)
        let service = self.service
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do { try service.register(); continuation.resume() } catch { continuation.resume(throwing: error) }
            }
        }
    }
    public func remove() async throws { try await service.unregister() }
    public func ping() async throws {
        let channel = NativeProbeChannel(requirement: try Probe.peer(daemon: false))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            request.start(channel: channel) { continuation.resume(with: $0) }
        }
    }
    public func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
