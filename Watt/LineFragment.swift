//
//  LineFragment.swift
//  Watt
//
//  Created by David Albert on 5/1/23.
//

import Foundation
import CoreText
import Cocoa

struct LineFragment {
    var line: CTLine
    let glyphOrigin: CGPoint
    let position: CGPoint
    let typographicBounds: CGRect
    let textRange: Range<String.Index>
    let characterOffset: Int

    var frame: CGRect {
        CGRect(origin: position, size: typographicBounds.size)
    }

    func draw(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()

        ctx.textMatrix = .identity

        ctx.translateBy(x: glyphOrigin.x, y: glyphOrigin.y)
        ctx.translateBy(x: point.x, y: point.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero

        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // The range of the string in the line. Always starts at 0
    var characterRange: NSRange {
        let range = CTLineGetStringRange(line)
        return NSRange(location: 0, length: range.length)
    }
}
