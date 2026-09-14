import Foundation
import CoreGraphics

public enum PlacementOutcome: Equatable { case placed, failed, cancelled }

/// AX writes can time out even when the destination app accepts them. Observe the
/// resulting frame, allow animation to settle, and never retry after a new gesture.
public enum WindowPlacement {
    @MainActor
    public static func settle(
        at target: CGRect,
        read: () -> CGRect?,
        write: (CGRect) -> Void,
        cancelled: () -> Bool,
        pause: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) async -> PlacementOutcome {
        guard target.width.isFinite, target.height.isFinite,
              target.minX.isFinite, target.minY.isFinite,
              target.width >= 50, target.height >= 50 else { return .failed }
        var consecutiveMatches = 0
        var previous: CGRect?
        var unchangedSamples = 0
        for sample in 0..<16 {
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            // Space corrective writes apart; repeated AX writes during an animation
            // can restart it indefinitely. Never restart while already at the target.
            if sample == 0 || ((sample == 5 || sample == 10) && unchangedSamples >= 2) {
                if read().map({ !SnapGeometry.nearlyEqual($0, target) }) ?? true { write(target) }
            }
            do { try await pause(75_000_000) } catch { return .cancelled }
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            let actual = read()
            if let actual, let previous, SnapGeometry.nearlyEqual(actual, previous) { unchangedSamples += 1 }
            else { unchangedSamples = 0 }
            previous = actual
            if let actual, SnapGeometry.nearlyEqual(actual, target) {
                consecutiveMatches += 1
                if consecutiveMatches == 2 { return .placed }
            } else { consecutiveMatches = 0 }
        }
        return .failed
    }
}
