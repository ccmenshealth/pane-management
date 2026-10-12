import Foundation
import SystemConfiguration
import AlwaysOnAudit
import AlwaysOnCore
import AlwaysOnIPC

public enum NativeSession {
    public static func consoleUID() -> UInt32? {
        var uid: uid_t = 0, gid: gid_t = 0
        guard let name = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid), (name as String) != "loginwindow", uid != 0, uid != UInt32.max else { return nil }
        return uid
    }
    public static func validate(_ session: ConsoleSession) -> Bool {
        let before = consoleUID()
        var returned: UInt32 = 0, auid: UInt32 = 0, flags: UInt64 = 0
        guard pane_audit_session(session.auditSession, &returned, &auid, &flags) == 0 else { return false }
        return BoundaryPolicy.auditValid(session: session, before: before, after: consoleUID(), returned: returned, auid: auid, flags: flags)
    }
}
