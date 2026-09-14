import Foundation
import CoreGraphics

/// All geometry uses logical points, with the primary display's top-left as origin.
public struct SnapLayout: Equatable {
    public let id: String
    public let name: String
    public var zones: [CGRect]

    public init(_ id: String, _ name: String, _ zones: [CGRect]) {
        self.id = id; self.name = name; self.zones = zones
    }

    public func frames(in workArea: CGRect, gap: CGFloat = 0) -> [CGRect] {
        zones.map { zone in
            // Round shared boundaries, not widths, to avoid one-pixel seams.
            let left = (workArea.minX + zone.minX * workArea.width).rounded()
            let top = (workArea.minY + zone.minY * workArea.height).rounded()
            let right = (workArea.minX + zone.maxX * workArea.width).rounded()
            let bottom = (workArea.minY + zone.maxY * workArea.height).rounded()
            return CGRect(x: left, y: top, width: right - left, height: bottom - top)
                .insetBy(dx: gap / 2, dy: gap / 2)
        }
    }

    public static let halves = SnapLayout("halves", "Two equal", [
        CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
    ])
    public static let wideLeft = SnapLayout("wideLeft", "Wide left", [
        CGRect(x: 0, y: 0, width: 2.0/3, height: 1), CGRect(x: 2.0/3, y: 0, width: 1.0/3, height: 1)
    ])
    public static let thirds = SnapLayout("thirds", "Three columns", (0..<3).map {
        CGRect(x: Double($0)/3, y: 0, width: 1.0/3, height: 1)
    })
    public static let leftStack = SnapLayout("leftStack", "Left + two", [
        CGRect(x: 0, y: 0, width: 0.5, height: 1),
        CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
        CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
    ])
    public static let quarters = SnapLayout("quarters", "Four windows", (0..<4).map {
        CGRect(x: Double($0 % 2)/2, y: Double($0 / 2)/2, width: 0.5, height: 0.5)
    })
    public static let centerWide = SnapLayout("centerWide", "Wide center", [
        CGRect(x: 0, y: 0, width: 0.25, height: 1),
        CGRect(x: 0.25, y: 0, width: 0.5, height: 1),
        CGRect(x: 0.75, y: 0, width: 0.25, height: 1)
    ])
    public static let full = SnapLayout("full", "Maximize", [CGRect(x: 0, y: 0, width: 1, height: 1)])
    public static let all: [SnapLayout] = [.halves, .wideLeft, .thirds, .leftStack, .quarters, .centerWide]

    /// Use logical work-area dimensions, not physical pixels. Never offer a
    /// three-column layout whose narrowest column is smaller than a useful window.
    public static func available(in work: CGRect) -> [SnapLayout] {
        all.filter { layout in
            layout.frames(in: work).allSatisfy { $0.width >= 320 && $0.height >= 240 }
        }
    }
}

public struct SnapTarget: Equatable {
    public let layout: SnapLayout
    public let zone: Int
    public init(_ layout: SnapLayout, _ zone: Int) { self.layout = layout; self.zone = zone }
}

public enum SnapGeometry {
    /// Wider exit threshold avoids flickering when the pointer jitters at an edge.
    /// Call again at mouse-up so a stale preview can never commit an unrelated drop.
    public static func dragTarget(at point: CGPoint, screen: CGRect, previous: SnapTarget?, threshold: CGFloat = 18) -> SnapTarget? {
        if let immediate = edgeTarget(at: point, screen: screen, threshold: threshold) { return immediate }
        if let previous, edgeTarget(at: point, screen: screen, threshold: threshold + 12) == previous { return previous }
        return nil
    }

    public static func isWindowMove(from start: CGRect, to current: CGRect, cursorTravel: CGFloat) -> Bool {
        cursorTravel >= 6 && hypot(current.minX-start.minX, current.minY-start.minY) > 3 &&
        abs(current.width-start.width) <= 8 && abs(current.height-start.height) <= 8
    }

    public static func edgeTarget(at p: CGPoint, screen: CGRect, threshold: CGFloat = 18) -> SnapTarget? {
        guard screen.insetBy(dx: -1, dy: -1).contains(p) else { return nil }
        let left = p.x <= screen.minX + threshold
        let right = p.x >= screen.maxX - threshold
        let top = p.y <= screen.minY + threshold
        let bottom = p.y >= screen.maxY - threshold
        if (left || right) && (top || bottom) {
            return SnapTarget(.quarters, (bottom ? 2 : 0) + (right ? 1 : 0))
        }
        if left { return SnapTarget(.halves, 0) }
        if right { return SnapTarget(.halves, 1) }
        if top { return SnapTarget(.full, 0) }
        return nil
    }

