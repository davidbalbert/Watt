//
//  LineFragment.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Foundation
import CoreGraphics
import CoreText

struct LineFragment {
    var ctLine: CTLine
    let glyphOrigin: CGPoint
    let origin: CGPoint
    let typographicBounds: CGRect
    let utf16Count: Int

    var frame: CGRect {
        CGRect(origin: origin, size: typographicBounds.size)
    }

    func draw(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()

        ctx.textMatrix = .identity

        ctx.translateBy(x: glyphOrigin.x, y: glyphOrigin.y)
        ctx.translateBy(x: point.x, y: point.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero

        CTLineDraw(ctLine, ctx)
        ctx.restoreGState()
    }

    func characterIndex(for point: CGPoint) -> Int {
        // empty last line
        if utf16Count == 0 {
            return 0
        }

        return CTLineGetStringIndexForPosition(ctLine, point)
    }
}
