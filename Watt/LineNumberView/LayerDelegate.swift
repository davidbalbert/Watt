//
//  LayerDelegate.swift
//  Watt
//
//  Created by David Albert on 5/15/23.
//

import Cocoa

extension LineNumberView {
    class LayerDelegate: NSObject, CALayerDelegate, NSViewLayerContentScaleDelegate {
        weak var lineNumberView: LineNumberView?

        func action(for layer: CALayer, forKey event: String) -> CAAction? {
            return NSNull()
        }

        func draw(_ layer: CALayer, in ctx: CGContext) {
            guard let lineNumberView, let lineno = layer.value(forKey: LineNumberView.lineNumberKey) as? Int else {
                return
            }

            let s = NSAttributedString(string: "\(lineno)", attributes: [.font: lineNumberView.font])
            let line = CTLineCreateWithAttributedString(s)

            let typographicBounds = CTLineGetBoundsWithOptions(line, [])

            // glyph origin in flipped coordinate space
            let glyphOrigin = CGPoint(
                x: typographicBounds.minX,
                y: floor(typographicBounds.height + typographicBounds.minY)
            )

            ctx.saveGState()
            ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            ctx.textPosition = glyphOrigin
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
            true
        }
    }
}
