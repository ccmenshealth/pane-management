import Foundation
import Darwin
import CoreGraphics
import SnapCore

// Command Line Tools don't ship XCTest. Keep these checks runnable with plain Swift.
private var failures = 0
private func fail(_ text: String, file: StaticString, line: UInt) {
    failures += 1
    print("FAIL \(file):\(line): \(text)")
}
private func XCTAssertTrue(_ value: Bool, _ message: String = "Expected true", file: StaticString = #file, line: UInt = #line) {
    if !value { fail(message, file: file, line: line) }
}
private func XCTAssertFalse(_ value: Bool, _ message: String = "Expected false", file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(!value, message, file: file, line: line)
}
private func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(value == nil, "Expected nil", file: file, line: line)
}
private func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "Values differ", file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(a == b, "\(message): \(a) != \(b)", file: file, line: line)
}
private func XCTAssertEqual(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat, _ message: String = "Values differ", file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(abs(a-b) <= accuracy, "\(message): \(a) != \(b)", file: file, line: line)
}

@main
final class SnapCoreTests {
    @MainActor static func main() async {
        let suite = SnapCoreTests()
        suite.testAllLayoutsTileWithoutOverlapOrLostArea()
        suite.testEdgesAndCornersOnDisplayLeftOfAndAbovePrimary()
        suite.testCoordinateConversionIsReversibleAcrossMonitors()
        suite.testAssistFillsOtherHalfThenFinishes()
        suite.testAssistSkipsAndNeverReusesAWindow()
        suite.testRestoreKeepsOriginalSizeAndCursorAnchorInsideWorkArea()
        suite.testSharedResizeKeepsHalvesContiguousAndClampsMinimum()
        suite.testSharedResizeMovesAllFourWindowBoundarySegments()
        suite.testDropRechecksLocationAndEdgeHysteresis()
        suite.testOnlyWindowMovementArmsSnapping()
        await suite.testPlacementWaitsForAnimationWithoutRestartingIt()
        await suite.testPlacementRetriesAStalledWrite()
        await suite.testPlacementDoesNotTrustOneTransientMatch()
        await suite.testPlacementCancellationNeverWritesAgain()
        await suite.testPlacementRejectsFixedSizeAndInvalidFrames()
        await suite.testPlacementAlreadyAtTargetNeedsNoWrite()
        suite.testAdaptiveLayoutsUseLogicalWorkArea()
        suite.testKeyboardSequencesPreserveQuarterRows()
        suite.testKeyboardRecognizesActualGeometry()
        suite.testKeyboardRestoresCustomLayoutBeforeMinimizing()
        suite.testLiveRestoreUsesOriginalGrabPointAcrossDisplays()
        suite.testHeightOnlyMaximizePreservesWidth()
        suite.testNativeSharedEdgeResize()
        suite.testNativeResizeRejectsMovementOutsideEdgesAndCorners()
        suite.testNearEdgePreferenceAndHysteresis()
        await suite.testGroupTransactionSettlesAllWindowsTogether()
        await suite.testGroupTransactionRollsBackAfterSizeRefusal()
        await suite.testGroupTransactionReportsFailedRollback()
        await suite.testGroupTransactionCancellationDoesNotRollback()
        await suite.testGroupTransactionRejectsIncompleteBaselines()
        await suite.testStagedPlacementDoesNotCancelSizeWithMove()
        await suite.testStagedPlacementShrinksBeforeCrossingDisplays()
        await suite.testStagedPlacementCancellationStopsRemainingStages()
        await suite.testStagedGroupDetectsLateDrift()
        await suite.testPreviewCheckDoesNotRequestAccessAutomatically()
        await suite.testExplicitPreviewCheckCanSucceedWithFalsePreflight()
        await suite.testPreviewDenialCanBeRetried()
        await suite.testPreviewCheckPreservesNonPermissionErrors()
        await suite.testPreviewChecksCoalesceWhilePending()
        await suite.testPreviewRevocationClearsVerifiedAccess()
        await suite.testStagedPlacementRecoversFromGrowthOriginConstraint()
        await suite.testStagedPlacementDoesNotAcceptPermanentlyConstrainedGrowth()
        await suite.testStateConfirmationWaitsForStableChange()
        await suite.testStateConfirmationRejectsUnknownAndRefusal()
        await suite.testStateConfirmationCancelsWithoutAnotherRead()
        suite.testWiderSplitPreservesLeftAndRightAssignments()
        suite.testWiderSplitCoversNegativeOriginDisplay()
        suite.testWiderSplitRejectsInsufficientRoomAndHeight()
        suite.testWiderSplitRejectsStackedAndInvalidGeometry()
        await suite.testWiderSplitTransactionAcceptsConstrainedCandidate()
        await suite.testWiderSplitTransactionRestoresBothWhenNeighborRefuses()
        print("51 scenarios completed; \(failures) failures")
        if failures > 0 { exit(1) }
    }

