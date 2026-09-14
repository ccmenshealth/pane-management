import AppKit
import SnapCore

private let accent = NSColor(calibratedRed: 0.36, green: 0.64, blue: 1, alpha: 1)
private let surface = NSColor(calibratedWhite: 0.11, alpha: 0.98)
private let secondary = NSColor(calibratedWhite: 0.68, alpha: 1)

/// Real AppKit controls keep custom-drawn cards operable through standard
/// Accessibility press actions, not only coordinate clicks on a painted view.
private final class OverlayActionButton: NSButton {
    var invoked: (() -> Void)?
    init(frame: CGRect, label: String, action: @escaping () -> Void) {
        super.init(frame: frame)
        title = label; isTransparent = true; isBordered = false
        setAccessibilityLabel(label)
        target = self; self.action = #selector(activate)
        invoked = action
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func activate() { invoked?() }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityChildren() -> [Any]? { [] }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, let invoked else { return false }
        invoked(); return true
    }
}

private final class AccessibleButton: NSAccessibilityElement {
    var action: (() -> Void)?
    override func accessibilityPerformPress() -> Bool { action?(); return action != nil }
}

private func accessibleButton(in view: NSView, rect: CGRect, title: String, action: @escaping () -> Void) -> NSAccessibilityElement {
    let button = AccessibleButton()
    button.setAccessibilityRole(.button)
    button.setAccessibilityLabel(title)
    button.setAccessibilityParent(view)
    if let window = view.window { button.setAccessibilityFrame(window.convertToScreen(view.convert(rect, to: nil))) }
    button.action = action
    return button
}

private func rounded(_ rect: CGRect, color: NSColor, radius: CGFloat = 10, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill(); path.fill()
    if let stroke { stroke.setStroke(); path.lineWidth = 1; path.stroke() }
}

private func label(_ value: String, rect: CGRect, size: CGFloat = 13, color: NSColor = .white, weight: NSFont.Weight = .regular) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    (value as NSString).draw(in: rect, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph
    ])
}

final class OverlayPanel: NSPanel {
    var allowsKeys = true
    override var canBecomeKey: Bool { allowsKeys }
    override var canBecomeMain: Bool { false }
    init(frame: CGRect, interactive: Bool = true) {
        super.init(contentRect: DisplaySpace.cocoa(frame), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = true
        level = .floating; hidesOnDeactivate = false; isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        ignoresMouseEvents = !interactive; allowsKeys = interactive
        appearance = NSAppearance(named: .darkAqua)
    }
}

final class PreviewView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        rounded(bounds.insetBy(dx: 3, dy: 3), color: accent.withAlphaComponent(0.22), radius: 12, stroke: accent.withAlphaComponent(0.85))
    }
}

final class PreviewOverlay {
    private var panel: OverlayPanel?
    func show(_ rect: CGRect) {
        if panel == nil {
            panel = OverlayPanel(frame: rect, interactive: false)
            panel?.hasShadow = false; panel?.contentView = PreviewView()
            panel?.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        }
        panel?.setFrame(DisplaySpace.cocoa(rect), display: true)
        panel?.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil) }
}

