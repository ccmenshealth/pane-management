import Foundation
import AlwaysOnCore
import AlwaysOnIPC
import AlwaysOnService
import AlwaysOnClient
import AlwaysOnSetup

private let session = ConsoleSession(uid: 501, auditSession: 7)
@MainActor private final class Clock: RecoveryClock { var now = 100.0 }
@MainActor private final class Journal: RecoveryJournal {
    var stored: JournalLoad = .missing
    func load() throws -> JournalLoad { stored }
    func save(_ record: RecoveryRecord) throws { stored = .record(record) }
    func clear() throws { stored = .missing }
}
@MainActor private final class Power: RecoveryPower {
    var writes: [Bool] = []
    func read() async throws -> PowerReceipt { .init(preference: false, rootDomain: false) }
    func setDisabled(_ value: Bool) async throws -> PowerReceipt { writes.append(value); return .init(preference: value, rootDomain: value) }
}
@MainActor private final class Environment: ServiceEnvironment {
    func isCurrent(_ value: ConsoleSession) -> Bool { value == session }
    func samples(for value: ConsoleSession) -> ServiceSamples {
        .init(battery: .normal, batteryAt: 100, thermal: .nominal, thermalAt: 100, sessionValid: value == session, sessionAt: 100)
    }
}
@MainActor private final class Channel: ClientChannel {
    var isOpen = true
    let key: ConnectionKey, service: ServiceCoordinator
    init(_ service: ServiceCoordinator) { self.service = service; key = service.accept(session)! }
    func send(_ data: Data, completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        Task { do { completion(.success(try BoundaryPolicy.encode(await service.handle(BoundaryPolicy.decode(data), from: key)))) }
            catch { completion(.failure(error)) } }
    }
    func close() { isOpen = false; Task { await service.disconnected(key) } }
    func whileOpen(_ action: () -> Void) -> Bool { guard isOpen else { return false }; action(); return true }
}
@MainActor private final class Transport: ClientTransport {
    let service: ServiceCoordinator
    init(_ service: ServiceCoordinator) { self.service = service }
    func connect(lost: @escaping @MainActor () -> Void) throws -> ClientChannel { Channel(service) }
}
@MainActor private final class Registration: SetupService {
    var removals = 0
    func status() async throws -> SetupServiceStatus { .enabled }
    func validateIdentity() throws {}
    func register() async throws { fatalError("Loopback must never register") }
    func unregister(_ completion: @escaping @MainActor (Result<Void, Error>) -> Void) { removals += 1; completion(.success(())) }
    func openLoginItems() { fatalError("Loopback must never open settings") }
}
@MainActor private final class Proof: SetupProof {
    func power() async throws -> PowerReceipt { fatalError("Configured service must not use absence proof") }
    func directoryAbsent() async throws -> Bool { fatalError("Configured service must not use absence proof") }
}
@MainActor func removalLoopback(_ check: (Bool, String) -> Void) async {
    let power = Power(), journal = Journal(), clock = Clock(), environment = Environment()
    let service = ServiceCoordinator(journal: journal, power: power, clock: clock, environment: environment)
    await service.start()
    let client = AlwaysOnClient(transport: Transport(service), scheduler: SystemClientScheduler(), activity: Activity())
    check(await client.status().state == .off, "loopback starts usable off")
    let failed = await client.remove { $0(.failure(ClientFailure.removal)) }
    check(!failed, "loopback failed unregister")
    check(await client.status().state == .removalRequired, "same client rediscovers closed admission after failure")
    check(await client.deactivate().state == .removalRequired, "retry restore preserves removal exit")
    let fresh = AlwaysOnClient(transport: Transport(service), scheduler: SystemClientScheduler(), activity: Activity())
    check(await fresh.status().state == .removalRequired, "new client discovers daemon removal state")
    check(await fresh.activate().state == .removalRequired && power.writes.isEmpty, "closed admission cannot offer usable activation")
    let registration = Registration(), setup = SetupCoordinator(service: registration, client: SetupClientAdapter(fresh), proof: Proof())
    await setup.startup()
    check(setup.observation.state == .removalRequired && setup.observation.quitSafe && setup.observation.remedy == .finishRemoval, "setup offers quiet finish-removal exit")
    await setup.activate(); check(power.writes.isEmpty, "setup cannot activate removal-required state")
    check(await setup.remove() && registration.removals == 1, "flagged strict final permit still unregisters")
    check(setup.observation.quitSafe && setup.observation.remedy == .setUp, "finished removal settled")
    let next = ServiceCoordinator(journal: Journal(), power: Power(), clock: clock, environment: environment)
    await next.start()
    let restarted = AlwaysOnClient(transport: Transport(next), scheduler: SystemClientScheduler(), activity: Activity())
    check(await restarted.status().state == .off, "new daemon incarnation can reopen after recovery")
}

private final class Activity: ClientActivity {
    var begins = 0, ends = 0
    func begin() -> AnyObject { begins += 1; return NSObject() }
    func end(_ token: AnyObject) { ends += 1 }
}
