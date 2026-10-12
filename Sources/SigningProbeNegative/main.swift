import Foundation
import Darwin
import SigningProbe
import AlwaysOnIPC

// Acceptance fixture only. Never linked into the app, daemon or production products.
// Caller must establish positive ping before AND after: failure alone proves nothing.
@main struct Negative {
    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2,
              let requirement = try? Probe.negativeRequirement(scenario: args[0], pin: args[1]) else {
            print("Fixture preflight failed. Use wrong-id|ad-hoc|wrong-pin and the required 40-hex peer pin; no test ran."); exit(2)
        }
        let ping = ProbePing()
        let result: Result<Void, Error> = await withCheckedContinuation { continuation in
            ping.start(channel: NativeProbeChannel(requirement: requirement)) { continuation.resume(returning: $0) }
        }
        switch result {
        case .success: print("UNEXPECTED SUCCESS: negative fixture authenticated."); exit(1)
        case .failure: print("NO SUCCESS (rejection, transport error, or timeout). Require successful GUI pings before AND after; this alone is not authentication proof."); exit(0)
        }
    }
}
