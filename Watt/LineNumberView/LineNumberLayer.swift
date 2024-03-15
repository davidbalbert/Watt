//
//  LineNumberLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

class LineNumberLayer: CALayer {
    let lineNumber: Int
    weak var lineNumberView: LineNumberView?

    init(lineNumber: Int, lineNumberView: LineNumberView? = nil) {
        self.lineNumber = lineNumber
        self.lineNumberView = lineNumberView
        super.init()
    }

    override init(layer: Any) {
        let layer = layer as! LineNumberLayer
        self.lineNumber = layer.lineNumber
        self.lineNumberView = layer.lineNumberView
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in ctx: CGContext) {
        guard let lineNumberView else {
            return
        }

        lineNumberView.effectiveAppearance.performAsCurrentDrawingAppearance {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lineNumberView.font,
                .foregroundColor: lineNumberView.textColor
            ]
            let s = NSAttributedString(string: "\(lineNumber)", attributes: attrs)
            let line = CTLineCreateWithAttributedString(s)

            let typographicBounds = CTLineGetBoundsWithOptions(line, [])

            // glyph origin in flipped coordinate space
            let glyphOrigin = CGPoint(
                x: bounds.width - lineNumberView.trailingPadding - typographicBounds.width,
                y: round(typographicBounds.height + typographicBounds.minY)
            )

            ctx.saveGState()
            ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            ctx.textPosition = glyphOrigin
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
