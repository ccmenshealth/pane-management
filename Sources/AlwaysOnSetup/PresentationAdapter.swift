import AlwaysOnCore

@MainActor public final class SetupPresentationAdapter: AlwaysOnBackend {
    private let coordinator: SetupCoordinator
    public var onChange: ((AlwaysOnSnapshot) -> Void)?
    public var snapshot: AlwaysOnSnapshot { Self.map(coordinator.observation) }
    public init(_ coordinator: SetupCoordinator) {
        self.coordinator = coordinator
        coordinator.onObservation = { [weak self] in self?.onChange?(Self.map($0)) }
    }
    public func refresh() async { await coordinator.refresh() }
    public func activate() async { await coordinator.activate() }
    public func deactivate() async { await coordinator.deactivate() }
    public func setup() async { await coordinator.setup() }
    public func remove() async { _ = await coordinator.remove() }
    public func openLoginItems() { coordinator.openLoginItems() }
    public static func map(_ value: SetupObservation) -> AlwaysOnSnapshot {
        let state: AlwaysOnState
        switch value.state {
        case .off: state = .off
        case .active: state = .active
        case .removalRequired: state = .removalRequired
        case .unavailable(let reason): state = .unavailable(reason)
        case .setupRequired(let reason): state = .setupRequired(reason)
        case .unknown(let reason): state = .recoveryRequired(reason)
        }
        let action: AlwaysOnAction, secondary: String?
        switch value.remedy {
        case .activate: action = .activate; secondary = nil
        case .deactivate: action = .deactivate; secondary = nil
        case .setUp: action = .setUp; secondary = nil
        case .finishRemoval: action = .openSettings; secondary = nil
        case .openLoginItems: action = .checkSetup; secondary = "Open Login Items"
        case .checkAgain: action = .checkSetup; secondary = nil
        case .retryDeactivationAndRepair: action = .deactivate; secondary = "Repair setup in Settings"
        case .retryRemoval: action = .deactivate; secondary = "Retry helper removal in Settings"
        case .wait: action = .wait; secondary = nil
        }
        return .init(revision: value.revision, state: state, action: action, secondaryTitle: secondary,
                     lifecyclePending: value.lifecyclePending, quitSafe: value.quitSafe)
    }
}
