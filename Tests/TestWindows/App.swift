import AppKit

@main
enum TestWindowsApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = FixtureDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Test Windows", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        let work = NSScreen.main!.visibleFrame
        for (index, spec) in [("Blue", NSColor.systemBlue), ("Green", NSColor.systemGreen), ("Amber", NSColor.systemOrange)].enumerated() {
            let frame = CGRect(x: work.minX+80+CGFloat(index)*65, y: work.maxY-440-CGFloat(index)*55,
                               width: min(650, work.width * 0.55), height: min(420, work.height * 0.6))
            let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Pane Test — \(spec.0)"
            window.minSize = CGSize(width: 160, height: 160)
            window.isReleasedWhenClosed = false
            let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
            view.wantsLayer = true; view.layer?.backgroundColor = spec.1.withAlphaComponent(0.18).cgColor
            let label = NSTextField(labelWithString: "\(spec.0) window\nDisposable Pane Management test window")
            label.font = .systemFont(ofSize: 24, weight: .medium); label.textColor = spec.1
            label.frame = CGRect(x: 24, y: 24, width: 450, height: 80)
            label.autoresizingMask = [.maxXMargin, .maxYMargin]
            view.addSubview(label); window.contentView = view
            window.makeKeyAndOrderFront(nil); windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