final class LayoutPaletteView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var selection: SnapTarget? { didSet { needsDisplay = true } }
    var layouts: [SnapLayout] = []
    private var numberedLayout: Int?
    var choose: ((SnapTarget) -> Void)?
    var cancel: (() -> Void)?
    var hover: ((SnapTarget?) -> Void)?
    private var tracking: NSTrackingArea?
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { "Snap layouts" }
    override func accessibilityChildren() -> [Any]? {
        if !subviews.isEmpty { return subviews }
        var children: [NSAccessibilityElement] = []
        for (index, layout) in layouts.enumerated() {
            for (zone, rect) in layout.frames(in: layoutRect(index), gap: 4).enumerated() {
                children.append(accessibleButton(in: self, rect: rect, title: "\(layout.name), position \(zone+1)") { [weak self] in
                    self?.choose?(SnapTarget(layout, zone))
                })
            }
        }
        return children
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        subviews.forEach { $0.removeFromSuperview() }
        for (index, layout) in layouts.enumerated() {
            for (zone, rect) in layout.frames(in: layoutRect(index), gap: 4).enumerated() {
                addSubview(OverlayActionButton(frame: rect, label: "\(layout.name), position \(zone+1)") { [weak self] in self?.choose?(SnapTarget(layout, zone)) })
            }
        }
    }
    var columns: Int { layouts.count > 4 ? 3 : 2 }
    var cellSize: CGSize { CGSize(width: (bounds.width - CGFloat(columns + 1) * 16) / CGFloat(columns), height: 64) }
    func layoutRect(_ index: Int) -> CGRect {
        CGRect(x: 16 + CGFloat(index % columns) * (cellSize.width + 16), y: 48 + CGFloat(index / columns) * 98,
               width: cellSize.width, height: cellSize.height)
    }
    func target(at point: CGPoint) -> SnapTarget? {
        for (index, layout) in layouts.enumerated() {
            let rect = layoutRect(index)
            for (zone, frame) in layout.frames(in: rect, gap: 4).enumerated() where frame.contains(point) {
                return SnapTarget(layout, zone)
            }
        }
        return nil
    }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited], owner: self)
        addTrackingArea(tracking!)
        super.updateTrackingAreas()
    }
    override func mouseMoved(with event: NSEvent) {
        selection = target(at: convert(event.locationInWindow, from: nil)); hover?(selection)
    }
    override func mouseExited(with event: NSEvent) { selection = nil; hover?(nil) }
    override func mouseUp(with event: NSEvent) {
        if let target = target(at: convert(event.locationInWindow, from: nil)) { choose?(target) }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancel?(); return }
        if event.keyCode == 36, let selection { choose?(selection); return }
        guard !layouts.isEmpty else { return }
        if let text = event.charactersIgnoringModifiers, let number = Int(text), number > 0 {
            if let index = numberedLayout {
                if layouts[index].zones.indices.contains(number-1) { choose?(SnapTarget(layouts[index], number-1)) }
            } else if layouts.indices.contains(number-1) {
                numberedLayout = number-1
                selection = SnapTarget(layouts[number-1], 0); hover?(selection)
            }
            return
        }
        numberedLayout = nil
        var index = selection.flatMap { selected in layouts.firstIndex { $0.id == selected.layout.id } } ?? 0
        var zone = selection?.zone ?? 0
        switch event.keyCode {
        case 48: index = (index + (event.modifierFlags.contains(.shift) ? layouts.count-1 : 1)) % layouts.count; zone = 0
        case 123: zone = (zone + layouts[index].zones.count - 1) % layouts[index].zones.count
        case 124: zone = (zone + 1) % layouts[index].zones.count
        case 125: index = (index + columns) % layouts.count; zone = 0
        case 126: index = (index + layouts.count - columns) % layouts.count; zone = 0
        default: return
        }
        selection = SnapTarget(layouts[index], zone); hover?(selection)
    }
    override func draw(_ dirtyRect: NSRect) {
        rounded(bounds.insetBy(dx: 1, dy: 1), color: surface, radius: 16, stroke: .white.withAlphaComponent(0.16))
        label(numberedLayout == nil ? "Choose a layout" : "Now choose a position number", rect: CGRect(x: 18, y: 16, width: bounds.width-36, height: 22), size: 14, weight: .semibold)
        for (index, layout) in layouts.enumerated() {
            let rect = layoutRect(index)
            for (zone, frame) in layout.frames(in: rect, gap: 4).enumerated() {
                let selected = selection == SnapTarget(layout, zone)
                rounded(frame, color: selected ? accent : NSColor(calibratedWhite: 0.26, alpha: 1), radius: 5,
                        stroke: .white.withAlphaComponent(selected ? 0.6 : 0.12))
                if numberedLayout == index { label("\(zone+1)", rect: CGRect(x: frame.midX-4, y: frame.midY-8, width: 16, height: 18), size: 12) }
            }
            label("\(index+1)  \(layout.name)", rect: CGRect(x: rect.minX + 2, y: rect.maxY + 5, width: rect.width, height: 16), size: 11, color: secondary)
        }
        label("Number: layout, then position · Tab / arrows · Return · Esc",
              rect: CGRect(x: 18, y: bounds.height - 27, width: bounds.width - 36, height: 18), size: 11, color: secondary)
    }
}

