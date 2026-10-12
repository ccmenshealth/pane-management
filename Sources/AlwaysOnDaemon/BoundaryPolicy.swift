import Foundation
import AlwaysOnCore
import AlwaysOnService

public enum BoundaryError: Error { case signing, identity, invalidMessage, unavailable }
public enum PeerRole { case app, daemon }
public enum BoundaryPolicy {
    public static let appID = "local.snapbridge.app"
    public static let daemonID = "local.snapbridge.alwayson.service"
    public static func requirement(role: PeerRole, team: String? = nil) throws -> String {
        var result = "anchor apple generic and identifier \"\(role == .app ? appID : daemonID)\""
        if let team {
            guard team.utf8.count == 10, team.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) }) else { throw BoundaryError.signing }
            result += " and certificate leaf[subject.OU] = \"\(team)\""
        }
        return result
    }
    // Public bsm flags: authenticated 0x4000, console 0x2000, graphic 0x10; remote 0x1000.
    public static func auditValid(session: ConsoleSession, before: UInt32?, after: UInt32?, returned: UInt32, auid: UInt32, flags: UInt64) -> Bool {
        session.uid != 0 && session.uid != UInt32.max && session.auditSession != 0 && session.auditSession != UInt32.max
            && before == session.uid && after == session.uid && returned == session.auditSession && auid == session.uid
            && flags & 0x6010 == 0x6010 && flags & 0x1000 == 0
    }
    /// Canonical, bounded JSON also rejects duplicate fields and ambiguous encodings.
    /// B3 uses this encoder, not a caller-selected serialization format.
    public static func decode(_ data: Data) throws -> ServiceRequest {
        guard !data.isEmpty, data.count <= 1024 else { throw BoundaryError.invalidMessage }
        let request = try JSONDecoder().decode(ServiceRequest.self, from: data)
        guard request.valid, try encode(request) == data else { throw BoundaryError.invalidMessage }
        return request
    }
    public static func encode(_ request: ServiceRequest) throws -> Data {
        guard request.valid else { throw BoundaryError.invalidMessage }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(request)
        guard data.count <= 1024 else { throw BoundaryError.invalidMessage }; return data
    }
    public static func encode(_ reply: ServiceReply) throws -> Data {
        guard reply.version == 1, (reply.reason?.utf8.count ?? 0) <= 2048 else { throw BoundaryError.invalidMessage }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(reply)
        guard data.count <= 4096 else { throw BoundaryError.invalidMessage }; return data
    }
    public static func preflight(uid: UInt32, signature: () throws -> String, construct: (String) throws -> Void) throws {
        guard uid == 0 else { throw BoundaryError.identity }
        let requirement = try signature()
        try construct(requirement)
    }
}
