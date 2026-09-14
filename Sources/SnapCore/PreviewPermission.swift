import Foundation

public enum PreviewPermissionState: Equatable {
    case unchecked, checking, available, denied, failed(String)
}

public enum PreviewPermissionFailure: Error {
    case denied
}

/// A preflight check is a hint, not the result of the actual capture API. Only
/// probe automatically when previously granted; an explicit user retry may
/// probe regardless of preflight. Never persist a grant across app launches.
public final class PreviewPermission {
    public private(set) var state: PreviewPermissionState = .unchecked {
        didSet { changed?(state) }
    }
    public var changed: ((PreviewPermissionState) -> Void)?
    public init() {}

    @MainActor
    public func check(preflight: Bool, userInitiated: Bool,
                      probe: () async throws -> Void) async {
        guard state != .checking, preflight || userInitiated else { return }
        state = .checking
        do {
            try await probe()
            state = .available
        } catch PreviewPermissionFailure.denied {
            state = .denied
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    public func captureWasDenied() { state = .denied }
}
