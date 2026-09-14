import AppKit
import SwiftUI
import ApplicationServices

@main
enum PaneManagementApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let preferences = Preferences()
    lazy var controller = SnapController(preferences: preferences)
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let identifier = Bundle.main.bundleIdentifier ?? "local.snapbridge.app"
        if NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: { $0.processIdentifier != getpid() }) {
            NSApp.terminate(nil); return
        }
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self; appMenu.addItem(settingsItem)
        appMenu.addItem(withTitle: "Quit Pane Management", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
        if let icon = AppArtwork.applicationIcon { NSApp.applicationIconImage = icon }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = AppArtwork.menuBarIcon
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Pane Management — window snapping"
        statusItem = item
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        rebuildMenu(menu)
        controller.start()
        PreviewAccess.shared.check(userInitiated: false)
        if !preferences.accessibility || CommandLine.arguments.contains("--settings") { showSettings() }
    }

    func menuWillOpen(_ menu: NSMenu) { rebuildMenu(menu) }
    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Pane Management", action: nil, keyEquivalent: ""); title.isEnabled = false
        menu.addItem(title)
        let enabled = NSMenuItem(title: preferences.enabled ? "Pause snapping" : "Resume snapping", action: #selector(toggle), keyEquivalent: "")
        enabled.target = self; menu.addItem(enabled)
        menu.addItem(.separator())
        let layouts = NSMenuItem(title: "Choose layout   ⌃⌥Z", action: #selector(showLayouts), keyEquivalent: "")
        layouts.target = self; menu.addItem(layouts)
        if !controller.groups.isEmpty {
            let chooser = NSMenuItem(title: "Browse snap groups…   ⌃⌥⇧G", action: #selector(showGroups), keyEquivalent: "")
            chooser.target = self; menu.addItem(chooser)
            let parent = NSMenuItem(title: "Snap groups", action: nil, keyEquivalent: "")
            let groups = NSMenu()
            for group in controller.groups {
                let item = NSMenuItem(title: group.name, action: #selector(restoreGroup(_:)), keyEquivalent: "")
                item.representedObject = group; item.target = self; groups.addItem(item)
            }
            parent.submenu = groups; menu.addItem(parent)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit Pane Management", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }
    @objc private func toggle() { preferences.enabled.toggle() }
    @objc private func showLayouts() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.controller.openLayouts() } }
    @objc private func showGroups() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.controller.openGroups() } }
    @objc private func restoreGroup(_ sender: NSMenuItem) {
        if let group = sender.representedObject as? SnapGroup { controller.restoreGroup(group) }
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Pane Management"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences, testAssist: { [weak self] in
                self?.settingsWindow?.orderOut(nil)
                DispatchQueue.main.asyncAfter(deadline: .now()+0.2) { self?.controller.testAssistWithFixture() }
            }, testIntegration: { [weak self] in self?.controller.testFixtureIntegration() }))
            window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopening an already-running menu-bar app must not cover an active
        // chooser with Settings or steal its keyboard focus.
        if controller.assistant.isVisible || controller.palette.isVisible || controller.groupPicker.isVisible { return false }
        showSettings(); return true
    }
    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject private var previewAccess = PreviewAccess.shared
    var testAssist: () -> Void
    var testIntegration: () -> Void
    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    if let icon = AppArtwork.applicationIcon {
                        Image(nsImage: icon).resizable().interpolation(.high).frame(width: 54, height: 54)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Snap. Pick. Keep going.").font(.system(size: 25, weight: .semibold))
                        Text("Windows-style snapping, with the other half included.").foregroundStyle(.secondary)
                    }
                }
                Text(preferences.status).font(.callout).foregroundStyle(preferences.accessibility ? Color.green : Color.orange)
                if NSRunningApplication.runningApplications(withBundleIdentifier: "local.snapbridge.testwindows").isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Test Snap Assist with disposable windows", action: testAssist)
                        Button("Run live fixture checks", action: testIntegration)
                        Text(preferences.fixtureCheckStatus).font(.caption).textSelection(.enabled)
                        Text("Moves only the disposable test windows, then restores their starting frames. Clears their test groups. Stop using the mouse until the checks finish; a new gesture cancels them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.disabled(preferences.fixtureChecksRunning)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        permissionRow("Move and resize windows", detail: "Accessibility access is required.", granted: preferences.accessibility, button: "Enable Accessibility") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                            openPrivacy("Privacy_Accessibility")
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            permissionRow("Preview your open windows", detail: previewAccess.message,
                                          granted: previewAccess.isAvailable,
                                          button: previewAccess.isChecking ? "Checking…" : (previewAccess.needsRecovery ? "Check Again" : "Enable Previews")) {
                                previewAccess.check(userInitiated: true)
                            }.disabled(previewAccess.isChecking)
                            if previewAccess.needsRecovery {
                                Text("Current app: \(Bundle.main.bundlePath)")
                                    .font(.caption).textSelection(.enabled)
                                HStack {
                                    Button("Open Screen Recording Settings") { openPrivacy("Privacy_ScreenCapture") }
                                    Button("Show App in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                                }
                                Button("Quit Pane Management") {
                                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                                    NSApp.terminate(nil)
                                }
                                Text("Quitting clears session-only snap groups. Reopen the selected app in Finder afterward.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(8)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Make Pane Management your window snapper").font(.headline)
                    Text("In macOS Desktop & Dock → Windows, turn off “Drag windows to screen edges to tile”, “Drag windows to menu bar to fill screen”, and “Drag windows to top of screen to enter Mission Control” if shown. This prevents competing drag actions.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Open Desktop & Dock settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
                    }
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable snapping", isOn: $preferences.enabled)
                        Toggle("After snapping, ask what fills the remaining space", isOn: $preferences.assist)
                        Toggle("Show layouts when hovering over the green button", isOn: $preferences.hover)
                        Toggle("Show the layout bar when dragging to the top", isOn: $preferences.topBar)
                        Toggle("Snap near an edge without touching it", isOn: $preferences.nearEdge)
                        Toggle("Restore original size when dragging a window away", isOn: $preferences.restore)
                        Toggle("Offer windows from this monitor only", isOn: $preferences.sameDisplay)
                        Toggle("Resize adjoining group windows together", isOn: $preferences.linkedResize)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use it").font(.headline)
                    Text("Drag to either side or a corner, then pick another window. Hold Control–Option while choosing positions with arrows; release to place. Resize a group using a shared window edge or the blue handle. Original size returns during recognized blank-title-bar drags, with an after-release fallback for other title bars.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                        shortcut("⌃⌥ + arrows", "Snap, maximize, restore, or minimize")
                        shortcut("⌃⌥Z", "Choose a layout")
                        shortcut("⌃⌥⇧ + ← / →", "Move to another monitor")
                        shortcut("⌃⌥G", "Bring back the latest snap group")
                        shortcut("⌃⌥⇧G", "Browse and recall snap groups")
                        shortcut("⌃⌥⇧↑", "Fill height, keeping the window’s width")
                        shortcut("Esc", "Dismiss the picker or cancel a snap preview")
                    }.font(.callout)
                }
                Text("Local prototype · macOS 14+ · No network connections\nWindow previews stay in memory and are cleared when the picker closes. Snap groups last until Pane Management quits. Full-screen Spaces and some app-specific window limits aren’t supported.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(26)
        }.frame(width: 580, height: 700)
    }
    private func permissionRow(_ title: String, detail: String, granted: Bool, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2) }
            else { Button(button, action: action) }
        }
    }
    private func shortcut(_ keys: String, _ description: String) -> some View {
        GridRow {
            Text(keys).font(.system(.callout, design: .monospaced)).foregroundStyle(.blue)
            Text(description).foregroundStyle(.secondary)
        }
    }
}
