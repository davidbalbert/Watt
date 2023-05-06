//
//  LineFragment.swift
//  Watt
//
//  Created by David Albert on 5/1/23.
//

import Foundation
import CoreText

struct LineFragment {
    var line: CTLine
    var bounds: CGRect
    var glyphOrigin: CGPoint

    func draw(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()

        ctx.textMatrix = .identity

        var origin = CGPoint(x: point.x + glyphOrigin.x, y: point.y + glyphOrigin.y)

        let isFlipped = ctx.ctm.d < 0
        if isFlipped {
            let t = CGAffineTransform(translationX: 0, y: bounds.height).scaledBy(x: 1, y: -1)
            origin = origin.applying(t)

            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
        }

        ctx.textPosition = origin
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
