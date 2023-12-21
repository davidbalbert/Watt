//
//  CGRect+Extensions.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation
import CoreGraphics

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
}

extension CGRect {
    func inset(by insets: NSEdgeInsets) -> CGRect {
        CGRect(
            x: origin.x + insets.left,
            y: origin.y + insets.bottom,
            width: size.width - insets.left - insets.right,
            height: size.height - insets.top - insets.bottom
        )
    }
}
