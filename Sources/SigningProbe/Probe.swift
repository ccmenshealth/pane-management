import Foundation
import Combine
import AlwaysOnIPC

public enum Probe {
    public static let appID = "local.snapbridge.signingprobe"
    public static let helperID = "local.snapbridge.signingprobe.service"
    public static let wrongID = "local.snapbridge.signingprobe.negative"
    public static func peer(daemon: Bool) throws -> String {
        try CertificateIdentity.peerRequirement(ownIdentifier: daemon ? helperID : appID,
                                               peerIdentifier: daemon ? appID : helperID)
    }
    /// Negative acceptance fixtures only: never called by the GUI or daemon.
    public static func negativeRequirement(scenario: String, pin: String,
                                           authority: SigningAuthority = SystemSigningAuthority()) throws -> String {
        guard ["wrong-id", "ad-hoc", "wrong-pin"].contains(scenario) else { throw BoundaryError.identity }
        let expected = try CertificateIdentity.requirement(identifier: helperID, leafFingerprint: pin)
        if scenario != "ad-hoc" {
            let actual = try CertificateIdentity.peerRequirement(ownIdentifier: scenario == "wrong-id" ? wrongID : appID,
                                                                 peerIdentifier: helperID, authority: authority)
            guard scenario == "wrong-pin" ? actual != expected : actual == expected else { throw BoundaryError.signing }
        }
        return expected
    }
    // Fixed binary protocol: version byte, canonical 36-byte UUID, optional root UID byte.
    public static func request(_ nonce: UUID) -> Data { Data([1]) + Data(nonce.uuidString.utf8) }
    public static func response(_ data: Data) throws -> Data {
        guard data.count == 37, data.first == 1,
              let text = String(data: data.dropFirst(), encoding: .utf8),
              let uuid = UUID(uuidString: text), text == uuid.uuidString else { throw BoundaryError.invalidMessage }
        return data + Data([0])
    }
    public static func valid(_ reply: Data, request: Data) -> Bool {
        guard let expected = try? response(request) else { return false }
        return reply == expected
    }
}
@objc public protocol ProbeXPC { func ping(_ nonce: Data, reply: @escaping (Data) -> Void) }

@MainActor public protocol ProbeChannel: AnyObject {
    func send(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void)
    func close()
}
public enum ProbeFailure: Error { case unavailable, timeout, invalidReply }
@MainActor public final class ProbePing {
    public typealias Scheduler = (@escaping @MainActor () -> Void) -> (() -> Void)
    private var completion: ((Result<Void, Error>) -> Void)?
    private var channel: ProbeChannel?
    private var cancel: (() -> Void)?
    private var generation = UUID()
    public init() {}
    public func start(channel: ProbeChannel, schedule: Scheduler = ProbePing.deadline,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        guard self.completion == nil else { channel.close(); completion(.failure(ProbeFailure.unavailable)); return }
        self.channel = channel; self.completion = completion
        let token = UUID(); generation = token
        let data = Probe.request(UUID())
        cancel = schedule { [weak self] in self?.finish(.failure(ProbeFailure.timeout), token: token) }
        channel.send(data) { [weak self] result in
            self?.finish(result.flatMap { Probe.valid($0, request: data) ? .success(()) : .failure(ProbeFailure.invalidReply) }, token: token)
        }
    }
    public static func deadline(_ fire: @escaping @MainActor () -> Void) -> (() -> Void) {
        let task = Task { try? await Task.sleep(nanoseconds: 5_000_000_000); if !Task.isCancelled { fire() } }
        return { task.cancel() }
    }
    private func finish(_ result: Result<Void, Error>, token: UUID) {
        guard generation == token, let done = completion else { return }
        completion = nil; cancel?(); cancel = nil
        let old = channel; channel = nil; old?.close()
        done(result)
    }
}
@MainActor public protocol ProbeService {
    var status: String { get }
    func register() async throws
    func remove() async throws
    func ping() async throws
    func openLoginItems()
}
@MainActor public final class ProbeModel: ObservableObject {
    @Published public private(set) var busy = false
    @Published public private(set) var message = "No action taken. Check status or register this harmless probe."
    public let service: ProbeService
    public init(service: ProbeService) { self.service = service }
    public func check() { guard !busy else { return }; message = service.status }
    public func loginItems() { guard !busy else { return }; service.openLoginItems() }
    public func perform(_ action: String) async {
        guard !busy else { return }
        busy = true; message = "Waiting for \(action) to complete…"
        defer { busy = false }
        do {
            switch action {
            case "Register": try await service.register(); message = "Registration completed. \(service.status)"
            case "Remove": try await service.remove(); message = "Removal completed. \(service.status)"
            case "Ping": try await service.ping(); message = "SUCCESS: authenticated root helper echoed this request's nonce."
            default: throw ProbeFailure.unavailable
            }
        } catch {
            message = "\(action) did not succeed (\(error is ProbeFailure ? String(describing: error) : "service or signature unavailable")). Check status, retry, or remove the probe. No authentication success is established."
        }
    }
}
