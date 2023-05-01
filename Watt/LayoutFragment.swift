//
//  LayoutFragment.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

struct LayoutFragment {
    struct EnumerationOptions: OptionSet {
        let rawValue: Int

        static let ensuresLayout = EnumerationOptions(rawValue: 1 << 0)
    }

    let textElement: TextElement

    var textRange: TextRange {
        textElement.textRange
    }

    var frame: CTFrame?
    var lines: [CTLine]?
    var bounds: CGRect = .zero

    mutating func layout() {
        let s = textElement.attributedString

        // TODO: docs say f can be NULL, but this returns a CTFramesetter, not a CTFramesetter? What happens if this returns NULL?
        let framesetter = CTFramesetterCreateWithAttributedString(s)

        let range = CFRange(location: 0, length: s.length)
        let container = CGRect(origin: .zero, size: CGSize(width: 200, height: 200))
        let path = CGPath(rect: container, transform: nil)

        let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]



        var width: CGFloat = 0
        var height: CGFloat = 0
        for line in lines {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let w = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            width = max(width, w)
            height += ascent + descent + leading
        }

        self.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        self.lines = lines
        self.frame = frame
    }

    func draw(at point: CGPoint, in ctx: CGContext) {
        guard let frame else {
            return
        }

        ctx.saveGState()

        let isFlipped = ctx.ctm.d < 0
        print("isFlipped", isFlipped, bounds)

//        ctx.textMatrix = .identity

        if isFlipped {
            ctx.translateBy(x: 0, y: 200)
            ctx.scaleBy(x: 1, y: -1)
        }

        CTFrameDraw(frame, ctx)

        ctx.restoreGState()
    }
}
