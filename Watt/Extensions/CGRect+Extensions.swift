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
