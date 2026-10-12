import Foundation
import Combine

/// Results are readback observations, not acknowledgments that a request was sent.
/// They do not verify physical sleep, lid behavior, or emergency-warning timing.
public enum AlwaysOnObservation: Equatable {
    case off
    case active
    /// No owned override exists, and activation is unavailable. A configured but
    /// unreachable helper MUST return unknown, including after a UI restart.
    case unavailable(String)
    /// State could not be verified; restoring normal sleep remains necessary.
    case unknown(String)
}

@MainActor public protocol AlwaysOnBackend: AnyObject {
    // Implementations must bound requests, authenticate replies and never persist
    // an activation intention across process restarts. No backend exists yet.
    func status() async -> AlwaysOnObservation
    func activate() async -> AlwaysOnObservation
    func deactivate() async -> AlwaysOnObservation
}

public enum AlwaysOnState: Equatable {
    case checking, off, activating, active, stopping
    case recoveryRequired(String), unavailable(String)
}

public enum AlwaysOnAction { case activate, deactivate, checkSetup }

@MainActor public final class AlwaysOnController: ObservableObject {
    @Published public private(set) var state: AlwaysOnState = .checking
    public var onQuitDecision: ((Bool) -> Void)?
    private let backend: AlwaysOnBackend
    public init(backend: AlwaysOnBackend) { self.backend = backend }
    private var busy = false
    private var stopRequested = false
    private var quitPending = false

    public func checkSetup() {
        guard !busy else { return }
        switch state {
        case .checking, .off, .unavailable: break
        default: return
        }
        busy = true; stopRequested = false; state = .checking
        Task {
            let result = await backend.status()
            switch result {
            case .active, .unknown:
                await restore()
            case .off, .unavailable:
                finish(result)
            }
        }
    }

    public func perform(_ action: AlwaysOnAction) {
        switch action {
        case .checkSetup: checkSetup()
        case .activate:
            guard !busy, state == .off else { return }
            busy = true; stopRequested = false; state = .activating
            Task {
                let result = await backend.activate()
                if stopRequested { await restore(); return }
                switch result {
                case .active: busy = false; state = .active
                case .unknown: await restore()
                case .off:
                    finish(.unavailable("Activation was not confirmed. Normal sleep is restored. Check setup before trying again."))
                case .unavailable: finish(result)
                }
            }
        case .deactivate:
            switch state {
            case .off, .unavailable: return
            default: break
            }
            stopRequested = true; state = .stopping
            // Do not cancel an in-flight backend call: a late write must finish
            // before the serialized restore. The helper owns timeout recovery.
            guard !busy else { return }
            busy = true
            Task { await restore() }
        }
    }

    public func criticalStop() { perform(.deactivate) }

    /// false means the AppKit caller must wait for onQuitDecision, including a
    /// negative reply on restore failure. Force Quit/OS death need helper recovery.
    public func requestQuit() -> Bool {
        switch state {
        case .off, .unavailable: return true
        default:
            quitPending = true
            perform(.deactivate)
            return false
        }
    }

    private func restore() async {
        state = .stopping
        finish(await backend.deactivate())
    }

    private func finish(_ result: AlwaysOnObservation) {
        busy = false
        let safe: Bool
        switch result {
        case .off: state = .off; safe = true
        case .unavailable(let reason): state = .unavailable(reason); safe = true
        case .active:
            state = .recoveryRequired("The Mac still reports always-on mode. Normal sleep has not been restored.")
            safe = false
        case .unknown(let reason): state = .recoveryRequired(reason); safe = false
        }
        if quitPending { quitPending = false; onQuitDecision?(safe) }
    }
}

/// Honest production boundary for this UI-only slice. This performs no power IO.
@MainActor public final class UnavailableAlwaysOnBackend: AlwaysOnBackend {
    public init() {}
    private var result: AlwaysOnObservation {
        .unavailable("Always-on setup is not available in this build. Normal sleep settings have not been changed.")
    }
    public func status() async -> AlwaysOnObservation { result }
    public func activate() async -> AlwaysOnObservation { result }
    public func deactivate() async -> AlwaysOnObservation { result }
}
