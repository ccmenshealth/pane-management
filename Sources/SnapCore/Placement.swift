import Foundation
import CoreGraphics

public enum PlacementOutcome: Equatable { case placed, failed, cancelled }
public enum TransactionOutcome: Equatable { case placed, rolledBack, rollbackFailed, cancelled }

/// AX writes can time out even when the destination app accepts them. Observe the
/// resulting frame, allow animation to settle, and never retry after a new gesture.
public enum WindowPlacement {
    /// State changes such as minimizing are asynchronous too. Unknown reads are
    /// not false, and one transient observation must not complete the operation.
    @MainActor
    public static func confirmState(
        _ target: Bool, read: () -> Bool?, cancelled: () -> Bool,
        pause: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) async -> PlacementOutcome {
        var matches = 0
        for _ in 0..<32 {
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            do { try await pause(75_000_000) } catch { return .cancelled }
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            matches = read() == target ? matches + 1 : 0
            if matches == 2 { return .placed }
        }
        return .failed
    }

    /// AppKit may animate each AX attribute independently. Issuing a position
    /// write immediately after a size write can replace that animation with a
    /// move using the old size. Settle each component before issuing the next.
    /// Shrink before crossing screens, then grow on the destination display.
    @MainActor
    public static func staged(
        at target: CGRect, read: () -> CGRect?,
        resize: (CGSize) -> Void, move: (CGPoint) -> Void, cancelled: () -> Bool,
        pause: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) async -> PlacementOutcome {
        guard valid(target), let initial = read(), valid(initial) else { return .failed }
        let smaller = CGSize(width: min(initial.width, target.width), height: min(initial.height, target.height))
        let stages: [(Bool, CGRect)] = [
            (true, CGRect(origin: .zero, size: smaller)),
            (false, CGRect(origin: target.origin, size: CGSize(width: 50, height: 50))),
            (true, CGRect(origin: .zero, size: target.size)),
            (false, CGRect(origin: target.origin, size: CGSize(width: 50, height: 50))),
            // Growing an AppKit window can shift its origin and clamp its size
            // against the display edge. Realign before one final grow attempt.
            (true, CGRect(origin: .zero, size: target.size)),
            (false, CGRect(origin: target.origin, size: CGSize(width: 50, height: 50)))
        ]
        for (index, stage) in stages.enumerated() {
            let (sizing, component) = stage
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            func readComponent() -> CGRect? {
                read().map { sizing ? CGRect(origin: .zero, size: $0.size) : CGRect(origin: $0.origin, size: CGSize(width: 50, height: 50)) }
            }
            if readComponent().map({ SnapGeometry.nearlyEqual($0, component) }) == true { continue }
            let result = await settle(at: component, read: readComponent,
                write: { if sizing { resize($0.size) } else { move($0.origin) } }, cancelled: cancelled, pause: pause)
            if result == .cancelled { return result }
            // A failed shrink cannot safely cross displays. A constrained grow
            // may recover after aligning the origin; final full-frame settling
            // still has to pass before placement is reported as successful.
            if result == .failed && !(sizing && index >= 2) { return result }
        }
        return await settle(at: target, read: read, write: { _ in }, cancelled: cancelled, pause: pause)
    }

    /// Use a verified asynchronous placer for each member, then check the complete
    /// group at one instant. No rollback may race a newer user gesture.
    @MainActor
    public static func stagedTransaction<ID: Hashable>(
        targets: [ID: CGRect], originals: [ID: CGRect], read: (ID) -> CGRect?,
        place: (ID, CGRect) async -> PlacementOutcome, cancelled: () -> Bool
    ) async -> TransactionOutcome {
        guard !targets.isEmpty, Set(targets.keys) == Set(originals.keys),
              targets.values.allSatisfy(valid), originals.values.allSatisfy(valid) else { return .rollbackFailed }
        var failed = false
        for (id, frame) in targets {
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            let result = await place(id, frame)
            if result == .cancelled || cancelled() || Task.isCancelled { return .cancelled }
            if result != .placed { failed = true; break }
        }
        if !failed && targets.allSatisfy({ id, frame in read(id).map { SnapGeometry.nearlyEqual($0, frame) } ?? false }) { return .placed }
        for (id, frame) in originals {
            guard !cancelled(), !Task.isCancelled else { return .cancelled }
            let result = await place(id, frame)
            if result == .cancelled || cancelled() || Task.isCancelled { return .cancelled }
        }
        return originals.allSatisfy { id, frame in read(id).map { SnapGeometry.nearlyEqual($0, frame) } ?? false } ? .rolledBack : .rollbackFailed
    }

    public static func valid(_ frame: CGRect) -> Bool {
        frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite &&
            frame.width >= 50 && frame.height >= 50
    }

    @MainActor
    public static func settle(
        at target: CGRect,
        read: () -> CGRect?,
        write: (CGRect) -> Void,
        cancelled: () -> Bool,
        pause: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) async -> PlacementOutcome {
        guard valid(target) else { return .failed }
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
