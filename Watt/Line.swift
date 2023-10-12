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
    var origin: CGPoint
    let typographicBounds: CGRect
    let range: Range<Buffer.Index>
    let lineFragments: [LineFragment]

    var frame: CGRect {
        CGRect(
            x: origin.x + typographicBounds.minX,
            y: origin.y + typographicBounds.minY,
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

    // TODO: there are probably places in LayoutManager where we can use this method
    func fragment(containing location: Buffer.Index) -> LineFragment? {
        for f in lineFragments {
            if f.range.contains(location) {
                return f
            }
        }

        return nil
    }

    // TODO: ditto
    // verticalOffset is in text container coordinates
    func fragment(forVerticalOffset verticalOffset: CGFloat) -> LineFragment? {
        let offsetInLine = verticalOffset - origin.y

        for f in lineFragments {
            if (f.frame.minY..<f.frame.maxY).contains(offsetInLine) {
                return f
            }
        }

        return nil
    }
}
