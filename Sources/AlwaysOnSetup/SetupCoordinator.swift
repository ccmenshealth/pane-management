import Foundation
import AlwaysOnClient

@MainActor public final class SetupCoordinator {
    public private(set) var observation = SetupObservation(revision: 0, state: .unknown("Check helper setup."), remedy: .checkAgain, lifecyclePending: false)
    public var onObservation: ((SetupObservation) -> Void)?
    private let service: SetupService, client: SetupClient, proof: SetupProof
    private let scheduler: ClientScheduler
    private var startupUnresolved = true, startupChecking = false, startupStep = 0
    private var startupTimer: ClientTimer?
    private var epoch: UInt64 = 0
    private var lifecycle = false, foreground = 0, refreshing = false
    private var approval = false
    private var intendedRemedy: SetupRemedy = .checkAgain
    public init(service: SetupService, client: SetupClient, proof: SetupProof, scheduler: ClientScheduler? = nil) {
        self.service = service; self.client = client; self.proof = proof; self.scheduler = scheduler ?? SystemClientScheduler()
        client.onChange = { [weak self] in self?.clientChanged() }
    }
    private var pending: Bool { lifecycle || foreground > 0 || client.removalPending }
    private func publish(_ state: SetupState, _ remedy: SetupRemedy) {
        intendedRemedy = remedy
        observation = .init(revision: observation.revision &+ 1, state: state,
                            remedy: lifecycle || client.removalPending ? .wait : remedy, lifecyclePending: pending)
        onObservation?(observation)
    }
    private func clientChanged() {
        stopStartup()
        epoch &+= 1; approval = false
        publishClient(client.state)
    }
    private func publishClient(_ state: ClientState) {
        switch state {
        case .off: publish(.off, .activate)
        case .active: publish(.active, .deactivate)
        case .removalRequired: publish(.removalRequired, .finishRemoval)
        case .unknown(let reason): publish(.unknown(reason), .retryDeactivationAndRepair)
        }
    }
    public func startup() async { await refresh() }
    public func refresh() async {
        guard !pending, !refreshing, !startupChecking else { return }
        if startupUnresolved {
            // Focus/wake notifications do not accelerate an already scheduled retry.
            guard startupTimer == nil else { return }
            startupChecking = true
            await inspect(startupOnly: true)
            startupChecking = false
            if startupUnresolved { scheduleStartup() }
        } else {
            refreshing = true; defer { refreshing = false }
            await inspect()
        }
    }
    private func stopStartup() {
        guard startupUnresolved else { return }
        startupUnresolved = false; epoch &+= 1
        startupTimer?.cancel(); startupTimer = nil
    }
    private func scheduleStartup() {
        let delays = [2.0, 5.0, 10.0, 30.0]
        let delay = delays[min(startupStep, delays.count - 1)]
        startupStep = min(startupStep + 1, delays.count - 1)
        let id = epoch
        startupTimer = scheduler.schedule(after: delay) { [weak self] in
            guard let self, self.startupUnresolved, self.epoch == id else { return }
            self.startupTimer = nil
            Task { [weak self] in
                // Cancellation may occur after the timer fires but before this
                // Task runs. Never let an obsolete retry enter ordinary refresh.
                guard let self, self.startupUnresolved, self.epoch == id else { return }
                await self.refresh()
            }
        }
    }
    private func inspect(registrationFailed: Bool = false, startupOnly: Bool = false) async {
        epoch &+= 1; let id = epoch; approval = false
        // An active warning remains actionable while its status is rechecked.
        // Safe off/unavailable snapshots expire as soon as a fresh proof starts.
        if observation.state != .active, !startupOnly || startupStep == 0 {
            publish(.unknown("Checking normal sleep and helper setup."), .wait)
        }
        do {
            let status = try await service.status()
            guard id == epoch else { return }
            switch status {
            case .enabled:
                if startupOnly {
                    let result = await client.probeStartup()
                    guard id == epoch else { return }
                    if !result.retry { stopStartup() }
                    publishClient(result.state)
                } else { await client.status() }
            case .requiresApproval:
                if startupOnly { stopStartup() }
                approval = true
                publish(.setupRequired("Approve the helper in Login Items, then check again."), .openLoginItems)
            case .notFound:
                if startupOnly { stopStartup() }
                do {
                    try service.validateIdentity()
                    let reason = registrationFailed
                        ? "Helper registration did not complete. Try Set Up again, or repair the signed installation and check again. Normal sleep is not verified."
                        : "The helper is not registered or could not be located. Choose Set up always-on helper to try setup. Normal sleep is not verified."
                    publish(.setupRequired(reason), .setUp)
                } catch {
                    publish(.setupRequired("Install the app and helper signed with the same certificate, then check again."), .checkAgain)
                }
            case .notRegistered:
                let power = try await proof.power()
                guard id == epoch else { return }
                guard power.verifiedOff else { throw SetupError.unverified }
                let absent = try await proof.directoryAbsent()
                guard id == epoch else { return }
                guard absent else { throw SetupError.unverified }
                let final = try await service.status()
                guard id == epoch else { return }
                guard final == .notRegistered else { throw SetupError.unverified }
                if startupOnly { stopStartup() }
                do {
                    try service.validateIdentity()
                    publish(.unavailable("Always-on helper is not set up."), .setUp)
                } catch {
                    publish(.unavailable("Install the app and helper signed with the same certificate, then check again."), .checkAgain)
                }
            }
        } catch {
            guard id == epoch else { return }
            publish(.unknown("Normal sleep is not verified. Retry deactivation or repair helper setup."), .retryDeactivationAndRepair)
        }
    }
    public func setup() async {
        stopStartup()
        guard !pending, !refreshing else { return }
        lifecycle = true; epoch &+= 1; approval = false
        publish(.setupRequired("Checking helper setup. Wait for completion."), .wait)
        var registrationFailed = false
        do {
            let status = try await service.status()
            // macOS can report notFound for a valid bundle before its first registration.
            if status == .notRegistered || status == .notFound {
                try service.validateIdentity()
                publish(.setupRequired("Registering helper. Wait for completion before changing setup."), .wait)
                // No timeout releases this slot: the OS can still apply a late registration.
                do { try await service.register() } catch { registrationFailed = true }
            }
        } catch { /* Status after completion/error resolves registration races. */ }
        await inspect(registrationFailed: registrationFailed)
        lifecycle = false
        publish(observation.state, intendedRemedy)

    }
    public func openLoginItems() {
        guard approval, !pending else { return }
        service.openLoginItems()
    }
    public func activate() async {
        stopStartup()
        guard !pending, !refreshing, observation.state == .off else { return }
        foreground += 1; epoch &+= 1; publish(.unknown("Activating always-on mode."), .deactivate)
        await client.activate(); foreground -= 1; clientChanged()
    }
    public func deactivate() async {
        stopStartup()
        // A stop can queue behind activation, preserving the client's late-enable latch.
        guard !lifecycle, !client.removalPending else { return }
        foreground += 1; epoch &+= 1; publish(.unknown("Restoring normal sleep."), .wait)
        await client.deactivate(); foreground -= 1; clientChanged()
    }
    public func remove() async -> Bool {
        stopStartup()
        guard !pending, !refreshing else { return false }
        lifecycle = true; epoch &+= 1; approval = false
        publish(.unknown("Preparing helper removal. Wait for completion."), .wait)
        let success = await client.remove { completion in self.service.unregister(completion) }
        lifecycle = false
        if success { publish(.unavailable("Helper removed. Normal sleep was verified."), .setUp) }
        else { publish(.unknown("Removal failed. Retry removal with a fresh verification."), .retryRemoval) }
        return success
    }
}
private enum SetupError: Error { case unverified }
