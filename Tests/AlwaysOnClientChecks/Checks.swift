import Foundation
import AlwaysOnIPC
import AlwaysOnClient

@MainActor final class Timer: ClientTimer { var cancelled = false; func cancel() { cancelled = true } }
@MainActor final class Scheduler: ClientScheduler {
    var now = 100.0
    var events: [(Double, Timer, @MainActor () -> Void)] = []
    func schedule(after: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ClientTimer { let t = Timer(); events.append((now + after, t, action)); return t }
    func advance(_ delta: Double, fire: Bool = true) { now += delta; if fire { let ready = events.filter { $0.0 <= now }; events.removeAll { $0.0 <= now }; for e in ready where !e.1.cancelled { e.2() } } }
}
@MainActor final class Channel: ClientChannel {
    var isOpen = true
    var requests: [ServiceRequest] = []
    var handler: ((ServiceRequest, @escaping @MainActor (Result<Data, Error>) -> Void) -> Void)?
    var lost: (() -> Void)?
    var token = UUID()
    var state: ServiceState = .off
    func send(_ data: Data, completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        let r = try! BoundaryPolicy.decode(data); requests.append(r)
        if let handler { handler(r, completion); return }
        if r.operation == .activate { state = .active }
        if r.operation == .deactivate || r.operation == .retryRestore { state = .off }
        completion(.success(try! BoundaryPolicy.encode(ServiceReply(state: state, outcome: r.operation == .activate ? .activated : .observed, activationToken: r.operation == .activate ? token : nil))))
    }
    func whileOpen(_ action: () -> Void) -> Bool { guard isOpen else { return false }; action(); return true }
    func close() { isOpen = false }
    func lose() { isOpen = false; lost?() }
}
@MainActor final class Transport: ClientTransport {
    var channels: [Channel] = []; var make: (() -> Channel)?; var fail = false
    func connect(lost: @escaping @MainActor () -> Void) throws -> ClientChannel { if fail { throw ClientFailure.unavailable }; let c = make?() ?? Channel(); c.lost = lost; channels.append(c); return c }
}
@MainActor func pump() async { for _ in 0..<25 { await Task.yield() } }
func isUnknown(_ state: ClientState) -> Bool { if case .unknown = state { return true }; return false }
@main struct Checks {
    @MainActor static func main() async {
        var count = 0, failures = 0
        func check(_ ok: Bool, _ label: String) { count += 1; if !ok { failures += 1; print("FAIL: \(label)") } }
        let t = Transport(), s = Scheduler(), c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
        check(await c.status().state == .off, "verified status off")
        check(await c.activate().state == .active, "fresh activation")
        check(t.channels.first?.requests.filter { $0.operation == .activate }.count == 1, "activation exactly once")
        s.advance(10); await pump()
        check(t.channels.first?.requests.last?.operation == .heartbeat, "heartbeat at ten seconds")
        check(await c.deactivate().state == .off, "deactivate verified off")
        check(t.channels.first?.requests.last?.operation == .deactivate, "owned token stop")
        do {
            let t = Transport(), s = Scheduler(); var held: (@MainActor (Result<Void, Error>) -> Void)?
            let p = PreparationPermit(incarnation: UUID(), epoch: 1)
            t.make = { let h = Channel(); var prepared = false; h.handler = { r, done in
                if r.operation == .prepareForUpdateOrRemoval { prepared = true; done(.success(try! BoundaryPolicy.encode(.init(state: .off, outcome: .prepared, preparationPermit: p, requiresRemoval: true)))) }
                else { done(.success(try! BoundaryPolicy.encode(.init(state: .off, preparationPermit: prepared ? p : nil, requiresRemoval: prepared)))) }
            }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            let task = Task { await c.remove { held = $0 } }; await pump(); s.advance(5); await pump()
            check(c.observation.removalPending, "timed out unregister retains lifecycle slot")
            check(isUnknown(c.observation.state), "pending unregister remains unknown")
            let calls = t.channels.flatMap(\.requests).count
            let queued = Task { await c.deactivate() }; await pump()
            check(t.channels.flatMap(\.requests).count == calls, "pending unregister prevents queued mutation")
            held?(.success(())); await pump()
            check(await task.value, "late unregister success reconciles")
            check(!c.observation.removalPending, "settled unregister releases lifecycle slot")
            _ = await queued.value
        }
        do {
            let t = Transport(), s = Scheduler(); var held: ((Result<Data, Error>) -> Void)?; var first = true
            t.make = { let h = Channel(); h.handler = { r, done in
                if first { first = false; held = done } else { done(.success(try! BoundaryPolicy.encode(.init(state: r.operation == .activate ? .active : .off, outcome: r.operation == .activate ? .activated : .observed, activationToken: r.operation == .activate ? UUID() : nil)))) }
            }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            let status = Task { await c.status() }; await pump()
            let activation = Task { await c.activate() }; await pump()
            let stop = Task { await c.deactivate() }; await pump()
            held?(.success(try! BoundaryPolicy.encode(.init(state: .off)))); await pump()
            _ = await status.value; _ = await activation.value; _ = await stop.value
            check(t.channels.flatMap(\.requests).allSatisfy { $0.operation != .activate }, "queued activation cannot erase later stop")
        }
        do {
            let t = Transport(), s = Scheduler(); var held: ((Result<Data, Error>) -> Void)?; var calls = 0
            t.make = { let h = Channel(); h.handler = { _, done in calls += 1; if calls == 1 { done(.success(try! BoundaryPolicy.encode(.init(state: .checking, outcome: .rejected)))) } else { held = done } }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity()); let task = Task { await c.status() }; await pump()
            s.advance(4); await pump(); s.advance(1); await pump()
            check(t.channels.count == 2, "readiness total budget includes later RPC")
            t.fail = true; s.advance(5); await pump(); held?(.failure(ClientFailure.connectionLost)); await pump()
            _ = await task.value
        }
        // Strict wire validation uses canonical bytes even for intentionally bad
        // semantic replies, independently of the production reply encoder.
        func bytes(_ r: ServiceReply) -> Data { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try! e.encode(r) }
        func rejected(_ d: Data, _ op: ServiceOperation = .status) -> Bool { (try? BoundaryPolicy.decodeReply(d, for: op)) == nil }
        let permit = PreparationPermit(incarnation: UUID(), epoch: 9)
        let good = ServiceReply(state: .off)
        check(!rejected(bytes(good)), "canonical off decoded")
        for payload in [Data(), Data(repeating: 32, count: 4097), Data("{}".utf8), Data("{\"version\":1,\"state\":\"off\",\"outcome\":\"observed\"}".utf8), Data("{\"outcome\":\"observed\",\"state\":\"off\",\"version\":2}".utf8), Data("{\"outcome\":\"observed\",\"state\":\"off\",\"version\":1,\"x\":0}".utf8), Data("{\"outcome\":\"observed\",\"state\":\"off\",\"version\":1,\"version\":1}".utf8), bytes(.init(state: .off, reason: String(repeating: "x", count: 2049)))] {
            check(rejected(payload), "reject noncanonical invalid payload")
        }
        for op in ServiceOperation.allCases {
            check(rejected(bytes(.init(state: .off, activationToken: UUID())), op), "no leaked token \(op)")
            check(rejected(bytes(.init(state: .active, outcome: .activated, activationToken: UUID())), op) == (op != .activate), "fresh activation only \(op)")
            check(rejected(bytes(.init(state: .off, outcome: .prepared, preparationPermit: permit, requiresRemoval: true)), op) == (op != .prepareForUpdateOrRemoval), "prepared operation \(op)")
            check(rejected(bytes(.init(state: .off, preparationPermit: permit, requiresRemoval: true)), op) == (op != .status), "sealed status only \(op)")
            check(rejected(bytes(.init(state: .active, preparationPermit: permit, requiresRemoval: true)), op), "permit must off \(op)")
            check(rejected(bytes(.init(state: .active, outcome: .activated)), op), "activation needs token \(op)")
            check(rejected(bytes(.init(state: .off, outcome: .prepared)), op), "preparation needs permit \(op)")
        }
        let canonical = String(data: bytes(good), encoding: .utf8)!
        for malformed in ["1", "\"true\"", "null"] {
            check(rejected(Data(canonical.replacingOccurrences(of: "\"requiresRemoval\":false", with: "\"requiresRemoval\":" + malformed).utf8)), "requiresRemoval strict Boolean \(malformed)")
        }
        check(rejected(Data(canonical.replacingOccurrences(of: "\"requiresRemoval\":false,", with: "").utf8)), "requiresRemoval cannot be omitted")
        check(rejected(bytes(.init(state: .active, outcome: .activated, activationToken: UUID(), requiresRemoval: true)), .activate), "activated forbids removal flag")
        check(rejected(bytes(.init(state: .off, outcome: .prepared, preparationPermit: permit)), .prepareForUpdateOrRemoval), "prepared requires removal flag")
        check(rejected(bytes(.init(state: .off, preparationPermit: permit))), "final permit requires removal flag")
        for outcome in [ServiceOutcome.rejected, .invalidRequest] {
            let t = Transport(), s = Scheduler()
            t.make = { let h = Channel(); h.handler = { _, done in done(.success(bytes(.init(state: .off, outcome: outcome, requiresRemoval: true)))) }; return h }
            let client = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            check(isUnknown(await client.status().state), "rejected removal metadata cannot assert safe state")
        }
        do {
            let t = Transport(), s = Scheduler()
            t.make = { let h = Channel(); h.handler = { r, done in
                let stopping = r.operation == .deactivate
                done(.success(bytes(.init(state: r.operation == .activate ? .active : .off,
                    outcome: r.operation == .activate ? .activated : .observed,
                    activationToken: r.operation == .activate ? UUID() : nil, requiresRemoval: stopping))))
            }; return h }
            let client = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            _ = await client.activate()
            check(await client.deactivate().state == .removalRequired, "owned stop propagates removal state")
        }
        do {
            let t = Transport(), s = Scheduler(); var closed = false
            t.make = { let h = Channel(); h.handler = { r, done in
                if r.operation == .heartbeat { closed = true }
                done(.success(bytes(.init(state: r.operation == .activate || r.operation == .heartbeat ? .active : .off,
                    outcome: r.operation == .activate ? .activated : .observed,
                    activationToken: r.operation == .activate ? UUID() : nil, requiresRemoval: closed))))
            }; return h }
            let client = AlwaysOnClient(transport: t, scheduler: s, activity: Activity()); _ = await client.activate(); s.advance(10)
            let deadline = ProcessInfo.processInfo.systemUptime + 2
            while !closed && ProcessInfo.processInfo.systemUptime < deadline { await Task.yield() }
            let afterHeartbeat = await client.status()
            check(closed && afterHeartbeat.state == .removalRequired, "heartbeat closed admission recovers to removal state")
        }
        var permitJSON = String(data: bytes(.init(state: .off, preparationPermit: permit, requiresRemoval: true)), encoding: .utf8)!
        check(rejected(Data(permitJSON.replacingOccurrences(of: permit.incarnation.uuidString, with: permit.incarnation.uuidString.lowercased()).utf8)), "canonical permit UUID")
        permitJSON = permitJSON.replacingOccurrences(of: "\"epoch\":9", with: "\"epoch\":9,\"extra\":1")
        check(rejected(Data(permitJSON.utf8)), "nested permit exact fields")
        do { _ = try NativeClientTransport().connect(lost: {}); check(false, "unsigned fixture refuses native connect") } catch { check(true, "unsigned fixture refuses native connect") }

        // Readiness starts with status and retries only that operation.
        do {
            let t = Transport(), s = Scheduler(); var statuses = 0
            t.make = { let h = Channel(); h.handler = { r, done in statuses += 1; done(.success(bytes(.init(state: statuses == 1 ? .checking : .off, outcome: statuses == 1 ? .rejected : .observed)))) }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            let task = Task { await c.status() }; await pump(); s.advance(0.25); await pump()
            check(await task.value.state == .off, "readiness settles")
            check(t.channels[0].requests.map(\.operation) == [.status, .status], "status-only readiness")
        }
        do {
            let t = Transport(), s = Scheduler()
            t.make = { let h = Channel(); h.handler = { _, done in done(.success(bytes(.init(state: .checking, outcome: .rejected)))) }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity()); let task = Task { await c.status() }
            for _ in 0..<45 { await pump(); s.advance(0.25) }; await pump()
            check(isUnknown(await task.value.state), "readiness timeout visible")
            check(t.channels.count == 2, "one bounded reconnect")
            check(t.channels.flatMap(\.requests).allSatisfy { $0.operation == .status }, "timeout never mutates")
        }
        for outcome in [ServiceOutcome.rejected, .invalidRequest] {
            let t = Transport(), s = Scheduler()
            t.make = { let h = Channel(); h.handler = { _, done in done(.success(bytes(.init(state: .off, outcome: outcome)))) }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            check(isUnknown(await c.status().state), "cached rejected off not authoritative \(outcome)")
            check(isUnknown(await c.activate().state), "rejected off prevents activation \(outcome)")
            check(t.channels.flatMap(\.requests).allSatisfy { $0.operation == .status }, "no mutation after rejection")
        }
        // Callback delayed beyond the deadline must fail even before timer fires.
        for callbackLate in [false, true] {
            let t = Transport(), s = Scheduler(); var held: ((Result<Data, Error>) -> Void)?
            var first = true
            t.make = { let h = Channel(); if first { first = false; h.handler = { r, done in if r.operation == .activate { held = done } else { done(.success(bytes(good))) } } }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity()); let task = Task { await c.activate() }; await pump()
            s.advance(5, fire: !callbackLate)
            if callbackLate { held?(.success(bytes(.init(state: .active, outcome: .activated, activationToken: UUID())))) }
            await pump(); check(await task.value.state == .off, "ambiguous activation restored \(callbackLate)")
            held?(.success(bytes(.init(state: .active, outcome: .activated, activationToken: UUID())))); await pump()
            check(c.observation.state == .off, "late duplicate cannot rearm")
            check(t.channels.flatMap(\.requests).filter { $0.operation == .activate }.count == 1, "never replay activation")
            check(t.channels.last?.requests.last?.operation == .retryRestore, "ambiguous mutation restores")
            check(!t.channels[0].isOpen, "ambiguous generation closed")
        }
        do {
            let t = Transport(), s = Scheduler(); var held: ((Result<Data, Error>) -> Void)?
            t.make = { let h = Channel(); h.handler = { r, done in if r.operation == .activate { held = done } else { done(.success(bytes(good))) } }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity()); var activePublished = false
            c.onObservation = { if $0.state == .active { activePublished = true } }
            let activating = Task { await c.activate() }; await pump(); let stopping = Task { await c.deactivate() }; await pump()
            held?(.success(bytes(.init(state: .active, outcome: .activated, activationToken: UUID())))); await pump()
            check(await activating.value.state == .off && !activePublished, "stop latches late activation")
            check(await stopping.value.state == .off, "queued stop settles")
            check(t.channels[0].requests.contains { $0.operation == .deactivate }, "late token used to stop")
        }
        do {
            let t = Transport(), s = Scheduler(); t.make = { let h = Channel(); h.state = .active; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            check(await c.status().state == .off, "orphan restored")
            check(t.channels.flatMap(\.requests).allSatisfy { $0.token == nil }, "orphan never adopts token")
        }
        for initiallyActive in [false, true] {
            for loss in ["interruption", "invalidation"] {
                let t = Transport(), s = Scheduler(), c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
                _ = initiallyActive ? await c.activate() : await c.status()
                var states: [ClientState] = []; c.onObservation = { states.append($0.state) }
                let old = t.channels[0]; old.lose(); old.lose(); await pump()
                check(states.contains(where: isUnknown), "\(loss) publishes uncertainty from \(initiallyActive)")
                check(c.observation.state == .off, "\(loss) recovers")
                check(t.channels.count == 2, "duplicate loss one reconnect")
                old.lost?(); await pump(); check(t.channels.count == 2, "old loss fenced")
                check(t.channels.last?.requests.contains { $0.operation == .retryRestore } == true, "loss restores")
            }
        }
        for heartbeatState in [ServiceState.off, .recoveryRequired, .active] {
            let t = Transport(), s = Scheduler(), c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            _ = await c.activate(); let old = t.channels[0]
            old.handler = { _, done in done(.success(bytes(.init(state: heartbeatState, outcome: heartbeatState == .active ? .rejected : .observed)))) }
            s.advance(10); await pump()
            check(c.observation.state == .off, "non-owned heartbeat restores \(heartbeatState)")
            check(t.channels.count == 2, "heartbeat renew stops on failure")
        }
        do {
            let t = Transport(), s = Scheduler(), c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            _ = await c.status(); t.fail = true; t.channels[0].lose(); await pump()
            check(isUnknown(c.observation.state), "failed recovery remains visible")
            t.fail = false; check(await c.deactivate().state == .off, "human retry exits recovery")
        }
        for operation in [ServiceOperation.status, .activate, .heartbeat, .deactivate] {
            let t = Transport(), s = Scheduler(), c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            _ = operation == .status ? await c.status() : await c.activate()
            let old = t.channels[0]
            old.handler = { r, done in
                if r.operation == operation { done(.success(Data("malformed".utf8))); done(.failure(ClientFailure.connectionLost)) }
                else { done(.success(bytes(.init(state: .off)))) }
            }
            switch operation {
            case .status: _ = await c.status()
            case .activate: _ = await c.activate()
            case .deactivate: _ = await c.deactivate()
            default: s.advance(10); await pump()
            }
            check(c.observation.state == .off, "malformed \(operation) restores")
            check(!old.isOpen, "malformed closes \(operation) generation")
        }
        do {
            let t = Transport(), s = Scheduler(), c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            _ = await c.activate(); let old = t.channels[0]; var held: ((Result<Data, Error>) -> Void)?
            old.handler = { _, done in held = done }
            let foreground = Task { await c.status() }; await pump(); let calls = old.requests.count
            s.advance(10, fire: false)
            old.lose(); await pump()
            held?(.success(bytes(.init(state: .active)))); await pump()
            check(await foreground.value.state == .off, "loss fences stale foreground active")
            check(old.requests.count == calls, "loss cancels renewal while foreground pending")
            check(c.observation.state == .off, "late stale callback does not overwrite recovery")
        }
        // Removal never reuses a permit, and expected disconnect during async
        // unregister is distinguished from a failed/late completion.
        for failure in ["none", "permit", "incarnation", "finalRejected", "loss", "unregister", "expectedLoss"] {
            let t = Transport(), s = Scheduler(); var registeredCalls = 0, rounds = 0
            t.make = { let h = Channel(); var prepared = false
                h.handler = { r, done in
                    if r.operation == .prepareForUpdateOrRemoval { prepared = true; rounds += 1; done(.success(bytes(.init(state: .off, outcome: .prepared, preparationPermit: permit, requiresRemoval: true)))); return }
                    if prepared {
                        if failure == "loss" { h.lose() }
                        let p = failure == "permit" ? PreparationPermit(incarnation: permit.incarnation, epoch: 10) : failure == "incarnation" ? PreparationPermit(incarnation: UUID(), epoch: 9) : permit
                        done(.success(bytes(.init(state: .off, outcome: failure == "finalRejected" ? .rejected : .observed, preparationPermit: failure == "finalRejected" ? nil : p, requiresRemoval: true))))
                    } else { done(.success(bytes(good))) }
                }; return h
            }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: Activity())
            let task = Task { await c.remove { done in registeredCalls += 1; if failure == "expectedLoss" { t.channels.last?.lose() }; if failure != "timeout" { done(failure == "unregister" ? .failure(ClientFailure.removal) : .success(())) } } }
            await pump(); if failure == "timeout" { s.advance(5); await pump() }
            let success = failure == "none" || failure == "expectedLoss"
            check(await task.value == success, "removal result \(failure)")
            check(registeredCalls == (["permit", "incarnation", "finalRejected", "loss"].contains(failure) ? 0 : 1), "unregister admission \(failure)")
            check(success ? c.observation.state == .off : isUnknown(c.observation.state), "removal state \(failure)")
            if failure == "unregister" {
                check(await c.remove { $0(.success(())) }, "fresh removal retries")
                check(rounds == 2 && t.channels.count == 2, "fresh prepare after unregister error")
            }
        }
        do {
            let t = Transport(), s = Scheduler(), a = Activity()
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: a)
            check(a.begins == 0, "activity constructor inert")
            _ = await c.status(); check(a.begins == 1 && a.ends == 1, "off status balances activity")
            _ = await c.activate(); check(a.begins == 2 && a.ends == 1, "owned token retains activity")
            _ = await c.status(); s.advance(10); await pump()
            check(a.begins == 2 && a.ends == 1, "owned refresh and heartbeat never gap activity")
            t.channels.last?.lose(); await pump()
            check(c.observation.state == .off && a.begins == 2 && a.ends == 2, "loss transfers hold through recovery")
            t.fail = true; _ = await c.deactivate()
            check(a.begins == 3 && a.ends == 3, "failed recovery releases settled no-token activity")
        }
        do {
            let t = Transport(), s = Scheduler(), a = Activity()
            var held: ((Result<Data, Error>) -> Void)?
            t.make = { let h = Channel(); h.handler = { r, done in
                if r.operation == .activate { held = done }
                else { done(.success(bytes(.init(state: .off)))) }
            }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: a)
            let activate = Task { await c.activate() }; await pump()
            let stop = Task { await c.deactivate() }; await pump()
            check(a.begins == 1 && a.ends == 0, "queued stop independently retains activity")
            held?(.success(bytes(.init(state: .active, outcome: .activated, activationToken: UUID()))))
            _ = await activate.value; _ = await stop.value
            check(a.begins == 1 && a.ends == 1, "late activation stop balances shared activity")
        }
        do {
            let t = Transport(), s = Scheduler(), a = Activity(); var held: (@MainActor (Result<Void, Error>) -> Void)?
            let p = PreparationPermit(incarnation: UUID(), epoch: 2)
            t.make = { let h = Channel(); var prepared = false; h.handler = { r, done in
                if r.operation == .prepareForUpdateOrRemoval { prepared = true }
                done(.success(bytes(.init(state: .off, outcome: r.operation == .prepareForUpdateOrRemoval ? .prepared : .observed,
                    preparationPermit: prepared ? p : nil, requiresRemoval: prepared))))
            }; return h }
            let c = AlwaysOnClient(transport: t, scheduler: s, activity: a)
            let removal = Task { await c.remove { held = $0 } }; await pump(); s.advance(5); await pump()
            check(a.begins == 1 && a.ends == 0 && c.observation.removalPending, "unregister notice does not release activity")
            t.channels.last?.lose(); await pump()
            check(a.ends == 0, "expected disconnect retains removal activity")
            held?(.failure(ClientFailure.removal)); _ = await removal.value
            check(a.begins == 1 && a.ends == 1, "actual failed unregister balances activity")
        }
        do {
            let a = Activity(), t = Transport(), s = Scheduler()
            var client: AlwaysOnClient? = AlwaysOnClient(transport: t, scheduler: s, activity: a)
            _ = await client?.activate(); client = nil
            check(a.begins == 1 && a.ends == 1, "client disposal balances owned activity")
        }
        check(!SystemClientActivity.options.contains(.idleSystemSleepDisabled), "activity permits idle system sleep")
        check(!SystemClientActivity.options.contains(.idleDisplaySleepDisabled), "activity permits display sleep")
        check(!SystemClientActivity.options.contains(.latencyCritical), "activity does not request latency critical")
        print("AlwaysOnClientChecks: \(count) assertions, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}

private final class Activity: ClientActivity {
    var begins = 0, ends = 0
    func begin() -> AnyObject { begins += 1; return NSObject() }
    func end(_ token: AnyObject) { ends += 1 }
}
