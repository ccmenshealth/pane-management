import Foundation
import AlwaysOnIPC

/// All foreground calls, renewal and recovery use a single FIFO lane. Transport
/// fencing is independent of this lane, so loss interrupts an outstanding RPC.
@MainActor public final class AlwaysOnClient {
    public private(set) var observation = ClientObservation(revision: 0, state: .unknown("Check helper status."), removalPending: false)
    public var onObservation: ((ClientObservation) -> Void)?
    private let transport: ClientTransport, scheduler: ClientScheduler
    private var channel: ClientChannel?, generation: UInt64 = 0, token: UUID?
    private var busy = false, waiters: [CheckedContinuation<Void, Never>] = []
    private var stopRevision: UInt64 = 0
    private var renewal: ClientTimer?, stopRequested = false, recovering = false, removing = false
    private var pending: ((Result<Data, Error>) -> Void)?
    public init(transport: ClientTransport, scheduler: ClientScheduler) { self.transport = transport; self.scheduler = scheduler }

    private func publish(_ state: ClientState) -> ClientObservation {
        observation = .init(revision: observation.revision &+ 1, state: state, removalPending: removing)
        onObservation?(observation); return observation
    }
    private func enter() async { if busy { await withCheckedContinuation { waiters.append($0) } }; busy = true }
    private func leave() { if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() } }
    private func discard() {
        renewal?.cancel(); renewal = nil; token = nil
        generation &+= 1; let old = channel; channel = nil; old?.close()
    }
    private func lost(_ id: UInt64) {
        guard generation == id else { return }
        let completion = pending
        discard()
        // During unregister the native completion, not its expected disconnect,
        // decides success. The observation remains uncertain until completion.
        if removing { return }
        _ = publish(.unknown("Helper connection was lost. Retry deactivation."))
        completion?(.failure(ClientFailure.connectionLost))
        if !busy && !recovering {
            Task { await self.enter(); defer { self.leave() }; _ = await self.recover() }
        }
    }
    private func connect() throws {
        if channel?.isOpen == true { return }
        discard(); let id = generation
        channel = try transport.connect { [weak self] in self?.lost(id) }
        guard channel?.isOpen == true else { discard(); throw ClientFailure.connectionLost }
    }
    private func rpc(_ operation: ServiceOperation, token: UUID? = nil, until: Double? = nil) async throws -> ServiceReply {
        guard let channel, channel.isOpen else { throw ClientFailure.connectionLost }
        let id = generation, deadline = min(scheduler.now + 5, until ?? .infinity)
        let data = try BoundaryPolicy.encode(ServiceRequest(operation: operation, token: token?.uuidString))
        let bytes: Data = try await withCheckedThrowingContinuation { continuation in
            var finished = false
            var timer: ClientTimer?
            let finish: (Result<Data, Error>) -> Void = { [weak self] result in
                guard !finished else { return }; finished = true; timer?.cancel()
                self?.pending = nil
                guard let self, self.generation == id, channel.isOpen else { continuation.resume(throwing: ClientFailure.connectionLost); return }
                guard self.scheduler.now.isFinite, self.scheduler.now < deadline else { continuation.resume(throwing: ClientFailure.timeout); return }
                continuation.resume(with: result)
            }
            pending = finish
            timer = scheduler.schedule(after: max(0, deadline - scheduler.now)) { finish(.failure(ClientFailure.timeout)) }
            channel.send(data, completion: finish)
        }
        guard generation == id, channel.isOpen else { throw ClientFailure.connectionLost }
        return try BoundaryPolicy.decodeReply(bytes, for: operation)
    }
    private func delay(_ duration: Double) async {
        await withCheckedContinuation { continuation in
            _ = scheduler.schedule(after: duration) { continuation.resume() }
        }
    }
    private func ready() async throws -> ServiceReply {
        try connect(); let deadline = scheduler.now + 5
        while true {
            let reply = try await rpc(.status, until: deadline)
            if reply.outcome == .observed, reply.state != .checking { return reply }
            guard reply.state == .checking, reply.outcome == .rejected || reply.outcome == .observed,
                  scheduler.now + 0.25 < deadline else { throw ClientFailure.unavailable }
            await delay(0.25)
            guard scheduler.now < deadline else { throw ClientFailure.timeout }
        }
    }
    private func off(_ reply: ServiceReply) -> Bool { reply.state == .off && reply.outcome == .observed }
    /// One fresh connection and one restore per recovery attempt. A user retry
    /// starts another attempt; no recursive retry or mutation replay occurs.
    private func recover() async -> ClientObservation {
        recovering = true; defer { recovering = false }
        discard()
        _ = publish(.unknown("Restoring normal sleep. Retry deactivation if this fails."))
        do {
            _ = try await ready()
            let result = try await rpc(.retryRestore)
            guard off(result) else { throw ClientFailure.invalidReply }
            return publish(.off)
        } catch {
            discard(); return publish(.unknown("Normal sleep is not verified. Retry deactivation or repair helper setup."))
        }
    }
    public func status() async -> ClientObservation {
        await enter(); defer { leave() }
        do {
            let reply = try await ready()
            if off(reply) { token = nil; renewal?.cancel(); return publish(.off) }
            if reply.state == .active, reply.outcome == .observed, token != nil { return publish(.active) }
            return await recover() // Never adopt another connection's global active state.
        } catch { return await recover() }
    }
    public func activate() async -> ClientObservation {
        let requestedAt = stopRevision
        await enter(); defer { leave() }
        guard requestedAt == stopRevision else { return await stop() }
        stopRequested = false
        do {
            let before = try await ready()
            guard off(before), !stopRequested else { return await recover() }
            let result = try await rpc(.activate)
            guard result.state == .active, result.outcome == .activated, let fresh = result.activationToken else { return await recover() }
            token = fresh
            if stopRequested { return await stop() }
            armRenewal(); return publish(.active)
        } catch { return await recover() }
    }
    public func deactivate() async -> ClientObservation {
        stopRequested = true; stopRevision &+= 1
        await enter(); defer { leave() }
        return await stop()
    }
    private func stop() async -> ClientObservation {
        renewal?.cancel(); renewal = nil
        guard let token, channel?.isOpen == true else { return await recover() }
        do {
            let result = try await rpc(.deactivate, token: token)
            self.token = nil
            guard off(result) else { return await recover() }
            return publish(.off)
        } catch { return await recover() }
    }
    private func armRenewal() {
        renewal?.cancel(); let id = generation
        renewal = scheduler.schedule(after: 10) { [weak self] in
            guard let self else { return }
            Task { await self.enter(); defer { self.leave() }
                guard self.generation == id, let token = self.token, !self.stopRequested else { return }
                do {
                    let reply = try await self.rpc(.heartbeat, token: token)
                    guard reply.outcome == .observed, reply.state == .active else { throw ClientFailure.invalidReply }
                    self.armRenewal(); _ = self.publish(.active)
                } catch { _ = await self.recover() }
            }
        }
    }
    /// The injected callback starts synchronously after the final fence check.
    /// B3b supplies SMAppService's completion-based unregister, never sync reap.
    public func remove(unregister: (@escaping @MainActor (Result<Void, Error>) -> Void) -> Void) async -> Bool {
        stopRequested = true; stopRevision &+= 1
        await enter(); defer { leave() }
        renewal?.cancel(); renewal = nil; token = nil
        _ = publish(.unknown("Preparing helper removal. Retry removal if this fails."))
        do {
            _ = try await ready()
            let prepared = try await rpc(.prepareForUpdateOrRemoval)
            guard prepared.state == .off, prepared.outcome == .prepared, let permit = prepared.preparationPermit else { throw ClientFailure.removal }
            let id = generation
            let final = try await rpc(.status)
            guard off(final), final.preparationPermit == permit, generation == id, channel?.isOpen == true else { throw ClientFailure.removal }
            removing = true
            _ = publish(.unknown("Removing helper. Wait for completion before changing setup."))
            try await unregisterBounded(unregister, generation: id)
            removing = false; discard(); _ = publish(.off); return true
        } catch {
            removing = false; discard(); _ = publish(.unknown("Helper removal is not verified. Retry removal or repair setup.")); return false
        }
    }
    private func unregisterBounded(_ action: (@escaping @MainActor (Result<Void, Error>) -> Void) -> Void, generation id: UInt64) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var finished = false
            var timer: ClientTimer?
            let finish: @MainActor (Result<Void, Error>) -> Void = { result in
                guard !finished else { return }; finished = true; timer?.cancel()
                continuation.resume(with: result)
            }
            // Unregister is destructive and cannot be cancelled or presumed
            // settled at a deadline. Keep the lane until actual OS completion.
            timer = scheduler.schedule(after: 5) { [weak self] in
                _ = self?.publish(.unknown("Helper removal is still pending. Wait for completion before changing setup."))
            }
            guard generation == id, let channel, channel.whileOpen({ action(finish) }) else {
                finish(.failure(ClientFailure.connectionLost)); return
            }
        }
    }
}
