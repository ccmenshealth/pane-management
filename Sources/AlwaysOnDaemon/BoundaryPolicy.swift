import Foundation
import AlwaysOnCore
@_exported import AlwaysOnIPC

public extension BoundaryPolicy {
    // Console 0x2000 + graphic 0x10; reject remote 0x1000. HAS_AUTHENTICATED
    // 0x4000 is mutable credential history, not durable console-session identity.
    static func auditValid(session: ConsoleSession, before: UInt32?, after: UInt32?, returned: UInt32, auid: UInt32, flags: UInt64) -> Bool {
        session.uid != 0 && session.uid != UInt32.max && session.auditSession != 0 && session.auditSession != UInt32.max
            && before == session.uid && after == session.uid && returned == session.auditSession && auid == session.uid
            && flags & 0x2010 == 0x2010 && flags & 0x1000 == 0
    }
    static func preflight(uid: UInt32, signature: () throws -> String, construct: (String) throws -> Void) throws {
        guard uid == 0 else { throw BoundaryError.identity }
        let requirement = try signature()
        try construct(requirement)
    }
}
