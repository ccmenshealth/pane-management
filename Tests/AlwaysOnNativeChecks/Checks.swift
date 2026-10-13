import Foundation
import CoreFoundation
import Darwin
import AlwaysOnCore
import AlwaysOnNative

@main struct Checks {
    @MainActor static var assertions = 0
    @MainActor static var failures = 0
    @MainActor static func check(_ value: Bool, _ label: String) {
        assertions += 1
        if !value { failures += 1; print("FAIL: \(label)") }
    }
    @MainActor static func rejects(_ label: String, _ body: () throws -> Void) {
        do { try body(); check(false, label) } catch { check(true, label) }
    }
    @MainActor static func rejectsAsync(_ label: String, _ body: () async throws -> Void) async {
        do { try await body(); check(false, label) } catch { check(true, label) }
    }
    static func fixture() {
        let args = CommandLine.arguments
        guard args.count > 2, args[1] == "--fixture" else { return }
        switch args[2] {
        case "nonzero": exit(7)
        case "output":
            let bytes = [UInt8](repeating: 97, count: 4096)
            for _ in 0..<512 { _ = bytes.withUnsafeBytes { Darwin.write(STDOUT_FILENO, $0.baseAddress, $0.count) } }
        case "late":
            signal(SIGTERM, SIG_IGN)
            try? String(getpid()).write(toFile: args[3] + ".pid", atomically: false, encoding: .utf8)
            usleep(600_000)
            try? "late".write(toFile: args[3], atomically: false, encoding: .utf8)
        case "environment":
            print(ProcessInfo.processInfo.environment.keys.sorted().joined(separator: ","))
        default: print("fixture-ok")
        }
        exit(0)
    }
    @MainActor static func main() async {
        fixture()
        if CommandLine.arguments.contains("--read-system") {
            do { let receipt = try StrictPowerValues.readSystem(); print("Read-only system receipt: preference=\(String(describing: receipt.preference)), rootDomain=\(String(describing: receipt.rootDomain))"); exit(0) }
            catch { print("Read-only system failure: \(error)"); exit(1) }
        }
        let fm = FileManager.default
        let parent = fm.temporaryDirectory.appendingPathComponent("native-io-\(UUID())")
        do { try fm.createDirectory(at: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]) }
        catch { print(error); exit(1) }
        let root = parent.appendingPathComponent("local.snapbridge.alwayson")
        let file = root.appendingPathComponent("recovery.json")
        let boot = UUID()
        let lease = RecoveryLease(token: UUID(), owner: .init(uid: 501, auditSession: 42))
        func make(_ id: UUID = boot, _ fault: ((JournalFault) throws -> Void)? = nil) throws -> NativeRecoveryJournal {
            try NativeRecoveryJournal(fixtureParent: parent, expectedUID: getuid(), bootID: id, fault: fault)
        }
        func loaded(_ journal: NativeRecoveryJournal, _ record: RecoveryRecord) -> Bool {
            if case .record(let result) = try? journal.load() { return result == record }; return false
        }
        do {
            var journal: NativeRecoveryJournal? = try make()
            if case .missing = try journal!.load() { check(true, "initial missing") } else { check(false, "initial missing") }
            rejects("held lock rejects second owner") { _ = try make() }
            for phase in RecoveryPhase.allCases {
                let record = RecoveryRecord(lease: lease, phase: phase)
                try journal!.save(record)
                check(loaded(journal!, record), "roundtrip \(phase)")
                journal = nil
                journal = try make(UUID())
                check(loaded(journal!, record), "old boot restart \(phase)")
            }
            let data = try Data(contentsOf: file)
            let envelope = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            check(envelope["bootID"] != nil && envelope["priorDisabled"] as? Bool == false, "boot and prior baseline persisted")
            var st = stat(); _ = lstat(file.path, &st)
            check(st.st_mode & 0o777 == 0o600 && st.st_nlink == 1 && st.st_uid == getuid(), "safe file metadata")
            try journal!.clear()
            if case .missing = try journal!.load() { check(true, "durable clear") } else { check(false, "durable clear") }
            journal = nil
            let record = RecoveryRecord(lease: lease, phase: .intent)
            journal = try make(boot, { if $0 == .beforeCommit { throw NativeIOError.failed } })
            rejects("before durable failure") { try journal!.save(record) }
            if case .missing = try journal!.load() { check(true, "before commit remains absent") } else { check(false, "before commit remains absent") }
            journal = nil
            journal = try make(boot, { if $0 == .afterCommit { throw NativeIOError.failed } })
            rejects("after durable failure") { try journal!.save(record) }
            check(loaded(journal!, record), "applied before failure persists")
            rejects("clear after durable failure") { try journal!.clear() }
            if case .missing = try journal!.load() { check(true, "clear applied before failure") } else { check(false, "clear applied before failure") }
            journal = nil; journal = try make()
            try journal!.save(record)
            for mutation in ["invalid-json", "unknown", "prior", "phase", "uid", "generation", "boot", "schema", "duplicate", "oversize"] {
                var altered = envelope
                switch mutation {
                case "unknown": altered["extra"] = true
                case "prior": altered["priorDisabled"] = 0
                case "phase": altered["phase"] = "resume"
                case "uid": altered["uid"] = "-1"
                case "generation": altered["generation"] = UUID().uuidString
                case "boot": altered["bootID"] = "bad"
                case "schema": altered["schema"] = "2"
                default: break
                }
                let canonical = try JSONSerialization.data(withJSONObject: altered, options: [.sortedKeys])
                let duplicate = Data(("{\"schema\":\"1\"," + String(data: canonical, encoding: .utf8)!.dropFirst()).utf8)
                let bytes = mutation == "invalid-json" ? Data("broken".utf8) : mutation == "oversize" ? Data(repeating: 65, count: 33000) : mutation == "duplicate" ? duplicate : canonical
                try bytes.write(to: file)
                if case .corrupt = try journal!.load() { check(true, "strict corrupt \(mutation)") } else { check(false, "strict corrupt \(mutation)") }
                try journal!.clear(); try journal!.save(record)
            }
            for attack in ["mode", "hardlink", "symlink", "directory", "fifo"] {
                try journal!.clear()
                let outside = parent.appendingPathComponent("outside")
                try Data("outside".utf8).write(to: outside)
                _ = chmod(outside.path, 0o600)
                switch attack {
                case "mode": try journal!.save(record); _ = chmod(file.path, 0o644)
                case "hardlink": _ = link(outside.path, file.path)
                case "symlink": _ = symlink(outside.path, file.path)
                case "directory": try fm.createDirectory(at: file, withIntermediateDirectories: false)
                default: _ = mkfifo(file.path, 0o600)
                }
                rejects("unsafe load \(attack)") { _ = try journal!.load() }
                rejects("unsafe clear \(attack)") { try journal!.clear() }
                rejects("unsafe save \(attack)") { try journal!.save(record) }
                check(try Data(contentsOf: outside) == Data("outside".utf8), "outside untouched \(attack)")
                try fm.removeItem(at: file); try fm.removeItem(at: outside)
            }
            try journal!.save(record)
            for target in [file, root, parent] {
                let chmodRunner = BoundedCommandRunner()
                _ = try await chmodRunner.run(executable: "/bin/chmod", arguments: ["+a", "everyone allow read", target.path])
                rejects("extended ACL load \(target.lastPathComponent)") { _ = try journal!.load() }
                rejects("extended ACL save \(target.lastPathComponent)") { try journal!.save(record) }
                rejects("extended ACL clear \(target.lastPathComponent)") { try journal!.clear() }
                // Restore only fixture ACLs, including when insecure pre-fix clear removed the file.
                if fm.fileExists(atPath: target.path) { _ = try await chmodRunner.run(executable: "/bin/chmod", arguments: ["-N", target.path]) }
                try journal!.save(record)
            }
            _ = chmod(root.path, 0o755)
            rejects("directory revalidation load") { _ = try journal!.load() }
            rejects("directory revalidation clear") { try journal!.clear() }
            _ = chmod(root.path, 0o700)
            try journal!.save(record)
            journal = nil
            journal = try make(boot, { if $0 == .beforeCommit { throw NativeIOError.failed } })
            rejects("clear before commit fails") { try journal!.clear() }
            check(loaded(journal!, record), "clear before commit retains ownership")
            journal = nil; journal = try make()
            let lockURL = root.appendingPathComponent("lock")
            try fm.removeItem(at: lockURL); try Data().write(to: lockURL); _ = chmod(lockURL.path, 0o600)
            rejects("lock replacement rejected") { _ = try journal!.load() }
            journal = nil
            _ = chmod(root.path, 0o755)
            rejects("unsafe existing directory refused") { _ = try make() }
            _ = chmod(root.path, 0o700)
            _ = chmod(lockURL.path, 0o644)
            rejects("unsafe existing lock refused") { _ = try make() }
            _ = chmod(lockURL.path, 0o600)
            rejects("wrong expected owner") { _ = try NativeRecoveryJournal(fixtureParent: parent, expectedUID: getuid() + 1, bootID: boot) }
            check(try fm.contentsOfDirectory(atPath: root.path).allSatisfy { ["lock", "recovery.json"].contains($0) }, "no pending temporary records remain")
            journal = try make()
            let moved = parent.appendingPathComponent("moved")
            try fm.moveItem(at: root, to: moved)
            try fm.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            rejects("held directory replacement rejected") { try journal!.clear() }
            journal = nil
            try fm.removeItem(at: root)
            _ = symlink(moved.path, root.path)
            rejects("journal directory symlink refused") { _ = try make() }
            try fm.removeItem(at: root); try fm.moveItem(at: moved, to: root)
        } catch { check(false, "filesystem suite unexpected \(error)") }
        do {
            let good = try StrictPowerValues.receipt(preferences: ["SleepDisabled": kCFBooleanFalse!], registry: ["SleepDisabled": kCFBooleanTrue!])
            check(good == .init(preference: false, rootDomain: true), "actual CFBooleans")
            let absent = try StrictPowerValues.receipt(preferences: nil, registry: [:])
            check(absent.preference == nil && absent.rootDomain == nil, "successful absence is nil")
            for bad: Any in [NSNumber(value: 0), NSNumber(value: 1), "false", NSNull(), [false]] {
                rejects("preference wrong type \(type(of: bad))") { _ = try StrictPowerValues.receipt(preferences: ["SleepDisabled": bad], registry: [:]) }
                rejects("registry wrong type \(type(of: bad))") { _ = try StrictPowerValues.receipt(preferences: [:], registry: ["SleepDisabled": bad]) }
            }
            rejects("invalid dictionary") { _ = try StrictPowerValues.receipt(preferences: false, registry: [:]) }
            var value = false, writes: [Bool] = [], reads = 0
            let power = NativeRecoveryPower(fixtureWrite: { value = $0; writes.append($0) }, fixtureRead: {
                reads += 1; return .init(preference: value, rootDomain: value)
            }, pollCount: 3)
            check(try await power.setDisabled(true).verifiedOn, "enable receipt")
            check(try await power.setDisabled(false).verifiedOff, "disable receipt")
            _ = try await power.read(); check(writes == [true, false] && reads == 3, "fixed bool transport plus fresh reads")
            let absentPower = NativeRecoveryPower(fixtureWrite: { _ in }, fixtureRead: { .init(preference: false, rootDomain: nil) }, pollCount: 2)
            await rejectsAsync("post-write absence fails") { _ = try await absentPower.setDisabled(false) }
            var delayedReads = 0
            let delayed = NativeRecoveryPower(fixtureWrite: { _ in }, fixtureRead: {
                delayedReads += 1; return delayedReads < 2 ? .init(preference: true, rootDomain: nil) : .init(preference: true, rootDomain: true)
            }, pollCount: 3)
            check(try await delayed.setDisabled(true).verifiedOn && delayedReads == 2, "bounded polling reaches explicit agreement")
            let mismatch = NativeRecoveryPower(fixtureWrite: { _ in }, fixtureRead: { .init(preference: true, rootDomain: false) }, pollCount: 2)
            await rejectsAsync("mismatch never accepted") { _ = try await mismatch.setDisabled(true) }
            let failRead = NativeRecoveryPower(fixtureWrite: { _ in }, fixtureRead: { throw NativeIOError.readback }, pollCount: 2)
            await rejectsAsync("read error propagates") { _ = try await failRead.read() }
            let appliedFail = NativeRecoveryPower(fixtureWrite: { value = $0; throw NativeIOError.failed }, fixtureRead: { .init(preference: value, rootDomain: value) })
            await rejectsAsync("applied then failed write") { _ = try await appliedFail.setDisabled(true) }
            check(value, "failed write really applied")
            check(try await appliedFail.read().verifiedOn, "failed write fresh observable")
        } catch { check(false, "power suite unexpected \(error)") }
        var sampledTime: TimeInterval = 0
        let lateRead = BoundedPowerReader(fixtureRead: {
            sampledTime = 2; return .init(preference: false, rootDomain: false)
        }, fixtureUptime: { sampledTime })
        await rejectsAsync("late sample cannot beat delayed deadline callback") { _ = try await lateRead.read() }
        let readGate = DispatchSemaphore(value: 0)
        let stalled = BoundedPowerReader(fixtureRead: {
            readGate.wait(); return .init(preference: true, rootDomain: true)
        }, timeout: 0.05)
        let readStart = ProcessInfo.processInfo.systemUptime
        await rejectsAsync("stalled read bounded") { _ = try await stalled.read() }
        check(ProcessInfo.processInfo.systemUptime - readStart < 0.5, "stalled read released service")
        await rejectsAsync("stalled read rejects queued sample") { _ = try await stalled.read() }
        readGate.signal()
        try? await Task.sleep(nanoseconds: 50_000_000)
        readGate.signal()
        do { check(try await stalled.read().verifiedOn, "fresh sample after discarded late result") }
        catch { check(false, "fresh read after stall \(error)") }
        let runner = BoundedCommandRunner()
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
        do {
            let ok = try await runner.run(executable: executable, arguments: ["--fixture", "ok"])
            check(ok.status == 0 && String(data: ok.output, encoding: .utf8)?.contains("fixture-ok") == true, "real successful child")
            await rejectsAsync("real nonzero exit") { _ = try await runner.run(executable: executable, arguments: ["--fixture", "nonzero"]) }
            await rejectsAsync("output cap drains and reaps") { _ = try await runner.run(executable: executable, arguments: ["--fixture", "output"], outputLimit: 64) }
            setenv("NATIVE_IO_MUST_NOT_INHERIT", "sentinel", 1)
            defer { unsetenv("NATIVE_IO_MUST_NOT_INHERIT") }
            let rawEnvironment = try await runner.run(executable: "/usr/bin/env", arguments: [])
            check(Set((String(data: rawEnvironment.output, encoding: .utf8) ?? "").split(separator: "\n").map(String.init)) == Set(["PATH=/usr/bin:/bin", "LANG=C", "LC_ALL=C"]), "exact spawn environment via env")
            let env = try await runner.run(executable: executable, arguments: ["--fixture", "environment"])
            let keys = Set((String(data: env.output, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",").map(String.init))
            check(keys.isSubset(of: ["LANG", "LC_ALL", "PATH", "__CF_USER_TEXT_ENCODING"]) && keys.isSuperset(of: ["LANG", "LC_ALL", "PATH"]), "sanitized environment; CoreFoundation may add text encoding")
            for cancelled in [false, true] {
                let marker = parent.appendingPathComponent("late-\(cancelled)").path
                let start = ProcessInfo.processInfo.systemUptime
                let task = Task { try await runner.run(executable: executable, arguments: ["--fixture", "late", marker], timeout: cancelled ? 2 : 0.15) }
                if cancelled { try await Task.sleep(nanoseconds: 150_000_000); task.cancel() }
                else {
                    // Establish that the first child is live before queuing a second.
                    for _ in 0..<20 where !fm.fileExists(atPath: marker + ".pid") { try await Task.sleep(nanoseconds: 5_000_000) }
                    let follower = try await runner.run(executable: executable, arguments: ["--fixture", "ok"])
                    check(follower.status == 0, "queued command resumes after timeout")
                    if let text = try? String(contentsOfFile: marker + ".pid"), let firstPID = Int32(text) {
                        errno = 0; check(kill(firstPID, 0) == -1 && errno == ESRCH, "second command cannot overtake live writer")
                    } else { check(false, "first writer launched before follower") }
                }
                await rejectsAsync("\(cancelled ? "cancel" : "timeout") throws after quiescence") { _ = try await task.value }
                check(ProcessInfo.processInfo.systemUptime - start < 1.5, "ordinary process bound")
                if let pidText = try? String(contentsOfFile: marker + ".pid"), let pid = Int32(pidText) {
                    errno = 0; check(kill(pid, 0) == -1 && errno == ESRCH, "child reaped")
                } else { check(false, "fixture actually launched") }
                try await Task.sleep(nanoseconds: 650_000_000)
                check(!fm.fileExists(atPath: marker), "no delayed write after return")
            }
            let after = try await runner.run(executable: executable, arguments: ["--fixture", "ok"])
            check(after.status == 0, "runner usable after termination")
        } catch { check(false, "process suite unexpected \(error)") }
        do { try fm.removeItem(at: parent); check(!fm.fileExists(atPath: parent.path), "all temp fixtures cleaned") }
        catch { check(false, "cleanup \(error)") }
        print("AlwaysOnNativeChecks: \(assertions) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
