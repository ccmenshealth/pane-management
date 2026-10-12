import Foundation
import Security
import CryptoKit

public protocol SigningAuthority {
    func validate(_ requirement: String) throws
    func leafCertificateFingerprint() throws -> String
}
public enum TrustedIdentity {
    public static func peerRequirement(own: PeerRole, authority: SigningAuthority = SystemSigningAuthority()) throws -> String {
        try CertificateIdentity.peerRequirement(
            ownIdentifier: own == .app ? BoundaryPolicy.appID : BoundaryPolicy.daemonID,
            peerIdentifier: own == .app ? BoundaryPolicy.daemonID : BoundaryPolicy.appID,
            authority: authority)
    }
}
/// Callers supply fixed code identifiers, never text in Apple's requirement language.
public enum CertificateIdentity {
    public static func requirement(identifier: String, leafFingerprint: String? = nil) throws -> String {
        let bytes = identifier.utf8
        guard (3...128).contains(bytes.count), identifier.contains("."),
              bytes.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 46 || $0 == 45 }),
              identifier.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty }) else { throw BoundaryError.identity }
        var text = "identifier \"\(identifier)\""
        if let pin = leafFingerprint {
            guard pin.utf8.count == 40, pin.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { throw BoundaryError.signing }
            text += " and certificate leaf = H\"\(pin.uppercased())\""
        }
        return text
    }
    public static func peerRequirement(ownIdentifier: String, peerIdentifier: String,
                                       authority: SigningAuthority = SystemSigningAuthority()) throws -> String {
        let own = try requirement(identifier: ownIdentifier)
        _ = try requirement(identifier: peerIdentifier)
        try authority.validate(own)
        let pin = try authority.leafCertificateFingerprint()
        try authority.validate(requirement(identifier: ownIdentifier, leafFingerprint: pin))
        return try requirement(identifier: peerIdentifier, leafFingerprint: pin)
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
