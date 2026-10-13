import Foundation
import Darwin
import SigningProbe

final class Echo: NSObject, ProbeXPC {
    func ping(_ nonce: Data, reply: @escaping (Data) -> Void) { reply((try? Probe.response(nonce)) ?? Data()) }
}
final class Listener: NSObject, NSXPCListenerDelegate {
    let requirement: String
    init(_ requirement: String) { self.requirement = requirement }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: ProbeXPC.self)
        connection.exportedObject = Echo()
        connection.activate()
        return true
    }
}
// No listener, subprocess, power port or storage is constructed before self checks.
guard geteuid() == 0, let requirement = try? Probe.peer(daemon: true) else { exit(1) }
let delegate = Listener(requirement)
let listener = NSXPCListener(machServiceName: Probe.helperID)
listener.delegate = delegate
listener.setConnectionCodeSigningRequirement(requirement)
listener.activate()
RunLoop.main.run()
