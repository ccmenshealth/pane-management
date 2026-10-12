import AppKit
import SwiftUI
import AlwaysOnCore
import AlwaysOnUI

/// In-memory fixture only; this executable has no privileged or power API client.
@MainActor final class PreviewBackend: ObservableObject, AlwaysOnBackend {
    @Published var failNextRestoration = false
    private var observation: AlwaysOnObservation = .off
    func status() async -> AlwaysOnObservation { observation }
    func activate() async -> AlwaysOnObservation {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        observation = .active; return observation
    }
    func deactivate() async -> AlwaysOnObservation {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if failNextRestoration {
            failNextRestoration = false
            return .unknown("Simulated helper readback failure.")
        }
        observation = .off; return observation
    }
}

struct PreviewControls: View {
    @ObservedObject var backend: PreviewBackend
    @ObservedObject var controller: AlwaysOnController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Always-on warning preview").font(.title2.bold())
            Text("Isolated UI fixture. No power settings, permissions, installed apps, or hardware are changed.")
            AlwaysOnControls(controller: controller)
            Toggle("Fail next restoration", isOn: $backend.failNextRestoration)
            Button("Simulate critical stop") { controller.criticalStop() }
            Button("Quit preview") { NSApp.terminate(nil) }
            Text("Activation/restoration takes two seconds to show pending states. Escape and closing a warning do not dismiss it. Use Deactivate to restore the simulated state.").font(.caption)
        }.padding(24).frame(width: 330)
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
        appMenu.addItem(withTitle: "Hide Preview Controls", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Always-on Preview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 40, y: 80, width: 378, height: 420), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Always-on Preview Controls"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreviewControls(backend: backend, controller: controller))
        self.window = window
        warnings = AlwaysOnWarnings(controller: controller, preview: true)
        controller.onQuitDecision = { NSApp.reply(toApplicationShouldTerminate: $0) }
        controller.checkSetup()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
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
