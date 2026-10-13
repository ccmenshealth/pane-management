import Foundation
import AlwaysOnCore
import AlwaysOnService
import AlwaysOnDaemon

@main struct Checks {
    @MainActor static func main() async {
        var count = 0, failures = 0
        func check(_ ok: Bool, _ label: String) { count += 1; if !ok { failures += 1; print("FAIL: \(label)") } }
        func rejects(_ block: () throws -> Void) -> Bool { do { try block(); return false } catch { return true } }
        let owner = ConsoleSession(uid: 501, auditSession: 7)
        let goodFlags: UInt64 = 0x6010
        check(BoundaryPolicy.auditValid(session: owner, before: 501, after: 501, returned: 7, auid: 501, flags: goodFlags), "valid console policy")
        for field in 0..<10 {
            check(!BoundaryPolicy.auditValid(session: field == 0 ? .init(uid: 0, auditSession: 7) : (field == 1 ? .init(uid: 501, auditSession: 0) : owner), before: field == 2 ? nil : 501, after: field == 3 ? 502 : 501, returned: field == 4 ? 8 : 7, auid: field == 5 ? 502 : 501, flags: field == 6 ? goodFlags | 0x1000 : field == 7 ? goodFlags & ~0x10 : field == 8 ? goodFlags & ~0x2000 : field == 9 ? goodFlags & ~0x4000 : goodFlags), "audit rejects defect \(field)")
        }
        let pin = String(repeating: "0123456789ABCDEF", count: 2) + "01234567"
        let appRequirement = "identifier \"local.snapbridge.app\""
        let daemonRequirement = "identifier \"local.snapbridge.alwayson.service\""
        let expected = appRequirement + " and certificate leaf = H\"\(pin)\""
        check((try? BoundaryPolicy.requirement(role: .app, leafFingerprint: pin)) == expected, "exact certificate peer requirement")
        check((try? BoundaryPolicy.requirement(role: .daemon)) == daemonRequirement, "fixed self identifier before certificate extraction")
        check((try? BoundaryPolicy.requirement(role: .app, leafFingerprint: pin.lowercased())) == expected, "canonical lowercase certificate pin")
        for invalid in ["", "ABCDE12345", String(repeating: "A", count: 39), String(repeating: "A", count: 41), String(repeating: "G", count: 40), String(repeating: "A", count: 39) + "\n", "\" or true or \"", String(repeating: "é", count: 20)] {
            check(rejects { _ = try BoundaryPolicy.requirement(role: .app, leafFingerprint: invalid) }, "reject unsafe certificate fingerprint")
            let signing = FakeSigning(); signing.fingerprint = invalid
            check(rejects { _ = try TrustedIdentity.peerRequirement(own: .app, authority: signing) }, "bad extracted fingerprint fails closed")
            check(signing.events == ["validate:" + appRequirement, "certificate"], "bad fingerprint never revalidates or produces peer")
        }
        for op in ServiceOperation.allCases {
            let token = (op == .heartbeat || op == .deactivate) ? UUID().uuidString : nil
            let value = ServiceRequest(operation: op, token: token)
            let data = try! JSONEncoder.canonical.encode(value)
            let decoded = try? BoundaryPolicy.decode(data)
            check(decoded?.operation == op && decoded?.token == token, "wire \(op)")
            check((try? BoundaryPolicy.encode(value)) == data, "encode \(op)")
        }
        for bad in ["{}", "{\"version\":2,\"operation\":\"status\"}", "{\"version\":1,\"operation\":\"status\",\"path\":\"/tmp\"}", "{\"version\":1,\"operation\":\"activate\",\"operation\":\"status\"}", "{\"version\":1,\"operation\":\"heartbeat\"}", String(repeating: " ", count: 1025)] {
            check(rejects { _ = try BoundaryPolicy.decode(Data(bad.utf8)) }, "invalid wire")
        }
        var constructed = false, signed = false
        check(rejects { try BoundaryPolicy.preflight(uid: 501, signature: { signed = true; return "trusted" }, construct: { _ in constructed = true }) }, "nonroot rejected")
        check(!constructed && !signed, "root precedes signing/storage")
        constructed = false
        check(rejects { try BoundaryPolicy.preflight(uid: 0, signature: { throw BoundaryError.signing }, construct: { _ in constructed = true }) }, "bad signature rejected")
        check(!constructed, "no storage after signing failure")
        for role: PeerRole in [.app, .daemon] {
            let own = role == .app ? appRequirement : daemonRequirement
            let peer = role == .app ? daemonRequirement : appRequirement
            let signing = FakeSigning()
            check((try? TrustedIdentity.peerRequirement(own: role, authority: signing)) == peer + " and certificate leaf = H\"\(pin)\"", "local certificate without Team ID produces exact reciprocal peer")
            check(signing.events == ["validate:" + own, "certificate", "validate:" + own + " and certificate leaf = H\"\(pin)\""], "validated self precedes extraction and pinned self revalidation")
            for failure in [1, 2] {
                let failed = FakeSigning(); failed.failValidationNumber = failure
                check(rejects { _ = try TrustedIdentity.peerRequirement(own: role, authority: failed) }, "self validation failure rejects peer")
                check(failed.events == (failure == 1 ? ["validate:" + own] : ["validate:" + own, "certificate", "validate:" + own + " and certificate leaf = H\"\(pin)\""]), "self failure has no subsequent metadata or peer")
            }
            let missing = FakeSigning(); missing.failCertificate = true
            check(rejects { _ = try TrustedIdentity.peerRequirement(own: role, authority: missing) }, "missing or ad-hoc leaf certificate rejected")
            check(missing.events == ["validate:" + own, "certificate"], "missing certificate never revalidates or produces peer")
        }
        check(rejects { _ = try TrustedIdentity.peerRequirement(own: .daemon) }, "actual unsigned/adhoc check executable rejected")
        let internalBattery: [[String: Any]] = [["Type": "InternalBattery", "Is Present": true]]
        check(TelemetryPolicy.battery(descriptions: internalBattery, warning: 1) == .normal, "OS none normal")
        check(TelemetryPolicy.battery(descriptions: internalBattery, warning: 2) == .normal, "OS early not arbitrary cutoff")
        check(TelemetryPolicy.battery(descriptions: internalBattery, warning: 3) == .finalWarning, "OS final stops")
        for invalid: [[String: Any]]? in [nil, [], [["Type": "UPS", "Is Present": true]], [["Is Present": true]], [["Type": "InternalBattery"]], [["Type": "InternalBattery", "Is Present": false]], [["Type": "InternalBattery", "Is Present": 1]]] {
            check(TelemetryPolicy.battery(descriptions: invalid, warning: 1) == .unknown, "battery enumeration/type failure unknown")
        }
        check(TelemetryPolicy.battery(descriptions: internalBattery, warning: 0) == .unknown, "unknown warning rejected")
        check(TelemetryPolicy.thermal(.serious) == .serious, "serious permits guarded work")
        check(TelemetryPolicy.thermal(.critical) == .critical, "critical stops")
        check(TelemetryPolicy.thermal(.fair) == .nominal, "fair permits work")
        let cache = TelemetryCache(), time = TestTime()
        let environment = CachedEnvironment(cache: cache, now: { time.now })
        cache.setSession(owner, valid: true, at: 100); cache.setBattery(.normal, at: 100); cache.setThermal(.nominal, at: 100)
        check(!environment.isCurrent(owner) && environment.samples(for: owner).battery == .unknown, "unregistered notifications fail closed")
        cache.setNotificationsHealthy(true)
        check(environment.isCurrent(owner), "fresh validated session")
        time.now = 106; check(!environment.isCurrent(owner), "stale session")
        time.now = 99; check(!environment.isCurrent(owner), "future session timestamp")
        time.now = .nan; check(!environment.isCurrent(owner), "unknown clock")
        time.now = 100; cache.setNotificationHealth(battery: false, thermal: true, session: true)
        check(environment.isCurrent(owner) && environment.samples(for: owner).battery == .unknown, "battery registration failure still permits authenticated recovery")
        cache.setNotificationsHealthy(true); cache.removeSession(owner)
        check(!environment.isCurrent(owner), "removed session unknown")
        do {
            let rig = Rig(); await rig.service.start(); rig.cache.removeSession(owner)
            let channel = ManagedConnection(service: rig.service, session: owner)
            let before = await channel.handle(wire(.status))
            check(before.state == .checking && before.outcome == .rejected, "first request waits for collected session")
            rig.cache.setSession(owner, valid: true, at: 100)
            let after = await channel.handle(wire(.status))
            check(after.state == .off && after.outcome == .observed, "same connection retries after fresh collection")
        }
        do {
            let rig = Rig(); await rig.service.start(); rig.power.pause = "enable"
            let channel = ManagedConnection(service: rig.service, session: owner)
            let bridge = DaemonRequestBridge(channel)
            let first = Task { await withCheckedContinuation { continuation in bridge.request(wire(.activate)) { continuation.resume(returning: $0) } } }
            for _ in 0..<1000 { if rig.power.waiting != nil { break }; await Task.yield() }
            check(rig.power.waiting != nil, "production ingress reaches awaited enable")
            let duplicate: Data = await withCheckedContinuation { continuation in bridge.request(wire(.status)) { continuation.resume(returning: $0) } }
            check((try? JSONDecoder().decode(ServiceReply.self, from: duplicate).outcome) == .rejected, "production ingress bounds concurrent messages")
            rig.cache.setThermal(.critical, at: 100)
            let monitor = Task { await rig.service.monitor() }
            _ = channel.fence.close(); let loss = Task { await channel.lost() }
            for _ in 0..<20 { await Task.yield() }
            rig.power.release()
            let final = try? JSONDecoder().decode(ServiceReply.self, from: await first.value)
            await monitor.value; await loss.value
            check(final?.activationToken == nil && !rig.power.value, "ingress slot does not block critical/loss latch")
            let closed: Data = await withCheckedContinuation { continuation in bridge.request(wire(.activate)) { continuation.resume(returning: $0) } }
            check((try? JSONDecoder().decode(ServiceReply.self, from: closed).outcome) == .rejected, "closed ingress denies new messages")
        }
        let gate = ConnectionFence()
        check(gate.begin() && !gate.begin(), "bounded request slot")
        gate.finish(); check(gate.begin(), "slot reusable after completion")
        check(gate.close() && !gate.close(), "loss idempotent")
        gate.finish(); check(!gate.begin() && gate.whileOpen({ true }) == nil, "closed never readmits")
        let oversized = ServiceReply(state: .recoveryRequired, reason: String(repeating: "x", count: 2049))
        check(rejects { _ = try BoundaryPolicy.encode(oversized) }, "reply size bounded")
        for op in ServiceOperation.allCases {
            let rig = Rig(); await rig.service.start()
            let channel = ManagedConnection(service: rig.service, session: owner)
            _ = channel.fence.close()
            let token = (op == .heartbeat || op == .deactivate) ? UUID().uuidString : nil
            let response = await channel.handle(try! BoundaryPolicy.encode(.init(operation: op, token: token)))
            check(response.outcome == .rejected && response.activationToken == nil && rig.power.writes.isEmpty, "loss before admission \(op)")
        }
        do {
            let rig = Rig(); await rig.service.start()
            let first = ManagedConnection(service: rig.service, session: owner)
            let status = await first.handle(wire(.status))
            check(status.state == .off && status.activationToken == nil, "status does not arm")
            let active = await first.handle(wire(.activate))
            check(active.outcome == .activated && active.activationToken != nil && rig.power.value, "bridge admitted activation")
            let duplicate = await first.handle(wire(.activate))
            check(duplicate.activationToken == nil, "duplicate cannot obtain token")
            let reconnect = ManagedConnection(service: rig.service, session: owner)
            let stolen = await reconnect.handle(wire(.deactivate, active.activationToken))
            check(stolen.outcome == .rejected && rig.power.value, "same session different connection cannot inherit")
            _ = first.fence.close(); await first.lost(); await first.lost()
            check(!rig.power.value && rig.power.writes == [true, false], "both loss callbacks restore once")
            let next = await reconnect.handle(wire(.activate))
            check(next.activationToken != nil, "new activation after verified restoration")
            await first.lost(); check(rig.power.value, "late old loss cannot stop new owner")
            _ = await reconnect.handle(wire(.deactivate, next.activationToken))
            check(!rig.power.value, "native port deactivation verifies off")
        }
        for suspension in ["baseline", "enable"] {
            let rig = Rig(); await rig.service.start()
            let channel = ManagedConnection(service: rig.service, session: owner)
            rig.power.pause = suspension
            let task = Task { await channel.handle(wire(.activate)) }
            for _ in 0..<1000 { if rig.power.waiting != nil { break }; await Task.yield() }
            check(rig.power.waiting != nil, "fixture suspended \(suspension)")
            _ = channel.fence.close()
            let loss = Task { await channel.lost() }
            for _ in 0..<20 { await Task.yield() }
            rig.power.release()
            let result = await task.value; await loss.value
            check(result.activationToken == nil && result.outcome == .rejected && !rig.power.value, "loss through \(suspension) cannot publish token")
        }
        do {
            let rig = Rig(); await rig.service.start()
            let channel = ManagedConnection(service: rig.service, session: owner)
            _ = await channel.handle(wire(.activate))
            rig.cache.setBattery(.finalWarning, at: 100)
            await rig.service.monitor()
            check(!rig.power.value, "native cache final warning restores")
            rig.cache.setBattery(.normal, at: 100); _ = await channel.handle(wire(.activate))
            rig.cache.setThermal(.critical, at: 100); await rig.service.monitor()
            check(!rig.power.value, "native cache critical thermal restores")
            rig.cache.setThermal(.serious, at: 100)
            check((await channel.handle(wire(.activate))).activationToken != nil, "serious does not cutoff")
            rig.clock.now = 106; await rig.service.monitor()
            check(!rig.power.value, "stale collection restores")
        }
        for stalledSource in ["battery", "thermal"] {
            let stats = PumpStats(), held = DispatchSemaphore(value: 0)
            let telemetry = NativeTelemetry(fixtureBattery: { stats.collected(); if stalledSource == "battery" { held.wait() }; return .normal }, fixtureThermal: { if stalledSource == "thermal" { held.wait() }; return .nominal }, fixtureSession: { _ in true }, fixtureNow: { 100 }, fixtureMonitor: { stats.monitored() })
            telemetry.cache.setNotificationsHealthy(true)
            let registration = telemetry.track(owner)!
            telemetry.tick()
            for _ in 0..<100 { if stats.reads > 0 && stats.monitors > 0 { break }; try? await Task.sleep(nanoseconds: 1_000_000) }
            // A stalled power reader must not take away authenticated recovery.
            for _ in 0..<100 { if telemetry.cache.sample(owner).sessionValid { break }; try? await Task.sleep(nanoseconds: 1_000_000) }
            check(telemetry.cache.sample(owner).sessionValid, "session collection independent of stalled \(stalledSource)")
            let stalledEnvironment = CachedEnvironment(cache: telemetry.cache, now: { 100 })
            let stalledPower = Power(), stalledJournal = Journal(), stalledClock = Clock()
            let stalledService = ServiceCoordinator(journal: stalledJournal, power: stalledPower, clock: stalledClock, environment: stalledEnvironment)
            await stalledService.start()
            let stalledChannel = ManagedConnection(service: stalledService, session: owner)
            let observed = await stalledChannel.handle(wire(.status))
            check(observed.state == .off && observed.outcome == .observed, "stalled \(stalledSource) leaves authenticated status available")
            let recovered = await stalledChannel.handle(wire(.retryRestore))
            check(recovered.state == .off && recovered.outcome == .observed, "stalled \(stalledSource) leaves authenticated recovery available")
            let refused = await stalledChannel.handle(wire(.activate))
            check(refused.activationToken == nil && stalledPower.writes.isEmpty, "stalled battery still forbids activation")
            check(stats.reads == 1 && stats.monitors > 0, "watchdog independent of blocked collector")
            for _ in 0..<50 { telemetry.tick() }
            try? await Task.sleep(nanoseconds: 10_000_000)
            check(stats.reads == 1, "blocked collector does not queue jobs")
            telemetry.untrack(registration); held.signal()
            try? await Task.sleep(nanoseconds: 20_000_000)
            check(!telemetry.cache.sample(owner).sessionValid, "untracked session not resurrected")
            check(stats.reads == 1, "no latent collection jobs after unblock")
            var registrations: [UUID] = []
            for _ in 0..<64 { if let id = telemetry.track(owner) { registrations.append(id) } }
            check(registrations.count == 64 && telemetry.track(owner) == nil, "connection collection bound")
            registrations.forEach { telemetry.untrack($0) }
        }
        print("Read-only native battery probe: \(TelemetryPolicy.battery()) (OS None/Nominal internal-error ambiguity remains)")
        print("AlwaysOnDaemonChecks: \(count) assertions, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
private extension JSONEncoder { static var canonical: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder } }

private final class FakeSigning: SigningAuthority {
    var events: [String] = [], failValidationNumber: Int?, failCertificate = false
    var fingerprint = String(repeating: "0123456789ABCDEF", count: 2) + "01234567"
    private var validations = 0
    func validate(_ requirement: String) throws {
        events.append("validate:" + requirement); validations += 1
        if failValidationNumber == validations { throw BoundaryError.signing }
    }
    func leafCertificateFingerprint() throws -> String {
        events.append("certificate")
        if failCertificate { throw BoundaryError.signing }
        return fingerprint
    }
}
private final class TestTime { var now = 100.0 }
@MainActor private final class Clock: RecoveryClock { var now = 100.0 }
@MainActor private final class Journal: RecoveryJournal {
    var record: JournalLoad = .missing
    func load() throws -> JournalLoad { record }
    func save(_ next: RecoveryRecord) throws { record = .record(next) }
    func clear() throws { record = .missing }
}
@MainActor private final class Power: RecoveryPower {
    var value = false, writes: [Bool] = [], pause: String?
    var waiting: CheckedContinuation<Void, Never>?
    func suspend(_ point: String) async { if pause == point { await withCheckedContinuation { waiting = $0 } } }
    func release() { pause = nil; let held = waiting; waiting = nil; held?.resume() }
    func read() async throws -> PowerReceipt { await suspend("baseline"); return .init(preference: value, rootDomain: value) }
    func setDisabled(_ disabled: Bool) async throws -> PowerReceipt { writes.append(disabled); await suspend(disabled ? "enable" : "disable"); value = disabled; return .init(preference: value, rootDomain: value) }
}
@MainActor private final class Rig {
    let cache = TelemetryCache(), clock = Clock(), journal = Journal(), power = Power()
    lazy var environment = CachedEnvironment(cache: cache, now: { self.clock.now })
    lazy var service = ServiceCoordinator(journal: journal, power: power, clock: clock, environment: environment)
    init() {
        cache.setNotificationsHealthy(true); cache.setBattery(.normal, at: 100); cache.setThermal(.nominal, at: 100)
        cache.setSession(.init(uid: 501, auditSession: 7), valid: true, at: 100)
    }
}
private func wire(_ operation: ServiceOperation, _ token: UUID? = nil) -> Data {
    let required = operation == .heartbeat || operation == .deactivate
    return try! BoundaryPolicy.encode(ServiceRequest(operation: operation, token: required ? (token ?? UUID()).uuidString : nil))
}
private final class PumpStats: @unchecked Sendable {
    private let lock = NSLock(); private var count = 0, ticks = 0
    var reads: Int { lock.lock(); defer { lock.unlock() }; return count }
    var monitors: Int { lock.lock(); defer { lock.unlock() }; return ticks }
    func collected() { lock.lock(); count += 1; lock.unlock() }
    func monitored() { lock.lock(); ticks += 1; lock.unlock() }
}
