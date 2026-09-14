import AppKit
import ApplicationServices
import ScreenCaptureKit
import SnapCore

struct DisplaySpace {
    let id: CGDirectDisplayID
    let frame: CGRect
    let work: CGRect
    let name: String
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
    static var all: [DisplaySpace] {
        NSScreen.screens.map { screen in
            DisplaySpace(id: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0,
                         frame: SnapGeometry.cocoaRect(from: screen.frame, primaryHeight: primaryHeight),
                         work: SnapGeometry.cocoaRect(from: screen.visibleFrame, primaryHeight: primaryHeight),
                         name: screen.localizedName)
        }
    }
    static func containing(_ point: CGPoint) -> DisplaySpace? { all.first { $0.frame.contains(point) } }
    static func containing(_ rect: CGRect) -> DisplaySpace? {
        all.max { a, b in
            let x = a.frame.intersection(rect), y = b.frame.intersection(rect)
            return (x.isNull ? 0 : x.width*x.height) < (y.isNull ? 0 : y.width*y.height)
        }
    }
    static var cursor: CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }
    static func cocoa(_ rect: CGRect) -> CGRect { SnapGeometry.cocoaRect(from: rect, primaryHeight: primaryHeight) }
}

enum AXRead {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }
    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = value(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = value(element, kAXPositionAttribute), let s = value(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        let position = unsafeBitCast(p, to: AXValue.self), size = unsafeBitCast(s, to: AXValue.self)
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool { (value(element, attribute) as? Bool) == true }
}

final class ManagedWindow: Identifiable {
    let id = UUID()
    let ax: AXUIElement
    let pid: pid_t
    var title: String
    let appName: String
    let icon: NSImage?
    var windowID: CGWindowID?
    var originalFrame: CGRect?
    var snappedFrame: CGRect?
    // A successful adjusted width, scoped to this AX window and this process.
    // It is a preference for the next fit attempt, never a persisted minimum.
    var accommodatedWidth: CGFloat?
    var thumbnail: NSImage?
    var frame: CGRect? { AXRead.frame(ax) }
    var isAvailable: Bool {
        !AXRead.bool(ax, kAXMinimizedAttribute) && !AXRead.bool(ax, "AXFullScreen") && frame != nil
    }
    init(ax: AXUIElement, pid: pid_t, app: NSRunningApplication) {
        self.ax = ax; self.pid = pid
        self.appName = app.localizedName ?? "Application"
        self.title = (AXRead.value(ax, kAXTitleAttribute) as? String).flatMap { $0.isEmpty ? nil : $0 } ?? appName
        self.icon = app.icon
        AXUIElementSetMessagingTimeout(ax, 0.15)
    }
}

final class WindowService {
    private(set) var known: [ManagedWindow] = []
    private(set) var lastPlacementResult = ""
    static var trusted: Bool { AXIsProcessTrusted() }
    static var canCapture: Bool { PreviewAccess.shared.isAvailable }

    func fixtureDiagnostics(pids: Set<pid_t>) -> String {
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let count = rows.filter { ($0[kCGWindowOwnerPID as String] as? Int32).map { pids.contains($0) } ?? false }.count
        var parts = ["Visible server windows: \(count)"]
        for pid in pids {
            let app = AXUIElementCreateApplication(pid)
            var result: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &result)
            let elements = result as? [AXUIElement] ?? []
            parts.append("AX \(error.rawValue), windows \(elements.count)")
            for element in elements {
                var p: DarwinBoolean = false, s: DarwinBoolean = false
                let pe = AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &p)
                let se = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &s)
                let title = AXRead.value(element, kAXTitleAttribute) as? String ?? "untitled"
                let role = AXRead.value(element, kAXSubroleAttribute) as? String ?? "unknown"
                parts.append("\(title) [\(role)]: position \(p.boolValue)/\(pe.rawValue), size \(s.boolValue)/\(se.rawValue), frame \(String(describing: AXRead.frame(element)))")
            }
        }
        return parts.joined(separator: "; ")
    }

    func managed(_ element: AXUIElement) -> ManagedWindow? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != getpid(),
              let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular,
              (AXRead.value(element, kAXRoleAttribute) as? String) == kAXWindowRole,
              !AXRead.bool(element, "AXFullScreen"), !AXRead.bool(element, kAXMinimizedAttribute) else { return nil }
        // Sheets, floating palettes and utility windows are not snap candidates.
        if let subrole = AXRead.value(element, kAXSubroleAttribute) as? String,
           subrole != kAXStandardWindowSubrole { return nil }
        var resizable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &resizable) == .success,
           !resizable.boolValue { return nil }
        guard AXRead.frame(element) != nil else { return nil }
        if let existing = known.first(where: { $0.pid == pid && CFEqual($0.ax, element) }) { return existing }
        let window = ManagedWindow(ax: element, pid: pid, app: app)
        known.append(window)
        return window
    }

    func focused() -> ManagedWindow? {
        guard Self.trusted, let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return nil }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(ax, 0.15)
        guard let win = AXRead.element(ax, kAXFocusedWindowAttribute) else { return nil }
        return managed(win)
    }

    func at(_ point: CGPoint) -> ManagedWindow? {
        guard Self.trusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.15)
        var found: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &found) == .success,
              let element = found else { return nil }
        if (AXRead.value(element, kAXRoleAttribute) as? String) == kAXWindowRole { return managed(element) }
        if let window = AXRead.element(element, kAXWindowAttribute) { return managed(window) }
        return nil
    }

    /// Conservative hit test: only blank standard title-bar background, never a
    /// title/proxy icon, tab, toolbar control, resize border, or traffic-light button.
    func restorableTitleBar(at point: CGPoint) -> (ManagedWindow, CGRect)? {
        guard known.contains(where: { $0.snappedFrame != nil && $0.originalFrame != nil }),
              let window = at(point), window.snappedFrame != nil, window.originalFrame != nil,
              let frame = window.frame, point.y >= frame.minY + 5, point.y <= frame.minY + 27,
              point.x > frame.minX + 80, point.x < frame.maxX - 8 else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              let element, CFEqual(element, window.ax) else { return nil }
        for name in [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute, kAXFullScreenButtonAttribute, kAXTitleUIElementAttribute] {
            if let button = AXRead.element(window.ax, name), let rect = AXRead.frame(button), rect.insetBy(dx: -4, dy: -4).contains(point) { return nil }
        }
        return (window, frame)
    }

    func greenButton(at point: CGPoint) -> (ManagedWindow, CGRect)? {
        guard let win = at(point) else { return nil }
        for name in [kAXFullScreenButtonAttribute, kAXZoomButtonAttribute] {
            if let element = AXRead.element(win.ax, name), let rect = AXRead.frame(element), rect.contains(point) {
                return (win, rect)
            }
        }
        return nil
    }

    func candidates(excluding: Set<UUID> = [], display: DisplaySpace? = nil, sameDisplay: Bool = true) -> [ManagedWindow] {
        guard Self.trusted else { return [] }
        let info = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowLayer as String] as? Int) == 0 && ($0[kCGWindowOwnerPID as String] as? Int32) != getpid() }
        let pids = Set(info.compactMap { $0[kCGWindowOwnerPID as String] as? Int32 })
        var result: [(Int, ManagedWindow)] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && pids.contains(app.processIdentifier) {
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(ax, 0.15)
            guard let windows = AXRead.value(ax, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for element in windows {
                guard let window = managed(element), !excluding.contains(window.id), window.isAvailable,
                      let frame = window.frame, frame.width >= 100, frame.height >= 80 else { continue }
                if sameDisplay, let display, DisplaySpace.containing(frame)?.id != display.id { continue }
                let matches = info.enumerated().filter { _, row in
                    guard row[kCGWindowOwnerPID as String] as? Int32 == window.pid,
                          let bounds = row[kCGWindowBounds as String] as? [String: Any],
                          let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
                    return SnapGeometry.nearlyEqual(frame, rect, tolerance: 5)
                }
                // AX can list windows on other Spaces; require a visible WindowServer match.
                guard !matches.isEmpty else { continue }
                let exact = matches.filter { $0.element[kCGWindowName as String] as? String == window.title }
                let match = exact.count == 1 ? exact.first : (matches.count == 1 ? matches.first : nil)
                // Never display another window's capture when identity is ambiguous.
                window.windowID = match?.element[kCGWindowNumber as String] as? UInt32
                window.title = (AXRead.value(element, kAXTitleAttribute) as? String).flatMap { $0.isEmpty ? nil : $0 } ?? window.appName
                result.append((match?.offset ?? matches[0].offset, window))
            }
        }
        known.removeAll { NSRunningApplication(processIdentifier: $0.pid) == nil }
        return result.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    @discardableResult
    func apply(_ frame: CGRect, to window: ManagedWindow) -> Bool {
        guard window.isAvailable else { return false }
        return writeGeometry(frame, to: window)
    }

    /// Streaming writes are bounded by the controller; don't do three blocking AX
    /// reads for every pointer sample. Final positions always use settled placement.
    @discardableResult
    func writeGeometry(_ frame: CGRect, to window: ManagedWindow, resize: Bool = true) -> Bool {
        guard WindowPlacement.valid(frame) else { return false }
        var p = frame.origin, size = frame.size
        guard let position = AXValueCreate(.cgPoint, &p), let dimensions = AXValueCreate(.cgSize, &size) else { return false }
        // One resize/move pass. The settled-placement path retries after the app
        // has processed this pass (including constraints on a different display).
        let firstSize = resize ? AXUIElementSetAttributeValue(window.ax, kAXSizeAttribute as CFString, dimensions) : .success
        let move = AXUIElementSetAttributeValue(window.ax, kAXPositionAttribute as CFString, position)
        lastPlacementResult = "move \(move.rawValue), resize \(firstSize.rawValue)"
        return move == .success && firstSize == .success
    }

    @MainActor
    func setMinimized(_ minimized: Bool, window: ManagedWindow, cancelled: () -> Bool) async -> PlacementOutcome {
        guard !cancelled(), !Task.isCancelled else { return .cancelled }
        // A timeout may still have dispatched the request. Verify the resulting
        // state instead of interpreting the immediate AX return as completion.
        AXUIElementSetAttributeValue(window.ax, kAXMinimizedAttribute as CFString, minimized ? kCFBooleanTrue : kCFBooleanFalse)
        return await WindowPlacement.confirmState(minimized,
            read: { AXRead.value(window.ax, kAXMinimizedAttribute) as? Bool }, cancelled: cancelled)
    }

    @MainActor
    func place(_ frame: CGRect, to window: ManagedWindow, cancelled: () -> Bool) async -> PlacementOutcome {
        await WindowPlacement.staged(at: frame, read: { window.frame }, resize: { size in
            var size = size
            guard let value = AXValueCreate(.cgSize, &size) else { return }
            let result = AXUIElementSetAttributeValue(window.ax, kAXSizeAttribute as CFString, value)
            self.lastPlacementResult = "resize \(result.rawValue)"
        }, move: { point in
            var point = point
            guard let value = AXValueCreate(.cgPoint, &point) else { return }
            let result = AXUIElementSetAttributeValue(window.ax, kAXPositionAttribute as CFString, value)
            self.lastPlacementResult = "move \(result.rawValue)"
        }, cancelled: cancelled)
    }

    @MainActor
    func placeGroup(_ members: [Int: ManagedWindow], targets: [Int: CGRect], originals: [Int: CGRect],
                    cancelled: () -> Bool) async -> TransactionOutcome {
        await WindowPlacement.stagedTransaction(targets: targets, originals: originals,
            read: { members[$0]?.frame }, place: { id, frame in
                guard let window = members[id] else { return .failed }
                return await self.place(frame, to: window, cancelled: cancelled)
            }, cancelled: cancelled)
    }

    @MainActor
    func fit(_ window: ManagedWindow, zone: Int, layout: SnapLayout, display: DisplaySpace,
             members: [Int: ManagedWindow], originals: [Int: CGRect], cancelled: () -> Bool) async -> AdaptivePlacementResult {
        let result = await AdaptivePlacement.place(layout: layout, zone: zone, work: display.work,
            originals: originals, widthHint: window.accommodatedWidth,
            read: { members[$0]?.frame }, place: { id, frame in
                guard let member = members[id], member.isAvailable else { return .failed }
                return await self.place(frame, to: member, cancelled: cancelled)
            }, cancelled: cancelled)
        if result.outcome == .placed {
            window.accommodatedWidth = result.layout.zones == layout.zones ? nil : result.layout.frames(in: display.work)[zone].width
        } else if result.outcome != .cancelled {
            window.accommodatedWidth = nil
        }
        return result
    }

    func raise(_ window: ManagedWindow) {
        _ = NSRunningApplication(processIdentifier: window.pid)?.activate(options: [])
        AXUIElementPerformAction(window.ax, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window.ax, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    @MainActor
    func thumbnails(for windows: [ManagedWindow], refreshed: @escaping () -> Void) async {
        guard Self.canCapture else { return }
        let content: SCShareableContent
        do { content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) }
        catch { PreviewAccess.shared.captureFailed(error); return }
        for window in windows {
            guard !Task.isCancelled, let id = window.windowID,
                  let captureWindow = content.windows.first(where: { $0.windowID == id }) else { continue }
            let filter = SCContentFilter(desktopIndependentWindow: captureWindow)
            let config = SCStreamConfiguration()
            let ratio = min(1, 480 / max(1, captureWindow.frame.width))
            config.width = max(1, Int(captureWindow.frame.width * ratio))
            config.height = max(1, Int(captureWindow.frame.height * ratio))
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            do {
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                guard !Task.isCancelled else { return }
                window.thumbnail = NSImage(cgImage: image, size: NSSize(width: config.width, height: config.height))
                refreshed()
            } catch {
                PreviewAccess.shared.captureFailed(error)
                if !Self.canCapture { return }
            }
        }
    }
}
