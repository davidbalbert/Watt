//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import QuartzCore

protocol LayoutManagerDelegate: AnyObject {
    func layoutManagerWillLayoutText(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, insertTextLayer layer: CALayer)
    func layoutManagerDidLayoutText(_ layoutManager: LayoutManager)

    func layoutManagerWillLayoutSelections(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, insertSelectionLayer layer: CALayer)
    func layoutManagerDidLayoutSelections(_ layoutManager: LayoutManager)

    func layoutManagerWillLayoutInsertionPoints(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, insertInsertionPointsLayer layer: CALayer)
    func layoutManagerDidLayoutInsertionPoints(_ layoutManager: LayoutManager)
}

protocol LayoutManagerLineNumberDelegate: AnyObject {
    func layoutManagerShouldUpdateLineNumbers(_ layoutManager: LayoutManager) -> Bool
    func layoutManagerWillUpdateLineNumbers(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, addLineNumber lineno: Int, at position: CGPoint, withLineHeight lineHeight: CGFloat)
    func layoutManagerDidUpdateLineNumbers(_ layoutManager: LayoutManager)
}

class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    weak var lineNumberDelegate: LayoutManagerLineNumberDelegate?

    var buffer: Buffer {
        willSet {
            // TODO: unsubscribe from changes to old buffer
        }
        didSet {
            // TODO: subscribe to changes to new buffer
            selection = Selection(head: buffer.documentRange.lowerBound)
            invalidateLayout()
        }
    }

    var textContainer: TextContainer {
        didSet {
            invalidateLayout()
        }
    }

    var textContainerInset: CGSize {
        didSet {
            invalidateLayout()
        }
    }

    var viewportBounds: CGRect {
        didSet {
            if viewportBounds.size != oldValue.size {
                invalidateLayout()
            }
        }
    }

    var selection: Selection

    init() {
        self.buffer = Buffer()
        self.textContainer = TextContainer()
        self.textContainerInset = .zero
        self.viewportBounds = .zero

        // TODO: subscribe to changes to buffer.
        self.selection = Selection(head: buffer.documentRange.lowerBound)
    }

    var contentHeight: CGFloat {
        // TODO: make this real
        10000
    }

    func layoutText() {
        guard let delegate else {
            return
        }

        let updateLineNumbers = lineNumberDelegate?.layoutManagerShouldUpdateLineNumbers(self) ?? false

        delegate.layoutManagerWillLayoutText(self)
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerWillUpdateLineNumbers(self)
        }

        var lineno: Int = 1
        var y: CGFloat = 0

        // TODO: make this actually layout what's in the viewport
        for s in buffer.lines.prefix(10) {
            let line = layout(NSAttributedString(string: s), at: CGPoint(x: 0, y: y))

            let layer = LineLayer(line: line)
            layer.anchorPoint = .zero
            layer.needsDisplayOnBoundsChange = true
            layer.bounds = line.typographicBounds
            layer.position = convertFromTextContainer(line.position)

            delegate.layoutManager(self, insertTextLayer: layer)
            if updateLineNumbers {
                lineNumberDelegate!.layoutManager(self, addLineNumber: lineno, at: line.position, withLineHeight: line.typographicBounds.height)
            }

            y += line.typographicBounds.height
            lineno += 1
        }

        delegate.layoutManagerDidLayoutText(self)
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerDidUpdateLineNumbers(self)
        }
    }

    func layout(_ attrStr: NSAttributedString, at position: CGPoint) -> Line {
        // TODO: docs say typesetter can be NULL, but this returns a CTTypesetter, not a CTTypesetter? What happens if this returns NULL?
        let typesetter = CTTypesetterCreateWithAttributedString(attrStr)

        var width: CGFloat = 0
        var height: CGFloat = 0
        var i = 0

        var lineFragments: [LineFragment] = []

        while i < attrStr.length {
            let next = i + CTTypesetterSuggestLineBreak(typesetter, i, textContainer.lineWidth)
            let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: i, length: next - i))

            let p = CGPoint(x: 0, y: height)
            let (glyphOrigin, typographicBounds) = lineMetrics(for: ctLine, in: textContainer)

            let lineFragment = LineFragment(ctLine: ctLine, glyphOrigin: glyphOrigin, position: p, typographicBounds: typographicBounds)
            lineFragments.append(lineFragment)

            i = next
            width = max(width, typographicBounds.width)
            height += typographicBounds.height
        }

        return Line(position: position, typographicBounds: CGRect(x: 0, y: 0, width: width, height: height), lineFragments: lineFragments)
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
    }


    func layoutSelections() {

    }

    func layoutInsertionPoints() {
        
    }

    func invalidateLayout() {

    }

    func convertFromTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + textContainerInset.width, y: point.y + textContainerInset.height)
    }

    func convertToTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - textContainerInset.width, y: point.y - textContainerInset.height)
    }

    func convertFromTextContainer(_ rect: CGRect) -> CGRect {
        CGRect(origin: convertFromTextContainer(rect.origin), size: rect.size)
    }

    func convertToTextContainer(_ rect: CGRect) -> CGRect {
        CGRect(origin: convertToTextContainer(rect.origin), size: rect.size)
    }
}
