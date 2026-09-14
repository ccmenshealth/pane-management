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

final class FixtureWindow: NSWindow {
    var keyPresses = 0
    var dragEvents = 0
    override func sendEvent(_ event: NSEvent) {
        // Counts only events delivered to this disposable window. Never records
        // text, observes another app's input, or writes diagnostics to disk.
        if event.type == .keyDown { keyPresses += 1 }
        if event.type == .leftMouseDragged { dragEvents += 1 }
        super.sendEvent(event)
    }
}

final class FixtureDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windows: [NSWindow] = []
    var frameLabels: [NSWindow: NSTextField] = [:]
    var inputLabels: [NSWindow: NSTextField] = [:]
    private var diagnosticTimer: Timer?
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
            let window = FixtureWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Pane Test — \(spec.0)"
            window.minSize = CGSize(width: 160, height: 160)
            window.isReleasedWhenClosed = false
            window.delegate = self
            let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
            view.wantsLayer = true; view.layer?.backgroundColor = spec.1.withAlphaComponent(0.18).cgColor
            let label = NSTextField(labelWithString: "\(spec.0) window\nDisposable Pane Management test window")
            label.font = .systemFont(ofSize: 24, weight: .medium); label.textColor = spec.1
            label.frame = CGRect(x: 24, y: 24, width: 450, height: 80)
            label.autoresizingMask = [.maxXMargin, .maxYMargin]
            let sizeLabel = NSTextField(labelWithString: "")
            sizeLabel.frame = CGRect(x: 24, y: 110, width: 580, height: 36)
            sizeLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            let fit = NSButton(title: "Fit left half (fixture control)", target: self, action: #selector(fitLocally(_:)))
            fit.frame = CGRect(x: 24, y: 155, width: 240, height: 30)
            let limit = NSButton(title: "Toggle 900pt minimum width", target: self, action: #selector(toggleLimit(_:)))
            limit.frame = CGRect(x: 24, y: 195, width: 240, height: 30)
            let focus = NSButton(title: "Focus this test window", target: self, action: #selector(focusLocally(_:)))
            focus.frame = CGRect(x: 24, y: 235, width: 240, height: 30)
            let inputLabel = NSTextField(labelWithString: "")
            inputLabel.frame = CGRect(x: 24, y: 275, width: 580, height: 42)
            inputLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            view.addSubview(label); view.addSubview(sizeLabel); view.addSubview(fit); view.addSubview(limit)
            view.addSubview(focus); view.addSubview(inputLabel)
            inputLabels[window] = inputLabel
            window.contentView = view; frameLabels[window] = sizeLabel
            window.makeKeyAndOrderFront(nil); windows.append(window)
            report(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.windows.forEach { self.report($0) }
        }
        RunLoop.main.add(timer, forMode: .common); diagnosticTimer = timer
    }
    @objc private func focusLocally(_ sender: NSButton) {
        guard let window = sender.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        report(window)
    }
    @objc private func fitLocally(_ sender: NSButton) {
        guard let window = sender.window, let work = window.screen?.visibleFrame else { return }
        window.setFrame(CGRect(x: work.minX, y: work.minY, width: work.width/2, height: work.height), display: true, animate: false)
        report(window)
    }
    @objc private func toggleLimit(_ sender: NSButton) {
        guard let window = sender.window else { return }
        window.minSize = CGSize(width: window.minSize.width > 160 ? 160 : 900, height: 160)
        report(window)
    }
    private func report(_ window: NSWindow) {
        let r = window.frame
        frameLabels[window]?.stringValue = "Cocoa frame: x \(Int(r.minX)), y \(Int(r.minY)), \(Int(r.width)) × \(Int(r.height))\nMinimum: \(Int(window.minSize.width)) × \(Int(window.minSize.height))"
        let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid()
        let fixture = window as? FixtureWindow
        inputLabels[window]?.stringValue = "Foreground: \(foreground ? "yes" : "no") · Key window: \(window.isKeyWindow ? "yes" : "no")\nDelivered key presses: \(fixture?.keyPresses ?? 0) · Drag events: \(fixture?.dragEvents ?? 0)"
    }
    func windowDidResize(_ notification: Notification) { if let window = notification.object as? NSWindow { report(window) } }
    func windowDidMove(_ notification: Notification) { if let window = notification.object as? NSWindow { report(window) } }
}
