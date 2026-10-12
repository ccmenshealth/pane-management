import Foundation
import AlwaysOnCore
import AlwaysOnUI

@MainActor final class Backend: AlwaysOnBackend {
    var snapshot = AlwaysOnSnapshot(revision: 0, state: .off, action: .activate, quitSafe: true)
    var onChange: ((AlwaysOnSnapshot) -> Void)?
    var refreshes = 0, activates = 0, stops = 0, setups = 0, removals = 0, navigations = 0
    var holdRefresh = false, holdActivation = false, holdStop = false, holdRemoval = false
    var refreshGate: CheckedContinuation<Void, Never>?, activationGate: CheckedContinuation<Void, Never>?
    var stopGate: CheckedContinuation<Void, Never>?, removalGate: CheckedContinuation<Void, Never>?
    var stopFails = false
    func emit(_ state: AlwaysOnState, _ action: AlwaysOnAction, safe: Bool = false, pending: Bool = false, secondary: String? = nil) {
        snapshot = .init(revision: snapshot.revision + 1, state: state, action: action, secondaryTitle: secondary, lifecyclePending: pending, quitSafe: safe)
        onChange?(snapshot)
    }
    func refresh() async {
        refreshes += 1
        if holdRefresh { await withCheckedContinuation { refreshGate = $0 } }
    }
    func activate() async {
        activates += 1; emit(.activating, .deactivate, pending: true)
        if holdActivation { await withCheckedContinuation { activationGate = $0 } }
        emit(.active, .deactivate)
    }
    func deactivate() async {
        stops += 1
        if holdStop { await withCheckedContinuation { stopGate = $0 } }
        emit(stopFails ? .recoveryRequired("readback failed") : .off, stopFails ? .deactivate : .activate, safe: !stopFails)
    }
    func setup() async { setups += 1; emit(.setupRequired("Approval needed"), .checkSetup, secondary: "Open Login Items") }
    func remove() async {
        removals += 1; emit(.recoveryRequired("Removing"), .wait, pending: true)
        if holdRemoval { await withCheckedContinuation { removalGate = $0 } }
        emit(.unavailable("Removed"), .setUp, safe: true)
    }
    func openLoginItems() { navigations += 1 }
}
@main enum Checks {
    @MainActor static func main() async {
        var assertions = 0, failures = 0
        func check(_ value: Bool, _ label: String) { assertions += 1; if !value { failures += 1; print("FAIL: \(label)") } }
        func wait(_ label: String, _ condition: () -> Bool) async {
            let deadline = ProcessInfo.processInfo.systemUptime + 2
            while !condition() && ProcessInfo.processInfo.systemUptime < deadline { await Task.yield() }
            check(condition(), "settled \(label)")
        }
        let b = Backend(), c = AlwaysOnController(backend: Backend())
        check(c.requestQuit(), "fresh off permits quit")
        for surface in ["Dock", "menu", "Settings", "warning"] {
            let b = Backend(), c = AlwaysOnController(backend: b)
            c.perform(.activate); c.perform(.activate)
            await wait(surface + " active") { c.state == .active }
            check(b.activates == 1, "repeated activation rejected")
            c.perform(.deactivate); c.perform(.deactivate)
            await wait(surface + " off") { c.state == .off }
            check(b.stops == 1, "repeated stop rejected")
        }
        let owned = AlwaysOnController(backend: b)
        owned.perform(.activate); await wait("owned active") { owned.state == .active }
        for _ in 0..<3 { let n = b.refreshes; owned.checkSetup(); await wait("owned refresh") { b.refreshes > n && owned.canRemove } }
        check(owned.state == .active && b.stops == 0, "startup wake focus preserve owned active")
        check(b.setups == 0 && b.navigations == 0 && b.removals == 0, "refresh has no implicit lifecycle/navigation")
        let stale = b.snapshot
        b.emit(.recoveryRequired("newer"), .deactivate)
        b.onChange?(stale); b.onChange?(.init(revision: b.snapshot.revision, state: .off, action: .activate, quitSafe: true))
        check(owned.state == .recoveryRequired("newer"), "stale and equal revisions ignored")
        do {
            let b = Backend(), c = AlwaysOnController(backend: b); b.holdActivation = true; b.holdStop = true
            c.perform(.activate); await wait("held activation") { b.activationGate != nil }
            check(c.action == .deactivate && c.actionEnabled, "pending activation keeps stop actionable")
            var replies: [Bool] = []; c.onQuitDecision = { replies.append($0) }
            check(!c.requestQuit(), "quit during activation waits")
            await wait("queued stop") { b.stopGate != nil }
            b.activationGate?.resume(); b.activationGate = nil
            await wait("activation returned") { b.snapshot.state == .active }
            check(c.state == .stopping && replies.isEmpty, "late active cannot erase stop or quit")
            b.stopGate?.resume(); b.stopGate = nil
            await wait("quit restored") { !replies.isEmpty }
            check(replies == [true] && c.state == .off, "quit exactly once after confirmed off")
        }
        do {
            let b = Backend(), c = AlwaysOnController(backend: b); b.holdActivation = true
            c.perform(.activate); await wait("early stop activation") { b.activationGate != nil }
            c.perform(.deactivate); await wait("early stop returned") { b.stops == 1 && b.snapshot.state == .off }
            check(c.state == .stopping && !c.canRemove, "early stop cannot clear held activation")
            b.activationGate?.resume(); b.activationGate = nil
            await wait("late unsafe settlement") { c.state != .stopping }
            check(!c.requestQuit(), "late active never claims safe quit")
            await wait("late active restored") { c.state == .off }
        }
        do {
            let b = Backend(), c = AlwaysOnController(backend: b); b.holdRefresh = true
            c.checkSetup(); check(c.state == .checking && !c.requestQuit(), "wake immediately revokes safe snapshot")
            for _ in 0..<20 { c.checkSetup() }
            await wait("refresh held") { b.refreshGate != nil }
            check(b.refreshes == 1, "refresh coalesces in-flight")
            b.holdRefresh = false; b.refreshGate?.resume(); b.refreshGate = nil
            await wait("coalesced followup") { c.canRemove }
            check(b.refreshes == 2, "one dirty followup only")
        }
        do {
            let b = Backend(), c = AlwaysOnController(backend: b); b.stopFails = true
            b.emit(.active, .deactivate)
            var replies: [Bool] = []; c.onQuitDecision = { replies.append($0) }
            check(!c.requestQuit(), "unsafe quit waits for recovery")
            await wait("failed quit") { !replies.isEmpty }
            check(replies == [false] && c.state == .recoveryRequired("readback failed"), "failed stop refuses quit visibly")
            b.stopFails = false; c.perform(.deactivate); await wait("retry") { c.state == .off }
        }
        do {
            let b = Backend(), c = AlwaysOnController(backend: b); var settings = 0
            c.onOpenSettings = { settings += 1 }
            b.emit(.removalRequired, .openSettings, safe: true)
            c.perform(c.action)
            check(settings == 1 && b.removals == 0 && b.activates == 0 && c.requestQuit(), "finish removal only routes to Settings")
            b.emit(.setupRequired("Approve"), .checkSetup, secondary: "Open Login Items")
            c.perform(.checkSetup); await wait("approval recheck") { c.canRemove }
            check(b.navigations == 0, "approval recheck never navigates")
            c.perform(.openLoginItems); check(b.navigations == 1, "explicit approval navigation")
            b.emit(.unavailable("Not installed"), .setUp, safe: true)
            c.perform(.setUp); await wait("explicit setup") { c.canRemove }
            check(b.setups == 1, "setup only explicit action")
            b.holdRemoval = true; c.removeHelperFromSettings(); await wait("removal held") { b.removalGate != nil }
            var replies: [Bool] = []; c.onQuitDecision = { replies.append($0) }
            check(!c.requestQuit() && !c.canRemove && !c.actionEnabled, "actual lifecycle blocks quit and mutation")
            c.perform(.setUp); c.removeHelperFromSettings()
            check(b.removals == 1 && b.setups == 1 && replies.isEmpty, "unsettled removal retains ownership")
            b.removalGate?.resume(); b.removalGate = nil; await wait("removed quit") { !replies.isEmpty }
            check(replies == [true], "settled removal permits quit")
        }
        do {
            let b = Backend(), c = AlwaysOnController(backend: b)
            let rows: [(AlwaysOnState, AlwaysOnAction, String, Bool)] = [
                (.off, .activate, "Activate always-on mode", false),
                (.active, .deactivate, "Deactivate", true),
                (.activating, .deactivate, "Deactivate", true),
                (.recoveryRequired("failure"), .deactivate, "Retry deactivation", true),
                (.unavailable("setup"), .setUp, "Set up always-on helper", false),
                (.unavailable("signing"), .checkSetup, "Check again", false),
                (.setupRequired("approve"), .checkSetup, "Check again", true),
                (.removalRequired, .openSettings, "Finish helper removal in Settings", false),
                (.stopping, .wait, "Please wait…", true)]
            for (state, action, label, warning) in rows {
                b.emit(state, action)
                check(c.actionTitle == label && c.action == action, "shared label matches dispatched action: \(label)")
                check(c.state.showsWarning == warning && c.actionEnabled == (action != .wait), "shared warning/action availability: \(label)")
            }
        }
        print("\(assertions) always-on assertions; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
