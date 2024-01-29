//
//  CGSize+Extensions.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import CoreGraphics

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

