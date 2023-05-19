//
//  LineFragment.swift
//  Watt
//
//  Created by David Albert on 5/1/23.
//

import Foundation
import CoreText

extension LayoutManager {
    struct LineFragment {
        var line: CTLine
        let glyphOrigin: CGPoint
        let position: CGPoint
        let typographicBounds: CGRect
        let characterOffset: Int

        var frame: CGRect {
            CGRect(origin: position, size: typographicBounds.size)
        }

        func draw(at point: CGPoint, in ctx: CGContext) {
            ctx.saveGState()

            ctx.textMatrix = .identity

            var origin = CGPoint(x: point.x + glyphOrigin.x, y: point.y + glyphOrigin.y)

            let isFlipped = ctx.ctm.d < 0
            if isFlipped {
                let t = CGAffineTransform(translationX: 0, y: typographicBounds.height).scaledBy(x: 1, y: -1)
                origin = origin.applying(t)

                ctx.translateBy(x: 0, y: typographicBounds.height)
                ctx.scaleBy(x: 1, y: -1)
            }

            ctx.textPosition = origin
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        var characterRange: NSRange {
            let range = CTLineGetStringRange(line)

            return NSRange(location: characterOffset + range.location, length: range.length)
        }

        func offsetForCharacter(at index: Int) -> CGFloat {
            CTLineGetOffsetForStringIndex(line, index, nil)
        }
    }
}
