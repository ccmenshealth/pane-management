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
