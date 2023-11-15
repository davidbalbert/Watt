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

    // The upper left corner of this line fragment
    // in its parent Line's coordinate space.
    //
    // The origin is used for tiling and drawing line
    // fragments (see alignmentFrame),
    //
    //
    // Invariants:
    // - origin.x == textContainer.lineFragmentPadding
    // - origin.y is point-aligned
    let origin: CGPoint

    // The typographic bounds of the line fragment as
    // reported by CTLineGetBoundsWithOptions(ctLine, []),
    // but translated so that typographicBounds.origin
    // is (0, 0).
    //
    // We assume a flipped coordinate space where
    // typographicBounds.origin is in the upper left
    // corner of the rectangle.
    //
    // Width and height can both be ractional
    let typographicBounds: CGRect

    // The left corner of the line fragment's baseline,
    // relative to typographicBounds. This assumes a
    // flipped coordinate space with (0, 0) at the
    // top left corner of typographicBounds.
    //
    // As a hypothetical example for latin text, if
    // typographicBounds.height == 14.25, glyphOrigin.y
    // might be somewhere around 11.5. I.e. the baseline
    // is somewhere between 2/3 and 3/4 down from the
    // upper left corner of the typographic bounds.
    //
    // glyphOrigin.y can be fractional. To properly
    // draw this line fragment within its alignmentFrame,
    // glyphOrigin.y should be rounded.
    //
    // Invariants:
    // - glyphOrigin.x == typographicBounds.minX == 0
    // - glyphOrigin.y > 0.
    let glyphOrigin: CGPoint

    // The start of the Line that contains self.
    var lineStart: Buffer.Index
    var range: Range<Buffer.Index>
    let utf16Count: Int

    // The frame used for tiling line fragments.
    //
    // Invariants:
    // - frag1.alignmentFrame.maxY == frag2.alignmentFrame.minY
    // - alignmentFrame.minY and alignmentFrame.height are point-aligned
    var alignmentFrame: CGRect {
        CGRect(
            x: origin.x,
            y: origin.y,
            width: typographicBounds.width,
            height: round(typographicBounds.height)
        )
    }

    // The size of the rendering surface needed to render
    // an individual line fragment.
    //
    // Invariants:
    // - All edges are point-aligned.
    // - Equal in size or larger than both typographicBounds
    //   and alignmentFrame.
    var renderingSurfaceBounds: CGRect {
        typographicBounds.integral
    }

    func draw(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()

        ctx.textMatrix = .identity

        ctx.translateBy(x: glyphOrigin.x, y: round(glyphOrigin.y))
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

    func caretOffset(forUTF16OffsetInLine offsetInLine: Int) -> CGFloat {
        CTLineGetOffsetForStringIndex(ctLine, offsetInLine, nil)
    }
}
