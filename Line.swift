//
//  Line.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Foundation
import CoreGraphics
import CoreText

struct Line {
    let position: CGPoint
    let typographicBounds: CGRect
    let lineFragments: [LineFragment]

    func draw(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)

        for f in lineFragments {
            f.draw(at: f.frame.origin, in: ctx)
        }

        ctx.restoreGState()
    }
}
