import Foundation
import Darwin

public struct CommandResult: Sendable {
    public let output: Data
    public let status: Int32
    public init(output: Data, status: Int32) { self.output = output; self.status = status }
}
private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
/// Serial queue stays occupied until waitpid proves the writer has exited.
/// A kernel-stuck child can exceed the deadline; it cannot free this writer slot.
public final class BoundedCommandRunner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.snapbridge.power-command")
    public init() {}
    public func run(executable: String, arguments: [String], timeout: TimeInterval = 3,
                    outputLimit: Int = 8192) async throws -> CommandResult {
        let flag = CancellationFlag()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do { continuation.resume(returning: try Self.execute(executable, arguments, timeout, outputLimit, flag)) }
                    catch { continuation.resume(throwing: error) }
                }
            }
        }, onCancel: { flag.cancel() })
    }
    private static func quiescenceUnknown() -> Never {
        // No successful reply or second writer is possible. A broken external
        // reaper/kernel requires service-level diagnosis, not a guessed timeout.
        while true { Thread.sleep(forTimeInterval: 60) }
    }
    private static func execute(_ executable: String, _ arguments: [String], _ timeout: TimeInterval,
                                _ limit: Int, _ flag: CancellationFlag) throws -> CommandResult {
        guard timeout.isFinite, timeout > 0, limit >= 0, executable.hasPrefix("/"),
              !([executable] + arguments).contains(where: { $0.utf8.contains(0) }) else { throw NativeIOError.failed }
        if flag.cancelled { throw NativeIOError.cancelled }
        var pipes: [Int32] = [0, 0]
        guard pipe(&pipes) == 0 else { throw NativeIOError.system(errno) }
        defer { close(pipes[0]); close(pipes[1]) }
        guard fcntl(pipes[0], F_SETFL, O_NONBLOCK) == 0,
              fcntl(pipes[0], F_SETFD, FD_CLOEXEC) == 0,
              fcntl(pipes[1], F_SETFD, FD_CLOEXEC) == 0 else { throw NativeIOError.system(errno) }
        var actions: posix_spawn_file_actions_t?, attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw NativeIOError.failed }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { throw NativeIOError.failed }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0,
              posix_spawn_file_actions_adddup2(&actions, pipes[1], STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, pipes[1], STDERR_FILENO) == 0,
              posix_spawn_file_actions_addclose(&actions, pipes[0]) == 0,
              posix_spawn_file_actions_addclose(&actions, pipes[1]) == 0,
              posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0 else { throw NativeIOError.failed }
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let environmentStrings: [String] = ["PATH=/usr/bin:/bin", "LANG=C", "LC_ALL=C"]
        let env = environmentStrings.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) }; env.forEach { free($0) } }
        var pid: pid_t = 0
        let spawned = argv.withUnsafeBufferPointer { args in
            env.withUnsafeBufferPointer { environment in
                posix_spawn(&pid, executable, &actions, &attributes, args.baseAddress!, environment.baseAddress!)
            }
        }
        guard spawned == 0 else { throw NativeIOError.system(spawned) }
        // Close only our write end now; defer's -1 close is harmless.
        close(pipes[1]); pipes[1] = -1
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var termination: NativeIOError?, killAt: TimeInterval?, output = Data(), overflow = false
        var status: Int32 = 0, bytes = [UInt8](repeating: 0, count: 4096)
        func drain() {
            // Bound each drain pass so an endless producer cannot starve the clock.
            for _ in 0..<16 {
                let count = bytes.withUnsafeMutableBytes { Darwin.read(pipes[0], $0.baseAddress, $0.count) }
                if count <= 0 { break }
                let keep = min(count, max(0, limit - output.count))
                output.append(contentsOf: bytes.prefix(keep)); if keep < count { overflow = true }
            }
        }
        while true {
            drain()
            var info = siginfo_t()
            let result = waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT)
            if result < 0 {
                if errno == EINTR { continue }
                // Lost wait ownership means identity may already be recycled.
                // Neither signal it nor free the writer slot on uncertain proof.
                Self.quiescenceUnknown()
            }
            if info.si_pid == pid {
                // WNOWAIT reserves the leader identity through group cleanup.
                // The fixed pmset executable is the sole possible power writer.
                _ = kill(-pid, SIGKILL)
                while true {
                    let reaped = waitpid(pid, &status, 0)
                    if reaped == pid { break }
                    if reaped < 0 && errno == EINTR { continue }
                    Self.quiescenceUnknown()
                }
                break
            }
            let now = ProcessInfo.processInfo.systemUptime
            if termination == nil && (flag.cancelled || now >= deadline) {
                termination = flag.cancelled ? .cancelled : .timeout
                _ = kill(-pid, SIGTERM); killAt = now + 0.1
            }
            if let target = killAt, now >= target { _ = kill(-pid, SIGKILL); killAt = nil }
            usleep(5_000)
        }
        // No PID/group signals after reaping: those IDs can now be reused.
        drain()
        if let termination { throw termination }
        if ProcessInfo.processInfo.systemUptime >= deadline { throw NativeIOError.timeout }
        if flag.cancelled { throw NativeIOError.cancelled }
        if overflow { throw NativeIOError.outputLimit }
        guard status == 0 else { throw NativeIOError.failed }
        return .init(output: output, status: status)
    }
}