    public static func cocoaRect(from quartz: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: quartz.minX, y: primaryHeight - quartz.maxY, width: quartz.width, height: quartz.height)
    }

    public static func nearlyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 3) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    public static func restoredFrame(original: CGRect, snapped: CGRect, cursor: CGPoint, workArea: CGRect) -> CGRect {
        let ratio = min(1, max(0, (cursor.x - snapped.minX) / max(1, snapped.width)))
        let width = min(original.width, workArea.width)
        let height = min(original.height, workArea.height)
        return CGRect(x: min(workArea.maxX - width, max(workArea.minX, cursor.x - width * ratio)),
                      y: min(workArea.maxY - height, max(workArea.minY, cursor.y - 15)),
                      width: width, height: height)
    }

    public static func restoredDragFrame(original: CGRect, start: CGRect, grab: CGPoint, cursor: CGPoint, work: CGRect) -> CGRect {
        let ratio = min(1, max(0, (grab.x - start.minX) / max(1, start.width)))
        let width = min(original.width, work.width), height = min(original.height, work.height)
        let titleOffset = min(28, max(4, grab.y - start.minY))
        return CGRect(x: min(work.maxX - width, max(work.minX, cursor.x - width * ratio)),
                      y: min(work.maxY - height, max(work.minY, cursor.y - titleOffset)), width: width, height: height)
    }

    public static func verticallyMaximized(_ frame: CGRect, in work: CGRect) -> CGRect {
        CGRect(x: min(work.maxX - min(frame.width, work.width), max(work.minX, frame.minX)),
               y: work.minY, width: min(frame.width, work.width), height: work.height)
    }
}

/// State transitions used by both the desktop controller and the tests.
public struct AssistSession<ID: Hashable> {
    public let layout: SnapLayout
    public private(set) var assignments: [Int: ID]
    public private(set) var skipped: Set<Int> = []
    public var nextZone: Int? { layout.zones.indices.first { assignments[$0] == nil && !skipped.contains($0) } }
    public var usedWindows: Set<ID> { Set(assignments.values) }
    public init(layout: SnapLayout, firstZone: Int, window: ID) {
        self.layout = layout; self.assignments = [firstZone: window]
    }
    @discardableResult public mutating func choose(_ window: ID) -> Bool {
        guard let zone = nextZone, !usedWindows.contains(window) else { return false }
        assignments[zone] = window; return true
    }
    public mutating func skip() { if let zone = nextZone { skipped.insert(zone) } }
}

public enum BoundaryAxis: Equatable { case vertical, horizontal }
public struct SharedBoundary: Equatable {
    public let axis: BoundaryAxis
    public let position: CGFloat
    public let start: CGFloat
    public let end: CGFloat
}

extension SnapLayout {
    /// An observed size is not a proven minimum. Offer one explicit wider retry
    /// for a two-column layout, then verify both windows transactionally.
    /// Never squeeze the neighbor below a useful width or widen a stacked grid.
    public func widerSplit(for zone: Int, observed: CGSize, in work: CGRect,
                           minimumNeighborWidth: CGFloat = 320) -> SnapLayout? {
        guard zones.count == 2, zones.indices.contains(zone),
              WindowPlacement.valid(work), observed.width.isFinite, observed.height.isFinite,
              observed.width >= 50, observed.height >= 50, observed.height <= work.height + 3,
              minimumNeighborWidth.isFinite, minimumNeighborWidth >= 50 else { return nil }
        let ordered = zones.sorted { $0.minX < $1.minX }
        guard ordered.allSatisfy({ abs($0.minY) < 0.001 && abs($0.height - 1) < 0.001 }),
              abs(ordered[0].minX) < 0.001, abs(ordered[1].maxX - 1) < 0.001,
              abs(ordered[0].maxX - ordered[1].minX) < 0.001 else { return nil }
        let frames = frames(in: work)
        let width = observed.width.rounded(.up)
        guard width > frames[zone].width + 3,
              width <= work.width - minimumNeighborWidth else { return nil }
        var result = self
        let onLeft = abs(zones[zone].minX) < 0.001
        let fraction = width / work.width
        result.zones[zone] = CGRect(x: onLeft ? 0 : 1-fraction, y: 0, width: fraction, height: 1)
        result.zones[1-zone] = CGRect(x: onLeft ? fraction : 0, y: 0, width: 1-fraction, height: 1)
        let proposed = result.frames(in: work)
        guard proposed[zone].width >= width, proposed[1-zone].width >= minimumNeighborWidth else { return nil }
        return SnapLayout("\(id).wider", "Adjusted split", result.zones)
    }

