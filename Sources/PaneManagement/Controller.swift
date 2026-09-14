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
    @Published var topBar = UserDefaults.standard.object(forKey: "topBar") as? Bool ?? true { didSet { save("topBar", topBar) } }
    @Published var nearEdge = UserDefaults.standard.object(forKey: "nearEdge") as? Bool ?? true { didSet { save("nearEdge", nearEdge) } }
    @Published var accessibility = WindowService.trusted
    @Published var capture = WindowService.canCapture
    @Published var status = "Ready to set up"
    @Published var fixtureCheckStatus = "Live checks not run in this session"
    @Published var fixtureChecksRunning = false
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
    var owned = false
    var lastWrite: TimeInterval = 0
    var lastWrittenFrame: CGRect?
    var group: SnapGroup?
    var releasePending = false
}

private struct GroupResize {
    let group: SnapGroup
    let baseline: SnapLayout
    let originals: [Int: CGRect]
    var layout: SnapLayout
    var lastWrite: TimeInterval = 0
}

private struct KeyboardSession {
    let window: ManagedWindow
    let display: DisplaySpace
    let original: CGRect
    var sequence: KeyboardSequence
}

final class SnapController {
    let preferences: Preferences
    let windows = WindowService()
    let preview = PreviewOverlay()
    let palette = LayoutOverlay()
    let assistant = AssistOverlay()
    let toast = ToastOverlay()
    let groupPicker = GroupOverlay()
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
    private let restoredDrag = RestoredDragMonitor()
    private var restoreCandidate: (token: UUID, window: ManagedWindow, frame: CGRect)?
    private var groupResize: GroupResize?
    private var keyboard: KeyboardSession?
    private var edgeThreshold: CGFloat { preferences.nearEdge ? 18 : 2 }

