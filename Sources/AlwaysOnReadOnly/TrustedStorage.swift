import Foundation
import Darwin

public enum TrustedStorage {
    public static let directoryName = "local.snapbridge.alwayson"
    private static func metadata(_ fd: Int32) throws -> stat {
        var value = stat()
        guard fstat(fd, &value) == 0 else { throw NativeIOError.system(errno) }
        return value
    }
    public static func validateParent(_ fd: Int32, uid: uid_t) throws {
        let value = try metadata(fd)
        guard value.st_mode & S_IFMT == S_IFDIR, value.st_uid == uid,
              value.st_mode & 0o022 == 0 else { throw NativeIOError.unsafeStorage }
        try validateACL(fd)
    }
    public static func validateACL(_ fd: Int32) throws {
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
    public static func openSystemParent() throws -> Int32 {
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw NativeIOError.system(errno) }
        do {
            try validateParent(fd, uid: 0)
            for name in ["private", "var", "db"] {
                let next = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw NativeIOError.system(errno) }
                close(fd); fd = next; try validateParent(fd, uid: 0)
            }
            return fd
        } catch { close(fd); throw error }
    }
    public static func absent() throws -> Bool {
        let fd = try openSystemParent(); defer { close(fd) }
        return try absent(parentFD: fd, uid: 0)
    }
    public static func fixtureAbsent(parent: URL, expectedUID: UInt32) throws -> Bool {
        let fd = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw NativeIOError.system(errno) }
        defer { close(fd) }
        return try absent(parentFD: fd, uid: expectedUID)
    }
    private static func absent(parentFD: Int32, uid: UInt32) throws -> Bool {
        try validateParent(parentFD, uid: uid)
        var entry = stat()
        if fstatat(parentFD, directoryName, &entry, AT_SYMLINK_NOFOLLOW) == 0 { return false }
        guard errno == ENOENT else { throw NativeIOError.system(errno) }
        return true
    }
}