final class LayoutOverlay {
    private(set) var panel: OverlayPanel?
    private(set) var view: LayoutPaletteView?
    var isVisible: Bool { panel?.isVisible == true }
    var quartzFrame: CGRect? { panel.map { DisplaySpace.cocoa($0.frame) } }
    func show(on display: DisplaySpace, near anchor: CGRect? = nil, dragging: Bool,
              choose: @escaping (SnapTarget) -> Void, hover: @escaping (SnapTarget?) -> Void, cancel: @escaping () -> Void) {
        hide()
        let layouts = SnapLayout.available(in: display.work)
        guard !layouts.isEmpty else { return }
        let columns = layouts.count > 4 ? 3 : 2
        let rows = Int(ceil(Double(layouts.count) / Double(columns)))
        let width = min(510, display.work.width - 16), height: CGFloat = CGFloat(rows) * 98 + 70
        let x = min(display.work.maxX - width - 8, max(display.work.minX + 8, anchor?.minX ?? display.work.midX - width/2))
        let y = min(display.work.maxY - height - 8, max(display.work.minY + 8, anchor.map { $0.maxY + 8 } ?? display.work.minY + 12))
        let panel = OverlayPanel(frame: CGRect(x: x, y: y, width: width, height: height), interactive: !dragging)
        let view = LayoutPaletteView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.layouts = layouts
        view.choose = choose; view.hover = hover; view.cancel = cancel
        panel.contentView = view; panel.orderFrontRegardless()
        if !dragging { view.selection = SnapTarget(layouts[0], 0); panel.makeKey(); panel.makeFirstResponder(view) }
        self.panel = panel; self.view = view
    }
    func target(at quartzPoint: CGPoint) -> SnapTarget? {
        guard let rect = quartzFrame else { return nil }
        let target = view?.target(at: CGPoint(x: quartzPoint.x - rect.minX, y: quartzPoint.y - rect.minY))
        view?.selection = target; return target
    }
    func hide() { panel?.orderOut(nil); panel = nil; view = nil }
}

struct AssistCardFeedback {
    let detail: String
    let actionLabel: String?
}

