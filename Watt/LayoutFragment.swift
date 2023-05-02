//
//  LayoutFragment.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

class LayoutFragment {
    struct EnumerationOptions: OptionSet {
        let rawValue: Int

        static let ensuresLayout = EnumerationOptions(rawValue: 1 << 0)
    }

    let textElement: TextElement

    var textRange: TextRange {
        textElement.textRange
    }

    var lineFragments: [LineFragment]?
    var frame: CTFrame?
    var bounds: CGRect = .zero

    init(textElement: TextElement) {
        self.textElement = textElement
    }

    func layout() {
        let s = textElement.attributedString

        // TODO: docs say typesetter can be NULL, but this returns a CTTypesetter, not a CTTypesetter? What happens if this returns NULL?
        let typesetter = CTTypesetterCreateWithAttributedString(s)

        var lineFragments: [LineFragment] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        var i = 0

        while i < s.length {
            let next = i + CTTypesetterSuggestLineBreak(typesetter, i, 200) // TODO: 200 -> width of viewport
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: i, length: next - i))

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)


            var lineHeight = ascent + descent

            if leading <= 0 {
                leading = lineHeight * 0.2
            }

            lineHeight += leading

            let bounds = CGRect(origin: CGPoint(x: 0, y: height), size: CGSize(width: lineWidth, height: lineHeight))

            lineFragments.append(LineFragment(line: line, bounds: bounds))

            i = next
            width = max(width, lineWidth)
            height += lineHeight
        }

        self.lineFragments = lineFragments
        self.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }

    func draw(at point: CGPoint, in ctx: CGContext) {
        guard let lineFragments else {
            return
        }

        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)

        let isFlipped = ctx.ctm.d < 0
        for lineFragment in lineFragments {
            var origin = lineFragment.bounds.origin
            if !isFlipped {
                // TODO: not quite right. They don't line up in a non-flipped view.
                origin.y = bounds.height - lineFragment.bounds.height - origin.y
            }

            lineFragment.draw(at: origin, in: ctx)
        }

        ctx.restoreGState()
    }
}
