import Foundation
import CoreFoundation
import IOKit
import AlwaysOnCore

public enum StrictPowerValues {
    private static func value(_ container: Any?) throws -> Bool? {
        guard let container else { return nil }
        guard let dictionary = container as? [String: Any] else { throw NativeIOError.readback }
        guard let raw = dictionary["SleepDisabled"] else { return nil }
        guard CFGetTypeID(raw as CFTypeRef) == CFBooleanGetTypeID(), let value = raw as? Bool else { throw NativeIOError.readback }
        return value
    }
    /// Containers came from successful enumeration. Errors must be thrown by
    /// the transport before reaching this decoder, never converted to nil.
    public static func receipt(preferences: Any?, registry: Any?) throws -> PowerReceipt {
        .init(preference: try value(preferences), rootDomain: try value(registry))
    }
    public static func readSystem() throws -> PowerReceipt {
        let domain = "com.apple.PowerManagement" as CFString
        guard CFPreferencesSynchronize(domain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost) else { throw NativeIOError.readback }
        let preferences = CFPreferencesCopyValue("SystemPowerSettings" as CFString, domain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { throw NativeIOError.readback }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties else { throw NativeIOError.readback }
        return try receipt(preferences: preferences, registry: properties.takeRetainedValue())
    }
}
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
