//
//  LayoutFragment.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

extension LayoutManager {
    struct EnumerationOptions: OptionSet {
        let rawValue: Int

        static var ensuresLayout: Self { EnumerationOptions(rawValue: 1 << 0) }
    }

    class LayoutFragment {
        let textElement: TextElement

        var textRange: Range<Location> {
            textElement.textRange
        }

        var lineFragments: [LineFragment] = []
        var typographicBounds: CGRect = .zero
        var hasLayout: Bool = false

        var position: CGPoint = .zero
        var frame: CGRect {
            CGRect(origin: position, size: typographicBounds.size)
        }

        init(textElement: TextElement) {
            self.textElement = textElement
        }

        func layout(at position: CGPoint, in textContainer: TextContainer) {
            if hasLayout {
                print("warning: layout(at:in:) called on fragment that already has layout")
                return
            }

            self.position = position

            let s = textElement.attributedString

            // TODO: docs say typesetter can be NULL, but this returns a CTTypesetter, not a CTTypesetter? What happens if this returns NULL?
            let typesetter = CTTypesetterCreateWithAttributedString(s)

            var width: CGFloat = 0
            var height: CGFloat = 0
            var i = 0

            while i < s.length {
                let next = i + CTTypesetterSuggestLineBreak(typesetter, i, textContainer.lineWidth)
                let line = CTTypesetterCreateLine(typesetter, CFRange(location: i, length: next - i))

                let p = CGPoint(x: 0, y: height)
                let (glyphOrigin, typographicBounds) = lineMetrics(for: line, in: textContainer)

                let lineFragment = LineFragment(line: line, glyphOrigin: glyphOrigin, position: p, typographicBounds: typographicBounds)
                lineFragments.append(lineFragment)

                i = next
                width = max(width, typographicBounds.width)
                height += typographicBounds.height
            }

            self.typographicBounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
            self.hasLayout = true
        }

        func draw(at point: CGPoint, in ctx: CGContext) {
            guard hasLayout else {
                return
            }

            ctx.saveGState()
            ctx.translateBy(x: point.x, y: point.y)

            for lineFragment in lineFragments {
                lineFragment.draw(at: lineFragment.frame.origin, in: ctx)
            }

            ctx.restoreGState()
        }

        // returns glyphOrigin, typographicBounds
        func lineMetrics(for line: CTLine, in textContainer: TextContainer) -> (CGPoint, CGRect) {
            let ctTypographicBounds = CTLineGetBoundsWithOptions(line, [])

            let paddingWidth = 2*textContainer.lineFragmentPadding

            // ctTypographicBounds's coordinate system has the glyph origin at (0,0).
            // Here, we assume that the glyph origin lies on the left edge of
            // ctTypographicBounds. If it doesn't, we'd have to change our calculation
            // of typographicBounds's origin, though everything else should just work.
            assert(ctTypographicBounds.minX == 0)

            // defined to have the origin in the upper left corner
            let typographicBounds = CGRect(x: 0, y: 0, width: ctTypographicBounds.width + paddingWidth, height: floor(ctTypographicBounds.height))

            let glyphOrigin = CGPoint(
                x: ctTypographicBounds.minX + textContainer.lineFragmentPadding,
                y: floor(ctTypographicBounds.height + ctTypographicBounds.minY)
            )

            return (glyphOrigin, typographicBounds)

            // Leave out renderingSurfaceBounds for now. With monospaced fonts, we won't need it.

            // let ctGlyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            // let ctRenderingSurfaceBounds = ctTypographicBounds.union(ctGlyphBounds)

            // we're looking for the upper left corner of the rendering surface bounds, which
            // is in the typographicBounds' coordinate space. Because we know typographicBounds's
            // origin will be (0,0), we can just use the difference between the Core Text origins.
            // let x = ctRenderingSurfaceBounds.origin.x - ctTypographicBounds.origin.x
            // let y = ctRenderingSurfaceBounds.origin.y - ctTypographicBounds.origin.y
            // let renderingSurfaceBounds = CGRect(x: x, y: y, width: ctRenderingSurfaceBounds.width + paddingWidth, height: ctRenderingSurfaceBounds.height)

            // let ctRenderingSurfaceBounds = ctTypographicBounds.union(ctGlyphBounds)
        }
    }
}
