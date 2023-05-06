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

    func layout(in textContainer: TextContainer) {
        let s = textElement.attributedString

        // TODO: docs say typesetter can be NULL, but this returns a CTTypesetter, not a CTTypesetter? What happens if this returns NULL?
        let typesetter = CTTypesetterCreateWithAttributedString(s)

        var lineFragments: [LineFragment] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        var i = 0

        while i < s.length {
            let next = i + CTTypesetterSuggestLineBreak(typesetter, i, textContainer.lineWidth)
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: i, length: next - i))

            let b = CTLineGetBoundsWithOptions(line, [])
            let glyphOrigin = CGPoint(x: textContainer.lineFragmentPadding, y: b.height + b.minY)

            let bounds = CGRect(
                x: 0,
                y: height,
                width: b.width + 2*textContainer.lineFragmentPadding,
                height: b.height
            )

            lineFragments.append(LineFragment(line: line, bounds: bounds, glyphOrigin: glyphOrigin))

            i = next
            width = max(width, bounds.width)
            height += bounds.height
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

        for lineFragment in lineFragments {
            lineFragment.draw(at: lineFragment.bounds.origin, in: ctx)
        }

        ctx.restoreGState()
    }
}
