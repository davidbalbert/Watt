//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

protocol LayoutManagerDelegate: AnyObject {
    // Should be in text container coordinates.
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect
    func didInvalidateLayout(for layoutManager: LayoutManager)
    func typingAttributes(for layoutManager: LayoutManager) -> AttributedRope.Attributes
}

protocol LayoutManagerLineNumberDelegate: AnyObject {
    func layoutManagerShouldUpdateLineNumbers(_ layoutManager: LayoutManager) -> Bool
    func layoutManagerWillUpdateLineNumbers(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, addLineNumber lineno: Int, at position: CGPoint, withLineHeight lineHeight: CGFloat)
    func layoutManagerDidUpdateLineNumbers(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, lineCountDidChangeFrom old: Int, to new: Int)
}

class LayoutManager {
    weak var delegate: LayoutManagerDelegate?
    weak var lineNumberDelegate: LayoutManagerLineNumberDelegate?

    weak var buffer: Buffer? {
        didSet {
            if let buffer {
                selection = Selection(head: buffer.startIndex)
                heights = Heights(rope: buffer.text)
                lineCache = IntervalCache(upperBound: buffer.utf8.count)
            } else {
                selection = nil
                heights = Heights()
                lineCache = IntervalCache(upperBound: 0)
            }

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

    var selection: Selection?

    var lineCache: IntervalCache<Line>

    init() {
        self.heights = Heights()
        self.textContainer = TextContainer()
        self.lineCache = IntervalCache(upperBound: 0)
        self.selection = nil
    }

    var contentHeight: CGFloat {
        heights.contentHeight
    }

    func layoutText(using block: (_ line: Line, _ previousBounds: CGRect) -> Void) {
        guard let delegate, let buffer else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)

        let updateLineNumbers = lineNumberDelegate?.layoutManagerShouldUpdateLineNumbers(self) ?? false
        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerWillUpdateLineNumbers(self)
        }

        let viewportRange = lineRange(intersecting: viewportBounds, in: buffer)

        lineCache = lineCache[viewportRange.lowerBound.position..<viewportRange.upperBound.position]

        var lineno = buffer.lines.distance(from: buffer.startIndex, to: viewportRange.lowerBound)

        enumerateLines(in: viewportRange) { range, line, previousBounds in
            block(line, previousBounds)

            if updateLineNumbers {
                lineNumberDelegate!.layoutManager(self, addLineNumber: lineno + 1, at: line.origin, withLineHeight: line.typographicBounds.height)
            }

            lineno += 1

            return true
        }

        if updateLineNumbers {
            lineNumberDelegate!.layoutManagerDidUpdateLineNumbers(self)
        }
    }

    func layoutSelections(using block: (CGRect) -> Void) {
        guard let delegate, let selection, let buffer else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let viewportRange = lineRange(intersecting: viewportBounds, in: buffer)

        let rangeInViewport = selection.range.clamped(to: viewportRange)

        if rangeInViewport.isEmpty {
            return
        }

        enumerateTextSegments(in: rangeInViewport, type: .selection) { range, rect in
            if range.isEmpty {
                assert(range.upperBound == buffer.endIndex)
                return false
            }

            block(rect)

            return true
        }
    }

