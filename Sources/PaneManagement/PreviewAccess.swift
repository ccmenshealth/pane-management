import AppKit
import Combine
import ScreenCaptureKit
import SnapCore

final class PreviewAccess: ObservableObject {
    static let shared = PreviewAccess()
    @Published private(set) var state: PreviewPermissionState = .unchecked
    private let permission = PreviewPermission()
    var isAvailable: Bool { state == .available }
    var isChecking: Bool { state == .checking }
    var needsRecovery: Bool {
        switch state { case .denied, .failed: return true; default: return false }
    }
    var message: String {
        switch state {
        case .unchecked: return "Optional. Check access to enable window thumbnails. Icons and titles work without it."
        case .checking: return "Checking this running app’s access with ScreenCaptureKit…"
        case .available: return "ScreenCaptureKit access verified. Previews stay in memory."
        case .denied: return "macOS denied this running build access. If the switch is already on, quit and reopen Pane Management. If it still fails after a rebuild, remove and re-add this exact app in Screen & System Audio Recording."
        case .failed(let detail): return "The preview check failed: \(detail). Try Check Again; snapping can still use icons."
        }
    }

    private init() {
        permission.changed = { [weak self] in self?.state = $0 }
    }

    @MainActor
    func check(userInitiated: Bool) {
        Task { @MainActor in
            await permission.check(preflight: CGPreflightScreenCaptureAccess(), userInitiated: userInitiated) {
                do {
                    // Enumerates shareable content; this check does not take or
                    // retain screenshots. Explicit use may show macOS consent.
                    _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                } catch {
                    if Self.isPermissionDenied(error) { throw PreviewPermissionFailure.denied }
                    throw error
                }
            }
        }
    }

    static func isPermissionDenied(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue
    }

    @MainActor
    func captureFailed(_ error: Error) {
        if Self.isPermissionDenied(error) { permission.captureWasDenied() }
    }
}