    /// Recognize a native resize of exactly one internal edge. Moving the window,
    /// resizing an outside edge, or changing two edges must not move its neighbors.
    public func nativeResize(zone: Int, from old: CGRect, to new: CGRect, work: CGRect) -> (SharedBoundary, SnapLayout)? {
        guard zones.indices.contains(zone), work.width > 0, work.height > 0 else { return nil }
        let delta = [new.minX-old.minX, new.maxX-old.maxX, new.minY-old.minY, new.maxY-old.maxY]
        let changed = delta.indices.filter { abs(delta[$0]) > 3 }
        guard changed.count == 1, let edge = changed.first else { return nil }
        let vertical = edge < 2, r = zones[zone]
        let oldPosition = [r.minX, r.maxX, r.minY, r.maxY][edge]
        let position = vertical ? ([new.minX, new.maxX][edge] - work.minX) / work.width
                                : ([new.minY, new.maxY][edge-2] - work.minY) / work.height
        guard let boundary = boundaries.first(where: {
            $0.axis == (vertical ? .vertical : .horizontal) && abs($0.position-oldPosition) < 0.001
        }), let layout = moving(boundary, to: position) else { return nil }
        return (boundary, layout)
    }

    public var boundaries: [SharedBoundary] {
        var result: [SharedBoundary] = []
        for i in zones.indices {
            for j in zones.indices where j > i {
                let a = zones[i], b = zones[j]
                if abs(a.maxX - b.minX) < 0.001 || abs(b.maxX - a.minX) < 0.001 {
                    let lo = max(a.minY, b.minY), hi = min(a.maxY, b.maxY)
                    if hi > lo { result.append(SharedBoundary(axis: .vertical, position: max(a.minX, b.minX), start: lo, end: hi)) }
                }
                if abs(a.maxY - b.minY) < 0.001 || abs(b.maxY - a.minY) < 0.001 {
                    let lo = max(a.minX, b.minX), hi = min(a.maxX, b.maxX)
                    if hi > lo { result.append(SharedBoundary(axis: .horizontal, position: max(a.minY, b.minY), start: lo, end: hi)) }
                }
            }
        }
        return result
    }

    /// Move a shared grid line, preserving all adjoining rectangles and minimum fractions.
    public func moving(_ boundary: SharedBoundary, to requested: CGFloat, minimum: CGFloat = 0.15) -> SnapLayout? {
        var updated = self
        let p = boundary.position
        let vertical = boundary.axis == .vertical
        let affected = zones.indices.filter { i in
            let r = zones[i]
            let lo = vertical ? r.minX : r.minY, hi = vertical ? r.maxX : r.maxY
            return abs(lo-p) < 0.001 || abs(hi-p) < 0.001
        }
        var low: CGFloat = 0, high: CGFloat = 1
        for i in affected {
            let r = zones[i]
            let lo = vertical ? r.minX : r.minY, hi = vertical ? r.maxX : r.maxY
            if abs(hi-p) < 0.001 { low = max(low, lo + minimum) }
            if abs(lo-p) < 0.001 { high = min(high, hi - minimum) }
        }
        guard low <= high else { return nil }
        let value = min(high, max(low, requested))
        for i in affected {
            var r = zones[i]
            if vertical {
                if abs(r.maxX-p) < 0.001 { r.size.width = value-r.minX }
                else { let end = r.maxX; r.origin.x = value; r.size.width = end-value }
            } else {
                if abs(r.maxY-p) < 0.001 { r.size.height = value-r.minY }
                else { let end = r.maxY; r.origin.y = value; r.size.height = end-value }
            }
            updated.zones[i] = r
        }
        return updated
    }
}
