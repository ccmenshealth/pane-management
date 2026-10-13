import Foundation
import CoreFoundation
import IOKit.ps
import SystemConfiguration
import AlwaysOnCore
import AlwaysOnService

public enum TelemetryPolicy {
    public static func battery(descriptions: [[String: Any]]?, warning: UInt32) -> BatteryGuard {
        guard let descriptions, !descriptions.isEmpty else { return .unknown }
        var internalPresent = false
        for value in descriptions {
            guard let type = value[kIOPSTypeKey] as? String else { return .unknown }
            if type == kIOPSInternalBatteryType {
                guard let present = value[kIOPSIsPresentKey], CFGetTypeID(present as CFTypeRef) == CFBooleanGetTypeID(),
                      let boolean = present as? Bool, boolean else { return .unknown }
                internalPresent = true
            }
        }
        guard internalPresent else { return .unknown }
        switch warning { case 1, 2: return .normal; case 3: return .finalWarning; default: return .unknown }
    }
    public static func thermal(_ value: ProcessInfo.ThermalState) -> ThermalGuard {
        switch value { case .nominal, .fair: return .nominal; case .serious: return .serious; case .critical: return .critical; @unknown default: return .unknown }
    }
    public static func battery() -> BatteryGuard {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return .unknown }
        var descriptions: [[String: Any]] = []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else { return .unknown }
            descriptions.append(description)
        }
        return battery(descriptions: descriptions, warning: IOPSGetBatteryWarningLevel().rawValue)
    }
}
/// The collector writes a locked cache; the engine only reads it. Each source's
/// timestamp is taken BEFORE its potentially blocking read, never after it.
public final class TelemetryCache: @unchecked Sendable {
    private let lock = NSLock()
    private var battery: BatteryGuard = .unknown, thermal: ThermalGuard = .unknown
    private var batteryAt = Double.nan, thermalAt = Double.nan
    private var sessions: [String: (Bool, Double)] = [:]
    private var batteryNotifications = false, thermalNotifications = false, sessionNotifications = false
    public init() {}
    private func key(_ session: ConsoleSession) -> String { "\(session.uid):\(session.auditSession)" }
    public func setNotificationsHealthy(_ healthy: Bool) { setNotificationHealth(battery: healthy, thermal: healthy, session: healthy) }
    public func setNotificationHealth(battery: Bool, thermal: Bool, session: Bool) {
        lock.lock(); batteryNotifications = battery; thermalNotifications = thermal; sessionNotifications = session; lock.unlock()
    }
    public func setBattery(_ value: BatteryGuard, at: Double) { lock.lock(); battery = value; batteryAt = at; lock.unlock() }
    public func setThermal(_ value: ThermalGuard, at: Double) { lock.lock(); thermal = value; thermalAt = at; lock.unlock() }
    public func setSession(_ session: ConsoleSession, valid: Bool, at: Double) { lock.lock(); sessions[key(session)] = (valid, at); lock.unlock() }
    public func removeSession(_ session: ConsoleSession) { lock.lock(); sessions.removeValue(forKey: key(session)); lock.unlock() }
    public func sample(_ session: ConsoleSession) -> ServiceSamples {
        lock.lock(); defer { lock.unlock() }
        let validation = sessions[key(session)] ?? (false, .nan)
        return .init(battery: batteryNotifications ? battery : .unknown, batteryAt: batteryAt,
                     thermal: thermalNotifications ? thermal : .unknown, thermalAt: thermalAt,
                     sessionValid: sessionNotifications && validation.0, sessionAt: validation.1)
    }
}
@MainActor public final class CachedEnvironment: ServiceEnvironment {
    private let cache: TelemetryCache
    private let now: () -> Double
    public init(cache: TelemetryCache, now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) { self.cache = cache; self.now = now }
    public func isCurrent(_ session: ConsoleSession) -> Bool {
        let sample = cache.sample(session), time = now()
        return sample.sessionValid && time.isFinite && sample.sessionAt.isFinite && sample.sessionAt <= time && time - sample.sessionAt <= 5
    }
    public func samples(for session: ConsoleSession) -> ServiceSamples { cache.sample(session) }
}
/// One queued/running collection at most; a hung source cannot accumulate work.
/// The watchdog has a distinct queue and posts at most one monitor task at once.
public final class NativeTelemetry: @unchecked Sendable {
    public let cache = TelemetryCache()
    private let lock = NSLock(), collector = DispatchQueue(label: "local.snapbridge.alwayson.collector")
    private let watchdog = DispatchQueue(label: "local.snapbridge.alwayson.watchdog")
    private let sessionCollector = DispatchQueue(label: "local.snapbridge.alwayson.sessions")
    private var collecting = false, collectingSessions = false, monitoring = false
    private var tracked: [UUID: ConsoleSession] = [:]
    private var timer: DispatchSourceTimer?
    private var store: SCDynamicStore?
    private var source: CFRunLoopSource?
    private var thermalObserver: NSObjectProtocol?
    private var onMonitor: (@Sendable () async -> Void)?
    private var readBattery: () -> BatteryGuard = { TelemetryPolicy.battery() }
    private var readThermal: () -> ThermalGuard = { TelemetryPolicy.thermal(ProcessInfo.processInfo.thermalState) }
    private var readSession: (ConsoleSession) -> Bool = { NativeSession.validate($0) }
    private var now: () -> Double = { ProcessInfo.processInfo.systemUptime }
    public init() {}
    /// In-process test ports only; the production executable exposes no override.
    public convenience init(fixtureBattery: @escaping () -> BatteryGuard, fixtureThermal: @escaping () -> ThermalGuard,
                            fixtureSession: @escaping (ConsoleSession) -> Bool, fixtureNow: @escaping () -> Double,
                            fixtureMonitor: @escaping @Sendable () async -> Void) {
        self.init(); readBattery = fixtureBattery; readThermal = fixtureThermal
        readSession = fixtureSession; now = fixtureNow; onMonitor = fixtureMonitor
    }
    public func track(_ session: ConsoleSession) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        guard tracked.count < 64 else { return nil }
        let id = UUID(); tracked[id] = session; return id
    }
    public func untrack(_ id: UUID) {
        lock.lock(); let removed = tracked.removeValue(forKey: id)
        if let removed, !tracked.values.contains(removed) { cache.removeSession(removed) }
        lock.unlock()
    }
    public func start(monitor: @escaping @Sendable () async -> Void) {
        onMonitor = monitor
        // Registration occurs on an independent run-loop thread. Its source stays
        // alive for the service lifetime; failure never silently becomes healthy.
        Thread.detachNewThread { [self] in
            var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
            let callback: SCDynamicStoreCallBack = { _, _, info in
                guard let info else { return }; Unmanaged<NativeTelemetry>.fromOpaque(info).takeUnretainedValue().tick()
            }
            let key = SCDynamicStoreKeyCreateConsoleUser(nil)
            let store = SCDynamicStoreCreate(nil, "PaneAlwaysOn" as CFString, callback, &context)
            let consoleOK = store.map { SCDynamicStoreSetNotificationKeys($0, [key] as CFArray, nil) && SCDynamicStoreSetDispatchQueue($0, watchdog) } ?? false
            let source = IOPSNotificationCreateRunLoopSource({ info in
                guard let info else { return }; Unmanaged<NativeTelemetry>.fromOpaque(info).takeUnretainedValue().tick()
            }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
            self.store = store; self.source = source
            thermalObserver = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in self?.tick() }
            cache.setNotificationHealth(battery: source != nil, thermal: true, session: consoleOK); tick()
            if let source {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
                CFRunLoopRun()
                cache.setNotificationHealth(battery: false, thermal: true, session: consoleOK); tick()
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: watchdog)
        timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.tick() }; self.timer = timer; timer.resume()
    }
    public func tick() {
        lock.lock()
        let collect = !collecting, collectSessions = !collectingSessions, monitor = !monitoring
        if collect { collecting = true }
        if collectSessions { collectingSessions = true }
        if monitor { monitoring = true }
        lock.unlock()
        if collect { collector.async { [self] in
            let time = now
            var began = time(); let battery = readBattery(); cache.setBattery(battery, at: began)
            began = time(); let thermal = readThermal(); cache.setThermal(thermal, at: began)
            lock.lock(); collecting = false; lock.unlock()
        } }
        if collectSessions { sessionCollector.async { [self] in
            // Console authentication stays available for recovery even if an
            // unrelated battery or thermal read never returns.
            lock.lock(); let sessions = Array(tracked.values); lock.unlock()
            for session in sessions {
                let began = now(); let valid = readSession(session)
                lock.lock()
                if tracked.values.contains(session) { cache.setSession(session, valid: valid, at: began) }
                lock.unlock()
            }
            lock.lock(); collectingSessions = false; lock.unlock()
        } }
        if monitor { Task { [self] in
            await onMonitor?()
            finishedMonitor()
        } }
    }
    private func finishedMonitor() { lock.lock(); monitoring = false; lock.unlock() }
}
