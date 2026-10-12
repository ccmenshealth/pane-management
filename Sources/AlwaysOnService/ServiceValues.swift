import AlwaysOnCore
import Foundation
@_exported import AlwaysOnIPC

/// Native boundary retains this opaque value; it is never decoded from a request.
public struct ConnectionKey: Hashable, Sendable {
    public let id: UUID
    public let generation: UInt64
    internal init(generation: UInt64) { id = UUID(); self.generation = generation }
}
public struct ServiceSamples: Sendable {
    public let battery: BatteryGuard
    public let batteryAt: TimeInterval
    public let thermal: ThermalGuard
    public let thermalAt: TimeInterval
    public let sessionValid: Bool
    public let sessionAt: TimeInterval
    public init(battery: BatteryGuard = .unknown, batteryAt: TimeInterval,
                thermal: ThermalGuard = .unknown, thermalAt: TimeInterval,
                sessionValid: Bool, sessionAt: TimeInterval) {
        self.battery = battery; self.batteryAt = batteryAt; self.thermal = thermal
        self.thermalAt = thermalAt; self.sessionValid = sessionValid; self.sessionAt = sessionAt
    }
}
@MainActor public protocol ServiceEnvironment: AnyObject {
    /// Synchronous cached validation, maintained by the native boundary later.
    func isCurrent(_ session: ConsoleSession) -> Bool
    func samples(for session: ConsoleSession) -> ServiceSamples
}
@MainActor final class BoundGuards: RecoveryGuardSource {
    let environment: ServiceEnvironment
    let clock: RecoveryClock
    var binding: (epoch: UInt64, session: ConsoleSession)?
    init(_ environment: ServiceEnvironment, clock: RecoveryClock) { self.environment = environment; self.clock = clock }
    func snapshot(for session: ConsoleSession) -> RecoveryGuards {
        let sample = environment.samples(for: session)
        let times = [sample.batteryAt, sample.thermalAt, sample.sessionAt]
        let oldest = times.allSatisfy { $0.isFinite && $0 <= clock.now } ? times.min()! : .nan
        return RecoveryGuards(console: sample.sessionValid && environment.isCurrent(session) ? session : nil,
                              battery: sample.battery, thermal: sample.thermal, sampledAt: oldest)
    }
    var snapshot: RecoveryGuards {
        guard let binding else { return .init(console: nil, battery: .unknown, thermal: .unknown, sampledAt: .nan) }
        return snapshot(for: binding.session)
    }
    func clear(_ epoch: UInt64) { if binding?.epoch == epoch { binding = nil } }
}
