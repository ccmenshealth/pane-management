import Foundation
import SigningProbe
import AlwaysOnIPC

var checks = 0, failures = 0
func expect(_ value: @autoclosure () -> Bool, _ label: String) {
    checks += 1; if !value() { failures += 1; print("FAIL: \(label)") }
}
final class Authority: SigningAuthority {
    var calls = [String]()
    func validate(_ requirement: String) throws { calls.append(requirement) }
    func leafCertificateFingerprint() throws -> String { calls.append("leaf"); return String(repeating: "a", count: 40) }
}
@MainActor final class Channel: ProbeChannel {
    var sent = Data(), closed = 0
    var callback: ((Result<Data, Error>) -> Void)?
    func send(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void) { sent = data; callback = completion }
    func close() { closed += 1 }
}
@MainActor final class Service: ProbeService {
    var status = "fixture status", calls = [String]()
    var continuation: CheckedContinuation<Void, Error>?
    func register() async throws { calls.append("register"); try await suspend() }
    func remove() async throws { calls.append("remove"); try await suspend() }
    func ping() async throws { calls.append("ping"); try await suspend() }
    func openLoginItems() { calls.append("login") }
    func suspend() async throws { try await withCheckedThrowingContinuation { continuation = $0 } }
    func finish(_ failed: Bool = false) { let c = continuation; continuation = nil; if failed { c?.resume(throwing: ProbeFailure.unavailable) } else { c?.resume() } }
}
@main struct Checks {
    @MainActor static func main() async throws {
        let nonce = UUID(uuidString: "12345678-ABCD-ABCD-ABCD-123456789012")!
        let data = Probe.request(nonce), reply = try Probe.response(data)
        expect(data.count == 37 && reply.count == 38, "bounded protocol")
        expect(Probe.valid(reply, request: data), "valid nonce")
        for bad in [Data(), Data(repeating: 0, count: 10000), Data([2]) + data.dropFirst(), Data([1]) + Data(nonce.uuidString.lowercased().utf8), data + Data([0])] {
            expect((try? Probe.response(bad)) == nil, "reject malformed request")
        }
        for bad in [Data(), reply + Data([0]), Data(reply.dropLast()) + Data([1]), try Probe.response(Probe.request(UUID()))] {
            expect(!Probe.valid(bad, request: data), "reject malformed or different nonce reply")
        }
        let a = Authority()
        let requirement = try CertificateIdentity.peerRequirement(ownIdentifier: Probe.appID, peerIdentifier: Probe.helperID, authority: a)
        expect(a.calls.count == 3 && a.calls[1] == "leaf", "self before leaf and pinned revalidation")
        expect(requirement.contains(Probe.helperID) && requirement.contains(String(repeating: "A", count: 40)), "own leaf binds peer")
        for id in ["", "x", ".abc", "a..b", "a.b\" or true", "a.b\n", "a.b\\c", String(repeating: "a", count: 129)] {
            let authority = Authority()
            expect((try? CertificateIdentity.peerRequirement(ownIdentifier: id, peerIdentifier: Probe.helperID, authority: authority)) == nil, "bad own identifier")
            expect(authority.calls.isEmpty, "bad own rejected before security port")
            expect((try? CertificateIdentity.peerRequirement(ownIdentifier: Probe.appID, peerIdentifier: id, authority: authority)) == nil, "bad peer identifier")
            expect(authority.calls.isEmpty, "bad peer rejected before security port")
        }
        for pin in ["", String(repeating: "G", count: 40), String(repeating: "a", count: 39), String(repeating: "a", count: 41)] {
            expect((try? CertificateIdentity.requirement(identifier: Probe.appID, leafFingerprint: pin)) == nil, "invalid pin")
        }
        let pin = String(repeating: "A", count: 40), other = String(repeating: "B", count: 40)
        for (scenario, supplied, allowed) in [("wrong-id", pin, true), ("wrong-id", other, false),
                                              ("wrong-pin", pin, false), ("wrong-pin", other, true),
                                              ("ad-hoc", pin, true), ("unknown", pin, false), ("ad-hoc", "bad", false)] {
            let authority = Authority()
            expect(((try? Probe.negativeRequirement(scenario: scenario, pin: supplied, authority: authority)) != nil) == allowed, "negative fixture preflight")
            if scenario == "ad-hoc" { expect(authority.calls.isEmpty, "ad-hoc fixture alone skips self-certificate requirement") }
            if allowed && scenario != "ad-hoc" {
                expect(authority.calls.first?.contains(scenario == "wrong-id" ? Probe.wrongID : Probe.appID) == true, "isolated negative fixture client ID")
            }
        }
        let ping = ProbePing()
        var timer: (() -> Void)?, cancellations = 0, results = [Bool]()
        let schedule: ProbePing.Scheduler = { fire in timer = fire; return { cancellations += 1 } }
        let first = Channel()
        ping.start(channel: first, schedule: schedule) { results.append((try? $0.get()) != nil) }
        expect(first.sent.count == 37, "request sent")
        first.callback?(.success(try Probe.response(first.sent)))
        timer?(); first.callback?(.failure(ProbeFailure.unavailable))
        expect(results == [true] && first.closed == 1 && cancellations == 1, "success exactly once and closes")
        let second = Channel()
        ping.start(channel: second, schedule: schedule) { results.append((try? $0.get()) != nil) }
        let staleTimer = timer
        timer?(); second.callback?(.success(try Probe.response(second.sent)))
        expect(results == [true, false] && second.closed == 1, "timeout closes and late success ignored")
        let third = Channel()
        ping.start(channel: third, schedule: schedule) { results.append((try? $0.get()) != nil) }
        staleTimer?(); first.callback?(.success(try Probe.response(first.sent)))
        expect(third.closed == 0 && results.count == 2, "old callbacks cannot close next operation")
        let competing = Channel()
        ping.start(channel: competing, schedule: schedule) { results.append((try? $0.get()) != nil) }
        expect(competing.closed == 1 && third.closed == 0, "concurrent ping rejected")
        third.callback?(.success(Data()))
        expect(results == [true, false, false, false] && third.closed == 1, "malformed reply is failure")
        for action in ["Register", "Remove", "Ping"] {
            for failure in [false, true] {
                let service = Service(), model = ProbeModel(service: Service())
                expect(model.message.contains("No action"), "launch is inert")
                let m = ProbeModel(service: service)
                let task = Task { await m.perform(action) }
                for _ in 0..<1000 { if service.continuation != nil { break }; await Task.yield() }
                expect(m.busy && service.continuation != nil, "actual completion pending")
                let pending = m.message
                m.check(); m.loginItems(); await m.perform("Register")
                expect(service.calls.count == 1 && m.message == pending, "pending serializes all actions")
                service.finish(failure); await task.value
                expect(!m.busy, "completion releases slot")
                expect(failure ? m.message.contains("did not succeed") : m.message.contains(action == "Ping" ? "SUCCESS:" : "completed"), "accurate result")
                m.check(); expect(m.message == service.status, "Check status exit")
                m.loginItems(); expect(service.calls.last == "login", "approval exit")
                let retry = Task { await m.perform("Remove") }
                for _ in 0..<1000 { if service.continuation != nil { break }; await Task.yield() }
                service.finish(); await retry.value
                expect(!m.busy && m.message.contains("Removal completed"), "retry removal exit")
            }
        }
        print("SigningProbeChecks: \(checks) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
