import Foundation

public enum SnapKey { case left, right, up, down }

public struct KeyboardSequence {
    public private(set) var placement: KeyboardPlacement
    public private(set) var minimize = false
    private var canRestore: Bool
    public init(placement: KeyboardPlacement, canRestore: Bool) {
        self.placement = placement; self.canRestore = canRestore
    }
    public mutating func press(_ key: SnapKey) {
        minimize = key == .down && placement == .floating && !canRestore
        placement = placement.pressing(key)
        canRestore = placement != .floating
    }
}

public enum KeyboardPlacement: Equatable {
    case floating, left, right, topLeft, topRight, bottomLeft, bottomRight, maximized

    public var target: SnapTarget? {
        switch self {
        case .floating: return nil
        case .left: return SnapTarget(.halves, 0)
        case .right: return SnapTarget(.halves, 1)
        case .topLeft: return SnapTarget(.quarters, 0)
        case .topRight: return SnapTarget(.quarters, 1)
        case .bottomLeft: return SnapTarget(.quarters, 2)
        case .bottomRight: return SnapTarget(.quarters, 3)
        case .maximized: return SnapTarget(.full, 0)
        }
    }

    public static func matching(_ frame: CGRect, work: CGRect) -> KeyboardPlacement {
        let positions: [KeyboardPlacement] = [.left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight, .maximized]
        return positions.first { position in
            guard let target = position.target else { return false }
            return SnapGeometry.nearlyEqual(frame, target.layout.frames(in: work)[target.zone])
        } ?? .floating
    }

    public func pressing(_ key: SnapKey) -> KeyboardPlacement {
        switch key {
        case .left:
            switch self {
            case .right: return .floating
            case .topRight: return .topLeft
            case .bottomRight: return .bottomLeft
            case .topLeft, .bottomLeft: return self
            default: return .left
            }
        case .right:
            switch self {
            case .left: return .floating
            case .topLeft: return .topRight
            case .bottomLeft: return .bottomRight
            case .topRight, .bottomRight: return self
            default: return .right
            }
        case .up:
            switch self {
            case .left, .bottomLeft: return .topLeft
            case .right, .bottomRight: return .topRight
            default: return .maximized
            }
        case .down:
            switch self {
            case .left, .topLeft: return .bottomLeft
            case .right, .topRight: return .bottomRight
            default: return .floating
            }
        }
    }
}
