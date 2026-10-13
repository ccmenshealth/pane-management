import Foundation
import Darwin
import AlwaysOnCore
import AlwaysOnService
import AlwaysOnNative

@MainActor public final class MonotonicClock: RecoveryClock {
    public init() {}
    public var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
public enum DaemonRuntime {
    @MainActor public static func run() async throws {
        var peer: String?
        try BoundaryPolicy.preflight(uid: geteuid(), signature: { try TrustedIdentity.peerRequirement(own: .daemon) }, construct: { peer = $0 })
        guard let peer else { throw BoundaryError.signing }
        // These fixed native ports are constructed only after root/self validation.
        let journal = try NativeRecoveryJournal(), power = NativeRecoveryPower()
        let telemetry = NativeTelemetry(), clock = MonotonicClock()
        let environment = CachedEnvironment(cache: telemetry.cache)
        let service = ServiceCoordinator(journal: journal, power: power, clock: clock, environment: environment)
        telemetry.start { await service.monitor() }
        await service.start()
        let listener = DaemonListener(service: service, telemetry: telemetry, requirement: peer)
        listener.activate()
        // Retain the service, lock and listener for this incarnation. launchd
        // restarts crashes; durable startup recovery never resumes activation.
        while true {
            try await Task.sleep(nanoseconds: 60_000_000_000)
            withExtendedLifetime((journal, power, telemetry, service, listener)) {}
        }
    }
}
