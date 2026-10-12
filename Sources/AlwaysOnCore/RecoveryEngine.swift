import Foundation

public struct ConsoleSession: Equatable, Sendable {
    public let uid: UInt32
    public let auditSession: UInt32
    public init(uid: UInt32, auditSession: UInt32) { self.uid = uid; self.auditSession = auditSession }
}

/// The generated UUID is also the journal generation identifier.
public struct RecoveryLease: Equatable, Sendable {
    public let token: UUID
    public let owner: ConsoleSession
    public init(token: UUID, owner: ConsoleSession) { self.token = token; self.owner = owner }
}

public enum RecoveryPhase: String, CaseIterable, Sendable { case intent, active, restoring, off }
public struct RecoveryRecord: Equatable, Sendable {
    public let lease: RecoveryLease
    public let phase: RecoveryPhase
    public init(lease: RecoveryLease, phase: RecoveryPhase) { self.lease = lease; self.phase = phase }
}
/// corrupt means malformed payload in a security-validated root-owned regular
/// file. Unsafe ownership, links, modes or file type must throw, never corrupt.
public enum JournalLoad { case missing, corrupt, record(RecoveryRecord) }

/// Native implementations must validate protected ownership/schema and atomically
/// replace + fsync the record/directory. Calls are synchronous (no actor reentry),
/// and may throw AFTER persistence. Clear is durable too. No caller paths.
/// Disk syscalls can stall: native integration must isolate this executor from
/// telemetry collection. A hung executor/kernel is outside the recovery guarantee.
@MainActor public protocol RecoveryJournal: AnyObject {
    func load() throws -> JournalLoad
    func save(_ record: RecoveryRecord) throws
    func clear() throws
}

/// nil means confirmed absence after a successful read. Type errors and read
/// failures must throw; they must never become nil or a default Boolean.
public struct PowerReceipt: Equatable, Sendable {
    public let preference: Bool?
    public let rootDomain: Bool?
    public init(preference: Bool?, rootDomain: Bool?) {
        self.preference = preference; self.rootDomain = rootDomain
    }
    public var verifiedOff: Bool { preference == false && rootDomain == false }
    public var verifiedOn: Bool { preference == true && rootDomain == true }
    // An absent root property is acceptable only before any owned write.
    public var initiallyOff: Bool { preference == false && rootDomain != true }
}

/// Every call has a fixed adapter-owned bound. A write may apply then throw.
/// On return/throw the writer MUST be quiescent: terminate/reap on timeout;
/// cancellation alone is insufficient. No delayed mutation may escape a call.
/// Both observations are read afresh after the fixed write command completes.
@MainActor public protocol RecoveryPower: AnyObject {
    func read() async throws -> PowerReceipt
    func setDisabled(_ disabled: Bool) async throws -> PowerReceipt
}
@MainActor public protocol RecoveryClock: AnyObject { var now: TimeInterval { get } }

public enum BatteryGuard: Sendable { case normal, finalWarning, unknown }
public enum ThermalGuard: Sendable { case nominal, serious, critical, unknown }
public struct RecoveryGuards: Sendable {
    public let console: ConsoleSession?
    public let battery: BatteryGuard
    public let thermal: ThermalGuard
    public let sampledAt: TimeInterval
    public init(console: ConsoleSession?, battery: BatteryGuard = .normal,
                thermal: ThermalGuard = .nominal, sampledAt: TimeInterval) {
        self.console = console; self.battery = battery; self.thermal = thermal; self.sampledAt = sampledAt
    }
}
/// Cached telemetry only; unknown/failure must not be normalized to safe values.
@MainActor public protocol RecoveryGuardSource: AnyObject { var snapshot: RecoveryGuards { get } }
public enum RecoveryStatus: Equatable, Sendable {
    case checking, off, activating, active(RecoveryLease), stopping, recoveryRequired(String), conflict(String)
}

/// Pure service logic. The authenticated native boundary supplies ConsoleSession;
/// it must never accept claimed identity from an IPC payload. The scheduler must
/// call monitor periodically and on guard notifications; no automatic activation.
@MainActor public final class RecoveryEngine {
    private let journal: RecoveryJournal
    private let power: RecoveryPower
    private let clock: RecoveryClock
    private let guards: RecoveryGuardSource
    public init(journal: RecoveryJournal, power: RecoveryPower, clock: RecoveryClock, guards: RecoveryGuardSource) {
        self.journal = journal; self.power = power; self.clock = clock; self.guards = guards
    }
    private var state: RecoveryStatus = .checking
    private var initialized = false
    private var corruptRecord = false
    private var owned: RecoveryRecord?
    private var pendingOwner: ConsoleSession?
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var stopRequested = false
    private var heartbeatDeadline: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private let guardLifetime: TimeInterval = 5
    private let heartbeatLifetime: TimeInterval = 30

