import AlwaysOnCore
import Foundation

private enum Fault: Error { case injected }
@MainActor private final class Journal: RecoveryJournal {
    var stored: JournalLoad = .missing
    var fail: String?
    var applyBeforeThrow = false
    var events: [String] = []
    var onSave: ((RecoveryPhase) -> Void)?
    func load() throws -> JournalLoad {
        events.append("load")
        if fail == "load" { throw Fault.injected }
        return stored
    }
    func save(_ record: RecoveryRecord) throws {
        let name = record.phase.rawValue
        events.append(name)
        if fail == name && !applyBeforeThrow { throw Fault.injected }
        stored = .record(record)
        onSave?(record.phase)
        if fail == name { throw Fault.injected }
    }
    func clear() throws {
        events.append("clear")
        if fail == "clear" && !applyBeforeThrow { throw Fault.injected }
        stored = .missing
        if fail == "clear" { throw Fault.injected }
    }
}
@MainActor private final class Power: RecoveryPower {
    var receipt = PowerReceipt(preference: false, rootDomain: false)
    var fail: String?
    var applyBeforeThrow = true
    var unknownAfterWrite = false
    var writes: [Bool] = []
    var beforeEnable: (() -> Void)?
    var suspend: String?
    var suspended: CheckedContinuation<Void, Never>?
    var onRead: (() -> Void)?
    var reads = 0
    var failRead: Int?
    var pauseRead: Int?
    func pause(_ name: String) async {
        if suspend == name { await withCheckedContinuation { suspended = $0 } }
    }
    func release() { suspend = nil; suspended?.resume(); suspended = nil }
    func read() async throws -> PowerReceipt {
        reads += 1
        let index = reads
        if pauseRead == index { await withCheckedContinuation { suspended = $0 } }
        await pause("read"); onRead?()
        if fail == "read" || failRead == index { throw Fault.injected }
        return receipt
    }
    func setDisabled(_ disabled: Bool) async throws -> PowerReceipt {
        let name = disabled ? "enable" : "disable"
        if disabled { beforeEnable?() }
        writes.append(disabled)
        await pause(name)
        if fail == name && !applyBeforeThrow { throw Fault.injected }
        receipt = PowerReceipt(preference: disabled, rootDomain: unknownAfterWrite ? nil : disabled)
        if fail == name { throw Fault.injected }
        return receipt
    }
}
@MainActor private final class Clock: RecoveryClock { var now: TimeInterval = 100 }
@MainActor private final class Guards: RecoveryGuardSource {
    var snapshot = RecoveryGuards(console: owner, sampledAt: 100)
}
private let owner = ConsoleSession(uid: 501, auditSession: 7)
private let stranger = ConsoleSession(uid: 502, auditSession: 8)
@MainActor private final class Rig {
    let journal = Journal(), power = Power(), clock = Clock(), guards = Guards()
    lazy var engine = RecoveryEngine(journal: journal, power: power, clock: clock, guards: guards)
    var lease: RecoveryLease { RecoveryLease(token: UUID(), owner: owner) }
    func seed(_ phase: RecoveryPhase) { journal.stored = .record(.init(lease: lease, phase: phase)); power.receipt = .init(preference: true, rootDomain: true) }
    func fresh() { guards.snapshot = RecoveryGuards(console: owner, sampledAt: clock.now) }
}

