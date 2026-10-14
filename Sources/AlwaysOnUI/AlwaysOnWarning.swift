import AppKit
import SwiftUI
import Combine
import AlwaysOnCore

extension AlwaysOnState {
    public var heading: String {
        switch self {
        case .checking: return "Checking always-on status"
        case .statusUnverified: return "Always-on status is not yet verified"
        case .off: return "Always-on mode is off"
        case .activating: return "Activating always-on mode…"
        case .active: return "Always-on mode is activated"
        case .stopping: return "Restoring normal sleep…"
        case .recoveryRequired: return "Normal sleep needs recovery"
        case .unavailable: return "Always-on mode is unavailable"
        case .setupRequired: return "Always-on setup needs attention"
        case .removalRequired: return "Finish helper removal"
        }
    }
    public var explanation: String {
        switch self {
        case .checking: return "Checking whether normal sleep is available. Keep Pane Management open until this check finishes."
        case .off: return "Normal sleep is available. Always-on mode must be activated manually."
        case .activating: return "Activation has not been confirmed. Deactivate to cancel and restore normal sleep."
        case .active: return "Your Mac will stay awake even with the lid open. Deactivate before using it normally. Emergency sleep protection is not guaranteed."
        case .stopping: return "Keep Pane Management open. This warning stays until normal sleep has been confirmed."
        case .recoveryRequired(let reason): return "Normal sleep could not be confirmed. \(reason) Keep the Mac out of your bag and retry deactivation."
        case .unavailable(let reason), .setupRequired(let reason): return reason
        case .statusUnverified(let reason): return "\(reason) Window snapping remains available. Keep Pane Management running to finish checking, and do not rely on Always On until its status is confirmed."
        case .removalRequired: return "Normal sleep is verified. Finish removing the helper in Settings before setting it up again."
        }
    }
    public var showsWarning: Bool {
        switch self { case .off, .unavailable, .removalRequired, .statusUnverified: return false; default: return true }
    }
}

extension AlwaysOnController {
    public var explanation: String {
        if action == .wait, case .recoveryRequired(let reason) = state {
            return "\(reason) Keep Pane Management open and wait for completion."
        }
        return state.explanation
    }
    public var actionTitle: String {
        switch action {
        case .activate: return "Activate always-on mode"
        case .deactivate: return state == .active || state == .activating ? "Deactivate" : "Retry deactivation"
        case .checkSetup: return "Check again"
        case .setUp: return "Set up always-on helper"
        case .openSettings: return "Finish helper removal in Settings"
        case .openLoginItems: return "Open Login Items"
        case .wait: return "Please wait…"
        }
    }
}

/// Shared description and actions; Settings pins actions outside its scrolling body.
public struct AlwaysOnControls: View {
    @ObservedObject var controller: AlwaysOnController
    private let actions: Bool
    public init(controller: AlwaysOnController, actions: Bool = true) { self.controller = controller; self.actions = actions }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(controller.state.heading).font(.headline)
            Text(controller.explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
            if actions { AlwaysOnActions(controller: controller) }
        }
    }
}
public struct AlwaysOnActions: View {
    @ObservedObject var controller: AlwaysOnController
    private let settings: Bool
    public init(controller: AlwaysOnController, settings: Bool = false) { self.controller = controller; self.settings = settings }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !settings || controller.action != .openSettings {
                Button(controller.actionTitle) { controller.perform(controller.action) }.disabled(!controller.actionEnabled)
            }
            if let title = controller.secondaryTitle {
                if title == "Open Login Items" {
                    Button(settings ? title : "Approval options in Settings") { controller.perform(settings ? .openLoginItems : .openSettings) }
                        .disabled(settings && !controller.canOpenLoginItems)
                } else if !settings {
                    Button(title) { controller.perform(.openSettings) }
                }
            }
            if settings {
                HStack {
                    if controller.needsRepair {
                        Button("Repair helper setup") { controller.repairHelperFromSettings() }.disabled(!controller.canRemove)
                        if controller.action != .checkSetup {
                            Button("Check again") { controller.checkSetup(manual: true) }.disabled(!controller.canRemove)
                        }
                    }
                    Button("Remove always-on helper") { controller.removeHelperFromSettings() }.disabled(!controller.canRemove)
                }
            }
        }
    }
}

private struct WarningTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Alternating 45-degree bands; clipped by the warning's existing rounded outline.
private struct WarningStripes: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let band: CGFloat = 24
            for x in stride(from: rect.minX - rect.height, through: rect.maxX, by: band * 2) {
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x + band, y: rect.minY))
                path.addLine(to: CGPoint(x: x + band + rect.height, y: rect.maxY))
                path.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}