final class AssistView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var windows: [ManagedWindow] = []
    var choose: ((ManagedWindow) -> Void)?
    var cancel: (() -> Void)?
    var skip: (() -> Void)?
    var subtitle = ""
    var feedback: [UUID: AssistCardFeedback] = [:] { didSet { installActions(); needsDisplay = true } }
    var selected = 0
    var page = 0 { didSet { installActions() } }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { "Snap Assist. What goes here?" }
    override func accessibilityChildren() -> [Any]? {
        if !subviews.isEmpty { return subviews }
        var children: [NSAccessibilityElement] = []
        for index in 0..<perPage where windows.indices.contains(page * perPage + index) {
            let window = windows[page * perPage + index]
            let button = accessibleButton(in: self, rect: cardRect(index), title: cardLabel(window)) { [weak self] in self?.activate(window) }
            button.setAccessibilityEnabled(canChoose(window))
            children.append(button)
        }
        children.append(accessibleButton(in: self, rect: CGRect(x: 15, y: bounds.height-43, width: 80, height: 35), title: "Skip zone") { [weak self] in self?.skip?() })
        children.append(accessibleButton(in: self, rect: CGRect(x: bounds.width-50, y: 10, width: 40, height: 35), title: "Dismiss Snap Assist") { [weak self] in self?.cancel?() })
        if pageCount > 1 {
            children.append(accessibleButton(in: self, rect: CGRect(x: bounds.width-75, y: bounds.height-43, width: 70, height: 35), title: "Next page") { [weak self] in
                guard let self else { return }; self.page = (self.page + 1) % self.pageCount; self.needsDisplay = true
            })
        }
        return children
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); installActions() }
    private func installActions() {
        guard window != nil else { return }
        subviews.forEach { $0.removeFromSuperview() }
        for index in 0..<perPage where windows.indices.contains(page*perPage+index) {
            let candidate = windows[page*perPage+index]
            let button = OverlayActionButton(frame: cardRect(index), label: cardLabel(candidate)) { [weak self] in self?.activate(candidate) }
            button.isEnabled = canChoose(candidate)
            addSubview(button)
        }
        addSubview(OverlayActionButton(frame: CGRect(x: 15, y: bounds.height-43, width: 80, height: 35), label: "Skip zone") { [weak self] in self?.skip?() })
        addSubview(OverlayActionButton(frame: CGRect(x: bounds.width-50, y: 10, width: 40, height: 35), label: "Dismiss Snap Assist") { [weak self] in self?.cancel?() })
        if pageCount > 1 {
            addSubview(OverlayActionButton(frame: CGRect(x: bounds.width-75, y: bounds.height-43, width: 70, height: 35), label: "Next page") { [weak self] in
                guard let self else { return }
                self.page = (self.page+1) % self.pageCount; self.selected = self.page*self.perPage; self.needsDisplay = true
            })
        }
    }
    private func canChoose(_ candidate: ManagedWindow) -> Bool {
        feedback[candidate.id].map { $0.actionLabel != nil } ?? true
    }
    private func activate(_ candidate: ManagedWindow) {
        if canChoose(candidate) { choose?(candidate) }
    }
    private func cardLabel(_ candidate: ManagedWindow) -> String {
        let base = "\(candidate.appName): \(candidate.title)"
        guard let issue = feedback[candidate.id] else { return base }
        return "\(base). \(issue.detail). \(issue.actionLabel ?? "Unavailable for this zone; choose another window")"
    }
    var columns: Int { bounds.width > 650 ? 3 : (bounds.width > 370 ? 2 : 1) }
    var rows: Int { max(1, min(3, Int((bounds.height - 150) / 160))) }
    var perPage: Int { columns * rows }
    var pageCount: Int { max(1, Int(ceil(Double(windows.count) / Double(perPage)))) }
    var cardHeight: CGFloat { max(70, min(210, (bounds.height - 150) / CGFloat(rows))) }
    func cardRect(_ visibleIndex: Int) -> CGRect {
        let width = (bounds.width - 32 - CGFloat(columns - 1) * 10) / CGFloat(columns)
        return CGRect(x: 16 + CGFloat(visibleIndex % columns) * (width + 10),
                      y: 84 + CGFloat(visibleIndex / columns) * cardHeight,
                      width: width, height: cardHeight - 10)
    }
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.y < 45 && point.x > bounds.width - 55 { cancel?(); return }
        if point.y > bounds.height - 43 {
            if point.x < 90 { skip?() }
            else if point.x > bounds.width - 75 { page = (page + 1) % pageCount; selected = page*perPage; needsDisplay = true }
            return
        }
        for index in 0..<perPage where page * perPage + index < windows.count && cardRect(index).contains(point) {
            activate(windows[page * perPage + index]); return
        }
    }
    override func scrollWheel(with event: NSEvent) {
        guard abs(event.scrollingDeltaY) > 2 else { return }
        page = min(pageCount - 1, max(0, page + (event.scrollingDeltaY < 0 ? 1 : -1))); selected = page*perPage; needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: cancel?()
        case 36: if windows.indices.contains(selected) { activate(windows[selected]) }
        case 48: selected += event.modifierFlags.contains(.shift) ? -1 : 1
        case 123: selected -= 1
        case 124: selected += 1
        case 125: selected += columns
        case 126: selected -= columns
        case 49: skip?()
        default: return
        }
        if !windows.isEmpty { selected = (selected + windows.count) % windows.count; page = selected / perPage }
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        rounded(bounds.insetBy(dx: 1, dy: 1), color: surface.withAlphaComponent(0.96), radius: 18, stroke: .white.withAlphaComponent(0.18))
        label("What goes here?", rect: CGRect(x: 20, y: 20, width: bounds.width - 80, height: 25), size: 20, weight: .semibold)
        label("×", rect: CGRect(x: bounds.width - 43, y: 15, width: 30, height: 32), size: 26, color: secondary)
        label(subtitle, rect: CGRect(x: 20, y: 51, width: bounds.width - 40, height: 20), size: 12, color: secondary)
        for index in 0..<perPage {
            let absolute = page * perPage + index
            guard windows.indices.contains(absolute) else { continue }
            let window = windows[absolute], rect = cardRect(index)
            rounded(rect, color: NSColor(calibratedWhite: 0.19, alpha: 1), radius: 10,
                    stroke: absolute == selected ? accent : .white.withAlphaComponent(0.09))
            let issue = feedback[window.id]
            let preview = CGRect(x: rect.minX + 8, y: rect.minY + 8, width: rect.width - 16, height: max(10, rect.height - (issue == nil ? 53 : 75)))
            if let image = window.thumbnail {
                let scale = min(preview.width / max(1, image.size.width), preview.height / max(1, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: CGRect(x: preview.midX - size.width/2, y: preview.midY - size.height/2, width: size.width, height: size.height),
                           from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } else if let icon = window.icon {
                let side = min(48, preview.height)
                icon.draw(in: CGRect(x: preview.midX - side/2, y: preview.midY - side/2, width: side, height: side),
                          from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            if let issue {
                label(window.appName, rect: CGRect(x: rect.minX+10, y: rect.maxY-60, width: rect.width-20, height: 17), size: 12, weight: .medium)
                label(issue.detail, rect: CGRect(x: rect.minX+10, y: rect.maxY-42, width: rect.width-20, height: 16), size: 10, color: .systemOrange)
                label(issue.actionLabel ?? "Choose another window", rect: CGRect(x: rect.minX+10, y: rect.maxY-23, width: rect.width-20, height: 17), size: 11, color: issue.actionLabel == nil ? secondary : accent)
            } else {
                label(window.title, rect: CGRect(x: rect.minX + 10, y: rect.maxY - 38, width: rect.width - 20, height: 17), size: 12, weight: .medium)
                label(window.appName, rect: CGRect(x: rect.minX + 10, y: rect.maxY - 20, width: rect.width - 20, height: 16), size: 10, color: secondary)
            }
        }
        label("Skip zone", rect: CGRect(x: 20, y: bounds.height - 31, width: 80, height: 18), size: 12, color: accent)
        label("Esc to dismiss", rect: CGRect(x: 112, y: bounds.height - 31, width: bounds.width - 190, height: 18), size: 11, color: secondary)
        if pageCount > 1 { label("\(page+1)/\(pageCount)  →", rect: CGRect(x: bounds.width - 70, y: bounds.height - 31, width: 60, height: 18), size: 12, color: accent) }
    }
}

final class AssistOverlay {
    private(set) var panel: OverlayPanel?
    private(set) var view: AssistView?
    var isVisible: Bool { panel?.isVisible == true }
    func show(in rect: CGRect, windows: [ManagedWindow], subtitle: String,
              choose: @escaping (ManagedWindow) -> Void, skip: @escaping () -> Void, cancel: @escaping () -> Void) {
        hide()
        let frame = rect.insetBy(dx: 8, dy: 8)
        let panel = OverlayPanel(frame: frame)
        let view = AssistView(frame: CGRect(origin: .zero, size: frame.size))
        view.windows = windows; view.subtitle = subtitle; view.choose = choose; view.skip = skip; view.cancel = cancel
        panel.contentView = view; panel.orderFrontRegardless(); panel.makeKey(); panel.makeFirstResponder(view)
        self.panel = panel; self.view = view
    }
    func hide() { panel?.orderOut(nil); panel = nil; view = nil }
}

final class DividerView: NSView {
    var vertical = true
    var began: (() -> Void)?
    var moved: ((CGPoint) -> Void)?
    var ended: (() -> Void)?
    override func resetCursorRects() { addCursorRect(bounds, cursor: vertical ? .resizeLeftRight : .resizeUpDown) }
    override func draw(_ dirtyRect: NSRect) {
        rounded(bounds.insetBy(dx: 2, dy: 2), color: accent, radius: 4)
    }
    override func mouseDown(with event: NSEvent) { began?() }
    override func mouseDragged(with event: NSEvent) { moved?(DisplaySpace.cursor) }
    override func mouseUp(with event: NSEvent) { ended?() }
}

final class GroupPickerView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var groups: [SnapGroup] = []
    var selected = 0 { didSet { installActions() } }
    var choose: ((SnapGroup) -> Void)?
    var cancel: (() -> Void)?
    private var rows: Int { max(1, Int((bounds.height-90)/70)) }
    private var first: Int { selected / rows * rows }
    private func rect(_ row: Int) -> CGRect { CGRect(x: 12, y: 52+CGFloat(row)*70, width: bounds.width-24, height: 62) }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { "Snap groups" }
    override func accessibilityChildren() -> [Any]? {
        if !subviews.isEmpty { return subviews }
        return (0..<rows).compactMap { row in
            guard groups.indices.contains(first+row) else { return nil }
            let group = groups[first+row]
            return accessibleButton(in: self, rect: rect(row), title: "Restore \(group.name)") { [weak self] in self?.choose?(group) }
        }
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); installActions() }
    private func installActions() {
        guard window != nil else { return }
        subviews.forEach { $0.removeFromSuperview() }
        for row in 0..<rows where groups.indices.contains(first+row) {
            let group = groups[first+row]
            addSubview(OverlayActionButton(frame: rect(row), label: "Restore \(group.name)") { [weak self] in self?.choose?(group) })
        }
        addSubview(OverlayActionButton(frame: CGRect(x: bounds.width-50, y: 0, width: 50, height: 44), label: "Close snap groups") { [weak self] in self?.cancel?() })
    }
    override func keyDown(with event: NSEvent) {
        guard !groups.isEmpty else { return }
        switch event.keyCode {
        case 53: cancel?()
        case 36: choose?(groups[selected])
        case 125, 124: selected = (selected+1) % groups.count
        case 126, 123: selected = (selected+groups.count-1) % groups.count
        case 48: selected = (selected+groups.count+(event.modifierFlags.contains(.shift) ? -1 : 1)) % groups.count
        default:
            if let text = event.charactersIgnoringModifiers, let number = Int(text), groups.indices.contains(number-1) { choose?(groups[number-1]) }
        }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.y < 42, point.x > bounds.width-50 { cancel?(); return }
        for row in 0..<rows where groups.indices.contains(first+row) && rect(row).contains(point) { choose?(groups[first+row]); return }
    }
    override func scrollWheel(with event: NSEvent) {
        guard !groups.isEmpty, abs(event.scrollingDeltaY) > 2 else { return }
        selected = min(groups.count-1, max(0, selected + (event.scrollingDeltaY < 0 ? 1 : -1))); needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        rounded(bounds.insetBy(dx: 1, dy: 1), color: surface, radius: 16, stroke: .white.withAlphaComponent(0.18))
        label("Snap groups", rect: CGRect(x: 20, y: 16, width: 240, height: 26), size: 20, weight: .semibold)
        label("×", rect: CGRect(x: bounds.width-40, y: 10, width: 30, height: 32), size: 26, color: secondary)
        for row in 0..<rows where groups.indices.contains(first+row) {
            let index = first+row, group = groups[index], frame = rect(row)
            rounded(frame, color: NSColor(calibratedWhite: 0.19, alpha: 1), radius: 8, stroke: selected == index ? accent : nil)
            let miniature = CGRect(x: frame.minX+10, y: frame.minY+10, width: 70, height: 42)
            for (zone, box) in group.layout.frames(in: miniature, gap: 2).enumerated() {
                rounded(box, color: group.windows[zone] == nil ? .darkGray : accent.withAlphaComponent(0.75), radius: 3)
            }
            label("\(index+1)  \(group.name)", rect: CGRect(x: frame.minX+94, y: frame.minY+10, width: frame.width-108, height: 20), size: 13, weight: .medium)
            label(group.windows.sorted { $0.key < $1.key }.map { $0.value.title }.joined(separator: " · "),
                  rect: CGRect(x: frame.minX+94, y: frame.minY+34, width: frame.width-108, height: 18), size: 11, color: secondary)
        }
        label("↑ ↓ / Tab: choose · Return or number: restore · Esc: close",
              rect: CGRect(x: 20, y: bounds.height-28, width: bounds.width-40, height: 18), size: 11, color: secondary)
    }
}

