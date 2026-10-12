import Foundation
import Security
import CryptoKit

public protocol SigningAuthority {
    func validate(_ requirement: String) throws
    func leafCertificateFingerprint() throws -> String
}
public enum TrustedIdentity {
    public static func peerRequirement(own: PeerRole, authority: SigningAuthority = SystemSigningAuthority()) throws -> String {
        try authority.validate(BoundaryPolicy.requirement(role: own))
        // Never derive peer authority from a peer, a certificate name or config.
        // Validate self first, extract its leaf, then bind self and peer to it.
        let pin = try authority.leafCertificateFingerprint()
        try authority.validate(BoundaryPolicy.requirement(role: own, leafFingerprint: pin))
        return try BoundaryPolicy.requirement(role: own == .app ? .daemon : .app, leafFingerprint: pin)
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
    public func leafCertificateFingerprint() throws -> String {
        var information: CFDictionary?
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(try code(), [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [String: Any],
              let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first else { throw BoundaryError.signing }
        let der = SecCertificateCopyData(leaf) as Data
        guard !der.isEmpty else { throw BoundaryError.signing }
        // SHA-1 is Apple's certificate requirement syntax, not our signature
        // algorithm. Ad-hoc signatures have no leaf and cannot reach this point.
        return Insecure.SHA1.hash(data: der).map { String(format: "%02X", $0) }.joined()
    }
}