    func layoutInsertionPoints(using block: (CGRect) -> Void) {
        guard let delegate, let selection, let buffer else {
            return
        }

        guard selection.isEmpty else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let viewportRange = lineRange(intersecting: viewportBounds, in: buffer)

        guard viewportRange.contains(selection.lowerBound) || viewportRange.upperBound == selection.upperBound else {
            return
        }

        let start = buffer.lines.index(roundingDown: selection.lowerBound)

        let end: Buffer.Index
        if start == buffer.endIndex {
            end = start
        } else {
            end = buffer.lines.index(after: start)
        }

        let y = heights.yOffset(upThroughPosition: selection.lowerBound.position)
        let (line, _) = layoutLineIfNecessary(from: buffer, inRange: start..<end, atPoint: CGPoint(x: 0, y: y))

        var frag: LineFragment?
        var i = start
        var offsetOfLineFragment = 0
        for f in line.lineFragments {
            let next = buffer.utf16.index(i, offsetBy: f.utf16Count)
            let r = i..<next

            if selection.lowerBound == r.upperBound && selection.affinity == .upstream {
                frag = f
                break
            }

            if r.contains(selection.lowerBound) {
                frag = f
                break
            }

            offsetOfLineFragment += f.utf16Count
            i = next
        }

        guard let frag else {
            return
        }

        var rect: CGRect?
        var prevOffsetInLine = CTLineGetStringRange(frag.ctLine).location
        CTLineEnumerateCaretOffsets(frag.ctLine) { [weak self] caretOffset, offsetInLine, leadingEdge, stop in
            guard let self else {
                stop.pointee = true
                return
            }

            // Normally, CTLineEnumerateCaretOffsets calls block in like
            // this (note: caretOffsets have been fudged for simplicity):
            //
            // s = "ab"
            //
            //   caretOffset=0  offsetInLine=0 leadingEdge=true
            //   caretOffset=7  offsetInLine=0 leadingEdge=false
            //   caretOffset=7  offsetInLine=1 leadingEdge=true
            //   caretOffset=14 offsetInLine=1 leadingEdge=false
            //
            // For each UTF-16 offsetInLine, the block is called first
            // for the leadingEdge of the glyph, and then for the trailing
            // edge. The trailing edge of one glyph is at the same location
            // as the leading edge of the following glyph.
            //
            // If the a glyph is represented by a surrogate pair however,
            // the block is called like this:
            //
            // s = "🙂b"
            //
            //   caretOffset=0  offsetInLine=0 leadingEdge=true
            //   caretOffset=17 offsetInLine=1 leadingEdge=false
            //   caretOffset=17 offsetInLine=2 leadingEdge=true
            //   caretOffset=31 offsetInLine=2 leadingEdge=false
            //
            // The difference is that the trailing edge of the emoji is
            // called with offsetInLine pointing to its trailing surrogate.
            // I.e. [0, 1, 2, 2] rather than [0, 0, 1, 1].
            //
            // For multi-scalar grapheme clusters like "👨‍👩‍👧‍👦", offsetInLine
            // for the trailing edge will point to the trailing surrogate
            // of the last unicode scalar.
            //
            //   caretOffset=0  offsetInLine=0  leadingEdge=true
            //   caretOffset=17 offsetInLine=10 leadingEdge=false
            //
            // The above grapheme cluster is made up of 4 emoji, each
            // represented by a surrogate pair, and three zero-width
            // joiners, each represented by a single UTF-16 code unit,
            // for 11 code units in all (4*2 + 3). The last unicode
            // scalar is a surrogate pair, so the trailing edge of the
            // glyph has offset in line == 10, which is the offset of
            // the final trailing surrogate (11 - 1).
            //
            // Rope.Index can't represent trailing surrogate indices, so
            // we need a way to detect that we're looking at a trailing
            // surrogate.
            //
            // We know we're looking at a trailing surrogate when we're
            // looking at a trailing edge of a glyph and the previous
            // offsetInLine is not equal to the current offsetInLine.
            //
            // We only set prevOffsetInLine when we know we're not at
            // a trailing surrogate. If we didn't do this, i would stop
            // incrementing once we saw the first surrogate pair.
            //
            // TODO: if we ever do add a proper UTF-16 view, index(_:offsetBy:)
            // will no longer round down. We'd need to find another way
            // to handle surrogate pairs, likely relying on the fact
            // that a proper UTF-16 view implies that Rope.Index supports
            // surrogate pairs.

            let isTrailingSurrogate = !leadingEdge && prevOffsetInLine != offsetInLine
            if !isTrailingSurrogate {
                i = buffer.utf16.index(i, offsetBy: offsetInLine - prevOffsetInLine)
                prevOffsetInLine = offsetInLine
            }

            let next: Buffer.Index
            if i == buffer.endIndex {
                // empty last line
                next = i
            } else if isTrailingSurrogate {
                // If offsetInLine is pointing at a trailing surrogate, i will
                // still be pointing at the leading surrogate because
                // Buffer.utf16.index(_:offsetBy:) rounds down to the nearest
                // unicode scalar boundary.
                next = buffer.utf16.index(i, offsetBy: offsetInLine - prevOffsetInLine + 1)
            } else {
                next = buffer.utf16.index(i, offsetBy: 1)
            }

            let downstreamMatch = i == selection.lowerBound && leadingEdge && selection.affinity == .downstream
            let upstreamMatch = next == selection.lowerBound && !leadingEdge && selection.affinity == .upstream

            guard downstreamMatch || upstreamMatch else {
                return
            }

            let origin = convert(convert(CGPoint(x: caretOffset, y: 0), from: frag), from: line)
            let height = frag.typographicBounds.height

            rect = CGRect(
                x: round(min(origin.x + textContainer.lineFragmentPadding, textContainer.width - textContainer.lineFragmentPadding)),
                y: origin.y,
                width: 1,
                height: height
            )

            stop.pointee = true
        }

        guard let rect else {
            return
        }

        block(rect)
    }

