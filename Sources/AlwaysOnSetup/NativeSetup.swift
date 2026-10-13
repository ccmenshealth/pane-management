import Foundation
@preconcurrency import ServiceManagement
import AlwaysOnReadOnly
import AlwaysOnCore
import AlwaysOnIPC

@MainActor public final class NativeSetupProof: SetupProof {
    private let reader = BoundedPowerReader()
    private let absence = BoundedRead(sample: TrustedStorage.absent)
    public init() {}
    public func power() async throws -> PowerReceipt { try await reader.read() }
    public func directoryAbsent() async throws -> Bool { try await absence.read() }
}
@MainActor public final class NativeSetupService: SetupService {
    private let service: SMAppService
    private let reads: BoundedRead<SetupServiceStatus>
    private let registration = DispatchQueue(label: "local.snapbridge.setup-registration")
    private var registering = false
    public init() {
        let service = SMAppService.daemon(plistName: "local.snapbridge.alwayson.service.plist")
        self.service = service
        reads = BoundedRead { switch service.status {
            case .notRegistered: return .notRegistered
            case .enabled: return .enabled
            case .requiresApproval: return .requiresApproval
            case .notFound: return .notFound
            @unknown default: throw NativeIOError.failed
        } }
    }
    public func status() async throws -> SetupServiceStatus { try await reads.read() }
    public func validateIdentity() throws { _ = try TrustedIdentity.peerRequirement(own: .app) }
    public func register() async throws {
        guard !registering else { throw NativeIOError.busy }
        registering = true; defer { registering = false }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let service = service
            registration.async { continuation.resume(with: Result { try service.register() }) }
        }
    }
    public func unregister(_ completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        service.unregister { error in
            let result: Result<Void, Error> = error.map { .failure($0) } ?? .success(())
            Task { @MainActor in completion(result) }
        }
    }
    public func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
