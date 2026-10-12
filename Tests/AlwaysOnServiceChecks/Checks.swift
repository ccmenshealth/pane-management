import AlwaysOnCore
import AlwaysOnService
import Foundation

private let owner = ConsoleSession(uid: 501, auditSession: 7)
private let other = ConsoleSession(uid: 502, auditSession: 8)
private enum Fault: Error { case injected }
@MainActor private final class Clock: RecoveryClock { var now: TimeInterval = 100 }
@MainActor private final class Journal: RecoveryJournal {
    var stored: JournalLoad = .missing
    var failClear = false
    func load() throws -> JournalLoad { stored }
    func save(_ record: RecoveryRecord) throws { stored = .record(record) }
    func clear() throws { if failClear { throw Fault.injected }; stored = .missing }
}
@MainActor private final class Power: RecoveryPower {
    var value = false
    var writes: [Bool] = []
    var reads = 0
    var events: [String] = []
    var pauseEvent: String?
    var suspended: CheckedContinuation<Void, Never>?
    var failDisable = false
    var failRead = false
    var failReads: Set<Int> = []
    var receipts: [Int: PowerReceipt] = [:]
    func pause(_ name: String) async {
        events.append(name)
        if pauseEvent == name { await withCheckedContinuation { suspended = $0 } }
    }
    func release() { pauseEvent = nil; let next = suspended; suspended = nil; next?.resume() }
    func read() async throws -> PowerReceipt {
        reads += 1; let index = reads; await pause("read\(index)")
        if failRead || failReads.contains(index) { throw Fault.injected }
        return receipts[index] ?? .init(preference: value, rootDomain: value)
    }
    func setDisabled(_ disabled: Bool) async throws -> PowerReceipt {
        writes.append(disabled); await pause(disabled ? "enable" : "disable")
        value = disabled
        if !disabled && failDisable { throw Fault.injected }
        return .init(preference: value, rootDomain: value)
    }
}
@MainActor private final class Environment: ServiceEnvironment {
    var current: ConsoleSession? = owner
    var battery: BatteryGuard = .normal
    var thermal: ThermalGuard = .nominal
    var batteryAt = 100.0, thermalAt = 100.0, sessionAt = 100.0
    var sessionValid = true
    var targets: [ConsoleSession] = []
    func isCurrent(_ session: ConsoleSession) -> Bool { current == session }
    func samples(for session: ConsoleSession) -> ServiceSamples {
        targets.append(session)
        return .init(battery: battery, batteryAt: batteryAt, thermal: thermal, thermalAt: thermalAt,
                     sessionValid: sessionValid && current == session, sessionAt: sessionAt)
    }
}
@MainActor private final class Rig {
    let journal = Journal(), power = Power(), clock = Clock(), environment = Environment()
    lazy var service = ServiceCoordinator(journal: journal, power: power, clock: clock, environment: environment)
    lazy var key = service.accept(owner)!
    func send(_ operation: ServiceOperation, key: ConnectionKey? = nil, token: UUID? = nil) async -> ServiceReply {
        await service.handle(.init(operation: operation, token: token?.uuidString), from: key ?? self.key)
    }
    func ready() async { _ = key; await service.start() }
    func activate() async -> ServiceReply { await send(.activate) }
}