private struct WarningContent: View {
    @ObservedObject var controller: AlwaysOnController
    let preview: Bool
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                WarningTriangle().fill(Color(red: 0.84, green: 0.015, blue: 0.035))
                Text("!").font(.system(size: 58, weight: .black)).foregroundStyle(.white).offset(y: 9)
            }.frame(width: 96, height: 84).accessibilityLabel("Warning")
            VStack(spacing: 16) {
                Text(controller.state.heading).font(.system(size: 25, weight: .bold))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(controller.explanation).font(.system(size: 15))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Button { controller.perform(controller.action) } label: {
                    Text(controller.actionTitle).font(.system(size: 19, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                }.keyboardShortcut(.defaultAction)
                    .accessibilityHint("Performs the displayed always-on recovery action")
                    .buttonStyle(.borderedProminent).tint(Color(red: 0.84, green: 0.015, blue: 0.035))
                    .disabled(!controller.actionEnabled)
                if let title = controller.secondaryTitle {
                    Button(title == "Open Login Items" ? "Approval options in Settings" : title) { controller.perform(.openSettings) }
                        .fixedSize(horizontal: false, vertical: true)
                }
                if preview {
                    Text("PREVIEW ONLY · No power settings change").font(.caption.bold()).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)).padding(-8))
        }.padding(26).frame(maxWidth: .infinity)
    }
}

private struct WarningView: View {
    @ObservedObject var controller: AlwaysOnController
    let preview: Bool
    let overflow: Bool
    var body: some View {
        Group {
            if overflow {
                ScrollView(.vertical, showsIndicators: false) {
                    WarningContent(controller: controller, preview: preview)
                }
            } else {
                WarningContent(controller: controller, preview: preview)
            }
        }
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ZStack {
                    Color.yellow
                    WarningStripes().fill(.black)
                }.opacity(0.10)
            }.accessibilityHidden(true).allowsHitTesting(false)
        }
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red, lineWidth: 5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private final class WarningPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) {}
    override func performClose(_ sender: Any?) {}
    override func miniaturize(_ sender: Any?) {}
}

@MainActor public final class AlwaysOnWarnings {
    private let controller: AlwaysOnController
    private let preview: Bool
    private var panels: [String: NSPanel] = [:]
    private var stateSubscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    public init(controller: AlwaysOnController, preview: Bool = false) {
        self.controller = controller; self.preview = preview
        stateSubscription = controller.objectWillChange.sink { [weak self] _ in
            // Include action/secondary copy changes; defer until published values settle.
            Task { @MainActor [weak self] in self?.reconcile() }
        }
        for name in [NSApplication.didChangeScreenParametersNotification, NSApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reconcile() }
            })
        }
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reconcile() }
            })
        }
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    public func reconcile() {
        guard controller.state.showsWarning else {
            panels.values.forEach { $0.orderOut(nil) }; panels.removeAll(); return
        }
        var present = Set<String>()
        for screen in NSScreen.screens where screen.visibleFrame.width >= 320 && screen.visibleFrame.height >= 300 {
            let key = String(describing: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? screen)
            present.insert(key)
            let panel: NSPanel
            if let existing = panels[key] { panel = existing }
            else {
                panel = WarningPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.title = preview ? "Always-on warning preview" : "Always-on warning"
                panel.level = .screenSaver
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.canHide = false
                panel.becomesKeyOnlyIfNeeded = false; panel.isMovable = false; panel.isReleasedWhenClosed = false
                panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
                panel.animationBehavior = .none
                panels[key] = panel
            }
            Self.layout(panel, controller: controller, preview: preview, visible: screen.visibleFrame)
            panel.orderFrontRegardless() // Never makeKey or activate: typing stays with the current app.
        }
        for key in Array(panels.keys) where !present.contains(key) { panels.removeValue(forKey: key)?.orderOut(nil) }
    }
    private static func layout(_ panel: NSPanel, controller: AlwaysOnController, preview: Bool, visible: NSRect) {
        let width = min(520, visible.width - 24)
        // Measure the actual shared content at this display's available width.
        // The measuring view has no scroll container or fixed vertical proposal.
        let measurement = NSHostingView(rootView: WarningContent(controller: controller, preview: preview)
            .frame(width: width).fixedSize(horizontal: false, vertical: true))
        let contentHeight = ceil(measurement.fittingSize.height)
        let maximumHeight = visible.height - 24
        let root = WarningView(controller: controller, preview: preview, overflow: contentHeight > maximumHeight)
        let hosting: NSHostingView<WarningView>
        if let existing = panel.contentView as? NSHostingView<WarningView> {
            hosting = existing; hosting.rootView = root
        } else { hosting = NSHostingView(rootView: root) }
        // Explicit fitting above owns the window size. Hosting's default min/max
        // constraints otherwise expand this borderless window after setFrame.
        hosting.sizingOptions = []
        if panel.contentView !== hosting { panel.contentView = hosting }
        let size = NSSize(width: width, height: min(contentHeight, maximumHeight))
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height), display: true)
    }

    /// Exercises the production layout without displaying a window or touching power.
    @_spi(LayoutChecks) public static func layoutOffscreenPanel(
        controller: AlwaysOnController, preview: Bool, visibleFrame: NSRect, reusing panel: NSPanel? = nil
    ) -> NSPanel {
        let panel = panel ?? WarningPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        layout(panel, controller: controller, preview: preview, visible: visibleFrame)
        return panel
    }

}
