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

    // The origin in the text container's coordinate
    // space.
    //
    // Invariants:
    // - origin.x == 0
    // - origin.y is point-aligned
    var origin: CGPoint

    // The typographic bounds of the line.
    //
    // Assume a flipped coordinate space with (0, 0) at the
    // rectangle's upper left corner (typographicBounds.origin).
    //
    // The width is the widest line fragment (bounded by the
    // maximum line fragment width) plus the text container's
    // line fragment padding.
    //
    // N.b. You might think that the height is the sum of the
    // heights of the constituent line fragments' alignmentFrames,
    // but that's not correct. The fragments within a line are
    // tiled on integer boundaries by rounding their heights to make
    // drawing clearer, but if the heights of each line get rounded
    // down, we won't have enough space to draw the last fragment
    // of the line.
    //
    // A line's typographic bounds is calculated similar to the following:
    //
    // heights = lineFragments.map { $0.typographicBounds.height }
    // boundsHeight = heights.dropLast().map { round($0) } + heights.last
    //
    // Width and height can both be fractional.
    let typographicBounds: CGRect

    var range: Range<Buffer.Index>
    var lineFragments: [LineFragment]

    // The frame used for tiling lines.
    //
    // Invariants:
    // - line1.alignmentFrame.maxY == line2.alignmentFrame.minY
    // - alignmentFrame.minY and alignmentFrame.height are point-aligned
    var alignmentFrame: CGRect {
        CGRect(
            x: origin.x,
            y: origin.y,
            width: typographicBounds.width,
            height: round(typographicBounds.height)
        )
    }

    // The size of the rendering surface needed to render the entire line.
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
        ctx.translateBy(x: point.x, y: point.y)

        for frag in lineFragments {
            frag.draw(at: frag.origin, in: ctx)
        }

        ctx.restoreGState()
    }

    func fragment(containing index: Buffer.Index, affinity: Affinity) -> LineFragment? {
        for f in lineFragments {
            if index == f.range.upperBound && affinity == .upstream {
                return f
            }

            if f.range.contains(index) {
                return f
            }
        }

        return nil
    }

    // verticalOffset is in text container coordinates
    func fragment(forVerticalOffset verticalOffset: CGFloat) -> LineFragment? {
        let offsetInLine = verticalOffset - origin.y

        for f in lineFragments {
            if (f.alignmentFrame.minY..<f.alignmentFrame.maxY).contains(offsetInLine) {
                return f
            }
        }

        return nil
    }
}
