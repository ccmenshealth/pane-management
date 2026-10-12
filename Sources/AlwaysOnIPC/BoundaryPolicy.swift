import Foundation

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
}

@objc public protocol AlwaysOnXPC {
    func request(_ payload: Data, reply: @escaping (Data) -> Void)
}

public extension BoundaryPolicy {
    /// Re-encoding rejects unknown fields, nulls, duplicate keys, noncanonical UUIDs
    /// and nested permit extensions as well as whitespace and numeric ambiguity.
    static func decodeReply(_ data: Data, for operation: ServiceOperation) throws -> ServiceReply {
        guard !data.isEmpty, data.count <= 4096 else { throw BoundaryError.invalidMessage }
        let r = try JSONDecoder().decode(ServiceReply.self, from: data)
        guard r.version == 1, try encode(r) == data else { throw BoundaryError.invalidMessage }
        if r.outcome == .activated {
            guard operation == .activate, r.state == .active, r.activationToken != nil, r.preparationPermit == nil else { throw BoundaryError.invalidMessage }
        } else if r.activationToken != nil { throw BoundaryError.invalidMessage }
        if r.outcome == .prepared {
            guard operation == .prepareForUpdateOrRemoval, r.state == .off, r.preparationPermit != nil else { throw BoundaryError.invalidMessage }
        }
        if r.preparationPermit != nil {
            guard r.state == .off, (r.outcome == .prepared || (r.outcome == .observed && operation == .status)) else { throw BoundaryError.invalidMessage }
        }
        return r
    }
}
