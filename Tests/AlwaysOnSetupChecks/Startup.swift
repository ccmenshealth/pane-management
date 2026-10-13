import Foundation
import AlwaysOnCore
import AlwaysOnClient
import AlwaysOnIPC
import AlwaysOnSetup

// API-only overlay for the pre-fix run: the old coordinator has no scheduler
// injection, so accept and ignore it without changing its production behavior.
#if PRE_FIX
extension SetupCoordinator {
    convenience init(service: SetupService, client: SetupClient, proof: SetupProof, scheduler: ClientScheduler) {
        self.init(service: service, client: client, proof: proof)
    }
}
#endif
@MainActor private final class StartupTimer: ClientTimer {
    var cancelled = false
    func cancel() { cancelled = true }
}
@MainActor private final class StartupClock: ClientScheduler {
    var now = 0.0
    var events: [(Double, StartupTimer, @MainActor () -> Void)] = []
    var live: Int { events.filter { !$0.1.cancelled }.count }
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ClientTimer {
        let timer = StartupTimer(); events.append((now + delay, timer, action)); return timer
    }
    func fireWithoutDraining(after delay: Double) {
        now += delay
        let due = events.filter { $0.0 <= now }; events.removeAll { $0.0 <= now }
        for event in due where !event.1.cancelled { event.2() }
    }
    func tick() async {
        fireWithoutDraining(after: 1)
        await settle()
    }
    func advance(_ seconds: Int) async {
        let target = now + Double(seconds)
        while now < target {
            let next = events.filter { !$0.1.cancelled }.map { $0.0 }.min() ?? target
            now = min(target, max(now + 1, next)) - 1
            await tick()
        }
    }
}
@MainActor private func settle() async { for _ in 0..<100 { await Task.yield() } }
private final class StartupActivity: ClientActivity {
    var begins = 0
    func begin() -> AnyObject { begins += 1; return NSObject() }
    func end(_ token: AnyObject) {}
}
@MainActor private final class StartupChannel: ClientChannel {
    var isOpen = true
    let lost: @MainActor () -> Void
    let sendRequest: (ServiceRequest, @escaping @MainActor (Result<Data, Error>) -> Void) -> Void
    init(lost: @escaping @MainActor () -> Void, send: @escaping (ServiceRequest, @escaping @MainActor (Result<Data, Error>) -> Void) -> Void) { self.lost = lost; sendRequest = send }
    func send(_ data: Data, completion: @escaping @MainActor (Result<Data, Error>) -> Void) { sendRequest(try! BoundaryPolicy.decode(data), completion) }
    func close() { isOpen = false }
    func lose() { isOpen = false; lost() }
    func whileOpen(_ action: () -> Void) -> Bool { guard isOpen else { return false }; action(); return true }
}
@MainActor private final class StartupTransport: ClientTransport {
    let clock: StartupClock
    var availableAt = 100.0, reply = ServiceReply(state: .off)
    var channels: [StartupChannel] = [], requests: [ServiceOperation] = [], times: [Double] = []
    var hang = false, completions: [@MainActor (Result<Data, Error>) -> Void] = []
    init(_ clock: StartupClock) { self.clock = clock }
    func connect(lost: @escaping @MainActor () -> Void) throws -> ClientChannel {
        times.append(clock.now)
        let channel = StartupChannel(lost: lost) { [unowned self] request, completion in
            requests.append(request.operation)
            if hang { completions.append(completion); return }
            if clock.now < availableAt { completion(.failure(ClientFailure.unavailable)); return }
            if request.operation == .activate { completion(.success(try! BoundaryPolicy.encode(.init(state: .active, outcome: .activated, activationToken: UUID())))); return }
            completion(.success(try! BoundaryPolicy.encode(reply)))
        }
        channels.append(channel); return channel
    }
}
@MainActor private final class StartupService: SetupService {
    var value = SetupServiceStatus.enabled, registrations = 0, removals = 0, opens = 0
    func status() async throws -> SetupServiceStatus { value }
    func validateIdentity() throws {}
    func register() async throws { registrations += 1 }
    func unregister(_ completion: @escaping @MainActor (Result<Void, Error>) -> Void) { removals += 1; completion(.success(())) }
    func openLoginItems() { opens += 1 }
}
@MainActor private final class StartupProof: SetupProof {
    func power() async throws -> PowerReceipt { .init(preference: false, rootDomain: false) }
    func directoryAbsent() async throws -> Bool { false }
}
@MainActor private final class StartupHarness {
    let clock = StartupClock(), service = StartupService(), activity = StartupActivity()
    let transport: StartupTransport, client: AlwaysOnClient, setup: SetupCoordinator, adapter: SetupPresentationAdapter, controller: AlwaysOnController
    init() {
        transport = StartupTransport(clock)
        client = AlwaysOnClient(transport: transport, scheduler: clock, activity: activity)
        setup = SetupCoordinator(service: service, client: SetupClientAdapter(client), proof: StartupProof(), scheduler: clock)
        adapter = SetupPresentationAdapter(setup); controller = AlwaysOnController(backend: adapter)
    }
}
@MainActor func startupChecks(_ check: (Bool, String) -> Void) async {
    do {
        let h = StartupHarness()
        h.controller.checkSetup(); await settle() // Actual App startup driver through adapter.
        check(h.controller.needsRepair, "startup unavailable retains recovery warning")
        await h.clock.advance(99)
        check(h.controller.needsRepair, "startup remains truthful beyond original deadline")
        await h.clock.advance(35)
        check(h.controller.state == .off, "delayed helper over 90 seconds clears warning automatically")
        check(h.transport.requests.allSatisfy { $0 == .status }, "startup never replays restoration or any mutation")
        check(h.activity.begins == 0, "startup probing never prevents normal sleep")
        check(h.transport.channels.allSatisfy { !$0.isOpen }, "startup channels close after probes")
        let calls = h.transport.times.count; await h.clock.advance(90)
        check(h.transport.times.count == calls && h.clock.live == 0, "verified OFF terminates retries")
        check(h.service.registrations == 0 && h.service.removals == 0 && h.service.opens == 0, "startup performs no lifecycle or navigation")
        for channel in h.transport.channels { channel.lose() }; await settle()
        check(h.transport.times.count == calls && h.controller.state == .off, "old probe loss cannot restore or overwrite OFF")
    }
    do {
        let h = StartupHarness(); h.transport.availableAt = .infinity
        await h.adapter.refresh(); await h.clock.advance(200)
        check(h.controller.needsRepair && h.controller.action == .deactivate, "persistent unavailability keeps manual recovery exit")
        check(h.transport.times == [0, 2, 7, 17, 47, 77, 107, 137, 167, 197], "startup bounded backoff persists at thirty seconds")
        check(h.clock.live == 1, "only one retry timer remains")
        h.transport.availableAt = 0; await h.adapter.deactivate()
        let calls = h.transport.times.count; await h.clock.advance(90)
        check(h.controller.state == .off && h.transport.times.count == calls, "manual Retry supersedes scheduled startup work")
    }
    for state in [ServiceState.recoveryRequired, .active] {
        let h = StartupHarness(); h.transport.availableAt = 0; h.transport.reply = .init(state: state)
        await h.adapter.refresh(); let calls = h.transport.times.count; await h.clock.advance(90)
        check(h.controller.needsRepair && h.controller.action == .deactivate, "authoritative \(state) retains explicit deactivation exit")
        check(h.transport.requests == [.status] && h.transport.times.count == calls, "authoritative \(state) stops retries without mutation")
        h.transport.reply = .init(state: .off); await h.adapter.deactivate()
        check(h.controller.state == .off, "manual recovery from \(state) accepts verified OFF")
    }
    do {
        let h = StartupHarness(); h.transport.hang = true
        let initial = Task { await h.adapter.refresh() }; await settle()
        await h.adapter.refresh(); await h.adapter.refresh()
        check(h.transport.times.count == 1, "focus and wake coalesce during pending startup probe")
        await h.clock.advance(10); await initial.value
        check(h.controller.needsRepair, "hung probe has bounded deadline and truthful warning")
        check(h.controller.action == .deactivate && h.controller.canRemove && h.adapter.snapshot.secondaryTitle == "Repair setup in Settings", "background hung retry keeps manual Retry and Repair actionable")
        h.transport.hang = false; h.transport.availableAt = 0
        let stop = Task { await h.adapter.deactivate() }; await settle()
        await h.clock.advance(5); await stop.value; await h.adapter.activate()
        let revision = h.adapter.snapshot.revision
        for completion in h.transport.completions { completion(.success(try! BoundaryPolicy.encode(.init(state: .off)))) }
        await settle()
        check(h.controller.state == .active && h.adapter.snapshot.revision == revision, "late probe cannot erase manual activation")
        await h.adapter.deactivate()
    }
    do {
        let h = StartupHarness(); h.transport.hang = true
        let initial = Task { await h.adapter.refresh() }; await settle()
        h.transport.channels.first?.lose(); await settle(); await h.clock.advance(10)
        h.transport.hang = false; h.transport.availableAt = 0
        await h.clock.advance(40); await initial.value
        check(h.transport.requests.allSatisfy { $0 == .status }, "probe interruption never falls through to mutating recover")
        check(h.controller.state == .off, "probe interruption eventually rechecks verified OFF")
    }
    do {
        let h = StartupHarness(); h.transport.availableAt = 0
        h.transport.reply = .init(state: .off, preparationPermit: .init(incarnation: UUID(), epoch: 1), requiresRemoval: true)
        await h.adapter.refresh(); let calls = h.transport.times.count; await h.clock.advance(90)
        check(h.controller.state == .removalRequired && h.transport.times.count == calls && h.clock.live == 0, "removal-required stops retries and exposes Finish removal")
    }
    for remove in [false, true] {
        let h = StartupHarness(); h.transport.hang = true
        let initial = Task { await h.adapter.refresh() }; await settle()
        let manual = Task { if remove { await h.adapter.remove() } else { await h.adapter.setup() } }; await settle()
        h.transport.hang = false; h.transport.availableAt = 0
        await h.clock.advance(10); await initial.value; await manual.value
        let revision = h.adapter.snapshot.revision, calls = h.transport.times.count
        for completion in h.transport.completions { completion(.success(try! BoundaryPolicy.encode(.init(state: .off)))) }
        await h.clock.advance(90)
        check(h.adapter.snapshot.revision == revision && h.transport.times.count == calls, "manual lifecycle supersedes probe and retry: removal=\(remove)")
        if remove {
            check(h.controller.needsRepair && h.adapter.snapshot.secondaryTitle == "Retry helper removal in Settings", "failed manual removal retains its specific recovery exit")
        } else { check(h.controller.state == .off, "manual setup finishes with fresh authenticated OFF") }
    }
    for status in [SetupServiceStatus.requiresApproval, .notFound] {
        let h = StartupHarness(); await h.adapter.refresh(); h.service.value = status
        await h.clock.advance(2)
        let calls = h.transport.times.count; await h.clock.advance(90)
        check(h.transport.times.count == calls && h.clock.live == 0, "setup-required \(status) stops retries")
        check(h.controller.state != .off && h.service.registrations == 0, "setup-required stays explicit without registration")
    }
    do {
        var h: StartupHarness? = StartupHarness(); let clock = h!.clock
        weak let coordinator = h!.setup
        await h!.adapter.refresh(); h = nil; await settle(); await clock.advance(90)
        check(coordinator == nil && clock.live == 0, "retry timer does not retain discarded coordinator")
    }
}

