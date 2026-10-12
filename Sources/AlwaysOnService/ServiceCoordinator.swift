import AlwaysOnCore
import Foundation

/// One instance per daemon incarnation. Only its native boundary admits peers;
/// all request operations subsequently use the opaque admitted key.
@MainActor public final class ServiceCoordinator {
    private enum Admission { case bootstrapping, open, preparing(UInt64, ConnectionKey), sealed(UInt64, ConnectionKey) }
    private enum Stage { case baseline, activating, active, restoring }
    private struct Ownership {
        let epoch: UInt64; let key: ConnectionKey; let session: ConsoleSession
        var stage: Stage; var lease: RecoveryLease?
    }
    private let incarnation = UUID()
    private let guards: BoundGuards
    private let engine: RecoveryEngine
    // Exactly the same port as the engine: never an independently configured reader.
    private let power: RecoveryPower
    private let clock: RecoveryClock
    private var connections: [ConnectionKey: ConsoleSession] = [:]
    private var serial: UInt64 = 0
    private var revision: UInt64 = 0
    private var admission: Admission = .bootstrapping
    private var ownership: Ownership?
    private var cached: RecoveryStatus = .checking
    private var activationEpoch: UInt64?
    private var inFlight = 0
    private var settlementWaiters: [CheckedContinuation<Void, Never>] = []
    private var recoveryBusy = false
    public init(journal: RecoveryJournal, power: RecoveryPower, clock: RecoveryClock, environment: ServiceEnvironment) {
        guards = BoundGuards(environment, clock: clock); self.clock = clock; self.power = power
        engine = RecoveryEngine(journal: journal, power: power, clock: clock, guards: guards)
    }
    private func next() -> UInt64 { precondition(serial < UInt64.max); serial += 1; return serial }
    private func changed() { precondition(revision < UInt64.max); revision += 1 }
    public func accept(_ authenticatedSession: ConsoleSession) -> ConnectionKey? {
        guard authenticatedSession.uid != 0, guards.environment.isCurrent(authenticatedSession) else { return nil }
        let key = ConnectionKey(generation: next()); connections[key] = authenticatedSession; return key
    }
    private func caller(_ key: ConnectionKey) -> ConsoleSession? {
        guard let session = connections[key], guards.environment.isCurrent(session) else { return nil }
        return session
    }
    public func start() async {
        guard case .bootstrapping = admission, !recoveryBusy else { return }
        recoveryBusy = true; defer { recoveryBusy = false }
        cached = await engine.status()
        if cached == .off { admission = .open; changed() }
    }
    public func handle(_ request: ServiceRequest, from key: ConnectionKey) async -> ServiceReply {
        guard request.valid else { return reply(.invalidRequest) }
        guard caller(key) != nil else { return reply(.rejected) }
        switch request.operation {
        case .status: return await status(key)
        case .activate: return await activate(key)
        case .heartbeat: return await leased(key, token: UUID(uuidString: request.token!)!, stop: false)
        case .deactivate: return await leased(key, token: UUID(uuidString: request.token!)!, stop: true)
        case .retryRestore: return await recover(key, preparing: false)
        case .prepareForUpdateOrRemoval: return await recover(key, preparing: true)
        }
    }
    private func visible() -> (ServiceState, String?) {
        if let owned = ownership {
            if owned.stage == .baseline || owned.stage == .activating { return (.activating, nil) }
            if owned.stage == .restoring {
                switch cached { case .recoveryRequired, .conflict: break; default: return (.stopping, nil) }
            }
        }
        switch cached {
        case .checking: return (.checking, nil)
        case .off: return (.off, nil)
        case .activating: return (.activating, nil)
        case .active: return (.active, nil)
        case .stopping: return (.stopping, nil)
        case .recoveryRequired(let reason): return (.recoveryRequired, reason)
        case .conflict(let reason): return (.conflict, reason)
        }
    }
    private func reply(_ outcome: ServiceOutcome = .observed, token: UUID? = nil, permit: PreparationPermit? = nil) -> ServiceReply {
        let (state, reason) = visible()
        let requiresRemoval: Bool
        switch admission { case .preparing, .sealed: requiresRemoval = true; default: requiresRemoval = false }
        return .init(state: state, outcome: outcome, reason: reason, activationToken: token, preparationPermit: permit, requiresRemoval: requiresRemoval)
    }
    private func clear(_ epoch: UInt64) {
        guard ownership?.epoch == epoch else { return }
        ownership = nil; guards.clear(epoch); changed()
    }
    private func publish(_ result: RecoveryStatus, revision expected: UInt64) {
        guard revision == expected else { return }
        cached = result
        if result == .off, !recoveryBusy, let owned = ownership, activationEpoch != owned.epoch { clear(owned.epoch) }
        if result != .off, case .sealed(let epoch, let key) = admission {
            admission = .preparing(epoch, key); changed()
        }
    }
    private func status(_ key: ConnectionKey) async -> ServiceReply {
        inFlight += 1; defer { completed() }
        let before = revision
        let result = await engine.status()
        publish(result, revision: before)
        guard before == revision, caller(key) != nil, result == .off, ownership == nil, !recoveryBusy,
              case .sealed(let epoch, let owner) = admission, owner == key else { return reply() }
        // Ordinary engine status permits an absent root property at a clean
        // unowned startup. Removal requires a fresh strict dual-false receipt.
        let verified: Bool
        do { verified = try await power.read().verifiedOff } catch { verified = false }
        guard before == revision, caller(key) != nil, ownership == nil, !recoveryBusy,
              case .sealed(let currentEpoch, let currentOwner) = admission,
              currentEpoch == epoch, currentOwner == key else { return reply() }
        guard verified else {
            cached = .recoveryRequired("Final removal readback is unknown. Prepare removal again.")
            admission = .preparing(epoch, key); changed()
            return reply()
        }
        return reply(permit: .init(incarnation: incarnation, epoch: epoch))
    }
    private func safe(_ session: ConsoleSession) -> Bool {
        let sample = guards.snapshot(for: session), now = clock.now
        return sample.console == session && sample.battery == .normal
            && (sample.thermal == .nominal || sample.thermal == .serious)
            && now.isFinite && sample.sampledAt.isFinite && sample.sampledAt <= now && now - sample.sampledAt <= 5
    }
    private func matches(_ epoch: UInt64, _ key: ConnectionKey, stage: Stage) -> Bool {
        ownership?.epoch == epoch && ownership?.key == key && ownership?.stage == stage
    }
    private func activate(_ key: ConnectionKey) async -> ServiceReply {
        guard case .open = admission, !recoveryBusy, ownership == nil, let session = caller(key) else { return reply(.rejected) }
        inFlight += 1; defer { completed() }
        let epoch = next()
        ownership = .init(epoch: epoch, key: key, session: session, stage: .baseline)
        activationEpoch = epoch; changed()
        defer {
            if ownership?.epoch == epoch, cached == .off { clear(epoch) }
            activationEpoch = nil
        }
        let baseline = await engine.status()
        guard matches(epoch, key, stage: .baseline), case .open = admission, caller(key) == session, baseline == .off else {
            if ownership?.epoch == epoch {
                ownership?.stage = .restoring; cached = baseline
                if baseline == .off { clear(epoch) }
            }
            return reply(.rejected)
        }
        cached = .activating; ownership?.stage = .activating
        guards.binding = (epoch, session); changed()
        let result = await engine.activate(session)
        guard matches(epoch, key, stage: .activating), case .open = admission,
              caller(key) == session, safe(session), case .active(let lease) = result, lease.owner == session else {
            if ownership?.epoch == epoch {
                ownership?.stage = .restoring; cached = result
                // Even if the caller disappeared after engine completion, never
                // publish a token. Latch and settle rather than cancelling work.
                cached = await engine.disconnected(session)
            }
            return reply(.rejected)
        }
        ownership?.stage = .active; ownership?.lease = lease; cached = result; changed()
        return reply(.activated, token: lease.token)
    }
    private func leased(_ key: ConnectionKey, token: UUID, stop: Bool) async -> ServiceReply {
        guard let owned = ownership, owned.key == key, owned.stage == .active,
              let lease = owned.lease, lease.token == token, caller(key) == owned.session else { return reply(.rejected) }
        inFlight += 1; defer { completed() }
        if stop { ownership?.stage = .restoring; changed() }
        let before = revision
        let result = stop ? await engine.deactivate(lease) : await engine.heartbeat(lease)
        publish(result, revision: before)
        return reply()
    }
    /// Both interruption and invalidation call this. Never cancel an engine Task.
    public func disconnected(_ key: ConnectionKey) async {
        inFlight += 1; defer { completed() }
        connections.removeValue(forKey: key)
        if case .sealed(let epoch, let owner) = admission, owner == key {
            admission = .preparing(epoch, owner); changed()
        }
        guard let owned = ownership, owned.key == key else { return }
        ownership?.stage = .restoring; changed()
        let before = revision
        let result = await engine.disconnected(owned.session)
        publish(result, revision: before)
    }
    public func monitor() async {
        inFlight += 1; defer { completed() }
        if let owned = ownership, !safe(owned.session), owned.stage != .restoring {
            ownership?.stage = .restoring; changed()
        }
        let before = revision
        let result = await engine.monitor()
        publish(result, revision: before)
    }
    private func completed() {
        inFlight -= 1
        if inFlight == 0 {
            let ready = settlementWaiters; settlementWaiters.removeAll(); ready.forEach { $0.resume() }
        }
    }
    private func settleOperations() async {
        while inFlight != 0 { await withCheckedContinuation { settlementWaiters.append($0) } }
    }
    private func recover(_ key: ConnectionKey, preparing: Bool) async -> ServiceReply {
        guard !recoveryBusy, let session = caller(key) else { return reply(.rejected) }
        recoveryBusy = true; defer { recoveryBusy = false }
        let epoch = next()
        if preparing { admission = .preparing(epoch, key); changed() }
        else if case .sealed(let prior, let owner) = admission {
            admission = .preparing(prior, owner); changed()
        }
        if let owned = ownership {
            ownership?.stage = .restoring; changed()
            _ = await engine.disconnected(owned.session)
            await settleOperations()
        }
        guard caller(key) == session else { return reply(.rejected) }
        // No older engine operation/writer remains. Token-loss recovery may now bind
        // the authenticated current caller without changing an in-flight target.
        if let old = ownership { guards.clear(old.epoch) }
        ownership = .init(epoch: epoch, key: key, session: session, stage: .restoring)
        guards.binding = (epoch, session); changed()
        if preparing {
            let success = await engine.prepareForUpdateOrRemoval(session)
            guard ownership?.epoch == epoch else { return reply(.rejected) }
            cached = await engine.status()
            guard ownership?.epoch == epoch, success, cached == .off, caller(key) == session else { return reply(.rejected) }
            clear(epoch); admission = .sealed(epoch, key); changed()
            return reply(.prepared, permit: .init(incarnation: incarnation, epoch: epoch))
        }
        let result = await engine.retryRestore(session)
        guard ownership?.epoch == epoch else { return reply(.rejected) }
        cached = result
        if result == .off {
            clear(epoch)
            if case .bootstrapping = admission { admission = .open; changed() }
        }
        return reply()
    }
}
