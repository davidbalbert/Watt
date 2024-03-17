//
//  CALayer+Extensions.swift
//  Watt
//
//  Created by David Albert on 3/15/24.
//

import QuartzCore

extension CALayer {
    // Faster than setting sublayers = nil and then re-adding.
    func setSublayers(to new: [CALayer]) {
        guard let sublayers else {
            sublayers = new
            return
        }

        let diff = new.difference(from: sublayers)
        for c in diff {
            switch c {
            case let .remove(offset: _, element: layer, associatedWith: _):
                layer.removeFromSuperlayer()
            case let .insert(offset: i, element: layer, associatedWith: _):
                insertSublayer(layer, at: UInt32(i))
            }
        }
    }
}
