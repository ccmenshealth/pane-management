import AppKit
import SwiftUI
import Combine
import AlwaysOnCore

extension AlwaysOnState {
    public var heading: String {
        switch self {
        case .checking: return "Checking always-on status"
        case .off: return "Always-on mode is off"
        case .activating: return "Activating always-on mode…"
        case .active: return "Always-on mode is activated"
        case .stopping: return "Restoring normal sleep…"
        case .recoveryRequired: return "Normal sleep needs recovery"
        case .unavailable: return "Always-on mode is unavailable"
        }
    }
    public var explanation: String {
        switch self {
        case .checking: return "Checking whether normal sleep is available. You can request deactivation while this check finishes."
        case .off: return "Normal sleep is available. Always-on mode must be activated manually."
        case .activating: return "Activation has not been confirmed. Deactivate to cancel and restore normal sleep."
        case .active: return "Your Mac will stay awake even with the lid open. Deactivate before using it normally. Emergency sleep protection is not guaranteed."
        case .stopping: return "Keep Pane Management open. This warning stays until normal sleep has been confirmed."
        case .recoveryRequired(let reason): return "Normal sleep could not be confirmed. \(reason) Keep the Mac out of your bag and retry deactivation."
        case .unavailable(let reason): return reason
        }
    }
    public var showsWarning: Bool {
        switch self { case .off, .unavailable: return false; default: return true }
    }
    public var actionTitle: String {
        switch self {
        case .off: return "Activate always-on mode"
        case .unavailable: return "Check always-on setup"
        case .recoveryRequired: return "Retry deactivation"
        case .stopping: return "Deactivating…"
        default: return "Deactivate"
        }
    }
    public var action: AlwaysOnAction {
        switch self { case .off: return .activate; case .unavailable: return .checkSetup; default: return .deactivate }
    }
}

/// Shared Settings/fixture control. The menu items use the same state/action mapping.
public struct AlwaysOnControls: View {
    @ObservedObject var controller: AlwaysOnController
    public init(controller: AlwaysOnController) { self.controller = controller }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(controller.state.heading).font(.headline)
            Text(controller.state.explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
            Button(controller.state.actionTitle) { controller.perform(controller.state.action) }
                .disabled(controller.state == .stopping)
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

private struct WarningView: View {
    @ObservedObject var controller: AlwaysOnController
    let preview: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
            ZStack {
                WarningTriangle().fill(Color(red: 0.84, green: 0.015, blue: 0.035))
                Text("!").font(.system(size: 58, weight: .black)).foregroundStyle(.white).offset(y: 9)
            }.frame(width: 96, height: 84).accessibilityLabel("Warning")
            Text(controller.state.heading).font(.system(size: 25, weight: .bold))
                .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            ScrollView {
                Text(controller.state.explanation).font(.system(size: 15))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(height: 76)
            Button { controller.perform(.deactivate) } label: {
                Text(controller.state.actionTitle).font(.system(size: 19, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
            }.keyboardShortcut(.defaultAction)
                .accessibilityHint("Restores normal sleep before removing this warning")
                .buttonStyle(.borderedProminent).tint(Color(red: 0.84, green: 0.015, blue: 0.035))
                .disabled(controller.state == .stopping)
            if preview { Text("PREVIEW ONLY · No power settings change").font(.caption.bold()).foregroundStyle(.secondary) }
            }.padding(26).frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        stateSubscription = controller.$state.sink { [weak self] _ in
            // Published emits before the property changes; defer reconciliation.
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
                panel.contentView = NSHostingView(rootView: WarningView(controller: controller, preview: preview))
                panels[key] = panel
            }
            let visible = screen.visibleFrame
            let size = NSSize(width: min(520, visible.width - 24), height: min(390, visible.height - 24))
            panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height), display: true)
            panel.orderFrontRegardless() // Never makeKey or activate: typing stays with the current app.
        }
        for key in Array(panels.keys) where !present.contains(key) { panels.removeValue(forKey: key)?.orderOut(nil) }
    }
}
