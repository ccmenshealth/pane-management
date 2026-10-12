import SwiftUI
import AppKit
import SigningProbe

@main @MainActor struct ProbeApp: App {
    @StateObject private var model = ProbeModel(service: NativeProbeService())
    var body: some Scene {
        WindowGroup("Local Signing Probe") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Harmless local signing probe").font(.title2.bold())
                Text("This separate helper only echoes a random nonce. It cannot change sleep, power, or Pane Management settings.")
                Text(model.message).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Register probe") { Task { await model.perform("Register") } }
                    Button("Open Login Items") { model.loginItems() }
                    Button("Ping") { Task { await model.perform("Ping") } }
                }.disabled(model.busy)
                HStack {
                    Button("Remove probe") { Task { await model.perform("Remove") } }
                    Button("Check status") { model.check() }
                }.disabled(model.busy)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                if model.busy { Text("Quit remains available. The OS operation may continue after quitting. Reopen this app, then Check status or Remove to recover.").font(.caption) }
            }.padding(24).frame(width: 550).fixedSize(horizontal: false, vertical: true)
        }.windowResizability(.contentSize)
    }
}
