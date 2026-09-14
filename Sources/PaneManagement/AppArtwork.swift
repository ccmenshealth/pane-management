import AppKit

enum AppArtwork {
    static var applicationIcon: NSImage? {
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap { NSImage(contentsOf: $0) }
    }

    static var menuBarIcon: NSImage? {
        let image = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "pdf")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Pane Management")
        image?.isTemplate = true
        image?.size = NSSize(width: 14, height: 18)
        image?.accessibilityDescription = "Pane Management"
        return image
    }
}
