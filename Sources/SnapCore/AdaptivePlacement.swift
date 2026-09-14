import Foundation
import CoreGraphics

public struct AdaptivePlacementResult {
    public let outcome: TransactionOutcome
    public let layout: SnapLayout
    public let observedFailure: CGRect?
}

/// Fit against observed window behavior, not a hard-coded app list or an assumed
/// minimum size. Each attempt is a verified transaction with the same baseline.
public enum AdaptivePlacement {
    /// A narrower user-resized window invalidates an earlier working-width hint.
    public static func usableHint(_ width: CGFloat?, current: CGRect) -> CGFloat? {
        guard let width, width.isFinite, width >= 50, WindowPlacement.valid(current),
              current.width >= width - 3 else { return nil }
        return width
    }

    @MainActor
    public static func place(
        layout: SnapLayout, zone: Int, work: CGRect, originals: [Int: CGRect], widthHint: CGFloat?,
        read: (Int) -> CGRect?, place: (Int, CGRect) async -> PlacementOutcome, cancelled: () -> Bool
    ) async -> AdaptivePlacementResult {
        guard let original = originals[zone], !originals.isEmpty,
              originals.keys.allSatisfy({ layout.zones.indices.contains($0) }),
              originals.values.allSatisfy(WindowPlacement.valid), WindowPlacement.valid(work) else {
            return AdaptivePlacementResult(outcome: .rollbackFailed, layout: layout, observedFailure: nil)
        }
        var attempts: [SnapLayout] = []
        if let hint = usableHint(widthHint, current: original),
           let suggested = layout.widerSplit(for: zone, observed: CGSize(width: hint, height: min(original.height, work.height)), in: work) {
            attempts.append(suggested)
        }
        attempts.append(layout)
        var observedFailure: CGRect?
        var index = 0
        while index < attempts.count {
            guard !cancelled(), !Task.isCancelled else {
                return AdaptivePlacementResult(outcome: .cancelled, layout: layout, observedFailure: observedFailure)
            }
            let attempted = attempts[index]
            let frames = attempted.frames(in: work)
            let targets = Dictionary(uniqueKeysWithValues: originals.keys.map { ($0, frames[$0]) })
            var candidateFailure: CGRect?
            let result = await WindowPlacement.stagedTransaction(targets: targets, originals: originals, read: read,
                place: { id, frame in
                    let result = await place(id, frame)
                    if id == zone, result == .failed, let observed = read(id), WindowPlacement.valid(observed) {
                        candidateFailure = observed
                    }
                    return result
                }, cancelled: cancelled)
            if let candidateFailure { observedFailure = candidateFailure }
            guard result == .rolledBack else {
                return AdaptivePlacementResult(outcome: result, layout: attempted, observedFailure: observedFailure)
            }
            // After a failed cached hint, try the requested layout afresh. After
            // a real refusal, try its observed width once, only if not tried yet.
            // No more than three bounded attempts; never loop on a refusal.
            if attempted == layout, let observed = candidateFailure,
               let adjusted = layout.widerSplit(for: zone, observed: observed.size, in: work),
               !attempts.contains(where: { $0.zones == adjusted.zones }) {
                attempts.append(adjusted)
            }
            index += 1
        }
        return AdaptivePlacementResult(outcome: .rolledBack, layout: layout, observedFailure: observedFailure)
    }
}
