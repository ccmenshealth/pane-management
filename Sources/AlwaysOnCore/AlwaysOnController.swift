import Foundation
import Combine

public enum AlwaysOnState: Equatable, Sendable {
    case checking, off, activating, active, stopping, removalRequired
    case recoveryRequired(String), unavailable(String), setupRequired(String)
}
public enum AlwaysOnAction: Equatable, Sendable {
    case activate, deactivate, checkSetup, setUp, openSettings, openLoginItems, wait
}
public struct AlwaysOnSnapshot: Equatable, Sendable {
    public let revision: UInt64
    public let state: AlwaysOnState
    public let action: AlwaysOnAction
    public let secondaryTitle: String?
    public let lifecyclePending: Bool
    public let quitSafe: Bool
    public init(revision: UInt64, state: AlwaysOnState, action: AlwaysOnAction,
                secondaryTitle: String? = nil, lifecyclePending: Bool = false, quitSafe: Bool = false) {
        self.revision = revision; self.state = state; self.action = action
        self.secondaryTitle = secondaryTitle; self.lifecyclePending = lifecyclePending; self.quitSafe = quitSafe
    }
}
@MainActor public protocol AlwaysOnBackend: AnyObject {
    var snapshot: AlwaysOnSnapshot { get }
    var onChange: ((AlwaysOnSnapshot) -> Void)? { get set }
    func refresh() async
    func activate() async
    func deactivate() async
    func setup() async
    func remove() async
    func openLoginItems()
}

/// Presentation consumes authoritative revisioned observations. The client owns
/// token/orphan recovery; an ordinary owned-active refresh must not stop it.
@MainActor public final class AlwaysOnController: ObservableObject {
    @Published public private(set) var state: AlwaysOnState = .checking
    @Published public private(set) var action: AlwaysOnAction = .wait
    @Published public private(set) var secondaryTitle: String?
    public var onQuitDecision: ((Bool) -> Void)?
    public var onOpenSettings: (() -> Void)?
    private let backend: AlwaysOnBackend
    private var latest: AlwaysOnSnapshot
    private var operations = Set<UUID>()
    private var activation: UUID?, stopping: UUID?
    private var stopCompleted = false
    private var refreshing = false, refreshAgain = false, quitPending = false
    public init(backend: AlwaysOnBackend) {
        self.backend = backend; latest = backend.snapshot
        backend.onChange = { [weak self] in self?.receive($0) }
        render()
    }
    public var actionEnabled: Bool { action != .wait }
    public var canRemove: Bool { operations.isEmpty && !refreshing && !latest.lifecyclePending }
    public var needsRepair: Bool {
        switch latest.state { case .recoveryRequired, .setupRequired: return true; default: return false }
    }
    public var canOpenLoginItems: Bool { secondaryTitle == "Open Login Items" && canRemove }
    private var safe: Bool { latest.quitSafe && operations.isEmpty && !refreshing && !latest.lifecyclePending }
    private func receive(_ value: AlwaysOnSnapshot) {
        guard value.revision > latest.revision else { return }
        latest = value; render(); settleQuit()
    }
    private func render() {
        secondaryTitle = latest.secondaryTitle
        if stopping != nil { state = .stopping; action = .wait }
        else if activation != nil { state = .activating; action = .deactivate }
        else if refreshing && latest.quitSafe { state = .checking; action = .wait }
        else { state = latest.state; action = latest.action }
    }
    private func settleQuit() {
        guard quitPending, operations.isEmpty, !refreshing, !latest.lifecyclePending else { return }
        quitPending = false; onQuitDecision?(safe)
    }
    /// App startup, wake and focus all enter this coalescing driver. Revocation of
    /// stale safe state is synchronous, before the first suspension.
    public func checkSetup() {
        if refreshing { refreshAgain = true; return }
        refreshing = true; render()
        Task {
            while true {
                await backend.refresh(); receive(backend.snapshot)
                guard refreshAgain else { break }
                refreshAgain = false
            }
            refreshing = false; render(); settleQuit()
        }
    }
    public func perform(_ requested: AlwaysOnAction) {
        switch requested {
        case .openSettings: onOpenSettings?()
        case .openLoginItems: if canOpenLoginItems { backend.openLoginItems() }
        case .checkSetup: checkSetup()
        case .wait: break
        case .activate:
            guard action == .activate, canRemove, !quitPending else { return }
            let id = UUID(); activation = id; operations.insert(id); render()
            Task {
                // Stop requested before this task started prevents the activation.
                if stopping == nil { await backend.activate() }
                receive(backend.snapshot); operations.remove(id)
                if activation == id { activation = nil }
                settleStop(); render(); settleQuit()
            }
        case .deactivate:
            guard stopping == nil, action == .deactivate || activation != nil else { return }
            let id = UUID(); stopping = id; stopCompleted = false; operations.insert(id); render()
            Task {
                await backend.deactivate(); receive(backend.snapshot)
                if stopping == id { stopCompleted = true }
                settleStop(); render(); settleQuit()
            }
        case .setUp:
            guard action == .setUp, canRemove else { return }
            runLifecycle { await self.backend.setup() }
        }
    }
    private func settleStop() {
        guard stopCompleted, activation == nil, let id = stopping else { return }
        operations.remove(id); stopping = nil; stopCompleted = false
    }
    /// Called only by the explicit Settings removal button, never by menu/warning.
    public func removeHelperFromSettings() {
        guard canRemove else { return }
        runLifecycle { await self.backend.remove() }
    }
    public func repairHelperFromSettings() {
        guard canRemove, needsRepair else { return }
        runLifecycle { await self.backend.setup() }
    }
    private func runLifecycle(_ work: @escaping @MainActor () async -> Void) {
        let id = UUID(); operations.insert(id); state = .checking; action = .wait
        Task {
            await work(); receive(backend.snapshot); operations.remove(id)
            render(); settleQuit()
        }
    }
    public func criticalStop() { perform(.deactivate) }
    public func requestQuit() -> Bool {
        if safe { return true }
        quitPending = true
        if action == .deactivate || activation != nil { perform(.deactivate) }
        else if operations.isEmpty && !refreshing && !latest.lifecyclePending {
            // No cancellable operation is pending. Reply asynchronously for AppKit.
            Task { self.settleQuit() }
        }
        return false
    }
}
