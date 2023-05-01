//
//  NonAnimatingLayer.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Cocoa

class NonAnimatingLayer: CALayer {
    override static func defaultAction(forKey event: String) -> CAAction? {
        return NSNull()
    }
}
