import AppKit

/// Own only a preflighted snapped-title-bar gesture. Ordinary dragging, controls,
/// double clicks, modified clicks, and all keyboard events pass through untouched.
/// No AX calls or window writes are allowed in the event-tap callback.
final class RestoredDragMonitor {
    var began: ((UUID, CGPoint) -> Void)?
    var moved: ((CGPoint) -> Void)?
    var ended: ((CGPoint) -> Void)?
    var interrupted: (() -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var ownsSequence = false
    private var eventThread: Thread?
    private let lock = NSLock()
    private var armed: (token: UUID, point: CGPoint, time: TimeInterval)?
    private var lastAttempt: TimeInterval = 0
    var available: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func arm(token: UUID, at point: CGPoint) {
        lock.lock(); defer { lock.unlock() }
        armed = (token, point, ProcessInfo.processInfo.systemUptime)
    }

    func disarm() {
        lock.lock(); defer { lock.unlock() }
        armed = nil
    }

    private func claim(at point: CGPoint) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        defer { armed = nil }
        guard let armed, ProcessInfo.processInfo.systemUptime - armed.time < 0.22,
              hypot(point.x-armed.point.x, point.y-armed.point.y) <= 2 else { return nil }
        return armed.token
    }

    func start() {
        guard tap == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAttempt > 5 else { return }
        lastAttempt = now
        let mask = [CGEventType.leftMouseDown, .leftMouseDragged, .leftMouseUp].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<RestoredDragMonitor>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.ownsSequence = false
                    DispatchQueue.main.async {
                        monitor.interrupted?()
                        if type == .tapDisabledByTimeout, let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    }
                    return Unmanaged.passUnretained(event)
                }
                let point = event.location
                switch type {
                case .leftMouseDown:
                    let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
                    let token = monitor.claim(at: point)
                    monitor.ownsSequence = token != nil && event.flags.intersection(modifiers).isEmpty &&
                        event.getIntegerValueField(.mouseEventClickState) == 1
                    if monitor.ownsSequence, let token { DispatchQueue.main.async { monitor.began?(token, point) } }
                case .leftMouseDragged:
                    if monitor.ownsSequence { DispatchQueue.main.async { monitor.moved?(point) } }
                case .leftMouseUp:
                    if monitor.ownsSequence {
                        monitor.ownsSequence = false
                        DispatchQueue.main.async { monitor.ended?(point) }
                        return nil
                    }
                default: break
                }
                return monitor.ownsSequence ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap); self.tap = nil; return
        }
        self.source = source
        // An active tap on the main run loop would stall mouse input whenever an
        // unrelated AX read blocks. Only the bounded, locked preflight runs here.
        let thread = Thread { [self] in
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
            while !Thread.current.isCancelled { CFRunLoopRunInMode(.defaultMode, 0.25, false) }
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            withExtendedLifetime(self) {}
        }
        thread.name = "Pane Management drag filter"
        thread.qualityOfService = .userInteractive
        eventThread = thread; thread.start()
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        disarm()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        eventThread?.cancel(); eventThread = nil
        tap = nil; source = nil
    }
}
