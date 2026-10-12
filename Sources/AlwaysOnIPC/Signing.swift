import Foundation
import Security

public protocol SigningAuthority {
    func validate(_ requirement: String) throws
    func team() throws -> String
}
public enum TrustedIdentity {
    public static func peerRequirement(own: PeerRole, authority: SigningAuthority = SystemSigningAuthority()) throws -> String {
        try authority.validate(BoundaryPolicy.requirement(role: own))
        let team = try authority.team()
        try authority.validate(BoundaryPolicy.requirement(role: own, team: team))
        return try BoundaryPolicy.requirement(role: own == .app ? .daemon : .app, team: team)
    }
}
public struct SystemSigningAuthority: SigningAuthority {
    public init() {}
    private func code() throws -> SecCode {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { throw BoundaryError.signing }
        return code
    }
    public func validate(_ text: String) throws {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              let requirement, SecCodeCheckValidity(try code(), [], requirement) == errSecSuccess else { throw BoundaryError.signing }
    }
    public func team() throws -> String {
        var information: CFDictionary?
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(try code(), [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [String: Any], let team = dictionary[kSecCodeInfoTeamIdentifier as String] as? String else { throw BoundaryError.signing }
        return team
    }
}