    enum SegmentType {
        case standard
        case selection
    }

    func enumerateTextSegments(in range: Range<Buffer.Index>, type: SegmentType, using block: (Range<Buffer.Index>, CGRect) -> Bool) {
        guard let buffer else {
            return
        }

        enumerateLines(in: range) { lineRange, line, _ in
            var fragStart = lineRange.lowerBound

            for f in line.lineFragments {
                let fragEnd = buffer.utf16.index(fragStart, offsetBy: f.utf16Count)

                let rangeOfFrag = fragStart..<fragEnd

                let rangesOverlap = range.overlaps(rangeOfFrag) || range.isEmpty && rangeOfFrag.contains(range.lowerBound)
                let atEndOfDocument = fragEnd == buffer.endIndex && fragEnd == range.lowerBound
                assert(!atEndOfDocument || (atEndOfDocument && range.isEmpty))

                guard rangesOverlap || atEndOfDocument else {
                    fragStart = fragEnd
                    continue
                }

                let rangeInFrag = range.clamped(to: rangeOfFrag)

                let start = buffer.utf16.distance(from: lineRange.lowerBound, to: rangeInFrag.lowerBound)
                let xStart = positionForCharacter(atUTF16OffsetInLine: start, in: f).x

                let shouldExtendSegment: Bool
                if type == .selection && !rangeOfFrag.isEmpty {
                    let last = buffer.index(before: rangeOfFrag.upperBound)
                    let c = buffer.characters[last]
                    shouldExtendSegment = (range.upperBound == rangeOfFrag.upperBound && c == "\n") || range.upperBound > rangeOfFrag.upperBound
                } else {
                    shouldExtendSegment = false
                }

                let xEnd: CGFloat
                if shouldExtendSegment {
                    xEnd = textContainer.lineWidth
                } else {
                    let end = buffer.utf16.distance(from: lineRange.lowerBound, to: rangeInFrag.upperBound)
                    let x0 = positionForCharacter(atUTF16OffsetInLine: end, in: f).x
                    let x1 = textContainer.lineWidth
                    xEnd = min(x0, x1)
                }

                let bounds = f.typographicBounds
                let origin = f.origin
                let padding = textContainer.lineFragmentPadding

                // selection rect in line coordinates
                let rect = CGRect(x: xStart + padding, y: origin.y, width: xEnd - xStart, height: bounds.height)
                if !block(rangeInFrag, convert(rect, from: line)) {
                    return false
                }

                if range.upperBound <= rangeOfFrag.upperBound {
                    return false
                }

                fragStart = fragEnd
            }

            return true
        }
    }

