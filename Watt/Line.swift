//
//  Line.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Foundation
import CoreGraphics
import CoreText

struct Line: Identifiable {
    var id: UUID = UUID()
    var position: CGPoint
    let typographicBounds: CGRect
    let lineFragments: [LineFragment]

    var frame: CGRect {
        CGRect(
            x: position.x + typographicBounds.minX,
            y: position.y + typographicBounds.minY,
            width: typographicBounds.width,
            height: typographicBounds.height
        )
    }

    func draw(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)

        for f in lineFragments {
            f.draw(at: f.frame.origin, in: ctx)
        }

        ctx.restoreGState()
    }
}