    private func enter() async {
        while busy { await withCheckedContinuation { waiters.append($0) } }
        busy = true
    }
    private func leave() {
        busy = false
        let ready = waiters; waiters.removeAll()
        ready.forEach { $0.resume() }
    }
    private func isConsole(_ caller: ConsoleSession) -> Bool {
        caller.uid != 0 && guards.snapshot.console == caller
    }
    private func safe(_ caller: ConsoleSession, heartbeat: Bool = false) -> Bool {
        let now = clock.now, sample = guards.snapshot
        guard now.isFinite, now >= lastTime else { return false }
        lastTime = now
        return isConsole(caller) && sample.sampledAt.isFinite && sample.sampledAt <= now
            && now - sample.sampledAt <= guardLifetime
            && sample.battery == .normal
            && (sample.thermal == .nominal || sample.thermal == .serious)
            && (!heartbeat || now < heartbeatDeadline)
    }
    private func failure(_ reason: String) -> RecoveryStatus {
        state = .recoveryRequired(reason); return state
    }
    private func save(_ phase: RecoveryPhase) throws {
        guard let record = owned else { return }
        let next = RecoveryRecord(lease: record.lease, phase: phase)
        // Retain ownership even when a persistence failure might have applied.
        owned = next
        try journal.save(next)
    }
    /// Returns true only for a clean unowned start, never after recovery work.
    private func initialize() async -> Bool {
        if initialized { return owned == nil && state == .off }
        // Concurrent observers cannot reuse an old off result while ownership
        // is unresolved, including unowned rechecks after an earlier off read.
        state = .checking
        do {
            corruptRecord = false
            switch try journal.load() {
            case .record(let record):
                owned = record; initialized = true
                _ = await restore(); return false
            case .missing:
                let receipt = try await power.read()
                guard receipt.initiallyOff else {
                    state = .conflict("Unowned or unknown sleep override. Resolve its owner before activation.")
                    return false
                }
                initialized = true; state = .off; return true
            case .corrupt:
                corruptRecord = true
                let receipt = try await power.read()
                if receipt.verifiedOff {
                    _ = failure("Normal sleep verified; retry deactivation to clean invalid recovery record.")
                } else {
                    state = .conflict("Invalid ownership with an unverified override. Resolve its owner first.")
                }
                return false
            }
        } catch { _ = failure("Cannot establish recovery ownership. Retry deactivation."); return false }
    }
    private func restore() async -> RecoveryStatus {
        if owned?.phase == .off { return await clearOffRecord() }
        guard owned != nil else {
            initialized = false
            _ = await initialize()
            return state
        }
        state = .stopping
        var journalFailed = false
        do { try save(.restoring) } catch { journalFailed = true }
        do {
            // Do not cancel: even failed/timed-out writes must settle before retry.
            let result = try await power.setDisabled(false)
            guard result.verifiedOff else { return failure("Normal sleep is not confirmed. Retry deactivation.") }
            let confirmation = try await power.read()
            guard confirmation.verifiedOff else { return failure("Restoration readback is unknown. Retry deactivation.") }
            if journalFailed { return failure("Sleep restored; recovery record needs retry.") }
            try save(.off)
            try journal.clear()
            owned = nil; pendingOwner = nil; heartbeatDeadline = 0
            state = .off
        } catch { return failure("Restoration or durable cleanup failed. Retry deactivation.") }
        return state
    }
    private func latchStop() { stopRequested = true; if owned != nil || pendingOwner != nil { state = .stopping } }

