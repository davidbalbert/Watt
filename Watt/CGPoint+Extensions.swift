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

