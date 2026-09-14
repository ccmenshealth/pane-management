import AppKit
import Carbon
import Combine
import SnapCore

final class Preferences: ObservableObject {
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true { didSet { save("enabled", enabled) } }
    @Published var assist = UserDefaults.standard.object(forKey: "assist") as? Bool ?? true { didSet { save("assist", assist) } }
    @Published var hover = UserDefaults.standard.object(forKey: "hover") as? Bool ?? true { didSet { save("hover", hover) } }
    @Published var restore = UserDefaults.standard.object(forKey: "restore") as? Bool ?? true { didSet { save("restore", restore) } }
    @Published var sameDisplay = UserDefaults.standard.object(forKey: "sameDisplay") as? Bool ?? true { didSet { save("sameDisplay", sameDisplay) } }
    @Published var linkedResize = UserDefaults.standard.object(forKey: "linkedResize") as? Bool ?? true { didSet { save("linkedResize", linkedResize) } }
    @Published var accessibility = WindowService.trusted
    @Published var capture = WindowService.canCapture
    @Published var status = "Ready to set up"
    private func save(_ key: String, _ value: Bool) { UserDefaults.standard.set(value, forKey: key) }
}

final class SnapGroup {
    let id = UUID()
    var layout: SnapLayout
    var display: DisplaySpace
    let windows: [Int: ManagedWindow]
    var name: String { windows.sorted { $0.key < $1.key }.map { $0.value.appName }.joined(separator: " + ") }
    init(layout: SnapLayout, display: DisplaySpace, windows: [Int: ManagedWindow]) {
        self.layout = layout; self.display = display; self.windows = windows
    }
}

private struct WindowDrag {
    let window: ManagedWindow
    let startFrame: CGRect
    let startCursor: CGPoint
    var moving = false
    var target: SnapTarget?
    var display: DisplaySpace?
}