    public func status() async -> RecoveryStatus {
        if busy { return state }
        await enter(); defer { leave() }
        if !initialized { _ = await initialize(); return state }
        return await inspect()
    }
    public func activate(_ caller: ConsoleSession) async -> RecoveryStatus {
        guard !busy else { return state }
        guard isConsole(caller) else { return state }
        await enter(); defer { pendingOwner = nil; leave() }
        stopRequested = false; pendingOwner = caller
        if !initialized {
            let clean = await initialize()
            if !clean { return state }
        }
        guard owned == nil, state == .off, !stopRequested, safe(caller) else { return state }
        state = .activating
        do {
            // Recheck external ownership immediately before the intent commit.
            let baseline = try await power.read()
            guard baseline.initiallyOff else {
                initialized = false
                state = .conflict("Another owner controls the sleep override."); return state
            }
            guard !stopRequested, safe(caller) else { state = .off; return state }
            owned = RecoveryRecord(lease: .init(token: UUID(), owner: caller), phase: .intent)
            try save(.intent)
            guard !stopRequested, safe(caller) else { return await restore() }
            let result = try await power.setDisabled(true)
            guard !stopRequested, safe(caller), result.verifiedOn else { return await restore() }
            let confirmation = try await power.read()
            guard !stopRequested, safe(caller), confirmation.verifiedOn else { return await restore() }
            try save(.active)
            // No suspension exists between durable active and this last guard/reply.
            guard !stopRequested, safe(caller), let record = owned else { return await restore() }
            heartbeatDeadline = clock.now + heartbeatLifetime
            state = .active(record.lease)
        } catch {
            if owned != nil { return await restore() }
            return failure("Activation preflight could not verify power state. Retry deactivation.")
        }
        return state
    }
    public func heartbeat(_ lease: RecoveryLease) async -> RecoveryStatus {
        guard owned?.lease == lease, case .active = state else { return state }
        // Metadata-only events can run during a power await. An expired lease
        // must not get an active reply just because inspection is in flight.
        guard safe(lease.owner, heartbeat: true) else {
            latchStop()
            if busy { return state }
            return await stop()
        }
        heartbeatDeadline = clock.now + heartbeatLifetime
        return state
    }
    public func deactivate(_ lease: RecoveryLease) async -> RecoveryStatus {
        guard owned?.lease == lease, isConsole(lease.owner) else { return state }
        return await stop()
    }
    /// Also cancels an activation before its token has been returned. The native
    /// boundary supplies authenticated current console identity, never a payload.
    public func retryRestore(_ caller: ConsoleSession) async -> RecoveryStatus {
        guard isConsole(caller) else { return state }
        return await stop()
    }
    private func stop() async -> RecoveryStatus {
        latchStop()
        await enter(); defer { leave() }
        if !initialized {
            _ = await initialize()
            if corruptRecord { return await clearCorruptIfOff() }
            return state
        }
        if owned != nil { return await restore() }
        // Fresh unowned observation; never take over an external override.
        initialized = false; _ = await initialize()
        return state
    }
    private func clearOffRecord() async -> RecoveryStatus {
        do {
            // Restoration already completed before phase off. Any new true
            // value may belong to another owner: cleanup must never write power.
            guard try await power.read().verifiedOff else {
                state = .conflict("Restored session no longer owns this override. Resolve its owner first.")
                return state
            }
            try journal.clear()
            owned = nil; pendingOwner = nil; heartbeatDeadline = 0; state = .off
            return state
        } catch { return failure("Off-record cleanup failed. Retry deactivation.") }
    }
    private func clearCorruptIfOff() async -> RecoveryStatus {
        do {
            guard try await power.read().verifiedOff else {
                state = .conflict("Cannot clean invalid ownership until normal sleep is verified.")
                return state
            }
            try journal.clear()
            corruptRecord = false; initialized = true; state = .off
            return state
        } catch { return failure("Invalid recovery record cleanup failed. Retry deactivation.") }
    }
    public func prepareForUpdateOrRemoval(_ caller: ConsoleSession) async -> Bool {
        guard isConsole(caller) else { return false }
        let result = await stop()
        // Only strict post-write evidence is sufficient for removal. There is no
        // atomic promise across unregister: B2 must close activation admission
        // across prepare/unregister, and B3 must recheck before unregistering.
        guard result == .off else { return false }
        await enter(); defer { leave() }
        guard owned == nil, state == .off else { return false }
        do {
            guard try await power.read().verifiedOff else {
                initialized = false
                state = .conflict("Removal cannot confirm normal sleep."); return false
            }
            return true
        } catch { _ = failure("Removal readback failed. Retry deactivation."); return false }
    }
    public func monitor() async -> RecoveryStatus {
        if let caller = owned?.lease.owner ?? pendingOwner {
            let hasLease: Bool
            if case .active = state { hasLease = true } else { hasLease = false }
            if !safe(caller, heartbeat: hasLease) { latchStop() }
        }
        if busy { return state }
        await enter(); defer { leave() }
        if !initialized { _ = await initialize(); return state }
        return await inspect()
    }
    private func inspect() async -> RecoveryStatus {
        guard let record = owned else {
            initialized = false; _ = await initialize(); return state
        }
        if record.phase == .off { return await clearOffRecord() }
        if stopRequested || !safe(record.lease.owner, heartbeat: true) { return await restore() }
        do {
            let result = try await power.read()
            // Recheck guards AND stop latch after the suspension, including a
            // disconnect that arrives while status is awaiting its readback.
            if stopRequested || !safe(record.lease.owner, heartbeat: true) || !result.verifiedOn {
                return await restore()
            }
        } catch { return await restore() }
        return state
    }
    public func disconnected(_ caller: ConsoleSession) async -> RecoveryStatus {
        guard (owned?.lease.owner ?? pendingOwner) == caller else { return state }
        latchStop()
        if busy { return state }
        return await stop()
    }
}