final class GroupOverlay {
    private var panel: OverlayPanel?
    var isVisible: Bool { panel?.isVisible == true }
    func show(groups: [SnapGroup], on display: DisplaySpace, choose: @escaping (SnapGroup) -> Void, cancel: @escaping () -> Void) {
        hide()
        let width = min(560, display.work.width-24), height = min(CGFloat(groups.count)*70+90, display.work.height-24)
        let panel = OverlayPanel(frame: CGRect(x: display.work.midX-width/2, y: display.work.midY-height/2, width: width, height: height))
        let view = GroupPickerView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.groups = groups; view.choose = choose; view.cancel = cancel
        panel.contentView = view; panel.orderFrontRegardless(); panel.makeKey(); panel.makeFirstResponder(view)
        self.panel = panel
    }
    func hide() { panel?.orderOut(nil); panel = nil }
}

final class ToastOverlay {
    private var panel: OverlayPanel?
    private var dismissal: DispatchWorkItem?
    func show(_ message: String) {
        dismissal?.cancel(); panel?.orderOut(nil)
        guard let display = DisplaySpace.containing(DisplaySpace.cursor) ?? DisplaySpace.all.first else { return }
        let width = min(620, display.work.width - 40)
        let panel = OverlayPanel(frame: CGRect(x: display.work.midX-width/2, y: display.work.minY+32, width: width, height: 62), interactive: false)
        let field = NSTextField(wrappingLabelWithString: message)
        field.font = .systemFont(ofSize: 13); field.textColor = .white; field.alignment = .center
        field.frame = CGRect(x: 18, y: 8, width: width-36, height: 44)
        let background = NSView(frame: CGRect(x: 0, y: 0, width: width, height: 62))
        background.wantsLayer = true; background.layer?.backgroundColor = surface.cgColor; background.layer?.cornerRadius = 12
        background.addSubview(field); panel.contentView = background; panel.orderFrontRegardless(); self.panel = panel
        let item = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        dismissal = item; DispatchQueue.main.asyncAfter(deadline: .now()+4, execute: item)
    }
}