    // Empty ranges will still yield the line that contains them.
    //
    // Block parameters:
    //   range - the range of the line in buffer
    //   line - the line
    //   previousBounds - The (possibly estimated) bounds of the line before layout was performed. If the line was already laid out, this is equal to line.typographicBounds.
    func enumerateLines(in range: Range<Buffer.Index>, using block: (_ range: Range<Buffer.Index>, _ line: Line, _ previousBounds: CGRect) -> Bool) {
        guard let buffer else {
            return
        }

        var i = buffer.lines.index(roundingDown: range.lowerBound)

        let end: Buffer.Index
        if range.upperBound == buffer.endIndex {
            end = buffer.endIndex
        } else if range.isEmpty {
            end = buffer.lines.index(after: range.upperBound)
        } else {
            end = buffer.lines.index(roundingUp: range.upperBound)
        }

        var y = heights.yOffset(upThroughPosition: i.position)

        while i < end {
            let next = buffer.lines.index(after: i)
            let (line, oldBounds) = layoutLineIfNecessary(from: buffer, inRange: i..<next, atPoint: CGPoint(x: 0, y: y))

            let stop = !block(i..<next, line, oldBounds)

            if stop {
                return
            }

            y += line.typographicBounds.height
            i = next
        }

        if i == buffer.endIndex && (buffer.contents.isEmpty || buffer.characters.last == "\n") {
            let (line, oldBounds) = layoutLineIfNecessary(from: buffer, inRange: i..<i, atPoint: CGPoint(x: 0, y: y))

            _ = block(i..<i, line, oldBounds)
        }
    }

    func locationAndAffinity(interactingAt point: CGPoint) -> (Buffer.Index, Selection.Affinity)? {
        guard let buffer else {
            return nil
        }

        if point.y <= 0 {
            return (buffer.startIndex, .downstream)
        }
        
        // If we click past the end of the document, select the last character
        if point.y >= contentHeight {
            return (buffer.endIndex, .upstream)
        }

        let offset = heights.position(upThroughYOffset: point.y)
        let start = buffer.utf8.index(at: offset)

        // the document ends with an empty last line.
        if start == buffer.endIndex {
            return (buffer.endIndex, .upstream)
        }

        assert(start == buffer.lines.index(roundingDown: start))

        let end = buffer.lines.index(after: start)
        let y = heights.yOffset(upThroughPosition: offset)

        let (line, _) = layoutLineIfNecessary(from: buffer, inRange: start..<end, atPoint: CGPoint(x: 0, y: y))

        let pointInLine = convert(point, to: line)

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
        let pointInCTLine = CGPoint(
            x: pointInLineFragment.x - textContainer.lineFragmentPadding,
            y: pointInLineFragment.y
        )

        let offsetInLine = lineFragment.characterIndex(for: pointInCTLine)
        if offsetInLine == kCFNotFound {
            return nil
        }

        let offsetInLineFragment = offsetInLine - offsetOfLineFragment

        let fragStart = buffer.utf16.index(start, offsetBy: offsetOfLineFragment)
        var pos = buffer.utf16.index(fragStart, offsetBy: offsetInLineFragment)

        // TODO: what if lineFragment is empty?
        let next = buffer.utf16.index(fragStart, offsetBy: lineFragment.utf16Count)
        let last = buffer.index(before: next)
        let c = buffer.characters[last]

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

    func layoutLineIfNecessary(from buffer: Buffer, inRange range: Range<Buffer.Index>, atPoint point: CGPoint) -> (line: Line, previousBounds: CGRect) {
        assert(range.lowerBound == buffer.lines.index(roundingDown: range.lowerBound))
        assert(range.upperBound == buffer.endIndex || range.upperBound == buffer.lines.index(roundingDown: range.upperBound))

        if var line = lineCache[range.lowerBound.position] {
            line.origin.y = point.y
            return (line, line.typographicBounds)
        } else {
            let line = makeLine(from: range, in: buffer, at: point)
            lineCache.set(line, forRange: range.lowerBound.position..<range.upperBound.position)

            let hi = heights.index(at: range.lowerBound.position)
            let oldHeight = heights[hi]
            let newHeight = line.typographicBounds.height

            if oldHeight != newHeight {
                heights[hi] = newHeight
            }

            var old = line.typographicBounds
            old.size.height = oldHeight

            return (line, old)
        }
    }

    // TODO: once we save breaks, perhaps attrStr could be a visual line and this
    // method could return a LineFragment. That way, we won't have to worry about
    // calculating UTF-16 offsets into a LineFragment starting from the beginning
    // of the Line (e.g. see positionForCharacter(atUTF16Offset:in:)).
    func makeLine(from range: Range<Buffer.Index>, in buffer: Buffer, at point: CGPoint) -> Line {
        assert(range.lowerBound == buffer.lines.index(roundingDown: range.lowerBound))
        assert(range.upperBound == buffer.endIndex || range.upperBound == buffer.lines.index(roundingDown: range.upperBound))

        let attrStr: NSAttributedString
        let isEmptyLastLine = range.lowerBound == buffer.endIndex

        if isEmptyLastLine {
            let attrs = delegate?.typingAttributes(for: self) ?? AttributedRope.Attributes()

            // I believe this has to be a newline because an empty NSAttributedString
            // has no runs, and thus no styles. Confirm this by attempting to create
            // an empty NSAttributedString and see what happens.
            attrStr = NSAttributedString(string: "\n", attributes: .init(attrs))
        } else {
            attrStr = buffer.attributedSubstring(for: range)
        }

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
            var (glyphOrigin, typographicBounds) = lineMetrics(for: ctLine, in: textContainer)

            if isEmptyLastLine {
                typographicBounds.size.width = 0
            }

            let lineFragment = LineFragment(
                ctLine: ctLine,
                glyphOrigin: glyphOrigin,
                origin: p,
                typographicBounds: typographicBounds,
                utf16Count: isEmptyLastLine ? 0 : next - i
            )
            lineFragments.append(lineFragment)

            i = next
            width = min(max(width, typographicBounds.width), textContainer.width)
            height += typographicBounds.height
        }

        return Line(origin: point, typographicBounds: CGRect(x: 0, y: 0, width: width, height: height), lineFragments: lineFragments)
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
        let typographicBounds = CGRect(x: 0, y: 0, width: ctTypographicBounds.width + paddingWidth, height: round(ctTypographicBounds.height))

        let glyphOrigin = CGPoint(
            x: ctTypographicBounds.minX + textContainer.lineFragmentPadding,
            y: round(ctTypographicBounds.height + ctTypographicBounds.minY)
        )

        return (glyphOrigin, typographicBounds)
    }