// These actor-local methods intentionally never suspend, matching the permitted
// fast-completion path. That lets a manual operation settle between timer fire
// and execution of the Task queued by the timer, without sleeps or dispatch hooks.
@MainActor private final class ImmediateStartupClient: SetupClient {
    var state: ClientState = .unknown("Delayed helper")
    var removalPending = false
    var onChange: (() -> Void)?
    var statuses = 0, probes = 0, activations = 0, stops = 0, removals = 0
    func probeStartup() async -> (state: ClientState, retry: Bool) {
        probes += 1; return (.unknown("Delayed helper"), true)
    }
    func status() async { statuses += 1; state = .off; onChange?() }
    func activate() async { activations += 1; state = .active; onChange?() }
    func deactivate() async { stops += 1; state = .off; onChange?() }
    func remove(unregister: (@escaping @MainActor (Result<Void, Error>) -> Void) -> Void) async -> Bool {
        removals += 1; unregister { _ in }; state = .off; onChange?(); return true
    }
}
@MainActor func queuedStartupChecks(_ check: (Bool, String) -> Void) async {
    for action in ["deactivate", "activate", "setup", "remove"] {
        let clock = StartupClock(), service = StartupService(), client = ImmediateStartupClient()
        let coordinator = SetupCoordinator(service: service, client: client, proof: StartupProof(), scheduler: clock)
        await coordinator.refresh()
        check(client.probes == 1 && clock.live == 1, "queued fixture has exactly one unresolved startup retry")
        clock.fireWithoutDraining(after: 2)
        // No yielding between firing the callback and completing the manual action.
        switch action {
        case "deactivate": await coordinator.deactivate()
        case "activate": await coordinator.deactivate(); await coordinator.activate()
        case "setup": await coordinator.setup()
        default: _ = await coordinator.remove()
        }
        let settled = coordinator.observation
        let statuses = client.statuses, probes = client.probes
        let mutations = client.activations + client.stops + client.removals
        await settle()
        check(client.statuses == statuses, "fired retry cannot enter ordinary status after manual \(action)")
        check(coordinator.observation == settled, "fired retry cannot overwrite settled manual \(action)")
        await clock.advance(60)
        check(client.probes == probes && client.activations + client.stops + client.removals == mutations && clock.live == 0,
              "manual \(action) leaves no stale retry or mutation replay")
    }
    do {
        let clock = StartupClock(), client = ImmediateStartupClient()
        let coordinator = SetupCoordinator(service: StartupService(), client: client, proof: StartupProof(), scheduler: clock)
        await coordinator.refresh(); clock.fireWithoutDraining(after: 2)
        // A focus refresh can run before the queued timer Task and install the
        // next retry. The old Task must neither probe again nor clear that timer.
        await coordinator.refresh()
        check(client.probes == 2 && clock.live == 1, "intervening refresh schedules one new retry")
        await settle()
        check(client.probes == 2 && clock.live == 1, "stale queued retry preserves newer timer")
        await clock.advance(5)
        check(client.probes == 3 && clock.live == 1, "newer retry still executes once")
        await coordinator.deactivate()
    }
}