    func testWiderSplitPreservesLeftAndRightAssignments() {
        let work = CGRect(x: 0, y: 33, width: 1470, height: 923)
        for zone in 0...1 {
            let layout = SnapLayout.halves.widerSplit(for: zone, observed: CGSize(width: 900, height: 702), in: work)!
            let frames = layout.frames(in: work)
            XCTAssertEqual(frames[zone].width, 900)
            XCTAssertEqual(frames[1-zone].width, 570)
            XCTAssertEqual(frames[0].maxX, frames[1].minX)
            XCTAssertEqual(frames[0].minX, work.minX)
            XCTAssertEqual(frames[1].maxX, work.maxX)
            XCTAssertEqual(frames[zone].height, work.height)
        }
        // Refusing height/position without a wider observed frame is not evidence
        // for a wider retry, nor is an ordinary current width a proven minimum.
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: CGSize(width: 735, height: 702), in: work))
    }

    func testWiderSplitCoversNegativeOriginDisplay() {
        let work = CGRect(x: -1919, y: -307, width: 1919, height: 1047)
        let layout = SnapLayout.halves.widerSplit(for: 1, observed: CGSize(width: 1100.2, height: 702), in: work)!
        let frames = layout.frames(in: work)
        XCTAssertEqual(frames[1].width, 1101)
        XCTAssertEqual(frames[0].width, 818)
        XCTAssertEqual(frames[0].maxX, frames[1].minX)
        XCTAssertEqual(frames[1].maxX, work.maxX)
        XCTAssertEqual(frames[1].minY, work.minY)
        let reversed = SnapLayout("reversed", "Reversed", SnapLayout.halves.zones.reversed())
        let retry = reversed.widerSplit(for: 0, observed: CGSize(width: 1101, height: 702), in: work)!
        XCTAssertEqual(retry.frames(in: work)[0], frames[1])
    }

    func testWiderSplitRejectsInsufficientRoomAndHeight() {
        let work = CGRect(x: 0, y: 33, width: 1470, height: 923)
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: CGSize(width: 1200, height: 702), in: work))
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: CGSize(width: 900, height: 1000), in: work))
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: CGSize(width: 900, height: 702), in: CGRect(x: 0, y: 0, width: 1200, height: 900)))
    }

    func testWiderSplitRejectsStackedAndInvalidGeometry() {
        let work = CGRect(x: 0, y: 33, width: 1470, height: 923)
        let size = CGSize(width: 900, height: 702)
        for layout in [SnapLayout.thirds, .leftStack, .quarters, .full,
                       SnapLayout("rows", "Rows", [CGRect(x: 0, y: 0, width: 1, height: 0.5), CGRect(x: 0, y: 0.5, width: 1, height: 0.5)])] {
            XCTAssertNil(layout.widerSplit(for: 0, observed: size, in: work))
        }
        XCTAssertNil(SnapLayout.halves.widerSplit(for: -1, observed: size, in: work))
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 2, observed: size, in: work))
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: CGSize(width: CGFloat.nan, height: 702), in: work))
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: CGSize(width: 900, height: CGFloat.infinity), in: work))
        XCTAssertNil(SnapLayout.halves.widerSplit(for: 0, observed: size, in: .zero))
    }

    @MainActor func testWiderSplitTransactionAcceptsConstrainedCandidate() async {
        let work = CGRect(x: 0, y: 33, width: 1470, height: 923)
        let original = [0: CGRect(x: 285, y: 89, width: 900, height: 702), 1: SnapLayout.halves.frames(in: work)[1]]
        var frames = original
        let normal = await WindowPlacement.staged(at: SnapLayout.halves.frames(in: work)[0], read: { frames[0] },
            resize: { frames[0]!.size = CGSize(width: max(900, $0.width), height: $0.height) }, move: { frames[0]!.origin = $0 },
            cancelled: { false }, pause: { _ in })
        XCTAssertEqual(normal, .failed)
        let recovery = SnapLayout.halves.widerSplit(for: 0, observed: frames[0]!.size, in: work)!
        let targets = Dictionary(uniqueKeysWithValues: recovery.frames(in: work).enumerated().map { ($0.offset, $0.element) })
        let result = await WindowPlacement.stagedTransaction(targets: targets, originals: original, read: { frames[$0] },
            place: { id, frame in
                await WindowPlacement.staged(at: frame, read: { frames[id] },
                    resize: { frames[id]!.size = CGSize(width: max(id == 0 ? 900 : 320, $0.width), height: $0.height) },
                    move: { frames[id]!.origin = $0 }, cancelled: { false }, pause: { _ in })
            }, cancelled: { false })
        XCTAssertEqual(result, .placed)
        XCTAssertEqual(frames, targets)
    }

    @MainActor func testWiderSplitTransactionRestoresBothWhenNeighborRefuses() async {
        let work = CGRect(x: 0, y: 33, width: 1470, height: 923)
        let original = [0: CGRect(x: 285, y: 89, width: 900, height: 702), 1: SnapLayout.halves.frames(in: work)[1]]
        var frames = original
        let recovery = SnapLayout.halves.widerSplit(for: 0, observed: original[0]!.size, in: work)!
        let targets = Dictionary(uniqueKeysWithValues: recovery.frames(in: work).enumerated().map { ($0.offset, $0.element) })
        let result = await WindowPlacement.stagedTransaction(targets: targets, originals: original, read: { frames[$0] },
            place: { id, frame in
                await WindowPlacement.staged(at: frame, read: { frames[id] },
                    resize: { frames[id]!.size = CGSize(width: max(id == 0 ? 900 : 700, $0.width), height: $0.height) },
                    move: { frames[id]!.origin = $0 }, cancelled: { false }, pause: { _ in })
            }, cancelled: { false })
        XCTAssertEqual(result, .rolledBack)
        XCTAssertEqual(frames, original)
    }

    @MainActor func testStateConfirmationWaitsForStableChange() async {
        var samples = 0
        let states: [Bool?] = [false, nil, true, false, true, true]
        let result = await WindowPlacement.confirmState(true, read: { states[min(samples-1, states.count-1)] },
            cancelled: { false }, pause: { _ in samples += 1 })
        XCTAssertEqual(result, .placed)
        XCTAssertEqual(samples, 6)
    }

    @MainActor func testStateConfirmationRejectsUnknownAndRefusal() async {
        for state: Bool? in [nil, true] {
            var samples = 0
            let result = await WindowPlacement.confirmState(false, read: { state }, cancelled: { false }, pause: { _ in samples += 1 })
            XCTAssertEqual(result, .failed)
            XCTAssertEqual(samples, 32)
        }
    }

    @MainActor func testStateConfirmationCancelsWithoutAnotherRead() async {
        var cancelled = false, reads = 0
        let result = await WindowPlacement.confirmState(true, read: { reads += 1; return true },
            cancelled: { cancelled }, pause: { _ in cancelled = true })
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(reads, 0)
    }

    @MainActor func testPreviewCheckDoesNotRequestAccessAutomatically() async {
        let permission = PreviewPermission()
        var probes = 0
        await permission.check(preflight: false, userInitiated: false) { probes += 1 }
        XCTAssertEqual(probes, 0)
        XCTAssertEqual(permission.state, .unchecked)
    }

    @MainActor func testExplicitPreviewCheckCanSucceedWithFalsePreflight() async {
        let permission = PreviewPermission()
        var states: [PreviewPermissionState] = []
        permission.changed = { states.append($0) }
        await permission.check(preflight: false, userInitiated: true) {}
        XCTAssertEqual(states, [.checking, .available])
        // A later false preflight hint must not erase successful API access.
        await permission.check(preflight: false, userInitiated: false) { throw PreviewPermissionFailure.denied }
        XCTAssertEqual(permission.state, .available)
    }

    @MainActor func testPreviewDenialCanBeRetried() async {
        let permission = PreviewPermission()
        await permission.check(preflight: true, userInitiated: true) { throw PreviewPermissionFailure.denied }
        XCTAssertEqual(permission.state, .denied)
        await permission.check(preflight: false, userInitiated: true) {}
        XCTAssertEqual(permission.state, .available)
    }

    @MainActor func testPreviewCheckPreservesNonPermissionErrors() async {
        let permission = PreviewPermission()
        await permission.check(preflight: true, userInitiated: false) {
            throw NSError(domain: "Fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Capture service unavailable"])
        }
        XCTAssertEqual(permission.state, .failed("Capture service unavailable"))
    }

    @MainActor func testPreviewChecksCoalesceWhilePending() async {
        let permission = PreviewPermission()
        var probes = 0
        await permission.check(preflight: true, userInitiated: true) {
            probes += 1
            await permission.check(preflight: true, userInitiated: true) { probes += 1 }
        }
        XCTAssertEqual(probes, 1)
        XCTAssertEqual(permission.state, .available)
    }

    @MainActor func testPreviewRevocationClearsVerifiedAccess() async {
        let permission = PreviewPermission()
        await permission.check(preflight: true, userInitiated: false) {}
        permission.captureWasDenied()
        XCTAssertEqual(permission.state, .denied)
    }

    @MainActor func testStagedPlacementRecoversFromGrowthOriginConstraint() async {
        let target = CGRect(x: 735, y: 33, width: 735, height: 923)
        var frame = CGRect(x: 145, y: 76, width: 650, height: 452)
        var firstGrowth = true, requiresAlignment = false
        var resizedAfterAlignment = false
        let result = await WindowPlacement.staged(at: target, read: { frame }, resize: { size in
            if firstGrowth || requiresAlignment {
                firstGrowth = false; requiresAlignment = true
                frame = CGRect(x: 686, y: 37, width: size.width, height: 919)
            } else { frame.size = size; resizedAfterAlignment = true }
        }, move: { point in
            frame.origin = point
            if !firstGrowth { requiresAlignment = false }
        }, cancelled: { false }, pause: { _ in })
        XCTAssertEqual(result, .placed)
        XCTAssertEqual(frame, target)
        XCTAssertTrue(resizedAfterAlignment)
    }

    @MainActor func testStagedPlacementDoesNotAcceptPermanentlyConstrainedGrowth() async {
        let target = CGRect(x: 735, y: 33, width: 735, height: 923)
        var frame = CGRect(x: 145, y: 76, width: 650, height: 452)
        var writes = 0
        let result = await WindowPlacement.staged(at: target, read: { frame }, resize: { size in
            writes += 1; frame.size = CGSize(width: size.width, height: 919)
        }, move: { frame.origin = $0 }, cancelled: { false }, pause: { _ in })
        XCTAssertEqual(result, .failed)
        XCTAssertTrue(writes <= 6, "Growth correction must stay bounded")
        XCTAssertFalse(SnapGeometry.nearlyEqual(frame, target))
    }
    func testAllLayoutsTileWithoutOverlapOrLostArea() {
        for layout in SnapLayout.all {
            let work = CGRect(x: -1729, y: -931, width: 1729, height: 1003)
            let frames = layout.frames(in: work)
            XCTAssertEqual(frames.reduce(CGFloat(0)) { $0 + $1.width*$1.height }, work.width*work.height, accuracy: 1, layout.id)
            for i in frames.indices {
                XCTAssertTrue(work.contains(frames[i]), layout.id)
                for j in frames.indices where i < j {
                    let intersection = frames[i].intersection(frames[j])
                    XCTAssertTrue(intersection.isNull || intersection.width*intersection.height == 0, layout.id)
                }
            }
        }
    }
    func testEdgesAndCornersOnDisplayLeftOfAndAbovePrimary() {
        let screen = CGRect(x: -1440, y: -900, width: 1440, height: 900)
        XCTAssertEqual(SnapGeometry.edgeTarget(at: CGPoint(x: -1439, y: -450), screen: screen), SnapTarget(.halves, 0))
        XCTAssertEqual(SnapGeometry.edgeTarget(at: CGPoint(x: -1, y: -450), screen: screen), SnapTarget(.halves, 1))
        XCTAssertEqual(SnapGeometry.edgeTarget(at: CGPoint(x: -1439, y: -899), screen: screen), SnapTarget(.quarters, 0))
        XCTAssertEqual(SnapGeometry.edgeTarget(at: CGPoint(x: -1, y: -1), screen: screen), SnapTarget(.quarters, 3))
        XCTAssertEqual(SnapGeometry.edgeTarget(at: CGPoint(x: -720, y: -899), screen: screen), SnapTarget(.full, 0))
        XCTAssertNil(SnapGeometry.edgeTarget(at: CGPoint(x: 100, y: -450), screen: screen))
        XCTAssertNil(SnapGeometry.edgeTarget(at: CGPoint(x: -720, y: -450), screen: screen))
    }
    func testCoordinateConversionIsReversibleAcrossMonitors() {
        let rect = CGRect(x: -1900, y: -1200, width: 1900, height: 1150)
        let cocoa = SnapGeometry.cocoaRect(from: rect, primaryHeight: 982)
        XCTAssertEqual(cocoa.minY, 1032)
        XCTAssertEqual(SnapGeometry.cocoaRect(from: cocoa, primaryHeight: 982), rect)
    }
    func testAssistFillsOtherHalfThenFinishes() {
        var session = AssistSession(layout: .halves, firstZone: 1, window: "Safari:1")
        XCTAssertEqual(session.nextZone, 0)
        XCTAssertFalse(session.choose("Safari:1"))
        XCTAssertTrue(session.choose("Safari:2"), "Two windows from one app must both be selectable")
        XCTAssertNil(session.nextZone)
        XCTAssertEqual(session.assignments[0], "Safari:2")
    }
    func testAssistSkipsAndNeverReusesAWindow() {
        var session = AssistSession(layout: .quarters, firstZone: 2, window: 42)
        XCTAssertEqual(session.nextZone, 0)
        session.skip()
        XCTAssertEqual(session.nextZone, 1)
        XCTAssertTrue(session.choose(7))
        XCTAssertEqual(session.nextZone, 3)
        XCTAssertFalse(session.choose(42))
        session.skip()
        XCTAssertNil(session.nextZone)
        XCTAssertEqual(session.usedWindows, [42, 7])
    }
    func testRestoreKeepsOriginalSizeAndCursorAnchorInsideWorkArea() {
        let original = CGRect(x: 100, y: 100, width: 700, height: 500)
        let snapped = CGRect(x: 0, y: 25, width: 800, height: 900)
        let work = CGRect(x: 0, y: 25, width: 1600, height: 900)
        let result = SnapGeometry.restoredFrame(original: original, snapped: snapped, cursor: CGPoint(x: 700, y: 80), workArea: work)
        XCTAssertEqual(result.size, original.size)
        XCTAssertEqual(result.minX + 700*0.875, 700)
        XCTAssertTrue(work.contains(result))
        let bounded = SnapGeometry.restoredFrame(original: original, snapped: snapped, cursor: CGPoint(x: 0, y: 26), workArea: work)
        XCTAssertEqual(bounded.minX, 0)
        XCTAssertEqual(bounded.minY, 25)
    }
    func testSharedResizeKeepsHalvesContiguousAndClampsMinimum() {
        let layout = SnapLayout.halves
        let boundary = layout.boundaries[0]
        let moved = layout.moving(boundary, to: 0.7)!
        XCTAssertEqual(moved.zones[0].width, 0.7, accuracy: 0.0001)
        XCTAssertEqual(moved.zones[1].minX, moved.zones[0].maxX)
        XCTAssertEqual(moved.zones[1].maxX, 1, accuracy: 0.0001)
        XCTAssertEqual(layout.moving(boundary, to: 0.99)!.zones[1].width, 0.15, accuracy: 0.0001)
    }
    func testSharedResizeMovesAllFourWindowBoundarySegments() {
        let layout = SnapLayout.quarters
        let boundary = layout.boundaries.first { $0.axis == .vertical }!
        let moved = layout.moving(boundary, to: 0.63)!
        XCTAssertEqual(moved.zones[0].width, moved.zones[2].width)
        XCTAssertEqual(moved.zones[1].minX, moved.zones[3].minX)
        XCTAssertEqual(moved.zones.reduce(CGFloat(0)) { $0 + $1.width*$1.height }, 1, accuracy: 0.0001)
    }

    func testDropRechecksLocationAndEdgeHysteresis() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let left = SnapTarget(.halves, 0)
        XCTAssertEqual(SnapGeometry.dragTarget(at: CGPoint(x: 24, y: 400), screen: screen, previous: left), left)
        XCTAssertNil(SnapGeometry.dragTarget(at: CGPoint(x: 24, y: 400), screen: screen, previous: nil))
        XCTAssertNil(SnapGeometry.dragTarget(at: CGPoint(x: 300, y: 400), screen: screen, previous: left))
        XCTAssertEqual(SnapGeometry.dragTarget(at: CGPoint(x: 1439, y: 400), screen: screen, previous: left), SnapTarget(.halves, 1))
        XCTAssertEqual(SnapGeometry.dragTarget(at: CGPoint(x: 1, y: 1), screen: screen, previous: left), SnapTarget(.quarters, 0))
        XCTAssertNil(SnapGeometry.dragTarget(at: CGPoint(x: -100, y: 400), screen: screen, previous: left))
    }
    func testOnlyWindowMovementArmsSnapping() {
        let start = CGRect(x: 100, y: 100, width: 650, height: 420)
        XCTAssertFalse(SnapGeometry.isWindowMove(from: start, to: start, cursorTravel: 300), "Text selection is not a drag")
        XCTAssertFalse(SnapGeometry.isWindowMove(from: start, to: CGRect(x: 80, y: 100, width: 670, height: 420), cursorTravel: 20), "Edge resizing is not a drag")
        XCTAssertFalse(SnapGeometry.isWindowMove(from: start, to: start.offsetBy(dx: 20, dy: 0), cursorTravel: 2))
        XCTAssertTrue(SnapGeometry.isWindowMove(from: start, to: start.offsetBy(dx: 20, dy: 10), cursorTravel: 25))
    }

    @MainActor func testPlacementWaitsForAnimationWithoutRestartingIt() async {
        let target = CGRect(x: 0, y: 25, width: 720, height: 875)
        var frame = target.offsetBy(dx: 200, dy: 0), samples = 0, writes = 0
        let outcome = await WindowPlacement.settle(at: target, read: { frame }, write: { _ in writes += 1 }, cancelled: { false }, pause: { _ in
            samples += 1
            frame = target.offsetBy(dx: CGFloat(max(0, 200-samples*20)), dy: 0)
        })
        XCTAssertEqual(outcome, .placed)
        XCTAssertEqual(writes, 1, "Do not restart an in-flight animation")
        XCTAssertEqual(samples, 11, "Wait beyond the old 120 ms deadline and verify two frames")
    }
    @MainActor func testPlacementRetriesAStalledWrite() async {
        let target = CGRect(x: 0, y: 25, width: 720, height: 875)
        var frame = target.offsetBy(dx: 300, dy: 0), writes = 0
        let outcome = await WindowPlacement.settle(at: target, read: { frame }, write: { requested in
            writes += 1
            if writes == 2 { frame = requested }
        }, cancelled: { false }, pause: { _ in })
        XCTAssertEqual(outcome, .placed)
        XCTAssertEqual(writes, 2)
    }
    @MainActor func testPlacementDoesNotTrustOneTransientMatch() async {
        let target = CGRect(x: 0, y: 25, width: 720, height: 875)
        var samples = 0
        let outcome = await WindowPlacement.settle(at: target, read: { samples == 1 ? target : target.offsetBy(dx: 200, dy: 0) },
            write: { _ in }, cancelled: { false }, pause: { _ in samples += 1 })
        XCTAssertEqual(outcome, .failed)
    }
    @MainActor func testPlacementCancellationNeverWritesAgain() async {
        let target = CGRect(x: 0, y: 25, width: 720, height: 875)
        var cancelled = false, writes = 0
        let outcome = await WindowPlacement.settle(at: target, read: { .zero }, write: { _ in writes += 1 },
            cancelled: { cancelled }, pause: { _ in cancelled = true })
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(writes, 1)
        let beforeStart = await WindowPlacement.settle(at: target, read: { .zero }, write: { _ in writes += 1 },
            cancelled: { true }, pause: { _ in })
        XCTAssertEqual(beforeStart, .cancelled)
        XCTAssertEqual(writes, 1)
    }
    @MainActor func testPlacementRejectsFixedSizeAndInvalidFrames() async {
        let target = CGRect(x: 0, y: 25, width: 720, height: 875)
        var writes = 0
        let outcome = await WindowPlacement.settle(at: target, read: { CGRect(x: 0, y: 25, width: 900, height: 875) },
            write: { _ in writes += 1 }, cancelled: { false }, pause: { _ in })
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(writes, 3, "Retries must be bounded")
        let invalid = await WindowPlacement.settle(at: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 500), read: { .zero },
            write: { _ in writes += 1 }, cancelled: { false }, pause: { _ in })
        XCTAssertEqual(invalid, .failed)
        XCTAssertEqual(writes, 3)
    }
    @MainActor func testPlacementAlreadyAtTargetNeedsNoWrite() async {
        let target = CGRect(x: 0, y: 25, width: 720, height: 875)
        var writes = 0
        let outcome = await WindowPlacement.settle(at: target, read: { target }, write: { _ in writes += 1 },
            cancelled: { false }, pause: { _ in })
        XCTAssertEqual(outcome, .placed)
        XCTAssertEqual(writes, 0)
    }

    func testAdaptiveLayoutsUseLogicalWorkArea() {
        let small = SnapLayout.available(in: CGRect(x: 0, y: 25, width: 1000, height: 700))
        XCTAssertEqual(small.map(\.id), ["halves", "wideLeft", "thirds", "leftStack", "quarters"])
        XCTAssertEqual(SnapLayout.available(in: CGRect(x: -2000, y: -900, width: 1470, height: 923)), SnapLayout.all)
        XCTAssertEqual(SnapLayout.available(in: CGRect(x: 0, y: 0, width: 700, height: 400)).map(\.id), ["halves"])
        XCTAssertTrue(SnapLayout.available(in: CGRect(x: 0, y: 0, width: 500, height: 300)).isEmpty)
    }
    func testKeyboardSequencesPreserveQuarterRows() {
        XCTAssertEqual(KeyboardPlacement.floating.pressing(.left).pressing(.up), .topLeft)
        XCTAssertEqual(KeyboardPlacement.topLeft.pressing(.right), .topRight)
        XCTAssertEqual(KeyboardPlacement.bottomRight.pressing(.left), .bottomLeft)
        XCTAssertEqual(KeyboardPlacement.left.pressing(.right), .floating)
        XCTAssertEqual(KeyboardPlacement.maximized.pressing(.down), .floating)
        XCTAssertEqual(KeyboardPlacement.bottomLeft.pressing(.up), .topLeft)
        XCTAssertEqual(KeyboardPlacement.topRight.pressing(.down), .bottomRight)
    }
    func testKeyboardRecognizesActualGeometry() {
        let work = CGRect(x: -1470, y: -900, width: 1470, height: 900)
        for state: KeyboardPlacement in [.left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight, .maximized] {
            let target = state.target!
            XCTAssertEqual(KeyboardPlacement.matching(target.layout.frames(in: work)[target.zone], work: work), state)
        }
        XCTAssertEqual(KeyboardPlacement.matching(CGRect(x: -1000, y: -500, width: 500, height: 300), work: work), .floating)
    }
    func testKeyboardRestoresCustomLayoutBeforeMinimizing() {
        var sequence = KeyboardSequence(placement: .floating, canRestore: true)
        sequence.press(.down)
        XCTAssertFalse(sequence.minimize, "A custom layout or height-only maximized window should restore first")
        XCTAssertEqual(sequence.placement, .floating)
        sequence.press(.down)
        XCTAssertTrue(sequence.minimize)
        sequence.press(.up)
        XCTAssertFalse(sequence.minimize)
        XCTAssertEqual(sequence.placement, .maximized)
        sequence.press(.down)
        XCTAssertFalse(sequence.minimize)
        sequence.press(.down)
        XCTAssertTrue(sequence.minimize)
    }
    func testLiveRestoreUsesOriginalGrabPointAcrossDisplays() {
        let start = CGRect(x: 0, y: 33, width: 735, height: 923)
        let original = CGRect(x: 100, y: 100, width: 600, height: 400)
        let work = CGRect(x: -1470, y: -500, width: 1470, height: 900)
        let restored = SnapGeometry.restoredDragFrame(original: original, start: start, grab: CGPoint(x: 367.5, y: 48),
            cursor: CGPoint(x: -800, y: -300), work: work)
        XCTAssertEqual(restored, CGRect(x: -1100, y: -315, width: 600, height: 400))
        let bounded = SnapGeometry.restoredDragFrame(original: original, start: start, grab: CGPoint(x: 700, y: 48), cursor: work.origin, work: work)
        XCTAssertTrue(work.contains(bounded))
    }
    func testHeightOnlyMaximizePreservesWidth() {
        let work = CGRect(x: -1470, y: 33, width: 1470, height: 900)
        let frame = CGRect(x: -1100, y: 150, width: 600, height: 300)
        XCTAssertEqual(SnapGeometry.verticallyMaximized(frame, in: work), CGRect(x: -1100, y: 33, width: 600, height: 900))
    }
    func testNativeSharedEdgeResize() {
        let work = CGRect(x: -1400, y: 30, width: 1400, height: 900)
        let old = SnapLayout.halves.frames(in: work)[0]
        let resized = CGRect(x: old.minX, y: old.minY, width: 850, height: old.height)
        let result = SnapLayout.halves.nativeResize(zone: 0, from: old, to: resized, work: work)
        XCTAssertTrue(result != nil)
        let frames = result!.1.frames(in: work)
        XCTAssertEqual(frames[0], resized)
        XCTAssertEqual(frames[0].maxX, frames[1].minX)
        XCTAssertEqual(frames[1].maxX, work.maxX)
        let quarter = SnapLayout.quarters.frames(in: work)[0]
        let taller = CGRect(x: quarter.minX, y: quarter.minY, width: quarter.width, height: 550)
        XCTAssertEqual(SnapLayout.quarters.nativeResize(zone: 0, from: quarter, to: taller, work: work)?.0.axis, .horizontal)
    }
    func testNativeResizeRejectsMovementOutsideEdgesAndCorners() {
        let work = CGRect(x: 0, y: 30, width: 1400, height: 900), layout = SnapLayout.halves
        let old = layout.frames(in: work)[0]
        XCTAssertNil(layout.nativeResize(zone: 0, from: old, to: old.offsetBy(dx: 80, dy: 0), work: work))
        XCTAssertNil(layout.nativeResize(zone: 0, from: old, to: CGRect(x: -50, y: 30, width: 750, height: 900), work: work))
        XCTAssertNil(layout.nativeResize(zone: 0, from: old, to: CGRect(x: 0, y: 30, width: 750, height: 850), work: work))
        XCTAssertNil(layout.nativeResize(zone: 0, from: old, to: old, work: work))
    }
    func testNearEdgePreferenceAndHysteresis() {
        let work = CGRect(x: 0, y: 0, width: 1400, height: 900), point = CGPoint(x: 12, y: 400)
        XCTAssertNil(SnapGeometry.dragTarget(at: point, screen: work, previous: nil, threshold: 2))
        XCTAssertEqual(SnapGeometry.dragTarget(at: point, screen: work, previous: nil, threshold: 18), SnapTarget(.halves, 0))
        XCTAssertEqual(SnapGeometry.dragTarget(at: point, screen: work, previous: SnapTarget(.halves, 0), threshold: 2), SnapTarget(.halves, 0))
    }
    @MainActor func testGroupTransactionSettlesAllWindowsTogether() async {
        let targets = [0: CGRect(x: 0, y: 30, width: 700, height: 900), 1: CGRect(x: 700, y: 30, width: 700, height: 900)]
        let originals = targets.mapValues { $0.offsetBy(dx: 100, dy: 50) }
        var actual = originals, writes = 0
        let result = await WindowPlacement.stagedTransaction(targets: targets, originals: originals, read: { actual[$0] },
            place: { id, frame in writes += 1; actual[id] = frame; return .placed }, cancelled: { false })
        XCTAssertEqual(result, .placed)
        XCTAssertEqual(actual, targets)
        XCTAssertEqual(writes, 2)
    }
    @MainActor func testGroupTransactionRollsBackAfterSizeRefusal() async {
        let originals = [0: CGRect(x: 0, y: 30, width: 700, height: 900), 1: CGRect(x: 700, y: 30, width: 700, height: 900)]
        let targets = [0: CGRect(x: 0, y: 30, width: 1000, height: 900), 1: CGRect(x: 1000, y: 30, width: 400, height: 900)]
        var actual = originals
        let result = await WindowPlacement.stagedTransaction(targets: targets, originals: originals, read: { actual[$0] }, place: { id, frame in
            guard frame.width >= 600 else { return .failed }
            actual[id] = frame; return .placed
        }, cancelled: { false })
        XCTAssertEqual(result, .rolledBack)
        XCTAssertEqual(actual, originals)
    }
    @MainActor func testGroupTransactionReportsFailedRollback() async {
        let original = CGRect(x: 100, y: 100, width: 700, height: 500), target = CGRect(x: 0, y: 30, width: 700, height: 900)
        let result = await WindowPlacement.stagedTransaction(targets: [0: target], originals: [0: original], read: { _ in nil },
            place: { _, _ in .failed }, cancelled: { false })
        XCTAssertEqual(result, .rollbackFailed)
    }
    @MainActor func testGroupTransactionCancellationDoesNotRollback() async {
        let original = CGRect(x: 100, y: 100, width: 700, height: 500), target = CGRect(x: 0, y: 30, width: 700, height: 900)
        var cancelled = false, writes = 0
        let result = await WindowPlacement.stagedTransaction(targets: [0: target], originals: [0: original], read: { _ in original },
            place: { _, _ in writes += 1; cancelled = true; return .cancelled }, cancelled: { cancelled })
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(writes, 1)
    }
    @MainActor func testGroupTransactionRejectsIncompleteBaselines() async {
        let target = CGRect(x: 0, y: 30, width: 700, height: 900)
        var writes = 0
        let result = await WindowPlacement.stagedTransaction(targets: [0: target, 1: target], originals: [0: target], read: { _ in nil },
            place: { _, _ in writes += 1; return .placed }, cancelled: { false })
        XCTAssertEqual(result, .rollbackFailed)
        XCTAssertEqual(writes, 0)
    }
    @MainActor func testStagedPlacementDoesNotCancelSizeWithMove() async {
        var actual = CGRect(x: 210, y: 131, width: 650, height: 452)
        let target = CGRect(x: 0, y: 33, width: 735, height: 923)
        var pending: CGRect?, ticks = 0, interrupted = 0, writes = 0
        func schedule(_ frame: CGRect) {
            if pending != nil { interrupted += 1 }
            pending = frame; ticks = 0; writes += 1
        }
        let result = await WindowPlacement.staged(at: target, read: { actual }, resize: { size in
            // A resize changes the top-left while preserving its bottom edge.
            schedule(CGRect(x: actual.minX, y: actual.maxY-size.height, width: size.width, height: size.height))
        }, move: { schedule(CGRect(origin: $0, size: actual.size)) }, cancelled: { false }, pause: { _ in
            ticks += 1
            if ticks >= 3, let next = pending { actual = next; pending = nil }
        })
        XCTAssertEqual(result, .placed)
        XCTAssertEqual(actual, target)
        XCTAssertEqual(interrupted, 0, "A position write must never replace a pending resize")
        XCTAssertEqual(writes, 3)
    }
    @MainActor func testStagedPlacementShrinksBeforeCrossingDisplays() async {
        var actual = CGRect(x: 0, y: 30, width: 2400, height: 1400)
        let target = CGRect(x: -1400, y: 30, width: 700, height: 900)
        var order: [String] = []
        let result = await WindowPlacement.staged(at: target, read: { actual }, resize: { actual.size = $0; order.append("resize") },
            move: {
                XCTAssertTrue(actual.width <= target.width && actual.height <= target.height)
                actual.origin = $0; order.append("move")
            }, cancelled: { false }, pause: { _ in })
        XCTAssertEqual(result, .placed)
        XCTAssertEqual(order, ["resize", "move"])
    }
    @MainActor func testStagedPlacementCancellationStopsRemainingStages() async {
        let original = CGRect(x: 100, y: 100, width: 650, height: 452), target = CGRect(x: 0, y: 33, width: 735, height: 923)
        var cancelled = false, writes = 0
        let result = await WindowPlacement.staged(at: target, read: { original }, resize: { _ in writes += 1 }, move: { _ in writes += 1 },
            cancelled: { cancelled }, pause: { _ in cancelled = true })
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(writes, 1)
    }
    @MainActor func testStagedGroupDetectsLateDrift() async {
        let originals = [0: CGRect(x: 10, y: 40, width: 700, height: 500), 1: CGRect(x: 720, y: 40, width: 700, height: 500)]
        let targets = originals.mapValues { $0.offsetBy(dx: 0, dy: 100) }
        var actual = originals, count = 0
        let result = await WindowPlacement.stagedTransaction(targets: targets, originals: originals, read: { actual[$0] }, place: { id, frame in
            actual[id] = frame; count += 1
            if count == 2 { actual[1-id] = originals[1-id] }
            return .placed
        }, cancelled: { false })
        XCTAssertEqual(result, .rolledBack)
        XCTAssertEqual(actual, originals)
    }
}
