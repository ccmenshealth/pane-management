import Foundation
import AlwaysOnClient
import AlwaysOnCore

public enum SetupServiceStatus: Sendable { case notRegistered, enabled, requiresApproval, notFound }
@MainActor public protocol SetupService: AnyObject {
    func status() async throws -> SetupServiceStatus
    func validateIdentity() throws
    func register() async throws
    /// Start immediately inside the client's final transport fence.
    func unregister(_ completion: @escaping @MainActor (Result<Void, Error>) -> Void)
    func openLoginItems()
}
@MainActor public protocol SetupProof: AnyObject {
    func power() async throws -> PowerReceipt
    func directoryAbsent() async throws -> Bool
}
@MainActor public protocol SetupClient: AnyObject {
    var state: ClientState { get }
    var removalPending: Bool { get }
    var onChange: (() -> Void)? { get set }
    func status() async
    func activate() async
    func deactivate() async
    func remove(unregister: (@escaping @MainActor (Result<Void, Error>) -> Void) -> Void) async -> Bool
}
@MainActor public final class SetupClientAdapter: SetupClient {
    private let client: AlwaysOnClient
    public var onChange: (() -> Void)?
    public var state: ClientState { client.observation.state }
    public var removalPending: Bool { client.observation.removalPending }
    public init(_ client: AlwaysOnClient) {
        self.client = client
        client.onObservation = { [weak self] _ in self?.onChange?() }
    }
    public func status() async { _ = await client.status() }
    public func activate() async { _ = await client.activate() }
    public func deactivate() async { _ = await client.deactivate() }
    public func remove(unregister: (@escaping @MainActor (Result<Void, Error>) -> Void) -> Void) async -> Bool {
        await client.remove(unregister: unregister)
    }
}
public enum SetupState: Equatable, Sendable { case unavailable(String), off, active, setupRequired(String), unknown(String) }
public enum SetupRemedy: Equatable, Sendable { case setUp, activate, deactivate, openLoginItems, checkAgain, retryDeactivationAndRepair, retryRemoval, wait }
public struct SetupObservation: Equatable, Sendable {
    public let revision: UInt64
    public let state: SetupState
    public let remedy: SetupRemedy
    public let lifecyclePending: Bool
    public var quitSafe: Bool { if lifecyclePending { return false }; switch state { case .off, .unavailable: return true; default: return false } }
}
