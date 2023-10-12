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
    var range: Range<Buffer.Index>
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

    // Returns the offset in UTF-16 code units relative to
    // the containing Line (not the fragment itself).
    func utf16OffsetInLine(for point: CGPoint) -> Int? {
        // empty last line
        if utf16Count == 0 {
            return 0
        }

        let i = CTLineGetStringIndexForPosition(ctLine, point)
        if i == kCFNotFound {
            return nil
        }

        return i
    }

    func positionForCharacter(atUTF16OffsetInLine offsetInLine: Int) -> CGPoint {
        // TODO: do we need the equivalent of the utf16Count == 0 check above?
        CGPoint(x: CTLineGetOffsetForStringIndex(ctLine, offsetInLine, nil), y: 0)
    }
}
