//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import QuartzCore

protocol LayoutManagerDelegate: AnyObject {
    // Should be in text container coordinates.
    func visibleRect(for layoutManager: LayoutManager) -> CGRect
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect

    func layoutManager(_ layoutManager: LayoutManager, adjustScrollOffsetBy adjustment: CGSize)
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
            lineCache = IntervalCache(upperBound: buffer.utf8Count)
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

    var previousVisibleRect: CGRect

    var selection: Selection

    var lineCache: IntervalCache<Line>

    init() {
        self.buffer = Buffer()
        self.heights = Heights(rope: buffer.contents)
        self.textContainer = TextContainer()
        self.previousVisibleRect = .zero
        self.lineCache = IntervalCache(upperBound: buffer.utf8Count)

        // TODO: subscribe to changes to buffer.
        self.selection = Selection(head: buffer.startIndex)
    }

    var contentHeight: CGFloat {
        heights.contentHeight
    }

    func layoutText(using block: (Line) -> Void) {
        guard let delegate else {
            return
        }

        let visibleRect = delegate.visibleRect(for: self)
        let viewportBounds = delegate.viewportBounds(for: self)

        let updateLineNumbers = lineNumberDelegate?.layoutManagerShouldUpdateLineNumbers(self) ?? false
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerWillUpdateLineNumbers(self)
        }

        let viewportRange = lineRange(intersecting: viewportBounds)

        var i = viewportRange.lowerBound
        var lineno = buffer.lines.distance(from: buffer.startIndex, to: i)
        var y = heights.yOffset(upThroughPosition: i.position)

        lineCache = lineCache[viewportRange.lowerBound.position..<viewportRange.upperBound.position]

        var scrollAdjustment: CGSize = .zero

        while i < viewportRange.upperBound {
            let next = buffer.lines.index(after: i)
            let line = layoutLineIfNecessary(inRange: i..<next, atPoint: CGPoint(x: 0, y: y))

            block(line)

            if updateLineNumbers {
                lineNumberDelegate!.layoutManager(self, addLineNumber: lineno + 1, at: line.position, withLineHeight: line.typographicBounds.height)
            }

            let hi = heights.index(at: i.position)
            let oldHeight = heights[hi]
            let newHeight = line.typographicBounds.height
            let delta = newHeight - oldHeight

            let oldMaxY = line.position.y + oldHeight

            // TODO: I don't know why I have to use the previous frame's
            // visible rect here. My best guess is that it has something
            // to do with the fact that I'm doing deferred layout of my
            // sublayers (e.g. textLayer.setNeedsLayout(), etc.). I tried
            // changing the deferred layout calls in prepareContent(in:)
            // to immediate layout calls, but it didn't seem to fix the
            // problem. On the other hand, I'm not sure if I've totally
            // gotten scroll correction right here anyways (there are
            // sometimes things that look like jumps during scrolling).
            // I'll come back to this later.
            if oldMaxY <= previousVisibleRect.minY && delta != 0 {
                scrollAdjustment.height += delta
            }
            
            if oldHeight != newHeight {
                heights[hi] = newHeight
            }

            y += newHeight
            lineno += 1
            i = next
        }

        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerDidUpdateLineNumbers(self)
        }

        if scrollAdjustment != .zero {
            delegate.layoutManager(self, adjustScrollOffsetBy: scrollAdjustment)
        }

        previousVisibleRect = visibleRect
    }

    func layoutSelections(using block: (CGRect) -> Void) {
        guard let delegate else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let viewportRange = lineRange(intersecting: viewportBounds)

        let rangeInViewport = selection.range.clamped(to: viewportRange)

        if rangeInViewport.isEmpty {
            return
        }

        var i = buffer.lines.index(roundingDown: rangeInViewport.lowerBound)
        var y = heights.yOffset(upThroughPosition: i.position)

        while i < rangeInViewport.upperBound {
            let next = buffer.lines.index(after: i)
            let line = layoutLineIfNecessary(inRange: i..<next, atPoint: CGPoint(x: 0, y: y))
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

                if rangeInFrag.isEmpty && !fragRange.contains(rangeInFrag.lowerBound) {
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

                block(convert(rect, from: line))

                if rangeInViewport.upperBound <= fragRange.upperBound {
                    break
                }

                thisFrag = nextFrag
            }

            i = next
        }
    }

    // TODO: ditto re caching Lines
    func layoutInsertionPoints(using block: (CGRect) -> Void) {
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

        let offset = heights.position(upThroughYOffset: point.y)
        let start = buffer.index(at: offset)
        let end = buffer.lines.index(after: start)
        let y = heights.yOffset(upThroughPosition: offset)

        let line = layoutLineIfNecessary(inRange: start..<end, atPoint: CGPoint(x: 0, y: y))

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
        let fragStart = buffer.contents.index(start, offsetBy: offsetOfLineFragment, using: .utf16)
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

    func layoutLineIfNecessary(inRange range: Range<Buffer.Index>, atPoint point: CGPoint) -> Line {
        assert(range.lowerBound == buffer.lines.index(roundingDown: range.lowerBound))
        assert(range.upperBound == buffer.lines.index(roundingDown: range.upperBound))

        if var line = lineCache[range.lowerBound.position] {
            line.position.y = point.y
            return line
        } else {
            // TODO: get rid of the hack to set the font. It should be stored in the buffer's Spans.
            let line = layout(NSAttributedString(string: String(buffer.lines[range.lowerBound]), attributes: [.font: (delegate as! TextView).font]), at: point)

            lineCache.set(line, forRange: range.lowerBound.position..<range.upperBound.position)

            return line
        }
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
        lineCache.removeAll()
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

    // Returns the range of the buffer contained by rect. The start
    // and end of the range are rounded down and up to the nearest line
    // boundary respectively, so that if you were to lay out those lines,
    // you'd fill the entire viewport.
    func lineRange(intersecting rect: CGRect) -> Range<Buffer.Index> {
        let baseStart = heights.position(upThroughYOffset: rect.minY)
        let baseEnd = heights.position(upThroughYOffset: rect.maxY)

        let start = buffer.contents.utf8.index(at: baseStart)
        var end = buffer.contents.utf8.index(at: baseEnd)

        if baseEnd < buffer.utf8Count {
            end = buffer.lines.index(after: end)
        }

        assert(start == buffer.lines.index(roundingDown: start))
        assert(end == buffer.lines.index(roundingDown: end))

        return start..<end
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
