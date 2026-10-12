import Foundation
import AlwaysOnCore
import AlwaysOnReadOnly

@MainActor public final class NativeRecoveryPower: RecoveryPower {
    private let write: (Bool) async throws -> Void
    private let sample: () async throws -> PowerReceipt
    private let polls: Int
    private var busy = false
    public init() {
        let runner = BoundedCommandRunner()
        let reads = BoundedPowerReader()
        write = { disabled in
            _ = try await runner.run(executable: "/usr/bin/pmset", arguments: ["disablesleep", disabled ? "1" : "0"])
        }
        sample = { try await reads.read() }
        polls = 20
    }
    /// In-process simulation only; no executable, command or path is IPC input.
    public init(fixtureWrite: @escaping (Bool) async throws -> Void,
                fixtureRead: @escaping () throws -> PowerReceipt, pollCount: Int = 20) {
        let reads = BoundedPowerReader(fixtureRead: fixtureRead)
        write = fixtureWrite; sample = { try await reads.read() }; polls = max(1, min(20, pollCount))
    }
    public func read() async throws -> PowerReceipt { try await sample() }
    public func setDisabled(_ disabled: Bool) async throws -> PowerReceipt {
        guard !busy else { throw NativeIOError.busy }
        busy = true; defer { busy = false }
        try Task.checkCancellation()
        try await write(disabled)
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        for index in 0..<polls {
            try Task.checkCancellation()
            let receipt = try await sample()
            if ProcessInfo.processInfo.systemUptime >= deadline { break }
            if disabled ? receipt.verifiedOn : receipt.verifiedOff { return receipt }
            if index + 1 < polls { try await Task.sleep(nanoseconds: 50_000_000) }
        }
        throw NativeIOError.readback
    }
}