@main struct Checks {
    @MainActor static func main() async {
        var total = 0, failures = 0
        func check(_ value: Bool, _ label: String) {
            total += 1
            if !value { failures += 1; print("FAIL: \(label)") }
        }
        func recovering(_ state: RecoveryStatus) -> Bool { if case .recoveryRequired = state { return true }; return false }
        func conflict(_ state: RecoveryStatus) -> Bool { if case .conflict = state { return true }; return false }
        func active(_ state: RecoveryStatus) -> RecoveryLease? { if case .active(let lease) = state { return lease }; return nil }
        func waitForPause(_ power: Power) async { for _ in 0..<1000 { if power.suspended != nil { return }; await Task.yield() } }

        for entry in ["status", "activate", "monitor", "retry", "prepare"] {
            for baseline in ["off", "external", "corrupt"] {
                let r = Rig()
                if baseline != "off" { r.power.receipt = .init(preference: true, rootDomain: true) }
                if baseline == "corrupt" { r.journal.stored = .corrupt }
                r.power.pauseRead = 1
                let startup = Task { () -> (RecoveryStatus, Bool?) in
                    switch entry {
                    case "activate": return (await r.engine.activate(owner), nil)
                    case "monitor": return (await r.engine.monitor(), nil)
                    case "retry": return (await r.engine.retryRestore(owner), nil)
                    case "prepare":
                        let prepared = await r.engine.prepareForUpdateOrRemoval(owner)
                        return (await r.engine.status(), prepared)
                    default: return (await r.engine.status(), nil)
                    }
                }
                await waitForPause(r.power)
                check(await r.engine.status() == .checking, "cold \(entry)/\(baseline) cannot report off before ownership read")
                r.power.release()
                let (result, prepared) = await startup.value
                if baseline == "off" {
                    check(entry == "activate" ? active(result) != nil : result == .off,
                          "cold \(entry) completes only after confirmed baseline")
                } else {
                    check(conflict(result) && prepared != true && r.power.writes.isEmpty,
                          "cold \(entry)/\(baseline) resolves conflict without writes")
                }
            }
        }
        let recheck = Rig(); _ = await recheck.engine.status()
        recheck.power.receipt = .init(preference: true, rootDomain: true); recheck.power.pauseRead = 2
        let reinspection = Task { await recheck.engine.monitor() }
        await waitForPause(recheck.power)
        check(await recheck.engine.status() == .checking, "unowned recheck cannot reuse old off during ownership read")
        recheck.power.release()
        check(conflict(await reinspection.value), "unowned recheck reports newly external override")
        let basic = Rig()
        check(await basic.engine.status() == .off, "clean startup")
        var intentBeforeEnable = false
        basic.power.beforeEnable = { intentBeforeEnable = basic.journal.events.contains("intent") }
        let started = await basic.engine.activate(owner)
        check(intentBeforeEnable, "durable intent precedes enable")
        let token = active(started) ?? basic.lease
        check(active(started)?.owner == owner, "generated bound activation token")
        check(basic.journal.events.contains("active"), "durable active before reply")
        check(await basic.engine.heartbeat(token) == started, "valid heartbeat")
        let forged = RecoveryLease(token: UUID(), owner: owner)
        check(await basic.engine.deactivate(forged) == started && basic.power.writes == [true], "bad token cannot stop lease")
        check(await basic.engine.heartbeat(.init(token: token.token, owner: stranger)) == started, "token cannot transfer console identity")
        check(await basic.engine.deactivate(token) == .off && basic.power.writes == [true, false], "deactivate verifies off")
        check(basic.journal.events.suffix(3) == ["restoring", "off", "clear"], "durable off before clear")
        check(await basic.engine.monitor() == .off && basic.power.writes == [true, false], "monitor never rearms")

        for phase in [RecoveryPhase.intent, .active, .restoring] {
            let r = Rig(); r.seed(phase)
            check(await r.engine.status() == .off && r.power.writes == [false], "restart restores \(phase)")
            check(await r.engine.status() == .off && r.power.writes == [false], "restart \(phase) is idempotent")
        }
        for receipt in [PowerReceipt(preference: true, rootDomain: true), .init(preference: false, rootDomain: nil)] {
            let r = Rig(); r.seed(.off); r.power.receipt = receipt
            check(conflict(await r.engine.status()) && r.power.writes.isEmpty, "off record does not own a later true/unknown override")
            check(conflict(await r.engine.retryRestore(owner)) && r.power.writes.isEmpty, "off record retry never overwrites external state")
        }
        let offRecord = Rig(); offRecord.seed(.off); offRecord.power.receipt = .init(preference: false, rootDomain: false)
        check(await offRecord.engine.status() == .off && offRecord.power.writes.isEmpty && offRecord.journal.events.contains("clear"), "verified off record cleanup never writes power")
        let offCleanup = Rig(); _ = await offCleanup.engine.activate(owner); offCleanup.journal.fail = "clear"
        check(recovering(await offCleanup.engine.retryRestore(owner)), "clear failure retains off cleanup")
        offCleanup.journal.fail = nil; offCleanup.power.receipt = .init(preference: true, rootDomain: true)
        check(conflict(await offCleanup.engine.monitor()) && offCleanup.power.writes == [true, false], "monitor cannot overwrite external true after clear failure")
        check(conflict(await offCleanup.engine.retryRestore(owner)) && offCleanup.power.writes == [true, false], "retry cannot overwrite external true after clear failure")
        offCleanup.power.receipt = .init(preference: false, rootDomain: false)
        check(await offCleanup.engine.retryRestore(owner) == .off && offCleanup.power.writes == [true, false], "off cleanup resumes when external owner clears")
        let slowIntent = Rig()
        slowIntent.journal.onSave = { if $0 == .intent { slowIntent.clock.now = 106 } }
        check(await slowIntent.engine.activate(owner) == .off && slowIntent.power.writes == [false], "guard rechecked after slow synchronous intent durability")
        for corrupt in [false, true] {
            let r = Rig(); if corrupt { r.journal.stored = .corrupt }
            r.power.receipt = .init(preference: true, rootDomain: true)
            check(conflict(await r.engine.activate(owner)) && r.power.writes.isEmpty, "external true refuses takeover corrupt=\(corrupt)")
            check(!(await r.engine.prepareForUpdateOrRemoval(owner)), "external true blocks removal")
        }
        let absent = Rig(); absent.power.receipt = .init(preference: false, rootDomain: nil)
        check(active(await absent.engine.activate(owner)) != nil, "initial absent root permits activation")
        let unknown = Rig(); unknown.power.unknownAfterWrite = true
        check(recovering(await unknown.engine.activate(owner)) && unknown.power.writes == [true, false], "postwrite absent root is not off")
        unknown.power.unknownAfterWrite = false
        check(await unknown.engine.retryRestore(owner) == .off, "retry unknown receipt restoration")

        for fault in ["load", "intent", "active", "restoring", "off", "clear"] {
            for applied in [false, true] {
                let r = Rig(); r.journal.fail = fault; r.journal.applyBeforeThrow = applied
                if ["restoring", "off", "clear"].contains(fault) { r.seed(.active) }
                let result = await r.engine.activate(owner)
                check(active(result) == nil, "journal \(fault) applied=\(applied) cannot acknowledge active")
                if fault == "load" { check(r.power.writes.isEmpty, "unreadable ownership cannot write") }
                if ["restoring", "off", "clear"].contains(fault) { check(recovering(result), "journal \(fault) retains recovery") }
                r.journal.fail = nil
                check(await r.engine.retryRestore(owner) == .off, "retry journal \(fault) applied=\(applied)")
            }
        }
        for fault in ["read", "enable", "disable"] {
            for applied in [false, true] {
                let r = Rig(); r.power.fail = fault; r.power.applyBeforeThrow = applied
                if fault == "disable" { r.seed(.active) }
                check(active(await r.engine.activate(owner)) == nil, "power \(fault) applied=\(applied) never false active")
                r.power.fail = nil
                check(await r.engine.retryRestore(owner) == .off, "retry power \(fault) applied=\(applied)")
            }
        }
        for event in ["final", "critical", "unknown", "stale", "future", "console", "heartbeat", "disconnect", "clear"] {
            let r = Rig(); _ = await r.engine.activate(owner)
            switch event {
            case "final": r.guards.snapshot = .init(console: owner, battery: .finalWarning, sampledAt: 100)
            case "critical": r.guards.snapshot = .init(console: owner, thermal: .critical, sampledAt: 100)
            case "unknown": r.guards.snapshot = .init(console: owner, battery: .unknown, sampledAt: 100)
            case "stale": r.clock.now = 106
            case "future": r.guards.snapshot = .init(console: owner, sampledAt: 101)
            case "console": r.guards.snapshot = .init(console: stranger, sampledAt: 100)
            case "heartbeat": r.clock.now = 131; r.fresh()
            case "clear": r.power.receipt = .init(preference: false, rootDomain: false)
            default: break
            }
            let result = event == "disconnect" ? await r.engine.disconnected(owner) : await r.engine.monitor()
            check(result == .off && r.power.writes == [true, false], "\(event) stops owned mode")
            r.fresh(); _ = await r.engine.monitor()
            check(r.power.writes == [true, false], "\(event) never auto rearms")
        }
        for stage in ["read", "enable", "disable"] {
            let r = Rig(); r.power.suspend = stage
            if stage == "disable" { r.seed(.active) }
            let task = Task { await r.engine.activate(owner) }
            await waitForPause(r.power)
            r.guards.snapshot = .init(console: owner, thermal: .critical, sampledAt: 100)
            let stop = Task { await r.engine.monitor() }
            await Task.yield(); r.power.release()
            let result = await task.value; _ = await stop.value
            check(result == .off && active(result) == nil, "critical stop during \(stage) cannot reply active")
            check(r.power.writes.last == false || r.power.writes.isEmpty, "\(stage) stop restores last")
        }
        let late = Rig(); late.power.suspend = "enable"; late.power.fail = "enable"
        let activation = Task { await late.engine.activate(owner) }
        await waitForPause(late.power)
        let removal = Task { await late.engine.prepareForUpdateOrRemoval(owner) }
        await Task.yield(); late.power.release()
        check(await activation.value == .off, "late applied failed enable is restored")
        check(await removal.value && late.power.writes == [true, false], "removal waits for late writer and restoration")
        let removed = Rig(); _ = await removed.engine.activate(owner)
        check(await removed.engine.prepareForUpdateOrRemoval(owner) && removed.power.writes == [true, false], "prepare removal proves restoration")
        removed.power.receipt = .init(preference: true, rootDomain: true)
        check(!(await removed.engine.prepareForUpdateOrRemoval(owner)), "prepare removal rechecks external change")
        for read in 1...3 {
            let r = Rig(); r.power.failRead = read
            let result = await r.engine.activate(owner)
            check(active(result) == nil, "activation read boundary \(read) throws")
            check(read < 3 ? r.power.writes.isEmpty : r.power.writes == [true, false], "read \(read) restores only owned intent")
            r.power.failRead = nil
            check(await r.engine.retryRestore(owner) == .off, "retry activation read boundary \(read)")
        }
        let restoreRead = Rig(); restoreRead.seed(.active); restoreRead.power.failRead = 1
        check(recovering(await restoreRead.engine.status()), "restore confirmation read throws")
        restoreRead.power.failRead = nil
        check(await restoreRead.engine.retryRestore(owner) == .off, "retry restore confirmation")
        for read in 2...3 {
            let r = Rig(); r.power.pauseRead = read
            let task = Task { await r.engine.activate(owner) }
            await waitForPause(r.power)
            let cancel = Task { await r.engine.retryRestore(owner) }
            await Task.yield(); r.power.release()
            check(await task.value == .off, "token-lost stop during read \(read)")
            check(await cancel.value == .off && r.power.writes.last != true, "read \(read) cancellation settles")
        }
        for trigger in ["disconnect", "expired", "thermalUnknown"] {
            let r = Rig(); _ = await r.engine.activate(owner)
            r.power.pauseRead = r.power.reads + 1
            let inspection = Task { await r.engine.status() }
            await waitForPause(r.power)
            if trigger == "disconnect" { _ = await r.engine.disconnected(owner) }
            if trigger == "expired" { r.clock.now = 131; r.fresh() }
            if trigger == "thermalUnknown" { r.guards.snapshot = .init(console: owner, thermal: .unknown, sampledAt: 100) }
            r.power.release()
            check(await inspection.value == .off && r.power.writes == [true, false], "status await rechecks \(trigger)")
        }
        let deadline = Rig(); let deadlineToken = active(await deadline.engine.activate(owner)) ?? deadline.lease
        deadline.clock.now = 129; deadline.fresh()
        check(active(await deadline.engine.heartbeat(deadlineToken)) != nil, "heartbeat renews before deadline")
        deadline.clock.now = 159; deadline.fresh()
        check(await deadline.engine.heartbeat(deadlineToken) == .off && deadline.power.writes == [true, false], "heartbeat at deadline cannot revive")
        let busyHeartbeat = Rig(); let busyToken = active(await busyHeartbeat.engine.activate(owner)) ?? busyHeartbeat.lease
        busyHeartbeat.power.pauseRead = busyHeartbeat.power.reads + 1
        let busyStatus = Task { await busyHeartbeat.engine.status() }
        await waitForPause(busyHeartbeat.power)
        busyHeartbeat.clock.now = 129; busyHeartbeat.fresh()
        check(active(await busyHeartbeat.engine.heartbeat(busyToken)) != nil, "valid busy heartbeat renews metadata")
        busyHeartbeat.clock.now = 158; busyHeartbeat.fresh()
        check(active(await busyHeartbeat.engine.heartbeat(busyToken)) != nil, "busy heartbeat renewal survives original expiry")
        busyHeartbeat.clock.now = 188; busyHeartbeat.fresh()
        check(await busyHeartbeat.engine.heartbeat(busyToken) == .stopping, "expired busy heartbeat never replies active")
        busyHeartbeat.power.release()
        check(await busyStatus.value == .off && busyHeartbeat.power.writes == [true, false], "expired busy heartbeat serially restores")
        let backward = Rig(); _ = await backward.engine.activate(owner); backward.clock.now = 99; backward.fresh()
        check(await backward.engine.monitor() == .off && backward.power.writes == [true, false], "clock regression stops")
        let mismatch = Rig(); mismatch.power.receipt = .init(preference: false, rootDomain: true)
        check(conflict(await mismatch.engine.activate(owner)) && mismatch.power.writes.isEmpty, "disagreeing initial receipts refuse")
        let corruptOff = Rig(); corruptOff.journal.stored = .corrupt
        check(recovering(await corruptOff.engine.status()), "corrupt off journal offers retry cleanup")
        check(await corruptOff.engine.retryRestore(owner) == .off && corruptOff.power.writes.isEmpty && corruptOff.journal.events.contains("clear"), "corrupt verified-off cleanup without power write")
        let corruptUnknown = Rig(); corruptUnknown.journal.stored = .corrupt; corruptUnknown.power.receipt = .init(preference: false, rootDomain: nil)
        check(conflict(await corruptUnknown.engine.retryRestore(owner)) && !corruptUnknown.journal.events.contains("clear"), "corrupt unknown cannot clear")
        let corruptClear = Rig(); corruptClear.journal.stored = .corrupt; corruptClear.journal.fail = "clear"
        check(recovering(await corruptClear.engine.retryRestore(owner)), "corrupt cleanup durability failure stays recovery")
        corruptClear.journal.fail = nil
        check(await corruptClear.engine.retryRestore(owner) == .off && corruptClear.power.writes.isEmpty, "corrupt cleanup retry succeeds")
        let corruptSecurity = Rig(); corruptSecurity.journal.stored = .corrupt
        _ = await corruptSecurity.engine.status(); corruptSecurity.journal.fail = "load"
        check(recovering(await corruptSecurity.engine.retryRestore(owner)) && !corruptSecurity.journal.events.contains("clear"), "failed revalidation cannot clear previously corrupt record")
        let removeFailure = Rig(); _ = await removeFailure.engine.activate(owner); removeFailure.power.fail = "disable"
        check(!(await removeFailure.engine.prepareForUpdateOrRemoval(owner)), "failed restore blocks removal")
        removeFailure.power.fail = nil
        check(await removeFailure.engine.prepareForUpdateOrRemoval(owner), "removal retry succeeds")
        let restoreCancel = Rig(); restoreCancel.seed(.active); restoreCancel.power.suspend = "disable"; restoreCancel.power.fail = "disable"
        let restoration = Task { await restoreCancel.engine.status() }
        await waitForPause(restoreCancel.power)
        _ = await restoreCancel.engine.disconnected(owner); restoreCancel.power.release()
        check(recovering(await restoration.value), "disconnect during failed restore retains recovery")
        restoreCancel.power.fail = nil
        check(await restoreCancel.engine.retryRestore(owner) == .off, "restore interruption has retry exit")
        let invalid = Rig()
        check(active(await invalid.engine.activate(stranger)) == nil && invalid.power.writes.isEmpty, "wrong console refused")
        check(active(await invalid.engine.activate(.init(uid: 0, auditSession: 7))) == nil, "root refused")
        invalid.guards.snapshot = .init(console: owner, thermal: .serious, sampledAt: 100)
        check(active(await invalid.engine.activate(owner)) != nil, "serious thermal is permitted")
        print("AlwaysOnEngineChecks: \(total) assertions, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
