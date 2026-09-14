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
        print("16 scenarios completed; \(failures) failures")
        if failures > 0 { exit(1) }
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
}