@main struct Checks {
    @MainActor static func main() async {
        var count = 0, failures = 0
        func check(_ value: Bool, _ label: String) {
            count += 1; if !value { failures += 1; print("FAIL: \(label)") }
        }
        func wait(_ power: Power) async -> Bool {
            for _ in 0..<2000 { if power.suspended != nil { return true }; await Task.yield() }
            return false
        }
        func token(_ reply: ServiceReply) -> UUID { reply.activationToken ?? UUID() }
        // Invalid shapes cannot reach an operation, including valid-token siblings.
        for operation in ServiceOperation.allCases {
            let r = Rig(); await r.ready()
            let bad = await r.service.handle(.init(version: 2, operation: operation, token: UUID().uuidString), from: r.key)
            check(bad.outcome == .invalidRequest && r.power.writes.isEmpty, "version no mutation \(operation)")
            let malformed = await r.service.handle(.init(operation: operation, token: operation == .heartbeat || operation == .deactivate ? "bad" : UUID().uuidString), from: r.key)
            check(malformed.outcome == .invalidRequest && r.power.writes.isEmpty, "shape no mutation \(operation)")
        }
        for json in [#"{"version":1,"operation":"activate","uid":501}"#,
                     #"{"version":2,"operation":"status"}"#,
                     #"{"version":1,"operation":"shell"}"#,
                     #"{"version":1,"operation":"heartbeat","token":"bad"}"#] {
            check((try? JSONDecoder().decode(ServiceRequest.self, from: Data(json.utf8))) == nil, "decode rejects malformed request")
        }
        do {
            let r = Rig()
            check(await r.activate().outcome == .rejected, "startup must resolve before activation")
            r.power.pauseEvent = "read1"
            let startup = Task { await r.service.start() }
            check(await wait(r.power), "startup read suspended")
            check(await r.send(.status).state == .checking, "startup status truthful checking")
            check(await r.activate().activationToken == nil, "startup no token")
            r.power.release(); await startup.value
            check(await r.send(.status).state == .off, "startup exits off")
            check(r.service.accept(.init(uid: 0, auditSession: 0)) == nil, "root caller refused")
            check(r.service.accept(other) == nil, "nonconsole refused")
        }
        do {
            let r = Rig(); await r.ready()
            let active = await r.activate(), lease = token(active)
            check(active.outcome == .activated && active.state == .active && active.activationToken != nil, "new activation returns token")
            check(await r.send(.status).activationToken == nil, "status redacts token")
            check(await r.activate().activationToken == nil && r.power.writes == [true], "duplicate never adopts lease")
            check(await r.send(.heartbeat, token: lease).state == .active, "owner heartbeat")
            check(await r.send(.deactivate, token: UUID()).outcome == .rejected && r.power.value, "wrong token no stop")
            check(await r.send(.deactivate, token: lease).state == .off, "deactivate settles off")
            check(r.power.writes == [true, false], "one enable and restore")
            check(await r.activate().activationToken != nil, "off permits fresh activation")
        }
        // Every activation suspension fork, with every asynchronous stop source.
        // read2 = coordinator baseline, read3 = engine baseline, enable = write,
        // read4 = confirmation. All are real engine operations with fake power.
        for event in ["read2", "read3", "enable", "read4"] {
            for stop in ["disconnect", "retry", "prepare", "critical", "console", "finalBattery"] {
                let r = Rig(); await r.ready(); r.power.pauseEvent = event
                let activation = Task { await r.activate() }
                check(await wait(r.power), "\(event)/\(stop) suspension reached")
                let second = r.service.accept(owner)!
                check(await r.send(.activate, key: second).outcome == .rejected, "\(event)/\(stop) duplicate reserved")
                let writes = r.power.writes
                check(await r.send(.status, key: second).activationToken == nil, "\(event)/\(stop) status no token")
                check(r.power.writes == writes, "\(event)/\(stop) status no rearm")
                var recovery: Task<ServiceReply, Never>?
                switch stop {
                case "disconnect": await r.service.disconnected(r.key)
                case "retry": recovery = Task { await r.send(.retryRestore, key: second) }
                case "prepare": recovery = Task { await r.send(.prepareForUpdateOrRemoval, key: second) }
                case "critical": r.environment.thermal = .critical; await r.service.monitor()
                case "console": r.environment.current = other; await r.service.monitor()
                default: r.environment.battery = .finalWarning; await r.service.monitor()
                }
                // Let recovery enter and latch; it must remain reentrant while
                // waiting for the original writer, not cancel its task.
                for _ in 0..<20 { await Task.yield() }
                r.power.release()
                let late = await activation.value
                let recovered = await recovery?.value
                check(late.activationToken == nil && late.state != .active, "\(event)/\(stop) no late active reply")
                check(!r.power.value, "\(event)/\(stop) power restored")
                if stop == "prepare" {
                    check(recovered?.preparationPermit != nil, "\(event) preparation after pending activation")
                    check(await r.send(.activate, key: second).outcome == .rejected, "\(event) sealed activation refused")
                }
                r.environment.current = owner; r.environment.thermal = .nominal; r.environment.battery = .normal
                let reconnect = r.service.accept(owner)!
                let retry = await r.send(.retryRestore, key: reconnect)
                check(retry.state == .off, "\(event)/\(stop) offered retry reaches off")
                if stop != "prepare" {
                    check(await r.send(.activate, key: reconnect).activationToken != nil, "\(event)/\(stop) fresh activation after recovery")
                }
            }
        }
        do {
            let r = Rig(); await r.ready(); let first = token(await r.activate())
            let reconnect = r.service.accept(owner)!
            check(reconnect != r.key && reconnect.generation > r.key.generation, "same session distinct connection generation")
            check(await r.send(.heartbeat, key: reconnect, token: first).outcome == .rejected, "reconnect cannot inherit heartbeat")
            check(await r.send(.deactivate, key: reconnect, token: first).outcome == .rejected, "reconnect cannot inherit stop")
            check(await r.send(.retryRestore, key: reconnect).state == .off, "lost token retry exit")
            let fresh = await r.send(.activate, key: reconnect)
            check(fresh.activationToken != nil && fresh.activationToken != first, "new connection new lease")
            await r.service.disconnected(r.key); await r.service.disconnected(r.key)
            check(await r.send(.heartbeat, key: reconnect, token: token(fresh)).state == .active, "late old invalidation ignored")
            check(r.power.writes == [true, false, true], "late invalidation no power write")
            await r.service.disconnected(reconnect)
            check(!r.power.value, "current disconnect restores")
        }
        // Recovery must retain the old binding through EVERY outstanding engine
        // writer, including restoration started by a non-activation operation.
        for lane in ["deactivate", "status", "heartbeat", "monitor"] {
            for recoveryOperation in [ServiceOperation.retryRestore, .prepareForUpdateOrRemoval] {
                let r = Rig(); await r.ready(); let lease = token(await r.activate())
                r.power.pauseEvent = "disable"
                if lane == "status" { r.power.value = false }
                if lane == "heartbeat" {
                    r.clock.now = 131; r.environment.batteryAt = 131; r.environment.thermalAt = 131; r.environment.sessionAt = 131
                }
                if lane == "monitor" { r.environment.thermal = .critical }
                let stopping = Task {
                    if lane == "monitor" { await r.service.monitor() }
                    else { _ = await r.send(lane == "deactivate" ? .deactivate : lane == "status" ? .status : .heartbeat, token: lane == "status" ? nil : lease) }
                }
                check(await wait(r.power), "\(lane)/\(recoveryOperation) restore suspended")
                r.environment.current = other; r.environment.thermal = .nominal
                let replacement = r.service.accept(other)!
                r.environment.targets.removeAll()
                let recovering = Task { await r.send(recoveryOperation, key: replacement) }
                for _ in 0..<30 { await Task.yield() }
                check(!r.environment.targets.contains(other), "\(lane)/\(recoveryOperation) retain old target until writer settles")
                r.power.release(); await stopping.value
                let result = await recovering.value
                check(result.state == .off, "\(lane)/\(recoveryOperation) new console recovery succeeds")
            }
        }
        for failure in ["write", "journal", "read"] {
            let r = Rig(); await r.ready(); let active = await r.activate()
            r.power.failDisable = failure == "write"; r.journal.failClear = failure == "journal"; r.power.failRead = failure == "read"
            let failed = await r.send(.deactivate, token: token(active))
            check(failed.state == .recoveryRequired && failed.activationToken == nil, "\(failure) restoration failure explicit")
            check(await r.activate().outcome == .rejected, "\(failure) recovery prevents activation")
            r.power.failDisable = false; r.journal.failClear = false; r.power.failRead = false
            check(await r.send(.retryRestore).state == .off, "\(failure) retry clears recovery")
            check(await r.activate().activationToken != nil, "\(failure) resume after retry")
        }
        do {
            let r = Rig(); r.power.value = true; await r.ready()
            check(await r.send(.status).state == .conflict, "unowned startup conflict")
            check(await r.activate().activationToken == nil && r.power.writes.isEmpty, "startup conflict no adoption")
            r.power.value = false
            check(await r.send(.retryRestore).state == .off, "startup conflict external resolution plus retry")
            check(await r.activate().activationToken != nil, "retry opens bootstrap only after off")
        }
        for bad in ["staleBattery", "staleThermal", "staleSession", "futureThermal", "nanSession", "unknownBattery", "unknownThermal", "invalidSession"] {
            let r = Rig(); await r.ready()
            switch bad {
            case "staleBattery": r.environment.batteryAt = 94
            case "staleThermal": r.environment.thermalAt = 94
            case "staleSession": r.environment.sessionAt = 94
            case "futureThermal": r.environment.thermalAt = 101
            case "nanSession": r.environment.sessionAt = .nan
            case "unknownBattery": r.environment.battery = .unknown
            case "unknownThermal": r.environment.thermal = .unknown
            default: r.environment.sessionValid = false
            }
            check(await r.activate().activationToken == nil && r.power.writes.isEmpty, "\(bad) cannot enable")
        }
        do {
            let r = Rig(); await r.ready(); r.environment.thermal = .serious
            check(await r.activate().activationToken != nil, "serious thermal allowed")
            r.environment.targets.removeAll()
            _ = r.service.accept(owner); _ = await r.send(.status)
            check(r.environment.targets.allSatisfy { $0 == owner }, "acceptance/status retain bound target")
            r.clock.now = 131; r.environment.batteryAt = 131; r.environment.thermalAt = 131; r.environment.sessionAt = 131
            await r.service.monitor()
            check(await r.send(.status).state == .off && !r.power.value, "expired heartbeat restores with fresh guards")
        }
        // Preparation remains sealed across retry and only a fresh same-connection
        // preparation can mint another permit. No seventh cancel-removal API.
        do {
            let r = Rig(); await r.ready(); _ = await r.activate()
            let prepared = await r.send(.prepareForUpdateOrRemoval)
            check(prepared.state == .off && prepared.preparationPermit != nil, "active prepare restores and seals")
            let confirmation = await r.send(.status)
            check(confirmation.preparationPermit == prepared.preparationPermit, "same connection final off permit")
            let second = r.service.accept(owner)!
            check(await r.send(.status, key: second).preparationPermit == nil, "other connection status no permit")
            check(await r.send(.activate).outcome == .rejected, "failed unregister leaves sealed admission")
            check(await r.send(.retryRestore).state == .off, "sealed retry available")
            check(await r.send(.status).preparationPermit == nil, "retry invalidates prior permit")
            check(await r.send(.activate).outcome == .rejected, "retry never reopens sealed admission")
            let preparedAgain = await r.send(.prepareForUpdateOrRemoval)
            check(preparedAgain.preparationPermit != nil && preparedAgain.preparationPermit != prepared.preparationPermit, "reprepare fresh epoch")
            await r.service.disconnected(r.key)
            check(await r.send(.status, key: second).preparationPermit == nil, "disconnect invalidates permit")
            check(await r.send(.prepareForUpdateOrRemoval, key: second).preparationPermit != nil, "reconnect reprepare exit")
            let freshDaemon = Rig(); await freshDaemon.ready()
            check(await freshDaemon.send(.prepareForUpdateOrRemoval).preparationPermit?.incarnation != prepared.preparationPermit?.incarnation, "restart changes incarnation")
        }
        for fault in ["absentRoot", "mismatch", "error"] {
            let r = Rig(); await r.ready()
            let prepared = await r.send(.prepareForUpdateOrRemoval)
            check(prepared.preparationPermit != nil, "\(fault) preparation prerequisite")
            let finalRead = r.power.reads + 2 // engine status, then strict sealed read
            if fault == "error" { r.power.failReads.insert(finalRead) }
            else { r.power.receipts[finalRead] = .init(preference: false, rootDomain: fault == "absentRoot" ? nil : true) }
            let final = await r.send(.status)
            check(final.preparationPermit == nil && final.state == .recoveryRequired, "\(fault) final read revokes permit")
            check(await r.send(.status).preparationPermit == nil, "\(fault) permit cannot silently reappear")
            check(await r.activate().outcome == .rejected && r.power.writes.isEmpty, "\(fault) failed final read stays recovery-only")
            r.power.failReads = []; r.power.receipts = [:]
            check(await r.send(.prepareForUpdateOrRemoval).preparationPermit != nil, "\(fault) explicit preparation exit")
        }
        for race in ["reprepare", "disconnect"] {
            let r = Rig(); await r.ready(); _ = await r.send(.prepareForUpdateOrRemoval)
            r.power.pauseEvent = "read\(r.power.reads + 2)"
            let final = Task { await r.send(.status) }
            let reached = await wait(r.power)
            check(reached, "\(race) final strict read suspended")
            if !reached { r.power.release() }
            if race == "reprepare" {
                check(await r.send(.prepareForUpdateOrRemoval).preparationPermit != nil, "new epoch prepares while old observer awaits")
            } else { await r.service.disconnected(r.key) }
            r.power.release()
            check(await final.value.preparationPermit == nil, "\(race) stale final result no permit")
        }
        for event in ["disable", "read5", "read6", "read7", "read8"] {
            let r = Rig(); await r.ready(); _ = await r.activate(); r.power.pauseEvent = event
            let preparing = Task { await r.send(.prepareForUpdateOrRemoval) }
            check(await wait(r.power), "prepare \(event) suspension reached")
            let otherKey = r.service.accept(owner)!
            check(await r.send(.activate, key: otherKey).outcome == .rejected, "prepare \(event) closes admission")
            check(await r.send(.prepareForUpdateOrRemoval, key: otherKey).outcome == .rejected, "prepare \(event) concurrent preparation refused")
            await r.service.disconnected(r.key)
            r.power.release(); let old = await preparing.value
            check(old.preparationPermit == nil, "prepare \(event) interrupted no permit")
            check(await r.send(.prepareForUpdateOrRemoval, key: otherKey).preparationPermit != nil, "prepare \(event) reconnect retry")
        }
        do {
            let r = Rig(); await r.ready(); _ = await r.activate(); r.power.failDisable = true
            check(await r.send(.prepareForUpdateOrRemoval).preparationPermit == nil, "failed prepare no permit")
            check(await r.activate().outcome == .rejected, "failed prepare admission stays closed")
            r.power.failDisable = false
            check(await r.send(.retryRestore).state == .off, "failed prepare retry off")
            check(await r.activate().outcome == .rejected, "failed prepare retry no reopen")
            check(await r.send(.prepareForUpdateOrRemoval).preparationPermit != nil, "failed prepare explicit reprepare")
        }
        print("AlwaysOnServiceChecks: \(count) assertions, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