final class SnapController {
    let preferences: Preferences
    let windows = WindowService()
    let preview = PreviewOverlay()
    let palette = LayoutOverlay()
    let assistant = AssistOverlay()
    let toast = ToastOverlay()
    private(set) var groups: [SnapGroup] = []
    var groupsChanged: (() -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var drag: WindowDrag?
    private var session: AssistSession<UUID>?
    private var sessionDisplay: DisplaySpace?
    private var sessionPIDs: Set<pid_t>?
    private var thumbnailTask: Task<Void, Never>?
    private var operation = 0
    private var busy = false
    private var hoverWindow: UUID?
    private var hoverStart: TimeInterval = 0
    private var lastHoverCheck: TimeInterval = 0
    private var hoverPalette = false
    private var hoverAnchor: CGRect?
    private var dividerPanel: OverlayPanel?
    private var resizing = false
    private var wasEnabled = true
    private let hotkeys = Hotkeys()

    init(preferences: Preferences) { self.preferences = preferences }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown, .keyDown]) { [weak self] event in
            self?.handle(event)
        }
        // Local panels handle their own clicks. Escape must also stop a drag in our process.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { self?.cancel() }
            return event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in self?.tick() }
        hotkeys.action = { [weak self] action in self?.shortcut(action) }
        if WindowService.trusted && preferences.enabled { hotkeys.register() }
        preferences.status = WindowService.trusted ? "Running in the menu bar" : "Accessibility access is needed to snap windows"
    }

    func cancel() {
        operation += 1; busy = false; drag = nil
        preview.hide(); palette.hide(); hoverPalette = false
        finishAssist()
    }

    private func tick() {
        let trusted = WindowService.trusted
        if preferences.accessibility != trusted {
            preferences.accessibility = trusted
            preferences.status = trusted ? "Running in the menu bar" : "Accessibility access is needed"
            if trusted && preferences.enabled { hotkeys.register() }
            else { hotkeys.unregister(); cancel() }
        }
        let capture = WindowService.canCapture
        if preferences.capture != capture { preferences.capture = capture }
        if wasEnabled != preferences.enabled {
            wasEnabled = preferences.enabled
            if !wasEnabled { cancel(); dividerPanel?.orderOut(nil); hotkeys.unregister() }
            else if trusted { hotkeys.register() }
        }
        guard preferences.enabled, trusted, !busy, !resizing else { return }
        if NSEvent.pressedMouseButtons != 0 { return }
        updateDivider()
        guard drag == nil, !assistant.isVisible else { return }
        let point = DisplaySpace.cursor
        if hoverPalette, let rect = palette.quartzFrame {
            let corridor = rect.union(hoverAnchor ?? rect).insetBy(dx: -14, dy: -10)
            if !corridor.contains(point) { palette.hide(); preview.hide(); hoverPalette = false; hoverWindow = nil }
            return
        }
        guard preferences.hover, !palette.isVisible else { return }
        // Bound AX traffic while the pointer crosses windows.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHoverCheck > 0.28 else { return }
        lastHoverCheck = now
        if let (window, button) = windows.greenButton(at: point) {
            if hoverWindow != window.id { hoverWindow = window.id; hoverStart = now }
            else if now - hoverStart > 0.5, let display = DisplaySpace.containing(point) {
                openPalette(for: window, on: display, anchor: button, dragging: false)
                hoverPalette = true; hoverAnchor = button
            }
        } else { hoverWindow = nil }
    }

    private func handle(_ event: NSEvent) {
        guard preferences.enabled, WindowService.trusted, !resizing else { return }
        if event.type == .keyDown {
            if event.keyCode == 53 { cancel() }
            return
        }
        let point = event.cgEvent?.location ?? DisplaySpace.cursor
        switch event.type {
        case .leftMouseDown:
            cancel()
            dividerPanel?.orderOut(nil)
            if let window = windows.at(point), let frame = window.frame {
                drag = WindowDrag(window: window, startFrame: frame, startCursor: point)
            }
        case .leftMouseDragged:
            guard var current = drag else { return }
            if !current.moving {
                // Text selection, tabs, and native edge-resizing must not become window drags.
                guard let frame = current.window.frame,
                      SnapGeometry.isWindowMove(from: current.startFrame, to: frame,
                        cursorTravel: hypot(point.x-current.startCursor.x, point.y-current.startCursor.y)) else { return }
                current.moving = true
                detach(current.window)
            }
            guard let display = DisplaySpace.containing(point) else { return }
            let sameDisplay = current.display?.id == display.id
            current.display = display
            // Never resize while the destination app owns a native drag session.
            if palette.isVisible, !sameDisplay { palette.hide() }
            if point.y <= display.work.minY + 42, abs(point.x - display.work.midX) < display.work.width * 0.38, !palette.isVisible {
                openPalette(for: current.window, on: display, dragging: true)
            }
            let paletteTarget = palette.isVisible ? palette.target(at: point) : nil
            if palette.isVisible, let rect = palette.quartzFrame, point.y > rect.maxY + 40 { palette.hide() }
            current.target = paletteTarget ?? SnapGeometry.dragTarget(at: point, screen: display.frame,
                                                                       previous: sameDisplay ? current.target : nil)
            if let target = current.target { preview.show(target.layout.frames(in: display.work)[target.zone]) }
            else { preview.hide() }
            drag = current
        case .leftMouseUp:
            guard var current = drag else { return }
            if !current.moving, let frame = current.window.frame {
                current.moving = SnapGeometry.isWindowMove(from: current.startFrame, to: frame,
                    cursorTravel: hypot(point.x-current.startCursor.x, point.y-current.startCursor.y))
            }
            let display = DisplaySpace.containing(point)
            let target = display.flatMap { screen in
                (palette.isVisible ? palette.target(at: point) : nil) ??
                SnapGeometry.dragTarget(at: point, screen: screen.frame,
                    previous: current.display?.id == screen.id ? current.target : nil)
            }
            drag = nil; palette.hide(); preview.hide()
            if current.moving, let target, let display {
                snap(current.window, target: target, display: display)
            } else if current.moving {
                if preferences.restore, let original = current.window.originalFrame,
                   current.window.snappedFrame != nil, let display {
                    // Keep the original grab point, not a ratio recomputed at the
                    // far-away drop location. Restore only after native mouse-up.
                    let anchor = min(1, max(0, (current.startCursor.x-current.startFrame.minX) / max(1, current.startFrame.width)))
                    let virtualFrame = CGRect(x: point.x-anchor*current.startFrame.width, y: current.startFrame.minY,
                                              width: current.startFrame.width, height: current.startFrame.height)
                    let restored = SnapGeometry.restoredFrame(original: original, snapped: virtualFrame, cursor: point, workArea: display.work)
                    restoreAfterDrag(current.window, to: restored)
                } else {
                    current.window.snappedFrame = nil; current.window.originalFrame = nil
                }
            }
        case .rightMouseDown: cancel()
        default: break
        }
    }

    private func restoreAfterDrag(_ window: ManagedWindow, to frame: CGRect) {
        operation += 1; let token = operation; busy = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let self, token == self.operation else { return }
            let result = await self.windows.place(frame, to: window, cancelled: { token != self.operation })
            guard token == self.operation else { return }
            self.busy = false
            window.snappedFrame = nil
            if result == .placed { window.originalFrame = nil }
        }
    }

    func openLayouts() {
        guard preferences.enabled, WindowService.trusted else { toast.show("Enable Accessibility in Pane Management settings first."); return }
        guard let window = windows.focused(), let frame = window.frame, let display = DisplaySpace.containing(frame) else {
            toast.show("Focus a resizable app window, then press Control–Option–Z."); return
        }
        cancel(); openPalette(for: window, on: display, dragging: false)
    }

    /// Development-only entry point, available in Settings only while the separate fixture app runs.
    func testAssistWithFixture() {
        guard WindowService.trusted else { toast.show("Accessibility permission is required for this test."); return }
        let fixturePIDs = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "local.snapbridge.testwindows").map { $0.processIdentifier })
        let candidates = windows.candidates(sameDisplay: false).filter { fixturePIDs.contains($0.pid) }
        guard let window = candidates.first, let frame = window.frame, let display = DisplaySpace.containing(frame) else {
            preferences.status = "Test: \(windows.fixtureDiagnostics(pids: fixturePIDs))"
            toast.show(preferences.status); return
        }
        preferences.status = "Test: found \(candidates.count) resizable fixture windows"
        snap(window, target: SnapTarget(.halves, 0), display: display, candidatesFrom: fixturePIDs)
    }

    private func openPalette(for window: ManagedWindow, on display: DisplaySpace, anchor: CGRect? = nil, dragging: Bool) {
        palette.show(on: display, near: anchor, dragging: dragging, choose: { [weak self] target in
            self?.palette.hide(); self?.preview.hide(); self?.hoverPalette = false
            self?.snap(window, target: target, display: display)
        }, hover: { [weak self] target in
            if let target { self?.preview.show(target.layout.frames(in: display.work)[target.zone]) }
            else { self?.preview.hide() }
        }, cancel: { [weak self] in self?.cancel() })
    }

    private func snap(_ window: ManagedWindow, target: SnapTarget, display: DisplaySpace, candidatesFrom: Set<pid_t>? = nil) {
        guard let previous = window.frame else { return }
        operation += 1; let token = operation; busy = true
        finishAssist()
        let destination = target.layout.frames(in: display.work)[target.zone]
        // macOS may finish a native drag asynchronously; commit after its mouse-up handling.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let self, token == self.operation else { return }
            let result = await self.windows.place(destination, to: window, cancelled: { token != self.operation })
            guard token == self.operation else { return }
            guard result == .placed else {
                let diagnostic = "\(self.windows.lastPlacementResult); actual \(String(describing: window.frame)); requested \(destination)"
                let rollback = await self.windows.place(previous, to: window, cancelled: { token != self.operation })
                guard token == self.operation else { return }
                self.busy = false
                self.preferences.status = "Placement did not settle: \(diagnostic)"
                self.toast.show(rollback == .placed
                    ? "\(window.appName) didn’t accept this size. The previous position was restored."
                    : "\(window.appName) didn’t accept this size. Please reposition the window.")
                return
            }
            self.busy = false
            self.detach(window)
            if window.originalFrame == nil { window.originalFrame = previous }
            window.snappedFrame = destination
            self.preferences.status = "Snapped \(window.appName) · \(target.layout.name)"
            self.windows.raise(window)
            if self.preferences.assist, target.layout.zones.count > 1 {
                self.session = AssistSession(layout: target.layout, firstZone: target.zone, window: window.id)
                self.sessionDisplay = display
                self.sessionPIDs = candidatesFrom
                self.showNextChoice()
            }
        }
    }

    private func showNextChoice() {
        thumbnailTask?.cancel(); assistant.hide()
        guard let session, let zone = session.nextZone, let display = sessionDisplay else { finishAssist(); return }
        let candidates = windows.candidates(excluding: session.usedWindows, display: display, sameDisplay: preferences.sameDisplay)
            .filter { sessionPIDs?.contains($0.pid) ?? true }
        guard !candidates.isEmpty else { finishAssist(); return }
        let frame = session.layout.frames(in: display.work)[zone]
        // Tiny zones cannot accommodate a useful picker; leave them available for manual placement.
        guard frame.width >= 180, frame.height >= 230 else { self.session?.skip(); showNextChoice(); return }
        assistant.show(in: frame, windows: candidates,
                       subtitle: WindowService.canCapture ? "Choose a window · \(display.name)" : "Choose a window · Enable Screen Recording for previews",
                       choose: { [weak self] window in self?.choose(window) },
                       skip: { [weak self] in
                           guard let self, !self.busy else { return }
                           self.session?.skip(); self.showNextChoice()
                       },
                       cancel: { [weak self] in self?.cancel() })
        thumbnailTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.windows.thumbnails(for: candidates) { [weak self] in self?.assistant.view?.needsDisplay = true }
        }
    }

    private func choose(_ window: ManagedWindow) {
        guard !busy, let session, let zone = session.nextZone, let display = sessionDisplay,
              !session.usedWindows.contains(window.id), let previous = window.frame else { return }
        let target = session.layout.frames(in: display.work)[zone]
        busy = true; operation += 1; let token = operation
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.windows.place(target, to: window, cancelled: { token != self.operation })
            guard token == self.operation else { return }
            guard result == .placed else {
                let rollback = await self.windows.place(previous, to: window, cancelled: { token != self.operation })
                guard token == self.operation else { return }
                self.busy = false
                self.toast.show(rollback == .placed
                    ? "\(window.appName) won’t fit this zone. Choose another window."
                    : "\(window.appName) couldn’t be restored. Please reposition it.")
                return
            }
            self.busy = false
            if window.originalFrame == nil { window.originalFrame = previous }
            self.detach(window); window.snappedFrame = target
            self.windows.raise(window)
            self.session?.choose(window.id)
            self.showNextChoice()
        }
    }

    private func finishAssist() {
        thumbnailTask?.cancel(); thumbnailTask = nil; assistant.hide()
        if let session, let display = sessionDisplay, session.assignments.count > 1 {
            let members = session.assignments.compactMapValues { id in windows.known.first { $0.id == id } }
            if members.count > 1 {
                groups.insert(SnapGroup(layout: session.layout, display: display, windows: members), at: 0)
                groups = Array(groups.prefix(8)); groupsChanged?()
                preferences.status = "Snap group ready · \(members.count) windows"
            }
        }
        session = nil; sessionDisplay = nil; sessionPIDs = nil
        windows.known.forEach { $0.thumbnail = nil }
    }

    private func detach(_ window: ManagedWindow) {
        groups.removeAll { $0.windows.values.contains { $0.id == window.id } }
        dividerPanel?.orderOut(nil); groupsChanged?()
    }

    func restoreGroup(_ group: SnapGroup) {
        cancel()
        guard let display = DisplaySpace.all.first(where: { $0.id == group.display.id }) else {
            toast.show("Reconnect \(group.display.name) to restore this group."); return
        }
        group.display = display
        let frames = group.layout.frames(in: display.work)
        var failed = false
        for (zone, window) in group.windows.sorted(by: { $0.key < $1.key }) {
            if windows.apply(frames[zone], to: window) { window.snappedFrame = frames[zone]; windows.raise(window) }
            else { failed = true }
        }
        if failed { toast.show("Some windows in this group are closed, minimized, or unavailable.") }
    }

    private func shortcut(_ action: Hotkeys.Action) {
        guard preferences.enabled else { return }
        if action == .layouts { openLayouts(); return }
        if action == .group { if let group = groups.first { restoreGroup(group) }; return }
        guard WindowService.trusted, let window = windows.focused(), let frame = window.frame,
              let display = DisplaySpace.containing(frame) else { return }
        cancel()
        switch action {
        case .left: snap(window, target: SnapTarget(.halves, 0), display: display)
        case .right: snap(window, target: SnapTarget(.halves, 1), display: display)
        case .up:
            if let snapped = window.snappedFrame,
               SnapGeometry.nearlyEqual(snapped, SnapLayout.halves.frames(in: display.work)[0]) {
                snap(window, target: SnapTarget(.quarters, 0), display: display)
            } else if let snapped = window.snappedFrame, SnapGeometry.nearlyEqual(snapped, SnapLayout.halves.frames(in: display.work)[1]) {
                snap(window, target: SnapTarget(.quarters, 1), display: display)
            } else { snap(window, target: SnapTarget(.full, 0), display: display) }
        case .down:
            if let snapped = window.snappedFrame, SnapGeometry.nearlyEqual(snapped, SnapLayout.halves.frames(in: display.work)[0]) {
                snap(window, target: SnapTarget(.quarters, 2), display: display)
            } else if let snapped = window.snappedFrame, SnapGeometry.nearlyEqual(snapped, SnapLayout.halves.frames(in: display.work)[1]) {
                snap(window, target: SnapTarget(.quarters, 3), display: display)
            } else if let original = window.originalFrame {
                detach(window); _ = windows.apply(original, to: window); window.originalFrame = nil; window.snappedFrame = nil
            } else { AXUIElementSetAttributeValue(window.ax, kAXMinimizedAttribute as CFString, kCFBooleanTrue) }
        case .previousDisplay, .nextDisplay:
            let displays = DisplaySpace.all.sorted { $0.frame.minX < $1.frame.minX }
            guard displays.count > 1, let index = displays.firstIndex(where: { $0.id == display.id }) else { return }
            let next = displays[(index + (action == .nextDisplay ? 1 : displays.count-1)) % displays.count]
            let relative = CGRect(x: (frame.minX-display.work.minX)/display.work.width, y: (frame.minY-display.work.minY)/display.work.height,
                                  width: frame.width/display.work.width, height: frame.height/display.work.height)
            let destination = SnapLayout("transfer", "Transfer", [relative]).frames(in: next.work)[0]
            detach(window); _ = windows.apply(destination, to: window); window.snappedFrame = nil
        default: break
        }
    }

    private func updateDivider() {
        guard !groups.isEmpty, preferences.linkedResize, !assistant.isVisible, !palette.isVisible else { dividerPanel?.orderOut(nil); return }
        let point = DisplaySpace.cursor
        guard let focused = windows.focused(), let group = groups.first(where: { $0.windows.values.contains { $0.id == focused.id } }) else {
            dividerPanel?.orderOut(nil); return
        }
        let frames = group.layout.frames(in: group.display.work)
        guard group.windows.allSatisfy({ zone, window in window.frame.map { SnapGeometry.nearlyEqual($0, frames[zone]) } ?? false }) else {
            dividerPanel?.orderOut(nil); return
        }
        for boundary in group.layout.boundaries {
            let work = group.display.work, vertical = boundary.axis == .vertical
            let position = vertical ? work.minX + boundary.position * work.width : work.minY + boundary.position * work.height
            let start = vertical ? work.minY + boundary.start * work.height : work.minX + boundary.start * work.width
            let end = vertical ? work.minY + boundary.end * work.height : work.minX + boundary.end * work.width
            let across = vertical ? point.x : point.y, along = vertical ? point.y : point.x
            guard abs(across-position) < 12, along > start+16, along < end-16 else { continue }
            // Do not put an interactive handle over an unrelated foreground window.
            if let top = windows.at(point), !group.windows.values.contains(where: { $0.id == top.id }) { continue }
            let rect = vertical ? CGRect(x: position-5, y: along-28, width: 10, height: 56)
                                : CGRect(x: along-28, y: position-5, width: 56, height: 10)
            dividerPanel?.orderOut(nil)
            let panel = OverlayPanel(frame: rect)
            panel.allowsKeys = false
            let view = DividerView(frame: CGRect(origin: .zero, size: rect.size))
            view.vertical = vertical
            let baseline = group.layout
            view.began = { [weak self] in self?.resizing = true }
            view.moved = { [weak self] point in
                guard let self else { return }
                let fraction = vertical ? (point.x-work.minX)/work.width : (point.y-work.minY)/work.height
                guard let layout = baseline.moving(boundary, to: fraction) else { return }
                let nextFrames = layout.frames(in: work)
                let previousFrames = group.layout.frames(in: work)
                var valid = true
                for (zone, window) in group.windows {
                    if !self.windows.apply(nextFrames[zone], to: window) { valid = false }
                    if let actual = window.frame, !SnapGeometry.nearlyEqual(actual, nextFrames[zone], tolerance: 5) { valid = false }
                }
                if valid {
                    group.layout = layout
                    for (zone, window) in group.windows { window.snappedFrame = nextFrames[zone] }
                } else {
                    for (zone, window) in group.windows { _ = self.windows.apply(previousFrames[zone], to: window) }
                }
            }
            view.ended = { [weak self] in self?.resizing = false; self?.dividerPanel?.orderOut(nil) }
            panel.contentView = view; panel.orderFrontRegardless(); dividerPanel = panel
            return
        }
        dividerPanel?.orderOut(nil)
    }
}

final class Hotkeys {
    enum Action: UInt32 { case left = 1, right, up, down, layouts, group, previousDisplay, nextDisplay }
    var action: ((Action) -> Void)?
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    func register() {
        unregister()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, let action = Action(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue().action?(action)
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let keys: [(Action, UInt32, UInt32)] = [
            (.left, 123, 0), (.right, 124, 0), (.up, 126, 0), (.down, 125, 0), (.layouts, 6, 0), (.group, 5, 0),
            (.previousDisplay, 123, UInt32(shiftKey)), (.nextDisplay, 124, UInt32(shiftKey))
        ]
        for (action, code, extra) in keys {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: 0x534E4150, id: action.rawValue)
            if RegisterEventHotKey(code, UInt32(controlKey | optionKey) | extra, id, GetApplicationEventTarget(), 0, &reference) == noErr, let reference {
                references.append(reference)
            }
        }
    }
    func unregister() {
        references.forEach { UnregisterEventHotKey($0) }; references = []
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
    deinit { unregister() }
}
