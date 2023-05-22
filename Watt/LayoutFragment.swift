//
//  LayoutFragment.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

class LayoutFragment: Identifiable {
    struct EnumerationOptions: OptionSet {
        let rawValue: Int

        static var ensuresLayout: Self { EnumerationOptions(rawValue: 1 << 0) }
    }

    let id = UUID()

    var textElement: TextElement
    var lineNumber: Int = 0

    var textRange: Range<String.Index> {
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
}
