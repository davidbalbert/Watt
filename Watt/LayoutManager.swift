//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import QuartzCore

// Notes for a hypothetical, unlikely iOS port:
//
// On iOS, we'd probably want to render lines, selection, and
// insertion points into UIViews rather than CALayers, just
// because UIViews are lighter weight, and that seems to be
// what other similar systems like UITextView, Runestone, etc.
// do.
//
// But we still want LayoutManager to be in charge of caching
// the rendering surfaces. To handle this, we could add a generic
// parameter RenderingSurface to LayoutManager, as well as
// a RenderingSurface associated type to both delegates.
// RenderingSurface will end up either CALayer or UIView. There
// are no constraints needed for the type. All the layout manager
// will do is ask its delegate to create rendering surfaces,
// cache them, and then hand them back to it's delegate to insert
// them into its hierarchy.
//
// The reason we'd need all this nonsense, and the reason
// LayoutManager is responsible for caching layers in the first
// place, is because I'm not planning on caching Lines, which
// contain the output of Core Text's layout process, and I don't
// want to have to re-layout text in order to just give the
// delegate enough info to to figure out whether it has a layer
// in its cache.

protocol LayoutManagerDelegate: AnyObject {
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect

    func layoutManagerWillLayoutText(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, createTextLayerFor line: Line) -> LineLayer
    func layoutManager(_ layoutManager: LayoutManager, insertTextLayer layer: LineLayer)
    func layoutManagerDidLayoutText(_ layoutManager: LayoutManager)

    func layoutManagerWillLayoutSelections(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, createSelectionLayerFor rect: CGRect) -> CALayer
    func layoutManager(_ layoutManager: LayoutManager, insertSelectionLayer layer: CALayer)
    func layoutManagerDidLayoutSelections(_ layoutManager: LayoutManager)

    func layoutManagerWillLayoutInsertionPoints(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, insertInsertionPointLayer layer: CALayer)
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

    var heights: Heights

    var textContainer: TextContainer {
        didSet {
            invalidateLayout()
        }
    }

    // TODO: remove textContainerInset from LayoutManager and move the convert*TextContainer methods back to TextView.
    var textContainerInset: CGSize {
        didSet {
            invalidateLayout()
        }
    }

    var viewportBounds: CGRect {
        didSet {
            if viewportBounds.width != oldValue.width {
                invalidateLayout()
            }
        }
    }

    var selection: Selection

    var textLayerCache: WeakDictionary<Int, LineLayer>

    init() {
        self.buffer = Buffer()
        self.heights = Heights(rope: buffer.contents)
        self.textContainer = TextContainer()
        self.textContainerInset = .zero
        self.viewportBounds = .zero
        self.textLayerCache = WeakDictionary()

        // TODO: subscribe to changes to buffer.
        self.selection = Selection(head: buffer.documentRange.lowerBound)
    }

    var contentHeight: CGFloat {
        heights.contentHeight
    }

    func layoutText() {
        guard let delegate else {
            return
        }

        viewportBounds = delegate.viewportBounds(for: self)

        let updateLineNumbers = lineNumberDelegate?.layoutManagerShouldUpdateLineNumbers(self) ?? false

        delegate.layoutManagerWillLayoutText(self)
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerWillUpdateLineNumbers(self)
        }

        let range = heights.lineRange(for: viewportBounds)

        var lineno: Int = range.lowerBound
        var y = heights.yOffset(forLine: range.lowerBound)

        var i = buffer.lines.index(at: range.lowerBound)
        let end = buffer.lines.index(at: range.upperBound)

        while i < end {
            let layer: LineLayer
            let line: Line
//            if let l = textLayerCache[lineno] {
//                l.line.position.y = y
//                line = l.line
//                layer = l
//            } else {
                // TODO: get rid of the hack to set the font. It should be stored in the buffer's Spans.
                line = layout(NSAttributedString(string: buffer.lines[i], attributes: [.font: (delegate as! TextView).font]), at: CGPoint(x: 0, y: y))
                layer = delegate.layoutManager(self, createTextLayerFor: line)
//            }

            delegate.layoutManager(self, insertTextLayer: layer)
//            textLayerCache[lineno] = layer

            if updateLineNumbers {
                lineNumberDelegate!.layoutManager(self, addLineNumber: lineno + 1, at: line.position, withLineHeight: line.typographicBounds.height)
            }

            let height = line.typographicBounds.height
            heights[lineno] = height

            y += height
            lineno += 1
            buffer.lines.formIndex(after: &i)
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
        heights = Heights(rope: buffer.contents)
        textLayerCache.removeAll()
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