    init(preferences: Preferences) { self.preferences = preferences }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown, .keyDown, .flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
        // Local panels handle their own clicks. Escape must also stop a drag in our process.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            if event.keyCode == 53 { self?.cancel() }
            if event.type == .flagsChanged { self?.finishKeyboardIfReleased(event.modifierFlags) }
            return event
        }
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
        restoredDrag.began = { [weak self] token, point in self?.beginOwnedDrag(token: token, at: point) }
        restoredDrag.moved = { [weak self] point in self?.moveDrag(to: point) }
        restoredDrag.ended = { [weak self] point in self?.endDrag(at: point) }
        restoredDrag.interrupted = { [weak self] in self?.cancel() }
        if WindowService.trusted { restoredDrag.start() }
        hotkeys.action = { [weak self] action in self?.shortcut(action) }
        if WindowService.trusted && preferences.enabled { hotkeys.register() }
        preferences.status = WindowService.trusted ? "Running in the menu bar" : "Accessibility access is needed to snap windows"
    }

    func cancel() {
        restoredDrag.disarm()
        operation += 1; busy = false
        if let current = drag, current.owned, current.moving {
            current.window.snappedFrame = nil; current.window.originalFrame = nil
        }
        if let resize = groupResize { invalidate(resize.group) }
        drag = nil; keyboard = nil; groupResize = nil; resizing = false; restoreCandidate = nil
        dividerPanel?.orderOut(nil); groupPicker.hide()
        preview.hide(); palette.hide(); hoverPalette = false
        finishAssist()
    }

    func stop() {
        cancel(); restoredDrag.stop(); timer?.invalidate(); hotkeys.unregister()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    private func tick() {
        let trusted = WindowService.trusted
        if preferences.accessibility != trusted {
            preferences.accessibility = trusted
            preferences.status = trusted ? "Running in the menu bar" : "Accessibility access is needed"
            if trusted && preferences.enabled { hotkeys.register() }
            else { hotkeys.unregister(); cancel() }
        }
        if trusted, !restoredDrag.available { restoredDrag.start() }
        let capture = WindowService.canCapture
        if preferences.capture != capture { preferences.capture = capture }
        if wasEnabled != preferences.enabled {
            wasEnabled = preferences.enabled
            if !wasEnabled { cancel(); dividerPanel?.orderOut(nil); hotkeys.unregister() }
            else if trusted { hotkeys.register() }
        }
        guard preferences.enabled, trusted, !busy, !resizing else { return }
        if let drag, !drag.owned {
            // Native dragging can finish processing after the last dragged event.
            // Poll while held, and recover a missed mouse-up without reusing a preview.
            if NSEvent.pressedMouseButtons & 1 != 0 { moveDrag(to: DisplaySpace.cursor) }
            else { endDrag(at: DisplaySpace.cursor) }
            return
        }
        if keyboard != nil { finishKeyboardIfReleased(NSEvent.modifierFlags); return }
        if NSEvent.pressedMouseButtons != 0 { return }
        updateDivider()
        guard drag == nil, !assistant.isVisible, !groupPicker.isVisible else { return }
        let point = DisplaySpace.cursor
        if preferences.restore, !palette.isVisible, let (window, frame) = windows.restorableTitleBar(at: point),
           window.pid == NSWorkspace.shared.frontmostApplication?.processIdentifier {
            let token = UUID()
            restoreCandidate = (token, window, frame)
            restoredDrag.arm(token: token, at: point)
        } else { restoreCandidate = nil; restoredDrag.disarm() }
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
        guard preferences.enabled, WindowService.trusted else { return }
        if event.type == .flagsChanged { finishKeyboardIfReleased(event.modifierFlags); return }
        if event.type == .keyDown {
            if event.keyCode == 53 { cancel() }
            return
        }
        guard !resizing else { return }
        let point = event.cgEvent?.location ?? DisplaySpace.cursor
        switch event.type {
        case .leftMouseDown:
            cancel()
            dividerPanel?.orderOut(nil)
            if let window = windows.at(point), let frame = window.frame {
                drag = WindowDrag(window: window, startFrame: frame, startCursor: point)
                if preferences.linkedResize {
                    drag?.group = groups.first { group in
                        let frames = group.layout.frames(in: group.display.work)
                        return group.windows.values.contains { $0.id == window.id } && group.windows.allSatisfy { zone, member in
                            member.frame.map { SnapGeometry.nearlyEqual($0, frames[zone]) } ?? false
                        }
                    }
                }
            }
        case .leftMouseDragged:
            moveDrag(to: point)
        case .leftMouseUp:
            endDrag(at: point)
        case .rightMouseDown: cancel()
        default: break
        }
    }

    private func beginOwnedDrag(token: UUID, at point: CGPoint) {
        guard let claim = restoreCandidate, claim.token == token, preferences.enabled, preferences.restore else { return }
        cancel()
        drag = WindowDrag(window: claim.window, startFrame: claim.frame, startCursor: point, owned: true)
        windows.raise(claim.window)
    }

    private func moveDrag(to point: CGPoint) {
            guard var current = drag else { return }
            if !current.owned, let group = current.group, let frame = current.window.frame,
               let zone = group.windows.first(where: { $0.value.id == current.window.id })?.key,
               let (_, layout) = group.layout.nativeResize(zone: zone, from: current.startFrame, to: frame, work: group.display.work) {
                if groupResize == nil { beginGroupResize(group) }
                streamGroupResize(layout, excluding: current.window.id)
                return
            }
            if let resize = groupResize {
                streamGroupResize(resize.baseline, excluding: current.window.id)
                return
            }
            if !current.moving {
                // Text selection, tabs, and native edge-resizing must not become window drags.
                let travel = hypot(point.x-current.startCursor.x, point.y-current.startCursor.y)
                if current.owned { guard travel >= 6 else { return } }
                else {
                    guard let frame = current.window.frame,
                          SnapGeometry.isWindowMove(from: current.startFrame, to: frame, cursorTravel: travel) else { return }
                }
                current.moving = true
                detach(current.window)
            }
            guard let display = DisplaySpace.containing(point) else { return }
            if current.owned, let original = current.window.originalFrame {
                let frame = SnapGeometry.restoredDragFrame(original: original, start: current.startFrame,
                    grab: current.startCursor, cursor: point, work: display.work)
                let now = ProcessInfo.processInfo.systemUptime
                if now - current.lastWrite >= 1.0/30 {
                    _ = windows.writeGeometry(frame, to: current.window, resize: current.lastWrittenFrame?.size != frame.size)
                    current.lastWrittenFrame = frame; current.lastWrite = now
                }
            }
            let sameDisplay = current.display?.id == display.id
            current.display = display
            // Never resize while the destination app owns a native drag session.
            if palette.isVisible, !sameDisplay { palette.hide() }
            if preferences.topBar, point.y <= display.work.minY + 12, abs(point.x - display.work.midX) < display.work.width * 0.32, !palette.isVisible {
                openPalette(for: current.window, on: display, dragging: true)
            }
            let paletteTarget = palette.isVisible ? palette.target(at: point) : nil
            if palette.isVisible, let rect = palette.quartzFrame, point.y > rect.maxY + 40 { palette.hide() }
            current.target = paletteTarget ?? SnapGeometry.dragTarget(at: point, screen: display.frame,
                                                                       previous: sameDisplay ? current.target : nil, threshold: edgeThreshold)
            if let target = current.target { preview.show(target.layout.frames(in: display.work)[target.zone]) }
            else { preview.hide() }
            drag = current
    }

    private func endDrag(at point: CGPoint, retry: Bool = true) {
            if groupResize != nil { drag = nil; finishGroupResize(); return }
            guard var current = drag else { return }
            if retry, current.releasePending { return }
            if !current.owned, !current.moving, let frame = current.window.frame {
                current.moving = SnapGeometry.isWindowMove(from: current.startFrame, to: frame,
                    cursorTravel: hypot(point.x-current.startCursor.x, point.y-current.startCursor.y))
            }
            if retry, !current.owned, !current.moving, hypot(point.x-current.startCursor.x, point.y-current.startCursor.y) >= 6 {
                // A fast drag can deliver mouse-up before AX publishes its move.
                // One cancellable delayed read distinguishes it from text selection.
                current.releasePending = true; drag = current
                let token = operation
                DispatchQueue.main.asyncAfter(deadline: .now()+0.09) { [weak self] in
                    guard let self, token == self.operation else { return }
                    self.endDrag(at: point, retry: false)
                }
                return
            }
            let display = DisplaySpace.containing(point)
            let target = display.flatMap { screen in
                (palette.isVisible ? palette.target(at: point) : nil) ??
                SnapGeometry.dragTarget(at: point, screen: screen.frame,
                    previous: current.display?.id == screen.id ? current.target : nil, threshold: edgeThreshold)
            }
            drag = nil; palette.hide(); preview.hide()
            if current.moving, let target, let display {
                snap(current.window, target: target, display: display)
            } else if current.moving {
                if preferences.restore, let original = current.window.originalFrame,
                   current.window.snappedFrame != nil, let display {
                    // Keep the original grab point, not a ratio recomputed at the
                    // far-away drop location. For an owned drag this verifies the
                    // final live-restored frame; other title bars restore here.
                    let restored = SnapGeometry.restoredDragFrame(original: original, start: current.startFrame,
                        grab: current.startCursor, cursor: point, work: display.work)
                    restoreAfterDrag(current.window, to: restored)
                } else {
                    current.window.snappedFrame = nil; current.window.originalFrame = nil
                }
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

    /// Explicit fixture-only integration runner. It exercises the production
    /// placement/Assist/group paths but does not pretend to simulate user input.
    func testFixtureIntegration() {
        guard !preferences.fixtureChecksRunning, preferences.enabled, preferences.assist, WindowService.trusted else {
            preferences.fixtureCheckStatus = "Enable snapping, Snap Assist, and Accessibility before running live checks."
            return
        }
        cancel()
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "local.snapbridge.testwindows").map { $0.processIdentifier })
        let members = Array(windows.candidates(sameDisplay: false).filter { pids.contains($0.pid) }.prefix(3))
        guard members.count == 3, let firstFrame = members[0].frame, let display = DisplaySpace.containing(firstFrame),
              members.allSatisfy({ $0.frame.map { DisplaySpace.containing($0)?.id == display.id } ?? false }),
              SnapLayout.available(in: display.work).contains(.thirds) else {
            preferences.fixtureCheckStatus = "Open three disposable test windows on one display large enough for thirds."
            return
        }
        let indexed = Dictionary(uniqueKeysWithValues: members.enumerated().map { ($0.offset, $0.element) })
        let originals = indexed.compactMapValues { $0.frame }
        let ids = Set(members.map(\.id))
        preferences.fixtureChecksRunning = true
        Task { @MainActor in
            var token = self.operation
            var results: [String] = []
            struct CheckFailure: Error { let message: String }
            func require(_ condition: Bool, _ message: String) throws {
                if !condition { throw CheckFailure(message: message) }
            }
            func waitForPlacement() async throws {
                token = self.operation
                for _ in 0..<240 {
                    guard token == self.operation else { throw CancellationError() }
                    if !self.busy { return }
                    try await Task.sleep(nanoseconds: 75_000_000)
                }
                throw CheckFailure(message: "Placement timed out")
            }
            func report(_ message: String) {
                self.preferences.fixtureCheckStatus = (results + [message]).joined(separator: "\n")
            }
            func pass(_ message: String) { results.append("PASS · \(message)"); report("Running…") }
            func matches(_ layout: SnapLayout, count: Int) -> Bool {
                let frames = layout.frames(in: display.work)
                return (0..<count).allSatisfy { i in members[i].frame.map { SnapGeometry.nearlyEqual($0, frames[i]) } ?? false }
            }
            func fill(_ layout: SnapLayout, count: Int) async throws {
                self.snap(members[0], target: SnapTarget(layout, 0), display: display, candidatesFrom: pids)
                try await waitForPlacement()
                try require(self.session != nil && self.assistant.isVisible,
                            "Initial placement/picker failed for \(layout.name): session=\(self.session != nil), visible=\(self.assistant.isVisible), status=\(self.preferences.status)")
                for index in 1..<count {
                    self.choose(members[index])
                    try await waitForPlacement()
                    try require(self.session?.usedWindows.contains(members[index].id) == true || self.groups.first?.windows.values.contains(where: { $0.id == members[index].id }) == true,
                                "Assist did not accept fixture \(index+1): busy=\(self.busy), frame=\(String(describing: members[index].frame)), status=\(self.preferences.status)")
                }
                self.finishAssist()
                try require(matches(layout, count: count), "Final frames did not match \(layout.name)")
            }
            var failure: String?
            do {
                report("Checking actual fixture thumbnails…")
                try require(WindowService.canCapture, "ScreenCaptureKit access is not verified")
                await self.windows.thumbnails(for: members, refreshed: {})
                try require(token == self.operation, "A new gesture interrupted thumbnail checking")
                try require(members.allSatisfy { $0.thumbnail != nil }, "A fixture thumbnail could not be captured")
                pass("Actual ScreenCaptureKit thumbnails for all three fixtures")

                for attempt in 1...3 {
                    report("Checking two-window Assist (\(attempt)/3)…")
                    try await fill(.halves, count: 2)
                    pass("Two-window Assist and exact half-screen frames (\(attempt)/3)")
                }
                guard let group = self.groups.first else { throw CheckFailure(message: "No completed snap group") }
                report("Checking shared resize…")
                let baseline = group.windows.compactMapValues { $0.frame }
                let wider = SnapLayout.halves.moving(SnapLayout.halves.boundaries[0], to: 0.6)!
                self.commitGroup(group, layout: wider, originals: baseline, raise: false)
                try await waitForPlacement()
                try require(matches(wider, count: 2) && group.layout == wider, "Linked group resize failed")
                pass("Verified shared group resize to 60/40")

                report("Checking group recall after moving and minimizing a member…")
                let floating = CGRect(x: display.work.minX+80, y: display.work.minY+90, width: 600, height: 400)
                let moved = await self.windows.place(floating, to: members[0], cancelled: { token != self.operation })
                try require(moved == .placed, "Could not move fixture before recall")
                let minimized = await self.windows.setMinimized(true, window: members[1], cancelled: { token != self.operation })
                try require(minimized == .placed, "Could not minimize fixture before recall: \(minimized)")
                self.restoreGroup(group)
                try await waitForPlacement()
                try require(matches(wider, count: 2) && !AXRead.bool(members[1].ax, kAXMinimizedAttribute), "Group recall/unminimize failed")
                pass("Group recall restores moved and minimized members")

                for layout in [SnapLayout.thirds, .leftStack, .quarters] {
                    report("Checking \(layout.name)…")
                    try await fill(layout, count: 3)
                    pass("\(layout.name) placement through sequential Assist")
                }

                report("Checking refused-size rollback…")
                let before = members[0].frame!
                let refused = CGRect(x: before.minX, y: before.minY, width: 100, height: 100)
                let result = await self.windows.placeGroup([0: members[0]], targets: [0: refused], originals: [0: before], cancelled: { token != self.operation })
                try require(result == .rolledBack && members[0].frame.map { SnapGeometry.nearlyEqual($0, before) } == true,
                            "Minimum-size refusal did not produce verified rollback")
                pass("Refused-size transaction restores the original frame")
            } catch {
                failure = (error as? CheckFailure)?.message ?? "Interrupted by a new gesture"
            }
            if token == self.operation {
                report("Restoring fixture starting frames…")
                self.finishAssist()
                var allVisible = true
                for member in members {
                    let visible = await self.windows.setMinimized(false, window: member, cancelled: { token != self.operation })
                    if visible != .placed { allVisible = false }
                }
                let result = await self.windows.placeGroup(indexed, targets: originals,
                                                          originals: indexed.compactMapValues { $0.frame }, cancelled: { token != self.operation })
                if token == self.operation {
                    self.groups.removeAll { $0.windows.values.contains { ids.contains($0.id) } }
                    for member in members { member.originalFrame = nil; member.snappedFrame = nil; member.thumbnail = nil }
                    self.groupsChanged?()
                    if result == .placed && allVisible { results.append("PASS · Fixture starting frames restored and all three visible") }
                    else { failure = [failure, "Fixture restoration failed; reposition the disposable windows"].compactMap { $0 }.joined(separator: "; ") }
                }
            } else { failure = "Interrupted by a new gesture; no restoration was attempted over the new gesture" }
            self.preferences.fixtureChecksRunning = false
            self.preferences.fixtureCheckStatus = (results + [failure.map { "STOPPED · \($0)" } ?? "\(results.count) live checks passed. Physical gestures and picker input remain separate acceptance checks."]).joined(separator: "\n")
        }
    }

    private func openPalette(for window: ManagedWindow, on display: DisplaySpace, anchor: CGRect? = nil, dragging: Bool) {
        guard !SnapLayout.available(in: display.work).isEmpty else {
            if !dragging { toast.show("This display’s usable area is too small for the available layouts.") }
            return
        }
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
            self.busy = false
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
        preferences.status = "Placing \(window.appName) · position \(zone+1)"
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.windows.place(target, to: window, cancelled: { token != self.operation })
            guard token == self.operation else { return }
            guard result == .placed else {
                let diagnostic = "\(self.windows.lastPlacementResult); actual \(String(describing: window.frame)); requested \(target)"
                let rollback = await self.windows.place(previous, to: window, cancelled: { token != self.operation })
                guard token == self.operation else { return }
                self.busy = false
                self.preferences.status = "Second placement did not settle: \(diagnostic)"
                self.toast.show(rollback == .placed
                    ? "\(window.appName) won’t fit this zone. Choose another window."
                    : "\(window.appName) couldn’t be restored. Please reposition it.")
                return
            }
            if window.originalFrame == nil { window.originalFrame = previous }
            self.detach(window); window.snappedFrame = target
            self.windows.raise(window)
            self.session?.choose(window.id)
            self.showNextChoice()
            self.busy = false
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
        let originals = group.windows.compactMapValues { $0.frame }
        guard originals.count == group.windows.count, group.windows.values.allSatisfy({ !AXRead.bool($0.ax, "AXFullScreen") }) else {
            toast.show("A group window is closed or in full screen. The remaining windows were not moved."); return
        }
        group.display = display
        commitGroup(group, layout: group.layout, originals: originals, raise: true)
    }

    func openGroups() {
        cancel()
        groups.removeAll { group in group.windows.values.allSatisfy { NSRunningApplication(processIdentifier: $0.pid) == nil } }
        guard !groups.isEmpty, let display = DisplaySpace.containing(DisplaySpace.cursor) else {
            toast.show("Snap two or more windows together to create a group."); return
        }
        groupPicker.show(groups: groups, on: display, choose: { [weak self] in self?.restoreGroup($0) }, cancel: { [weak self] in self?.cancel() })
    }

    private func shortcut(_ action: Hotkeys.Action) {
        guard preferences.enabled else { return }
        if action == .layouts { openLayouts(); return }
        if action == .group { if let group = groups.first { restoreGroup(group) }; return }
        if action == .groups { openGroups(); return }
        let keys: [Hotkeys.Action: SnapKey] = [.left: .left, .right: .right, .up: .up, .down: .down]
        if let key = keys[action] { previewKeyboard(key); return }
        guard WindowService.trusted, let window = windows.focused(), let frame = window.frame,
              let display = DisplaySpace.containing(frame) else { return }
        cancel()
        switch action {
        case .vertical:
            if window.originalFrame == nil { window.originalFrame = frame }
            placeStandalone(window, at: SnapGeometry.verticallyMaximized(frame, in: display.work), restoring: false)
        case .previousDisplay, .nextDisplay:
            let displays = DisplaySpace.all.sorted { $0.frame.minX < $1.frame.minX }
            guard displays.count > 1, let index = displays.firstIndex(where: { $0.id == display.id }) else { return }
            let next = displays[(index + (action == .nextDisplay ? 1 : displays.count-1)) % displays.count]
            let relative = CGRect(x: (frame.minX-display.work.minX)/display.work.width, y: (frame.minY-display.work.minY)/display.work.height,
                                  width: frame.width/display.work.width, height: frame.height/display.work.height)
            let destination = SnapLayout("transfer", "Transfer", [relative]).frames(in: next.work)[0]
            placeStandalone(window, at: destination, restoring: true)
        default: break
        }
    }

    private func previewKeyboard(_ key: SnapKey) {
        if keyboard == nil {
            guard WindowService.trusted, let window = windows.focused(), let frame = window.frame,
                  let display = DisplaySpace.containing(frame) else { return }
            cancel()
            keyboard = KeyboardSession(window: window, display: display, original: window.originalFrame ?? frame,
                sequence: KeyboardSequence(placement: KeyboardPlacement.matching(frame, work: display.work),
                                           canRestore: window.originalFrame.map { !SnapGeometry.nearlyEqual($0, frame) } ?? false))
        }
        guard var session = keyboard else { return }
        session.sequence.press(key)
        keyboard = session
        if session.sequence.minimize { preview.hide() }
        else { preview.show(session.sequence.placement.target.map { $0.layout.frames(in: session.display.work)[$0.zone] } ?? session.original) }
        preferences.status = "Release Control or Option to place · Esc to cancel"
        finishKeyboardIfReleased(NSEvent.modifierFlags)
    }

    private func finishKeyboardIfReleased(_ flags: NSEvent.ModifierFlags) {
        guard let session = keyboard, !flags.contains([.control, .option]) else { return }
        keyboard = nil; preview.hide()
        if session.sequence.minimize {
            detach(session.window)
            AXUIElementSetAttributeValue(session.window.ax, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        } else if let target = session.sequence.placement.target {
            snap(session.window, target: target, display: session.display)
        } else { placeStandalone(session.window, at: session.original, restoring: true) }
    }

    private func placeStandalone(_ window: ManagedWindow, at target: CGRect, restoring: Bool) {
        guard let original = window.frame else { return }
        operation += 1; let token = operation; busy = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.windows.placeGroup([0: window], targets: [0: target], originals: [0: original], cancelled: { token != self.operation })
            guard token == self.operation else { return }
            self.busy = false
            if result == .placed {
                self.detach(window)
                window.snappedFrame = restoring ? nil : target
                if restoring { window.originalFrame = nil }
            } else {
                self.toast.show(result == .rolledBack ? "This window refused the size. Its previous position was restored." : "This window could not be placed or restored. Please reposition it.")
            }
        }
    }

    private func invalidate(_ group: SnapGroup) {
        groups.removeAll { $0.id == group.id }
        for member in group.windows.values { member.snappedFrame = nil }
        groupsChanged?()
    }

    private func beginGroupResize(_ group: SnapGroup) {
        operation += 1
        let frames = group.layout.frames(in: group.display.work)
        groupResize = GroupResize(group: group, baseline: group.layout,
                                  originals: Dictionary(uniqueKeysWithValues: group.windows.keys.map { ($0, frames[$0]) }), layout: group.layout)
    }

    private func streamGroupResize(_ layout: SnapLayout, excluding: UUID? = nil) {
        guard var resize = groupResize else { return }
        resize.layout = layout
        let now = ProcessInfo.processInfo.systemUptime
        if now - resize.lastWrite >= 1.0/20 {
            let frames = layout.frames(in: resize.group.display.work)
            for (zone, window) in resize.group.windows where window.id != excluding {
                _ = windows.writeGeometry(frames[zone], to: window)
            }
            resize.lastWrite = now
        }
        groupResize = resize
    }

    private func finishGroupResize() {
        guard let resize = groupResize else { return }
        groupResize = nil; resizing = false; dividerPanel?.orderOut(nil)
        commitGroup(resize.group, layout: resize.layout, originals: resize.originals, raise: false)
    }

    private func commitGroup(_ group: SnapGroup, layout: SnapLayout, originals: [Int: CGRect], raise: Bool) {
        operation += 1; let token = operation; busy = true
        let frames = layout.frames(in: group.display.work)
        let targets = Dictionary(uniqueKeysWithValues: group.windows.keys.map { ($0, frames[$0]) })
        Task { @MainActor [weak self] in
            // Let the source app finish its native edge-resize / unminimize first.
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let self, token == self.operation else { return }
            if raise {
                for window in group.windows.values {
                    let visible = await self.windows.setMinimized(false, window: window, cancelled: { token != self.operation })
                    guard token == self.operation else { return }
                    guard visible == .placed else {
                        self.busy = false
                        self.toast.show("A group window could not be unminimized. Its saved layout was kept for another attempt.")
                        return
                    }
                }
            }
            let result = await self.windows.placeGroup(group.windows, targets: targets, originals: originals, cancelled: { token != self.operation })
            guard token == self.operation else { return }
            if result == .placed {
                group.layout = layout
                for (zone, window) in group.windows.sorted(by: { $0.key < $1.key }) {
                    window.snappedFrame = frames[zone]
                    if raise { self.windows.raise(window) }
                }
                self.preferences.status = "Group ready · \(group.windows.count) windows"
            } else {
                // A successful rollback may be to arbitrary pre-recall positions.
                // Only retain membership when all windows still match its layout.
                let baseline = group.layout.frames(in: group.display.work)
                if !group.windows.allSatisfy({ zone, window in window.frame.map { SnapGeometry.nearlyEqual($0, baseline[zone]) } ?? false }) {
                    self.invalidate(group)
                }
                self.toast.show(result == .rolledBack ? "A window reached its size limit. The group’s previous positions were restored." : "The group could not be restored completely. Please reposition the affected windows.")
            }
            self.busy = false
        }
    }

    private func updateDivider() {
        guard !groups.isEmpty, preferences.linkedResize, !assistant.isVisible, !palette.isVisible, !groupPicker.isVisible else { dividerPanel?.orderOut(nil); return }
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
            view.began = { [weak self] in
                self?.beginGroupResize(group); self?.resizing = true
            }
            view.moved = { [weak self] point in
                guard let self else { return }
                let fraction = vertical ? (point.x-work.minX)/work.width : (point.y-work.minY)/work.height
                guard let layout = baseline.moving(boundary, to: fraction) else { return }
                self.streamGroupResize(layout)
            }
            view.ended = { [weak self] in self?.finishGroupResize() }
            panel.contentView = view; panel.orderFrontRegardless(); dividerPanel = panel
            return
        }
        dividerPanel?.orderOut(nil)
    }
}

final class Hotkeys {
    enum Action: UInt32 { case left = 1, right, up, down, layouts, group, previousDisplay, nextDisplay, groups, vertical }
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
            (.previousDisplay, 123, UInt32(shiftKey)), (.nextDisplay, 124, UInt32(shiftKey)),
            (.groups, 5, UInt32(shiftKey)), (.vertical, 126, UInt32(shiftKey))
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
