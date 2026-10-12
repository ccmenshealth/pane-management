import Foundation
import AlwaysOnCore

@MainActor final class Backend: AlwaysOnBackend {
    var observation: AlwaysOnObservation = .off
    var activationResult: AlwaysOnObservation = .active
    var stopResult: AlwaysOnObservation = .off
    var activates = 0, stops = 0
    var holdActivation = false, holdStop = false
    var activation: CheckedContinuation<AlwaysOnObservation, Never>?
    var stop: CheckedContinuation<AlwaysOnObservation, Never>?
    func status() async -> AlwaysOnObservation { observation }
    func activate() async -> AlwaysOnObservation {
        activates += 1
        if holdActivation { return await withCheckedContinuation { activation = $0 } }
        return activationResult
    }
    func deactivate() async -> AlwaysOnObservation {
        stops += 1
        if holdStop { return await withCheckedContinuation { stop = $0 } }
        return stopResult
    }
}

@main enum Checks {
    @MainActor static func main() async {
        var failures = 0, assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            assertions += 1
            if !condition() { failures += 1; print("FAIL: \(name)") }
        }
        func settle() async { for _ in 0..<30 { await Task.yield() } }
        func ready(_ backend: Backend) async -> AlwaysOnController {
            let controller = AlwaysOnController(backend: backend)
            controller.checkSetup(); await settle(); return controller
        }
        let b = Backend(), c = await ready(Backend())
        check(c.state == .off, "startup verifies off")
        check(c.requestQuit(), "verified off permits quit")
        // Shared actions used by Dock, status, Settings and warning.
        for entry in ["Dock", "status", "Settings", "warning"] {
            let controller = await ready(Backend())
            controller.perform(.activate); await settle()
            check(controller.state == .active, "\(entry) activation uses verified backend")
            controller.perform(.deactivate); await settle()
            check(controller.state == .off, "\(entry) deactivation confirms off")
        }
        let repeated = await ready(b)
        repeated.perform(.activate); repeated.perform(.activate); await settle()
        check(b.activates == 1, "repeated activation is serialized")
        repeated.perform(.activate); await settle()
        check(b.activates == 1, "active activation is idempotent")
        repeated.criticalStop(); await settle()
        check(repeated.state == .off && b.stops == 1, "critical event restores")
        await settle(); check(b.activates == 1, "critical stop never resumes")
        let late = Backend(); late.holdActivation = true
        let canceled = await ready(late)
        canceled.perform(.activate); await settle()
        check(canceled.state == .activating, "pending activation is not active")
        canceled.perform(.deactivate); canceled.perform(.activate)
        check(canceled.state == .stopping, "cancellation has a visible stopping state")
        late.activation?.resume(returning: .active); late.activation = nil; await settle()
        check(canceled.state == .off && late.stops == 1 && late.activates == 1, "late success restores instead of rearming")
        let failing = Backend(); let recovery = await ready(failing)
        recovery.perform(.activate); await settle()
        failing.stopResult = .unknown("readback failed")
        var quitReplies: [Bool] = []; recovery.onQuitDecision = { quitReplies.append($0) }
        check(!recovery.requestQuit(), "active quit waits")
        await settle()
        check(recovery.state == .recoveryRequired("readback failed"), "restore failure remains visible")
        check(quitReplies == [false], "restore failure refuses quit")
        failing.stopResult = .off; recovery.perform(.deactivate); await settle()
        check(recovery.state == .off, "retry restores")
        recovery.perform(.activate); await settle()
        check(!recovery.requestQuit(), "quit again awaits restoration"); await settle()
        check(quitReplies == [false, true], "quit succeeds only after readback off")
        let unavailable = AlwaysOnController(backend: UnavailableAlwaysOnBackend())
        unavailable.checkSetup(); await settle()
        if case .unavailable = unavailable.state { check(true, "missing backend") }
        else { check(false, "missing backend is explained") }
        unavailable.perform(.activate); await settle()
        if case .unavailable = unavailable.state { check(true, "no fake activation") }
        else { check(false, "missing backend cannot fake activation") }
        check(unavailable.requestQuit(), "safe missing backend allows quit")
        let invalid = Backend(); invalid.activationResult = .unknown("invalid reply")
        let rejected = await ready(invalid); rejected.perform(.activate); await settle()
        check(invalid.stops == 1 && rejected.state == .off, "unknown activation triggers restoration")
        let startup = Backend(); startup.observation = .active
        let restarted = await ready(startup)
        check(startup.stops == 1 && restarted.state == .off && startup.activates == 0, "startup restores stale active state without resuming")
        let slow = Backend(); slow.holdStop = true
        let stopping = await ready(slow); stopping.perform(.activate); await settle()
        stopping.perform(.deactivate); stopping.perform(.deactivate); await settle()
        check(slow.stops == 1 && stopping.state == .stopping, "repeated stop stays pending until confirmed")
        slow.stop?.resume(returning: .active); slow.stop = nil; await settle()
        if case .recoveryRequired = stopping.state { check(true, "active stop reply") }
        else { check(false, "still active readback cannot claim off") }
        let ambiguous = Backend()
        ambiguous.observation = .unknown("configured helper unreachable")
        ambiguous.stopResult = .unknown("configured helper unreachable")
        let uncertain = await ready(ambiguous)
        check(ambiguous.stops == 1 && uncertain.state == .recoveryRequired("configured helper unreachable"), "ambiguous startup must restore and retain recovery on failure")
        let refused = Backend(); refused.activationResult = .off
        let neverActive = await ready(refused); neverActive.perform(.activate); await settle()
        if case .unavailable = neverActive.state { check(true, "refused activation") }
        else { check(false, "off reply does not claim successful activation") }
        let quitDuringActivation = Backend(); quitDuringActivation.holdActivation = true
        let waiting = await ready(quitDuringActivation)
        var ended = false; waiting.onQuitDecision = { ended = $0 }
        waiting.perform(.activate); await settle()
        check(!waiting.requestQuit(), "quit during activation waits")
        quitDuringActivation.activation?.resume(returning: .active); quitDuringActivation.activation = nil; await settle()
        check(ended && waiting.state == .off && quitDuringActivation.stops == 1, "quit during activation restores late success")
        print("\(assertions) always-on assertions; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
