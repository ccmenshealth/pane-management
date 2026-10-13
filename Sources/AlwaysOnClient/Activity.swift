import Foundation

/// Scheduling only: this option explicitly permits idle system sleep and does
/// not include a display-sleep assertion. No global App Nap preference is used.
public protocol ClientActivity: AnyObject {
    func begin() -> AnyObject
    func end(_ token: AnyObject)
}
public final class SystemClientActivity: ClientActivity {
    public static let options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep
    public init() {}
    public func begin() -> AnyObject {
        ProcessInfo.processInfo.beginActivity(options: Self.options, reason: "Maintain the user-requested always-on helper session")
    }
    public func end(_ token: AnyObject) { ProcessInfo.processInfo.endActivity(token as! NSObjectProtocol) }
}
/// Holds are idempotent, independently owned, and may outlive the client during
/// actual unregister settlement. A single native activity covers overlapping work.
final class ActivityHold {
    private let lock = NSLock()
    private var release: (() -> Void)?
    init(_ release: @escaping () -> Void) { self.release = release }
    func finish() { lock.lock(); let action = release; release = nil; lock.unlock(); action?() }
    deinit { finish() }
}
final class ClientActivities {
    private let port: ClientActivity, lock = NSLock()
    private var count = 0, token: AnyObject?
    init(_ port: ClientActivity) { self.port = port }
    func hold() -> ActivityHold {
        lock.lock(); if count == 0 { token = port.begin() }; count += 1; lock.unlock()
        return ActivityHold { [self] in
            lock.lock(); count -= 1
            if count == 0, let token { self.token = nil; port.end(token) }
            lock.unlock()
        }
    }
}
