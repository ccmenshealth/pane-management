import Foundation
import Darwin
import CoreFoundation
import AlwaysOnCore

/// Construct once for the service lifetime; the held lock excludes other writers.
/// Synchronous disk calls can stall the service executor. They have no fake timeout.
@MainActor public final class NativeRecoveryJournal: RecoveryJournal {
    private let parent: Int32
    private let directory: Int32
    private let lock: Int32
    private let uid: uid_t
    private let boot: UUID
    private let fault: ((JournalFault) throws -> Void)?
    private static let directoryName = "local.snapbridge.alwayson"
    private static let recordName = "recovery.json"
    private static let limit = 32768

    public convenience init() throws {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1, size < 128 else { throw NativeIOError.failed }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0,
              let boot = UUID(uuidString: String(cString: bytes)) else { throw NativeIOError.failed }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw NativeIOError.system(errno) }
        do {
            try Self.validateParent(fd, uid: 0)
            // /var is a system symlink on macOS; traverse its fixed canonical path.
            for name in ["private", "var", "db"] {
                let next = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw NativeIOError.system(errno) }
                close(fd); fd = next
                try Self.validateParent(fd, uid: 0)
            }
        } catch { close(fd); throw error }
        try self.init(parentFD: fd, expectedUID: 0, bootID: boot, fault: nil)
    }
    /// Test-only dependency injection. Never export paths or UIDs through IPC.
    public convenience init(fixtureParent: URL, expectedUID: UInt32, bootID: UUID,
                            fault: ((JournalFault) throws -> Void)? = nil) throws {
        let fd = open(fixtureParent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw NativeIOError.system(errno) }
        try self.init(parentFD: fd, expectedUID: expectedUID, bootID: bootID, fault: fault)
    }
    private init(parentFD: Int32, expectedUID: UInt32, bootID: UUID,
                 fault: ((JournalFault) throws -> Void)?) throws {
        var dir: Int32 = -1, held: Int32 = -1
        do {
            try Self.validateParent(parentFD, uid: expectedUID)
            if mkdirat(parentFD, Self.directoryName, 0o700) != 0 && errno != EEXIST { throw NativeIOError.system(errno) }
            dir = openat(parentFD, Self.directoryName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard dir >= 0 else { throw NativeIOError.system(errno) }
            try Self.validate(dir, uid: expectedUID, directory: true)
            held = try Self.openFile(dir, "lock", create: true)
            try Self.validate(held, uid: expectedUID)
            guard flock(held, LOCK_EX | LOCK_NB) == 0 else { throw NativeIOError.busy }
            guard fsync(dir) == 0, fsync(parentFD) == 0 else { throw NativeIOError.system(errno) }
        } catch {
            if held >= 0 { close(held) }; if dir >= 0 { close(dir) }; close(parentFD); throw error
        }
        parent = parentFD; directory = dir; lock = held; uid = expectedUID; boot = bootID; self.fault = fault
        try revalidate()
    }
    deinit { close(lock); close(directory); close(parent) }
    private static func metadata(_ fd: Int32) throws -> stat {
        var value = stat()
        guard fstat(fd, &value) == 0 else { throw NativeIOError.system(errno) }
        return value
    }
    private static func validateParent(_ fd: Int32, uid: uid_t) throws {
        let value = try metadata(fd)
        guard value.st_mode & S_IFMT == S_IFDIR, value.st_uid == uid,
              value.st_mode & 0o022 == 0 else { throw NativeIOError.unsafeStorage }
        try validateACL(fd)
    }
    private static func validate(_ fd: Int32, uid: uid_t, directory: Bool = false) throws {
        let value = try metadata(fd)
        guard value.st_uid == uid, value.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG),
              value.st_mode & 0o7777 == (directory ? 0o700 : 0o600),
              directory || value.st_nlink == 1 else { throw NativeIOError.unsafeStorage }
        try validateACL(fd)
    }
    private static func validateACL(_ fd: Int32) throws {
        // acl_get_fd_np folds absent ACL and native read failure into nil. Use
        // successful descriptor metadata enumeration plus explicit presence.
        guard let security = filesec_init() else { throw NativeIOError.system(errno) }
        defer { filesec_free(security) }
        var info = stat(), present: Int32 = 0
        guard fstatx_np(fd, &info, security) == 0,
              filesec_query_property(security, FILESEC_ACL, &present) == 0 else { throw NativeIOError.system(errno) }
        if present == 0 { return }
        var optionalACL: acl_t?
        guard filesec_get_property(security, FILESEC_ACL, &optionalACL) == 0,
              let acl = optionalACL else { throw NativeIOError.unsafeStorage }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        guard acl_valid(acl) == 0 else { throw NativeIOError.unsafeStorage }
        var entry: acl_entry_t?
        errno = 0
        let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
        // Darwin returns 0 for an entry, -1/EINVAL for an exhausted valid ACL.
        guard result == -1, errno == EINVAL else { throw NativeIOError.unsafeStorage }
    }
    private static func sameEntry(_ parent: Int32, _ name: String, _ fd: Int32) throws {
        var entry = stat()
        guard fstatat(parent, name, &entry, AT_SYMLINK_NOFOLLOW) == 0 else { throw NativeIOError.system(errno) }
        let held = try metadata(fd)
        guard held.st_dev == entry.st_dev, held.st_ino == entry.st_ino else { throw NativeIOError.unsafeStorage }
    }
    private func revalidate() throws {
        try Self.validateParent(parent, uid: uid)
        try Self.validate(directory, uid: uid, directory: true)
        try Self.sameEntry(parent, Self.directoryName, directory)
        try Self.validate(lock, uid: uid)
        try Self.sameEntry(directory, "lock", lock)
    }
    private static func openFile(_ dir: Int32, _ name: String, create: Bool = false) throws -> Int32 {
        let flags = O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
        var fd = openat(dir, name, flags)
        if fd < 0 && errno == ENOENT && create {
            fd = openat(dir, name, flags | O_CREAT | O_EXCL, 0o600)
        }
        guard fd >= 0 else { throw NativeIOError.system(errno) }
        return fd
    }
    private func existing() throws -> Int32? {
        let fd: Int32
        do { fd = try Self.openFile(directory, Self.recordName) }
        catch NativeIOError.system(let code) where code == ENOENT { return nil }
        do { try Self.validate(fd, uid: uid); try Self.sameEntry(directory, Self.recordName, fd) }
        catch { close(fd); throw error }
        return fd
    }

    public func load() throws -> JournalLoad {
        try revalidate()
        guard let fd = try existing() else { return .missing }
        defer { close(fd) }
        guard try Self.metadata(fd).st_size <= Self.limit else { return .corrupt }
        var bytes = [UInt8](repeating: 0, count: Self.limit + 1), count = 0
        while count < bytes.count {
            let readCount = bytes.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!.advanced(by: count), $0.count - count) }
            if readCount < 0 { if errno == EINTR { continue }; throw NativeIOError.system(errno) }
            if readCount == 0 { break }; count += readCount
        }
        try revalidate(); try Self.validate(fd, uid: uid); try Self.sameEntry(directory, Self.recordName, fd)
        guard count <= Self.limit else { return .corrupt }
        guard let record = Self.decode(Data(bytes.prefix(count))) else { return .corrupt }
        return .record(record)
    }
    private static func decode(_ data: Data) -> RecoveryRecord? {
        guard let object = try? JSONSerialization.jsonObject(with: data), let fields = object as? [String: Any],
              Set(fields.keys) == Set(["schema", "generation", "token", "uid", "auditSession", "phase", "bootID", "priorDisabled"]),
              fields["schema"] as? String == "1",
              let tokenString = fields["token"] as? String, let token = UUID(uuidString: tokenString),
              fields["generation"] as? String == tokenString, tokenString == token.uuidString,
              let owner = fields["uid"] as? String, let ownerID = UInt32(owner), ownerID != 0, String(ownerID) == owner,
              let audit = fields["auditSession"] as? String, let auditID = UInt32(audit), String(auditID) == audit,
              let phaseName = fields["phase"] as? String, let phase = RecoveryPhase(rawValue: phaseName),
              let bootName = fields["bootID"] as? String, UUID(uuidString: bootName) != nil,
              let prior = fields["priorDisabled"], CFGetTypeID(prior as CFTypeRef) == CFBooleanGetTypeID(),
              (prior as? Bool) == false else { return nil }
        // Only our canonical JSON representation is accepted. This also rejects
        // duplicate keys, alternate numeric coercions and trailing content.
        guard let canonical = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]), canonical == data else { return nil }
        return .init(lease: .init(token: token, owner: .init(uid: ownerID, auditSession: auditID)), phase: phase)
    }
    public func save(_ record: RecoveryRecord) throws {
        try revalidate()
        if let old = try existing() { close(old) }
        let fields: [String: Any] = ["schema": "1", "generation": record.lease.token.uuidString,
            "token": record.lease.token.uuidString, "uid": String(record.lease.owner.uid),
            "auditSession": String(record.lease.owner.auditSession), "phase": record.phase.rawValue,
            "bootID": boot.uuidString, "priorDisabled": false]
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        guard Self.decode(data) != nil else { throw NativeIOError.malformed }
        let temp = "pending-" + UUID().uuidString
        let fd = openat(directory, temp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw NativeIOError.system(errno) }
        defer { close(fd); _ = unlinkat(directory, temp, 0) }
        try Self.validate(fd, uid: uid)
        try data.withUnsafeBytes { bytes in
            var count = 0
            while count < bytes.count {
                let wrote = Darwin.write(fd, bytes.baseAddress!.advanced(by: count), bytes.count - count)
                if wrote < 0 && errno == EINTR { continue }
                guard wrote > 0 else { throw NativeIOError.system(errno) }; count += wrote
            }
        }
        guard fsync(fd) == 0 else { throw NativeIOError.system(errno) }
        try fault?(.beforeCommit)
        try revalidate(); try Self.validate(fd, uid: uid); try Self.sameEntry(directory, temp, fd)
        if let old = try existing() { close(old) }
        guard renameat(directory, temp, directory, Self.recordName) == 0, fsync(directory) == 0 else { throw NativeIOError.system(errno) }
        try fault?(.afterCommit)
    }
    public func clear() throws {
        try revalidate()
        if let fd = try existing() {
            defer { close(fd) }
            try fault?(.beforeCommit)
            try revalidate(); try Self.validate(fd, uid: uid); try Self.sameEntry(directory, Self.recordName, fd)
            guard unlinkat(directory, Self.recordName, 0) == 0 else { throw NativeIOError.system(errno) }
        }
        guard fsync(directory) == 0 else { throw NativeIOError.system(errno) }
        try fault?(.afterCommit)
    }
}
