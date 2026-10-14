import AppKit
import SwiftUI
import AlwaysOnCore
import AlwaysOnUI

/// In-memory fixture only; this executable has no privileged or power API client.
@MainActor final class PreviewBackend: ObservableObject, AlwaysOnBackend {
    @Published var failNextRestoration = false
    @Published var fixture = "Off"
    let fixtures = ["Startup checking", "Startup unavailable", "Startup approval", "Off", "Active", "Setup available", "Missing signing", "Approval", "Repair installation", "Unknown recovery", "Activation pending", "Removal pending", "Removal failed", "Finish removal"]
    var snapshot = AlwaysOnSnapshot(revision: 0, state: .off, action: .activate, quitSafe: true)
    var onChange: ((AlwaysOnSnapshot) -> Void)?
    private func emit(_ state: AlwaysOnState, _ action: AlwaysOnAction, _ secondary: String? = nil, pending: Bool = false, safe: Bool = false) {
        snapshot = .init(revision: snapshot.revision + 1, state: state, action: action, secondaryTitle: secondary, lifecyclePending: pending, quitSafe: safe)
        onChange?(snapshot)
    }
    func select() {
        switch fixture {
        case "Startup checking": emit(.statusUnverified("Checking helper availability. Normal sleep has not been verified."), .wait)
        case "Startup unavailable": emit(.statusUnverified("The helper has not answered yet. Automatic checks continue; normal sleep has not been verified."), .checkSetup, "Repair setup in Settings")
        case "Startup approval": emit(.statusUnverified("Approve the helper in Login Items, then check again."), .checkSetup, "Open Login Items")
        case "Active": emit(.active, .deactivate)
        case "Setup available": emit(.unavailable("Always-on helper is not set up."), .setUp, safe: true)
        case "Missing signing": emit(.unavailable("Install the app and helper signed with the same certificate, then check again."), .checkSetup, safe: true)
        case "Approval": emit(.setupRequired("Approve the helper in Login Items, then check again."), .checkSetup, "Open Login Items")
        case "Repair installation": emit(.setupRequired("Repair the signed app installation, then check again."), .checkSetup)
        case "Unknown recovery": emit(.recoveryRequired("Helper connection was lost."), .deactivate, "Repair setup in Settings")
        case "Activation pending": emit(.activating, .deactivate, pending: true)
        case "Removal pending": emit(.recoveryRequired("Helper removal is still pending. Wait for completion before changing setup."), .wait, pending: true)
        case "Removal failed": emit(.recoveryRequired("Removal failed. Retry removal with a fresh verification."), .deactivate, "Retry helper removal in Settings")
        case "Finish removal": emit(.removalRequired, .openSettings, safe: true)
        default: emit(.off, .activate, safe: true)
        }
    }
    func refresh() async { select() }
    func activate() async {
        emit(.activating, .deactivate, pending: true)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        emit(.active, .deactivate)
    }
    func deactivate() async {
        // Fixture models the same FIFO late-activation behavior as the client.
        try? await Task.sleep(nanoseconds: 2_100_000_000)
        if failNextRestoration {
            failNextRestoration = false
            emit(.recoveryRequired("Simulated helper readback failure."), .deactivate, "Repair setup in Settings")
        } else { fixture = "Off"; select() }
    }
    func setup() async { fixture = "Approval"; select() }
    func remove() async { fixture = "Off"; select() }
    func openLoginItems() { /* Inert: no OS navigation. */ }
}

struct PreviewControls: View {
    @ObservedObject var backend: PreviewBackend
    @ObservedObject var controller: AlwaysOnController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Always-on warning preview").font(.title2.bold())
            Text("Isolated UI fixture. No power settings, permissions, installed apps, or hardware are changed.")
            Picker("Fixture state", selection: $backend.fixture) {
                ForEach(backend.fixtures, id: \.self) { Text($0) }
            }.onChange(of: backend.fixture) { _, _ in backend.select() }
            AlwaysOnControls(controller: controller, actions: false)
            Toggle("Fail next restoration", isOn: $backend.failNextRestoration)
            Button("Simulate critical stop") { controller.criticalStop() }
            Button("Quit preview") { NSApp.terminate(nil) }
            Text("Activation/restoration takes two seconds to show pending states. Escape and closing a warning do not dismiss it. Use Deactivate to restore the simulated state.").font(.caption)
            Spacer()
        }.padding(24).safeAreaInset(edge: .bottom) {
            AlwaysOnActions(controller: controller, settings: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.regularMaterial)
        }.frame(width: 580, height: 700)
    }
}

@MainActor final class PreviewDelegate: NSObject, NSApplicationDelegate {
    let backend = PreviewBackend()
    lazy var controller = AlwaysOnController(backend: backend)
    var warnings: AlwaysOnWarnings?
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu()
        menu.addItem(appItem); appItem.submenu = appMenu
        let showControls = NSMenuItem(title: "Show Preview Controls", action: #selector(showControls), keyEquivalent: "1")
        showControls.target = self; appMenu.addItem(showControls)
        appMenu.addItem(withTitle: "Hide Preview Controls", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Always-on Preview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 40, y: 80, width: 580, height: 700), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Always-on Preview Controls"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreviewControls(backend: backend, controller: controller))
        window.center()
        self.window = window
        warnings = AlwaysOnWarnings(controller: controller, preview: true)
        controller.onOpenSettings = { [weak self] in self?.window?.makeKeyAndOrderFront(nil) }
        controller.onQuitDecision = { NSApp.reply(toApplicationShouldTerminate: $0) }
        controller.checkSetup()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func showControls() { window?.makeKeyAndOrderFront(nil); warnings?.reconcile() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil); warnings?.reconcile(); return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller.requestQuit() ? .terminateNow : .terminateLater
    }
}

@main enum PreviewApp {
    @MainActor static func main() {
        let app = NSApplication.shared, delegate = PreviewDelegate()
        app.delegate = delegate; app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
