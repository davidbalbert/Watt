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
    func overdrawBounds(for layoutManager: LayoutManager) -> CGRect

    func layoutManager(_ layoutManager: LayoutManager, convertFromTextContainer point: CGPoint) -> CGPoint

    func layoutManager(_ layoutManager: LayoutManager, adjustScrollOffsetBy adjustment: CGSize)

    func layoutManagerWillLayoutText(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceForText line: Line)
    func layoutManagerDidLayoutText(_ layoutManager: LayoutManager)

    func layoutManagerWillLayoutSelections(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceForSelectionRect rect: CGRect)
    func layoutManagerDidLayoutSelections(_ layoutManager: LayoutManager)

    func layoutManagerWillLayoutInsertionPoints(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceForInsertionPointRect rect: CGRect)
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
            heights = Heights(rope: buffer.contents)
            invalidateLayout()
        }
    }

    var heights: Heights

    var textContainer: TextContainer {
        didSet {
            if textContainer != oldValue {
                invalidateLayout()
            }
        }
    }

    var previousViewportBounds: CGRect

    var selection: Selection

    init() {
        self.buffer = Buffer()
        self.heights = Heights(rope: buffer.contents)
        self.textContainer = TextContainer()
        self.previousViewportBounds = .zero

        // TODO: subscribe to changes to buffer.
        self.selection = Selection(head: buffer.startIndex)
    }

    var contentHeight: CGFloat {
        heights.contentHeight
    }

    func layoutText() {
        guard let delegate else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let overdrawBounds = delegate.overdrawBounds(for: self)

        let updateLineNumbers = lineNumberDelegate?.layoutManagerShouldUpdateLineNumbers(self) ?? false

        delegate.layoutManagerWillLayoutText(self)
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerWillUpdateLineNumbers(self)
        }

        let baseStart = heights.countBaseUnits(of: overdrawBounds.minY, measuredIn: .yOffset)
        let baseEnd = heights.countBaseUnits(of: overdrawBounds.maxY, measuredIn: .height)

        // TODO: maybe buffer.contents.index(inBaseMetricAt: Int)
        var i = buffer.contents.utf8.index(at: baseStart)
        let end = buffer.contents.utf8.index(at: baseEnd)

        assert(i == buffer.lines.index(roundingDown: i))
        assert(end == buffer.lines.index(roundingDown: end))

        var lineno = buffer.lines.distance(from: buffer.startIndex, to: i)
        var y = heights.count(.yOffset, upThrough: i.position)

        var scrollAdjustment: CGSize = .zero

        while i < end {
            let line: Line
//            if let l = textLayerCache[lineno] {
//                l.line.position.y = y
//                line = l.line
//                layer = l
//            } else {
                // TODO: get rid of the hack to set the font. It should be stored in the buffer's Spans.
                line = layout(NSAttributedString(string: String(buffer.lines[i]), attributes: [.font: (delegate as! TextView).font]), at: CGPoint(x: 0, y: y))
                delegate.layoutManager(self, configureRenderingSurfaceForText: line)
//            }
            
//            textLayerCache[lineno] = layer
            
            if updateLineNumbers {
                lineNumberDelegate!.layoutManager(self, addLineNumber: lineno + 1, at: line.position, withLineHeight: line.typographicBounds.height)
            }

            let hi = heights.index(at: i.position)
            let oldHeight = heights[hi]
            let newHeight = line.typographicBounds.height
            let delta = newHeight - oldHeight

            // TODO: after caching lines or breaks (whichever is more effective), moving the layer
            // cache out to the TextView.
            let minY = delegate.layoutManager(self, convertFromTextContainer: line.position).y
            let oldMaxY = minY + oldHeight
            
            // TODO: I don't know why I have to use the previous frame's
            // viewport bounds here. My best guess is that it has something
            // to do with the fact that I'm doing deferred layout of my
            // sublayers (e.g. textLayer.setNeedsLayout(), etc.). I tried
            // changing the deferred layout calls in prepareContent(in:)
            // to immediate layout calls, but it didn't seem to fix the
            // problem. On the other hand, I'm not sure if I've totally
            // gotten scroll correction right here anyways (there are
            // sometimes things that look like jumps during scrolling).
            // I'll come back to this later.
            if oldMaxY <= previousViewportBounds.minY && delta != 0 {
                scrollAdjustment.height += delta
            }
            
            if oldHeight != newHeight {
                heights[hi] = newHeight
            }

            y += newHeight
            lineno += 1
            buffer.lines.formIndex(after: &i)
        }

        delegate.layoutManagerDidLayoutText(self)
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerDidUpdateLineNumbers(self)
        }

        if scrollAdjustment != .zero {
            delegate.layoutManager(self, adjustScrollOffsetBy: scrollAdjustment)
        }

        previousViewportBounds = viewportBounds
    }

    // TODO: once we save breaks, perhaps attrStr could be a visual line and this
    // method could return a LineFragment. That way, we won't have to worry about
    // calculating UTF-16 offsets into a LineFragment starting from the beginning
    // of the Line (e.g. see locationForCharacter(atUTF16Offset:in:)).
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

            let lineFragment = LineFragment(ctLine: ctLine, glyphOrigin: glyphOrigin, position: p, typographicBounds: typographicBounds, utf16Count: next - i)
            lineFragments.append(lineFragment)

            i = next
            width = max(width, typographicBounds.width)
            height += typographicBounds.height
        }

        return Line(position: position, typographicBounds: CGRect(x: 0, y: 0, width: width, height: height), lineFragments: lineFragments)
    }

    // TODO: this is doing unnecessary layout. We need to cache Lines.
    func layoutSelections() {
        guard let delegate else {
            return
        }

        let overdrawBounds = delegate.overdrawBounds(for: self)

        delegate.layoutManagerWillLayoutSelections(self)

        let baseStart = heights.countBaseUnits(of: overdrawBounds.minY, measuredIn: .yOffset)
        let baseEnd = heights.countBaseUnits(of: overdrawBounds.maxY, measuredIn: .height)

        let start = buffer.contents.utf8.index(at: baseStart)
        let end = buffer.contents.utf8.index(at: baseEnd)

        let viewportRange = start..<end
        let rangeInViewport = selection.range.clamped(to: viewportRange)

        if rangeInViewport.isEmpty {
            return
        }

        var i = buffer.lines.index(roundingDown: rangeInViewport.lowerBound)
        var y = heights.count(.yOffset, upThrough: i.position)

        while i < rangeInViewport.upperBound {
            // TODO: get rid of the hack to set the font. It should be stored in the buffer's Spans.
            let s = NSAttributedString(string: String(buffer.lines[i]), attributes: [.font: (delegate as! TextView).font])
            let line = layout(s, at: CGPoint(x: 0, y: y))
            y += line.typographicBounds.height

            var thisFrag = i
            for f in line.lineFragments {
                // TODO: not validating!
                let nextFrag = buffer.contents.index(thisFrag, offsetBy: f.utf16Count, using: .utf16)

                let fragRange = thisFrag..<nextFrag

                // I think the only possible empty lineFragment would be the
                // last line of a document if it's empty. I don't know if we
                // represent those yet, but let's ignore them for now.
                guard !fragRange.isEmpty else {
                    return
                }

                let rangeInFrag = rangeInViewport.clamped(to: fragRange)

                if rangeInFrag.isEmpty && !fragRange.contains(rangeInFrag.lowerBound){
                    thisFrag = nextFrag
                    continue
                }

                let start = buffer.contents.distance(from: i, to: rangeInFrag.lowerBound, using: .utf16)
                let xStart = locationForCharacter(atUTF16OffsetInLine: start, in: f).x

                let last = buffer.index(before: fragRange.upperBound)
                let c = buffer[last]
                let shouldExtendSelection = (rangeInViewport.upperBound == fragRange.upperBound && c == "\n") || rangeInViewport.upperBound > fragRange.upperBound

                let xEnd: CGFloat
                if shouldExtendSelection {
                    xEnd = textContainer.lineWidth
                } else {
                    let end = buffer.contents.distance(from: i, to: rangeInFrag.upperBound, using: .utf16)
                    let x0 = locationForCharacter(atUTF16OffsetInLine: end, in: f).x
                    let x1 = textContainer.lineWidth
                    xEnd = min(x0, x1)
                }

                let bounds = f.typographicBounds
                let origin = f.position
                let padding = textContainer.lineFragmentPadding

                // selection rect in line coordinates
                let rect = CGRect(x: xStart + padding, y: origin.y, width: xEnd - xStart, height: bounds.height)

                delegate.layoutManager(self, configureRenderingSurfaceForSelectionRect: convert(rect, from: line))

                if rangeInViewport.upperBound <= fragRange.upperBound {
                    break
                }

                thisFrag = nextFrag
            }

            buffer.lines.formIndex(after: &i)
        }

        delegate.layoutManagerDidLayoutSelections(self)
    }

    func layoutInsertionPoints() {


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

    func invalidateLayout() {
//        textLayerCache.removeAll()
    }

    // offsetInLine is the offset in the Line, not the LineFragment.
    func locationForCharacter(atUTF16OffsetInLine offsetInLine: Int, in f: LineFragment) -> CGPoint {
        CGPoint(x: CTLineGetOffsetForStringIndex(f.ctLine, offsetInLine, nil), y: 0)
    }

    func location(interactingAt point: CGPoint) -> Buffer.Index? {
        guard let (location, _) = locationAndAffinity(interactingAt: point) else {
            return nil
        }

        return location
    }

    // TODO: this is gross and unsafe and needs to be different
    func locationAndAffinity(interactingAt point: CGPoint) -> (Buffer.Index, Selection.Affinity)? {
        if point.y <= 0 {
            return (buffer.startIndex, .downstream)
        }
        
        // If we click past the end of the document, select the last character
        if point.y >= contentHeight {
            return (buffer.endIndex, .upstream)
        }

        let offset = heights.countBaseUnits(of: point.y, measuredIn: .yOffset)

        let y = heights.count(.yOffset, upThrough: offset)
        let lineStart = buffer.index(at: offset)

        assert(lineStart == buffer.lines.index(roundingDown: lineStart))

        let s = NSAttributedString(string: String(buffer.lines[lineStart]), attributes: [.font: (delegate as! TextView).font])
        let line = layout(s, at: CGPoint(x: 0, y: y))

        let pointInLine = convert(point, to: line)

        // TODO: this could be a binary search, or we could even store line fragment info in Heights.
        var lineFragment: LineFragment?
        var offsetOfLineFragment = 0
        for f in line.lineFragments {
            let frame = f.frame
            if (frame.minY..<frame.maxY).contains(pointInLine.y) {
                lineFragment = f
                break
            }
            offsetOfLineFragment += f.utf16Count
        }

        guard let lineFragment else {
            return nil
        }

        let pointInLineFragment = convert(pointInLine, to: lineFragment)
        let adjusted = CGPoint(
            x: pointInLineFragment.x - textContainer.lineFragmentPadding,
            y: pointInLineFragment.y
        )

        let offsetInLine = CTLineGetStringIndexForPosition(lineFragment.ctLine, adjusted)
        if offsetInLine == kCFNotFound {
            return nil
        }

        let offsetInLineFragment = offsetInLine - offsetOfLineFragment

        // TODO: missing index validation here!
        let fragStart = buffer.contents.index(lineStart, offsetBy: offsetOfLineFragment, using: .utf16)
        var pos = buffer.contents.index(fragStart, offsetBy: offsetInLineFragment, using: .utf16)

        // TODO: what if lineFragment is empty?
        let next = buffer.contents.index(fragStart, offsetBy: lineFragment.utf16Count, using: .utf16)
        let last = buffer.contents.index(before: next)
        let c = buffer[last]

        // Rules:
        //   1. You cannot click to the right of a "\n". No matter how far
        //      far right you go, you will always be before the newline until
        //      you move down to the next line.
        //   2. The first location in a line fragment is always downstream.
        //      No exceptions.
        //   3. The last location in a line fragment is upstream, unless the
        //      line is empty (i.e. unless the line is "\n").
        //   4. All other locations are downstream.

        let atEnd = pos == last
        let afterEnd = pos == next

        if afterEnd && c == "\n" {
            pos = last
        }

        let affinity: Selection.Affinity
        if pos != fragStart && (afterEnd || (c == "\n" && atEnd)) {
            affinity = .upstream
        } else {
            affinity = .downstream
        }

        return (pos, affinity)
    }

    // MARK: - Converting coordinates

    func convert(_ rect: CGRect, from line: Line) -> CGRect {
        return CGRect(origin: convert(rect.origin, from: line), size: rect.size)
    }

    func convert(_ rect: CGRect, to line: Line) -> CGRect {
        return CGRect(origin: convert(rect.origin, to: line), size: rect.size)
    }

    func convert(_ point: CGPoint, from line: Line) -> CGPoint {
        CGPoint(
            x: line.frame.minX + point.x,
            y: line.frame.minY + point.y
        )
    }

    func convert(_ point: CGPoint, to line: Line) -> CGPoint {
        CGPoint(
            x: point.x - line.frame.minX,
            y: point.y - line.frame.minY
        )
    }

    func convert(_ rect: CGRect, from frag: LineFragment) -> CGRect {
        return CGRect(origin: convert(rect.origin, from: frag), size: rect.size)
    }

    func convert(_ rect: CGRect, to frag: LineFragment) -> CGRect {
        return CGRect(origin: convert(rect.origin, to: frag), size: rect.size)
    }

    func convert(_ point: CGPoint, from frag: LineFragment) -> CGPoint {
        CGPoint(
            x: frag.frame.minX + point.x,
            y: frag.frame.minY + point.y
        )
    }

    func convert(_ point: CGPoint, to frag: LineFragment) -> CGPoint {
        CGPoint(
            x: point.x - frag.frame.minX,
            y: point.y - frag.frame.minY
        )
    }
}
