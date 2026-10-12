import Foundation
import Darwin
import AlwaysOnCore
import AlwaysOnClient
import AlwaysOnReadOnly
import AlwaysOnSetup

private enum Failure: Error { case fixture }
@MainActor private final class Service: SetupService {
    var values: [SetupServiceStatus] = [.notRegistered]
    var reads = 0, registrations = 0, removals = 0, opens = 0, validations = 0
    var failRead = false, signed = true, registerFails = false
    var registerGate: CheckedContinuation<Void, Never>?
    var holdRegister = false, holdUnregister = false, unregisterFails = false
    var unregisterCompletion: (@MainActor (Result<Void, Error>) -> Void)?
    var onRead: (() -> Void)?
    var holdReadNumber: Int?
    var readGate: CheckedContinuation<Void, Never>?
    func status() async throws -> SetupServiceStatus {
        reads += 1; onRead?()
        if reads == holdReadNumber { await withCheckedContinuation { readGate = $0 } }
        if failRead { throw Failure.fixture }
        return values.count > 1 ? values.removeFirst() : values[0]
    }
    func validateIdentity() throws { validations += 1; if !signed { throw Failure.fixture } }
    func register() async throws {
        registrations += 1
        if holdRegister { await withCheckedContinuation { registerGate = $0 } }
        if registerFails { throw Failure.fixture }
        values = [.enabled]
    }
    func unregister(_ completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        removals += 1
        if holdUnregister { unregisterCompletion = completion; return }
        completion(unregisterFails ? .failure(Failure.fixture) : .success(()))
    }
    func openLoginItems() { opens += 1 }
}
@MainActor private final class Proof: SetupProof {
    var receipt = PowerReceipt(preference: false, rootDomain: false)
    var absent = true, failPower = false, failAbsence = false, holdPower = false
    var powers = 0, absences = 0
    var gate: CheckedContinuation<Void, Never>?
    func power() async throws -> PowerReceipt {
        powers += 1
        if holdPower { await withCheckedContinuation { gate = $0 } }
        if failPower { throw Failure.fixture }; return receipt
    }
    func directoryAbsent() async throws -> Bool { absences += 1; if failAbsence { throw Failure.fixture }; return absent }
}
@MainActor private final class Client: SetupClient {
    var state: ClientState = .off
    var removalPending = false
    var onChange: (() -> Void)?
    var statuses = 0, activations = 0, stops = 0, removes = 0
    var removeOK = true, holdRemove = false, holdActivate = false
    var removalGate: CheckedContinuation<Void, Never>?, activationGate: CheckedContinuation<Void, Never>?
    func event(_ state: ClientState) { self.state = state; onChange?() }
    func status() async { statuses += 1; onChange?() }
    func activate() async {
        activations += 1; let earlierStops = stops
        if holdActivate { await withCheckedContinuation { activationGate = $0 } }
        event(earlierStops == stops ? .active : .off)
    }
    func deactivate() async { stops += 1; event(.off) }
    func remove(unregister: (@escaping @MainActor (Result<Void, Error>) -> Void) -> Void) async -> Bool {
        removes += 1
        if holdRemove { await withCheckedContinuation { removalGate = $0 } }
        guard removeOK else { return false }
        removalPending = true; event(.unknown("Removing"))
        let ok = await withCheckedContinuation { continuation in
            unregister { result in continuation.resume(returning: (try? result.get()) != nil) }
        }
        removalPending = false; event(ok ? .off : .unknown("Failed")); return ok
    }
}
@MainActor private struct Harness {
    let service = Service(), client = Client(), proof = Proof()
    let setup: SetupCoordinator
    init() { setup = SetupCoordinator(service: service, client: client, proof: proof) }
}
@main struct Checks {
    @MainActor static var count = 0, failures = 0
    @MainActor static func check(_ value: Bool, _ label: String) { count += 1; if !value { failures += 1; print("FAIL: \(label)") } }
    @MainActor static func rejects(_ label: String, _ action: () throws -> Void) { do { try action(); check(false, label) } catch { check(true, label) } }
    @MainActor static func rejectsAsync(_ label: String, _ action: () async throws -> Void) async { do { try await action(); check(false, label) } catch { check(true, label) } }
    @MainActor static func spin(_ condition: () -> Bool) async { for _ in 0..<10000 { if condition() { check(true, "fixture reached suspension"); return }; await Task.yield() }; check(false, "fixture reached suspension") }
    @MainActor static func main() async {
        await presentation()
        let fresh = Harness()
        check(fresh.service.reads == 0 && fresh.service.registrations == 0, "constructor is inert")
        await fresh.setup.startup()
        check(fresh.setup.observation.quitSafe && fresh.setup.observation.remedy == .setUp, "fresh triple proof quiet setup")
        check(fresh.service.reads == 2 && fresh.proof.powers == 1 && fresh.proof.absences == 1, "ordered bracket reads")
        check(fresh.service.registrations == 0 && fresh.client.activations == 0 && fresh.service.opens == 0, "startup no mutation/navigation")
        await fresh.setup.refresh()
        check(fresh.service.reads == 4 && fresh.proof.powers == 2, "refresh never caches proof")
        fresh.setup.openLoginItems(); await fresh.setup.activate()
        check(fresh.service.opens == 0 && fresh.client.activations == 0, "fresh state cannot activate or open approval")
        for a: Bool? in [false, true, nil] { for b: Bool? in [false, true, nil] {
            let h = Harness(); h.proof.receipt = .init(preference: a, rootDomain: b); await h.setup.startup()
            check(h.setup.observation.quitSafe == (a == false && b == false), "strict receipt \(String(describing:a))/\(String(describing:b))")
        } }
        for fault in 0..<5 {
            let h = Harness()
            switch fault { case 0: h.service.failRead = true; case 1: h.proof.failPower = true; case 2: h.proof.failAbsence = true; case 3: h.proof.absent = false; default: h.service.values = [.notRegistered, .enabled] }
            await h.setup.startup()
            check(!h.setup.observation.quitSafe && h.setup.observation.remedy == .retryDeactivationAndRepair, "uncertain proof \(fault)")
            check(h.service.registrations == 0, "uncertain proof cannot register \(fault)")
        }
        for status in [SetupServiceStatus.enabled, .requiresApproval, .notFound] {
            let h = Harness(); h.service.values = [status]; await h.setup.startup()
            check(h.proof.powers == 0 && h.service.registrations == 0, "configured startup avoids optional proof \(status)")
            switch status {
            case .enabled: check(h.client.statuses == 1 && h.setup.observation.state == .off, "enabled connects")
            case .requiresApproval:
                check(h.setup.observation.remedy == .openLoginItems && !h.setup.observation.quitSafe, "approval visible")
                h.setup.openLoginItems(); check(h.service.opens == 1, "explicit navigation only")
            default: check(h.setup.observation.remedy == .checkAgain && !h.setup.observation.quitSafe, "missing bundle repair")
            }
            await h.setup.setup(); check(h.service.registrations == 0, "no duplicate/repair registration \(status)")
        }
        for signed in [false, true] { for fail in [false, true] {
            let h = Harness(); h.service.signed = signed; h.service.registerFails = fail
            await h.setup.setup()
            check(h.service.registrations == (signed ? 1 : 0), "signature before register \(signed)/\(fail)")
            check(h.client.activations == 0 && h.service.reads >= 2, "setup rechecks and never activates")
            check(h.setup.observation.quitSafe, "completed safe setup result")
            if !signed { check(h.setup.observation.remedy == .checkAgain, "signature failure offers signed repair and recheck") }
        } }
        let signedUnsafe = Harness(); signedUnsafe.service.signed = false; signedUnsafe.proof.absent = false
        await signedUnsafe.setup.setup()
        check(!signedUnsafe.setup.observation.quitSafe && signedUnsafe.setup.observation.remedy == .retryDeactivationAndRepair, "unsigned uncertain repair stays visible")
        let signatureRace = Harness(); signatureRace.service.signed = false
        signatureRace.service.values = [.notRegistered, .enabled]; signatureRace.client.state = .active
        await signatureRace.setup.setup()
        check(signatureRace.setup.observation.state == .active && signatureRace.setup.observation.remedy == .deactivate, "old signing failure cannot erase newer active observation")
        let stale = Harness(); stale.proof.holdPower = true
        let probe = Task { await stale.setup.refresh() }
        await spin { stale.proof.gate != nil }
        stale.client.event(.unknown("new loss")); let revision = stale.setup.observation.revision
        stale.proof.gate?.resume(); await probe.value
        check(stale.setup.observation.state == .unknown("new loss") && stale.setup.observation.revision == revision, "new client event defeats old proof")
        let wake = Harness(); await wake.setup.startup(); wake.proof.holdPower = true
        let wakeTask = Task { await wake.setup.refresh() }; await spin { wake.proof.gate != nil }
        check(!wake.setup.observation.quitSafe, "wake revalidation never exposes old quiet proof")
        wake.proof.gate?.resume(); await wakeTask.value
        check(wake.setup.observation.quitSafe, "fresh completed wake proof permits quiet state")
        let activeRefresh = Harness(); activeRefresh.service.values = [.enabled]; activeRefresh.client.state = .active
        await activeRefresh.setup.startup(); activeRefresh.service.holdReadNumber = 2
        let activeRefreshTask = Task { await activeRefresh.setup.refresh() }; await spin { activeRefresh.service.readGate != nil }
        check(activeRefresh.setup.observation.state == .active && activeRefresh.setup.observation.remedy == .deactivate, "active warning and stop survive refresh")
        await activeRefresh.setup.deactivate(); check(activeRefresh.client.stops == 1, "refresh permits stop")
        activeRefresh.service.readGate?.resume(); await activeRefreshTask.value
        check(activeRefresh.setup.observation.state == .off, "old refresh cannot erase completed stop")
        let reg = Harness(); reg.service.holdRegister = true
        let setup = Task { await reg.setup.setup() }; await spin { reg.service.registerGate != nil }
        check(reg.setup.observation.lifecyclePending && !reg.setup.observation.quitSafe, "pending register retains lane")
        await reg.setup.setup(); await reg.setup.activate(); await reg.setup.deactivate(); let removed = await reg.setup.remove(); await reg.setup.refresh(); reg.setup.openLoginItems()
        check(!removed && reg.service.registrations == 1 && reg.client.activations == 0 && reg.client.stops == 0 && reg.client.removes == 0, "pending register excludes all mutations")
        reg.service.registerGate?.resume(); await setup.value
        check(!reg.setup.observation.lifecyclePending && reg.setup.observation.state == .off, "actual registration settlement")
        await reg.setup.activate(); check(reg.setup.observation.state == .active && reg.setup.observation.remedy == .deactivate, "only off activates")
        await reg.setup.deactivate(); check(reg.setup.observation.state == .off, "deactivation exit")
        let removal = Harness(); removal.client.holdRemove = true
        let removeTask = Task { await removal.setup.remove() }; await spin { removal.client.removalGate != nil }
        await removal.setup.setup(); await removal.setup.activate(); await removal.setup.deactivate(); let duplicate = await removal.setup.remove()
        check(!duplicate && removal.service.registrations == 0 && removal.client.stops == 0 && removal.client.removes == 1 && removal.setup.observation.lifecyclePending, "preparation excludes all lifecycle competition")
        removal.client.removalGate?.resume(); check(await removeTask.value, "sole removal succeeds")
        check(removal.setup.observation.quitSafe && removal.setup.observation.remedy == .setUp, "same-process verified removal quiet")
        removal.proof.absent = false; await removal.setup.refresh()
        check(!removal.setup.observation.quitSafe, "retained root directory makes next refresh conservative")
        let failed = Harness(); failed.client.removeOK = false
        check(!(await failed.setup.remove()), "removal failure")
        check(failed.setup.observation.remedy == .retryRemoval && !failed.setup.observation.quitSafe, "removal retry exit")
        failed.client.removeOK = true; check(await failed.setup.remove(), "fresh removal retry")
        for final in [SetupServiceStatus.enabled, .requiresApproval, .notFound] {
            let h = Harness(); h.service.values = [.notRegistered, final]; await h.setup.refresh()
            check(!h.setup.observation.quitSafe, "changed bracket status rejects \(final)")
        }
        let finalError = Harness()
        finalError.service.onRead = { if finalError.service.reads == 2 { finalError.service.failRead = true } }
        await finalError.setup.refresh(); check(!finalError.setup.observation.quitSafe, "second status error rejects proof")
        let settlement = Harness(); settlement.service.holdReadNumber = 2
        let settlementTask = Task { await settlement.setup.setup() }; await spin { settlement.service.readGate != nil }
        await settlement.setup.setup(); let settlementRemoval = await settlement.setup.remove()
        check(!settlementRemoval && settlement.client.removes == 0 && settlement.service.reads == 2, "registration keeps lifecycle through status settlement")
        settlement.service.readGate?.resume(); await settlementTask.value
        check(settlement.setup.observation.state == .off && !settlement.setup.observation.lifecyclePending, "post-registration read completes lifecycle")
        let unregister = Harness(); unregister.service.holdUnregister = true
        let unregTask = Task { await unregister.setup.remove() }
        await spin { unregister.service.unregisterCompletion != nil }
        check(unregister.setup.observation.lifecyclePending && unregister.client.removalPending, "actual unregister pending retained")
        unregister.client.event(.unknown("expected transport loss"))
        await unregister.setup.setup(); await unregister.setup.activate(); await unregister.setup.deactivate()
        check(unregister.service.registrations == 0 && unregister.client.activations == 0 && unregister.client.stops == 0, "pending unregister excludes mutations after loss")
        unregister.service.unregisterCompletion?(.success(()))
        check(await unregTask.value, "actual completion beats expected loss")
        check(unregister.setup.observation.quitSafe && !unregister.setup.observation.lifecyclePending, "late successful unregister settles")
        let unregisterFailure = Harness(); unregisterFailure.service.unregisterFails = true
        check(!(await unregisterFailure.setup.remove()), "native unregister error propagates")
        check(unregisterFailure.setup.observation.remedy == .retryRemoval, "unregister error exposes retry")
        let activation = Harness(); activation.service.values = [.enabled]; await activation.setup.startup()
        activation.client.holdActivate = true
        let actTask = Task { await activation.setup.activate() }; await spin { activation.client.activationGate != nil }
        check(activation.setup.observation.remedy == .deactivate, "activation offers stop while pending")
        await activation.setup.setup(); let overlappingRemoval = await activation.setup.remove()
        check(!overlappingRemoval && activation.service.registrations == 0, "activation excludes setup/removal")
        await activation.setup.deactivate()
        check(activation.client.stops == 1, "activation admits queued stop to reviewed client")
        activation.client.activationGate?.resume(); await actTask.value
        check(activation.setup.observation.state == .off, "late activation cannot erase queued stop result")
        await removalLoopback(check)
        await files()
        await bounded()
        print("AlwaysOnSetupChecks: \(count) assertions, \(failures) failures")
        if failures != 0 { exit(1) }
    }
    @MainActor static func files() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("setup-check-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: root) }
            let child = root.appendingPathComponent(TrustedStorage.directoryName)
            func absent() throws -> Bool { try TrustedStorage.fixtureAbsent(parent: root, expectedUID: getuid()) }
            check(try absent(), "ENOENT proves absence")
            try Data().write(to: child); check(try !absent(), "existing file uncertain"); try FileManager.default.removeItem(at: child)
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false); check(try !absent(), "existing directory uncertain"); try FileManager.default.removeItem(at: child)
            try FileManager.default.createSymbolicLink(atPath: child.path, withDestinationPath: "/does-not-exist")
            check(try !absent(), "dangling symlink not ENOENT child"); try FileManager.default.removeItem(at: child)
            _ = chmod(root.path, 0o777); rejects("writable parent rejects") { _ = try absent() }; _ = chmod(root.path, 0o700)
            rejects("wrong owner rejects") { _ = try TrustedStorage.fixtureAbsent(parent: root, expectedUID: getuid() &+ 1) }
            let acl = Process(); acl.executableURL = URL(fileURLWithPath: "/bin/chmod"); acl.arguments = ["+a", "everyone allow read", root.path]; try acl.run(); acl.waitUntilExit()
            check(acl.terminationStatus == 0, "temporary ACL fixture installed")
            rejects("nonempty ACL rejects") { _ = try absent() }
            let clear = Process(); clear.executableURL = URL(fileURLWithPath: "/bin/chmod"); clear.arguments = ["-N", root.path]; try clear.run(); clear.waitUntilExit()
            check(try absent(), "cleared ACL allows absent")
            let link = root.appendingPathComponent("parent-link"); try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: root.path)
            rejects("parent symlink rejects") { _ = try TrustedStorage.fixtureAbsent(parent: link, expectedUID: getuid()) }
            rejects("missing parent not accepted as child absence") { _ = try TrustedStorage.fixtureAbsent(parent: root.appendingPathComponent("missing"), expectedUID: getuid()) }
            check(!FileManager.default.fileExists(atPath: child.path), "probe never creates child")
        } catch { check(false, "filesystem fixture: \(error)") }
    }
    @MainActor static func presentation() async {
        do {
            let h = Harness(); h.proof.absent = false
            let adapter = SetupPresentationAdapter(h.setup), controller: AlwaysOnController
            controller = AlwaysOnController(backend: adapter)
            await adapter.refresh()
            check(controller.needsRepair && controller.action == .deactivate, "retained journal needs explicit repair exit")
            check(h.service.registrations == 0, "uncertain startup never registers automatically")
            controller.perform(.openSettings)
            check(h.service.registrations == 0, "repair navigation never registers")
            controller.repairHelperFromSettings()
            await spin { controller.canRemove }
            check(h.service.registrations == 1 && h.client.statuses == 1 && controller.state == .off, "explicit repair registers missing helper and observes recovered off")
            check(h.client.activations == 0, "repair never autoactivates")
        }
        let h = Harness(), adapter: SetupPresentationAdapter
        adapter = SetupPresentationAdapter(h.setup)
        var revisions: [UInt64] = []; adapter.onChange = { revisions.append($0.revision) }
        await adapter.refresh()
        check(adapter.snapshot.action == .setUp && adapter.snapshot.quitSafe, "adapter fresh setup")
        h.service.signed = false; await adapter.refresh()
        check(adapter.snapshot.action == .checkSetup && adapter.snapshot.quitSafe, "adapter missing signing")
        h.service.values = [.requiresApproval]; await adapter.refresh()
        check(adapter.snapshot.action == .checkSetup && adapter.snapshot.secondaryTitle == "Open Login Items", "adapter approval action")
        check(h.service.opens == 0, "adapter refresh no implicit navigation")
        adapter.openLoginItems(); check(h.service.opens == 1, "adapter explicit approval")
        h.service.values = [.notFound]; await adapter.refresh()
        check(adapter.snapshot.action == .checkSetup && !adapter.snapshot.quitSafe, "adapter missing installation")
        h.service.values = [.enabled]; await adapter.refresh()
        check(adapter.snapshot.state == .off && adapter.snapshot.action == .activate, "adapter available off")
        await adapter.activate(); check(adapter.snapshot.state == .active && adapter.snapshot.action == .deactivate, "adapter activate")
        await adapter.refresh(); check(adapter.snapshot.state == .active && h.client.stops == 0, "adapter owned active refresh")
        h.client.event(.unknown("Unavailable"))
        check(adapter.snapshot.action == .deactivate && adapter.snapshot.secondaryTitle == "Repair setup in Settings", "adapter recovery remedy")
        h.client.event(.removalRequired)
        check(adapter.snapshot.state == .removalRequired && adapter.snapshot.action == .openSettings && adapter.snapshot.quitSafe, "adapter quiet finish removal")
        h.client.removeOK = false; await adapter.remove()
        check(adapter.snapshot.secondaryTitle == "Retry helper removal in Settings" && !adapter.snapshot.quitSafe, "adapter failed removal")
        check(zip(revisions, revisions.dropFirst()).allSatisfy { $0 < $1 }, "adapter preserves increasing revision")
    }
    @MainActor static func bounded() async {
        let gate = DispatchSemaphore(value: 0)
        let reader = BoundedRead(sample: { gate.wait(); return true }, timeout: 0.02)
        await rejectsAsync("stuck worker reports deadline") { _ = try await reader.read() }
        for _ in 0..<3 { await rejectsAsync("stuck worker keeps slot") { _ = try await reader.read() } }
        gate.signal(); try? await Task.sleep(nanoseconds: 30_000_000)
        let ready = BoundedRead(sample: { 7 })
        do { check(try await ready.read() == 7, "successful bounded read") } catch { check(false, "successful bounded read") }
        let broken = BoundedRead<Bool>(sample: { throw Failure.fixture })
        await rejectsAsync("read error preserved") { _ = try await broken.read() }
    }
}
