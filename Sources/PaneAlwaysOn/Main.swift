import Foundation
import AlwaysOnDaemon
@main struct Main {
    static func main() async {
        do { try await DaemonRuntime.run() }
        catch {
            // No dynamic payload, identity, path, token or underlying diagnostic.
            FileHandle.standardError.write(Data("PaneAlwaysOn could not start securely. Repair setup in Pane Management.\n".utf8))
            exit(1)
        }
    }
}