    // offsetInLine is the offset in the Line, not the LineFragment.
    func positionForCharacter(atUTF16OffsetInLine offsetInLine: Int, in f: LineFragment) -> CGPoint {
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
    func lineRange(intersecting rect: CGRect, in buffer: Buffer) -> Range<Buffer.Index> {
        let baseStart = heights.position(upThroughYOffset: rect.minY)
        let baseEnd = heights.position(upThroughYOffset: rect.maxY)

        let start = buffer.utf8.index(at: baseStart)
        var end = buffer.utf8.index(at: baseEnd)

        if baseEnd < buffer.utf8.count {
            end = buffer.lines.index(after: end)
        }

        assert(start == buffer.lines.index(roundingDown: start))
        assert(end == buffer.endIndex || end == buffer.lines.index(roundingDown: end))

        return start..<end
    }

    // MARK: - Editing
    func bufferContentsDidChange(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) {
        // TODO: this returns the entire invalidated range. Once we support multiple cursors, this could be much larger than necessary – imagine two cursors, one at the beginning of the document, and the other at the end. In that case we'd unnecessarily invalidate the entire document.
        let (oldRange, count) = delta.summary()

        let newRange = Range(oldRange.lowerBound..<(oldRange.lowerBound + count), in: new)

        heights.replaceSubrange(oldRange, with: new[newRange])

        // TODO: in addition to the todo above delta.summary(), once we have multiple selections we need to figure out a way to put each selection in the correct location. I think the interface to this function is probably too low level. In Delta, we can make as many changes as we want. With multiple selections, each selection can be a different length, but they all need to be replaced by the same string.
        selection = Selection(head: newRange.upperBound)
        if newRange.upperBound == new.endIndex {
            selection!.affinity = .upstream
        }

        lineCache.invalidate(delta: delta)

        delegate?.didInvalidateLayout(for: self)

        if old.lines.count != new.lines.count {
            lineNumberDelegate?.layoutManager(self, lineCountDidChangeFrom: old.lines.count, to: new.lines.count)
        }
    }

    func attributesDidChange(in range: Range<Buffer.Index>) {
        lineCache.invalidate(range: Range(intRangeFor: range))
        delegate?.didInvalidateLayout(for: self)
    }

    func invalidateLayout() {
        lineCache.removeAll()
        delegate?.didInvalidateLayout(for: self)
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
