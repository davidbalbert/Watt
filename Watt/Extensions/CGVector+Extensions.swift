//
//  CGVector+Extensions.swift
//  Watt
//
//  Created by David Albert on 3/28/24.
//

import CoreGraphics

extension CGVector: AdditiveArithmetic {
    public static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        .init(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    public static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        .init(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
}
