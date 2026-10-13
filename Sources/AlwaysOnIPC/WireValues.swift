import Foundation

public enum ServiceOperation: String, Codable, Sendable, CaseIterable {
    case status, activate, heartbeat, deactivate, retryRestore, prepareForUpdateOrRemoval
}
/// Transport decodes into this value before invoking the coordinator. Identity is
/// supplied exclusively by trusted connection admission, never by this payload.
public struct ServiceRequest: Codable, Sendable {
    public let version: Int
    public let operation: ServiceOperation
    public let token: String?
    public init(version: Int = 1, operation: ServiceOperation, token: String? = nil) {
        self.version = version; self.operation = operation; self.token = token
    }
    private enum CodingKeys: String, CodingKey, CaseIterable { case version, operation, token }
    private struct AnyKey: CodingKey {
        let stringValue: String; let intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: AnyKey.self)
        guard Set(all.allKeys.map(\.stringValue)).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown request field"))
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        operation = try values.decode(ServiceOperation.self, forKey: .operation)
        token = try values.decodeIfPresent(String.self, forKey: .token)
        guard valid else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid request shape or version"))
        }
    }
    public var valid: Bool {
        guard version == 1 else { return false }
        if operation == .heartbeat || operation == .deactivate {
            guard let token, let uuid = UUID(uuidString: token) else { return false }
            return uuid.uuidString == token
        }
        return token == nil
    }
}
public enum ServiceState: String, Codable, Sendable { case checking, off, activating, active, stopping, recoveryRequired, conflict }
public enum ServiceOutcome: String, Codable, Sendable { case observed, activated, prepared, rejected, invalidRequest }
public struct PreparationPermit: Equatable, Codable, Sendable {
    public let incarnation: UUID
    public let epoch: UInt64
    public init(incarnation: UUID, epoch: UInt64) { self.incarnation = incarnation; self.epoch = epoch }
}
public struct ServiceReply: Equatable, Codable, Sendable {
    public let version: Int
    public let state: ServiceState
    public let outcome: ServiceOutcome
    public let reason: String?
    public let activationToken: UUID?
    public let preparationPermit: PreparationPermit?
    public let requiresRemoval: Bool
    public init(state: ServiceState, outcome: ServiceOutcome = .observed, reason: String? = nil,
                activationToken: UUID? = nil, preparationPermit: PreparationPermit? = nil, requiresRemoval: Bool = false) {
        self.version = 1; self.state = state; self.outcome = outcome; self.reason = reason
        self.activationToken = activationToken; self.preparationPermit = preparationPermit; self.requiresRemoval = requiresRemoval
    }
}
