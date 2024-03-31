//
//  CGPoint+Extensions.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import CoreGraphics

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
}

extension CGPoint {
    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(x: x.clamped(to: rect.minX...rect.maxX), y: y.clamped(to: rect.minY...rect.maxY))
    }

    func rounded() -> CGPoint {
        CGPoint(x: x.rounded(), y: y.rounded())
    }
}
