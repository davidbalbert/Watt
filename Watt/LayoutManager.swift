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
    func defaultAttributes(for layoutManager: LayoutManager) -> AttributedRope.Attributes

    // An opportunity for the delegate to return a custom AttributedRope.
    func layoutManager(_ layoutManager: LayoutManager, attributedRopeFor attrRope: AttributedRope) -> AttributedRope
}

extension LayoutManagerDelegate {
    func layoutManager(_ layoutManager: LayoutManager, attributedRopeFor attrRope: AttributedRope) -> AttributedRope {
        attrRope
    }
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

        enumerateLines(in: viewportRange) { line, previousBounds in
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

        let line = line(containing: selection.lowerBound, in: buffer)

        var frag: LineFragment?
        var i = line.range.lowerBound
        var offsetOfLineFragment = 0
        for f in line.lineFragments {
            if selection.lowerBound == f.range.upperBound && selection.affinity == .upstream {
                frag = f
                break
            }

            if f.range.contains(selection.lowerBound) {
                frag = f
                break
            }

            offsetOfLineFragment += f.utf16Count
            i = f.range.upperBound
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

            // in line fragment coordinates
            let caretRect = CGRect(
                x: round(min(caretOffset, textContainer.lineFragmentWidth)) - 0.5,
                y: 0,
                width: 1,
                height: frag.typographicBounds.height
            )
            rect = convert(convert(caretRect, from: frag), from: line)

            stop.pointee = true
        }

        guard let rect else {
            return
        }

        block(rect)
    }

    func firstRect(forRange range: Range<Buffer.Index>) -> (CGRect, Range<Buffer.Index>)? {
        var res: (CGRect, Range<Buffer.Index>)?

        enumerateTextSegments(in: range, type: .standard) { segmentRange, frame in
            res = (frame, segmentRange)
            return false
        }

        return res
    }

    enum SegmentType {
        case standard
        case selection
    }

    func enumerateTextSegments(in range: Range<Buffer.Index>, type: SegmentType, using block: (Range<Buffer.Index>, CGRect) -> Bool) {
        guard let buffer else {
            return
        }

        enumerateLines(in: range) { line, _ in
            for frag in line.lineFragments {
                let rangesOverlap = range.overlaps(frag.range) || range.isEmpty && frag.range.contains(range.lowerBound)
                let atEndOfDocument = frag.range.upperBound == buffer.endIndex && frag.range.upperBound == range.lowerBound
                assert(!atEndOfDocument || (atEndOfDocument && range.isEmpty))

                guard rangesOverlap || atEndOfDocument else {
                    continue
                }

                let rangeInFrag = range.clamped(to: frag.range)

                let start = buffer.utf16.distance(from: line.range.lowerBound, to: rangeInFrag.lowerBound)
                let xStart = frag.positionForCharacter(atUTF16OffsetInLine: start).x

                let shouldExtendSegment: Bool
                if type == .selection && !frag.range.isEmpty {
                    let last = buffer.index(before: frag.range.upperBound)
                    let c = buffer.characters[last]
                    shouldExtendSegment = (range.upperBound == frag.range.upperBound && c == "\n") || range.upperBound > frag.range.upperBound
                } else {
                    shouldExtendSegment = false
                }

                let xEnd: CGFloat
                if shouldExtendSegment {
                    xEnd = textContainer.lineFragmentWidth
                } else {
                    let end = buffer.utf16.distance(from: line.range.lowerBound, to: rangeInFrag.upperBound)
                    let x0 = frag.positionForCharacter(atUTF16OffsetInLine: end).x
                    let x1 = textContainer.lineFragmentWidth
                    xEnd = min(x0, x1)
                }

                let bounds = frag.typographicBounds

                // segment rect in line fragment coordinates
                let rect = CGRect(x: xStart, y: 0, width: xEnd - xStart, height: bounds.height)

                if !block(rangeInFrag, convert(convert(rect, from: frag), from: line)) {
                    return false
                }

                if range.upperBound <= frag.range.upperBound {
                    return false
                }
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
    func enumerateLines(in range: Range<Buffer.Index>, using block: (_ line: Line, _ previousBounds: CGRect) -> Bool) {
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

            let stop = !block(line, oldBounds)

            if stop {
                return
            }

            y += line.typographicBounds.height
            i = next
        }

        if i == buffer.endIndex && (buffer.contents.isEmpty || buffer.characters.last == "\n") {
            let (line, oldBounds) = layoutLineIfNecessary(from: buffer, inRange: i..<i, atPoint: CGPoint(x: 0, y: y))

            _ = block(line, oldBounds)
        }
    }

    // Point is in text container coordinates.
    func location(interactingAt point: CGPoint) -> Buffer.Index? {
        guard let (location, _) = locationAndAffinity(interactingAt: point) else {
            return nil
        }

        return location
    }

    // Point is in text container coordinates.
    func locationAndAffinity(interactingAt point: CGPoint) -> (Buffer.Index, Selection.Affinity)? {
        guard let buffer else {
            return nil
        }

        // Rules:
        //   1. You cannot click to the right of a "\n". No matter how far
        //      far right you go, you will always be before the newline until
        //      you move down to the next line.
        //   2. The last location of any fragment that doesn't end in a "\n"
        //      is upstream. This means the last location in the document is
        //      always upstream.
        //   3. All other locations are downstream.

        if point.y <= 0 {
            return (buffer.startIndex, buffer.isEmpty ? .upstream : .downstream)
        }
        
        // If we click past the end of the document, select the last character
        if point.y >= contentHeight {
            return (buffer.endIndex, .upstream)
        }

        let line = line(forVerticalOffset: point.y, in: buffer)

        // we clicked on the empty last line
        if line.range.lowerBound == buffer.endIndex {
            return (buffer.endIndex, .upstream)
        }

        // A line containing point.y should always have a fragment
        // that contains point.y.
        let frag = line.fragment(forVerticalOffset: point.y)!

        let pointInLine = convert(point, to: line)
        let pointInLineFragment = convert(pointInLine, to: frag)

        guard let offsetInLine = frag.utf16OffsetInLine(for: pointInLineFragment) else {
            return nil
        }

        var pos = buffer.utf16.index(line.range.lowerBound, offsetBy: offsetInLine)

        // When calling CTLineGetStringIndexForPosition 
        // string
        if pos == frag.range.upperBound && buffer[frag.range].characters.last == "\n" {
            pos = buffer.index(before: pos)
        }

        return (pos, pos == frag.range.upperBound ? .upstream : .downstream)
    }

    func position(forCharacterAt location: Buffer.Index, affinity: Selection.Affinity) -> CGPoint {
        guard let buffer else {
            return .zero
        }

        let line = line(containing: location, in: buffer)
        // line should always have a fragment containing location
        let frag = line.fragment(containing: location, affinity: affinity)!

        let offsetInLine = buffer.utf16.distance(from: line.range.lowerBound, to: location)
        let fragPos = frag.positionForCharacter(atUTF16OffsetInLine: offsetInLine)
        let linePos = convert(fragPos, from: frag)
        return convert(linePos, from: line)
    }

    func line(forVerticalOffset verticalOffset: CGFloat, in buffer: Buffer) -> Line {
        let offset = heights.position(upThroughYOffset: verticalOffset)

        let lineStart = buffer.utf8.index(at: offset)
        assert(lineStart == buffer.lines.index(roundingDown: lineStart))

        return line(containing: lineStart, in: buffer)
    }

    func line(containing location: Buffer.Index) -> Line? {
        guard let buffer else {
            return nil
        }

        return line(containing: location, in: buffer)
    }

    private func line(containing location: Buffer.Index, in buffer: Buffer) -> Line {
        let start = buffer.lines.index(roundingDown: location)
        let end = start == buffer.endIndex ? start : buffer.lines.index(after: start)

        let y = heights.yOffset(upThroughPosition: start.position)

        let (line, _) = layoutLineIfNecessary(from: buffer, inRange: start..<end, atPoint: CGPoint(x: 0, y: y))

        return line
    }

    func layoutLineIfNecessary(from buffer: Buffer, inRange range: Range<Buffer.Index>, atPoint point: CGPoint) -> (line: Line, previousBounds: CGRect) {
        assert(range.lowerBound == buffer.lines.index(roundingDown: range.lowerBound))
        assert(range.upperBound == buffer.endIndex || range.upperBound == buffer.lines.index(roundingDown: range.upperBound))

        if var line = lineCache[range.lowerBound.position] {
            line.origin.y = point.y
            line.range = range

            var start = range.lowerBound
            for i in 0..<line.lineFragments.count {
                let end = buffer.utf16.index(start, offsetBy: line.lineFragments[i].utf16Count)
                line.lineFragments[i].range = start..<end
                start = end
            }

            assert(start == range.upperBound)

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

    func nsAttributedString(for range: Range<Buffer.Index>) -> NSAttributedString? {
        guard let buffer else { return nil }
        return nsAttributedSubstring(for: range, in: buffer)
    }

    func nsAttributedSubstring(for range: Range<Buffer.Index>, in buffer: Buffer) -> NSAttributedString {
        let attributedRope = AttributedRope(buffer[range])

        guard let delegate else {
            return NSAttributedString(attributedRope)
        }

        return NSAttributedString(delegate.layoutManager(self, attributedRopeFor: attributedRope))
    }

    // TODO: once we save breaks, perhaps attrStr could be a visual line and this
    // method could return a LineFragment. That way, we won't have to worry about
    // calculating UTF-16 offsets into a LineFragment starting from the beginning
    // of the Line (e.g. see positionForCharacter(atUTF16Offset:in:)).
    func makeLine(from range: Range<Buffer.Index>, in buffer: Buffer, at point: CGPoint) -> Line {
        assert(range.lowerBound == buffer.lines.index(roundingDown: range.lowerBound))
        assert(range.upperBound == buffer.endIndex || range.upperBound == buffer.lines.index(roundingDown: range.upperBound))

        if range.lowerBound == buffer.endIndex {
            return makeEmptyLastLine(using: buffer, at: point)
        }

        let attrStr = nsAttributedSubstring(for: range, in: buffer)

        // N.b. Docs say this can return NULL, but its declared inside CF_ASSUME_NONNULL_BEGIN,
        // so it's imported into swift as non-optional. I bet this just means the documentation
        // is out of date, but keep an eye on this.
        let typesetter = CTTypesetterCreateWithAttributedString(attrStr)

        var width: CGFloat = 0
        var height: CGFloat = 0
        var i = 0
        var bi = range.lowerBound

        var lineFragments: [LineFragment] = []

        while i < attrStr.length {
            let next = i + CTTypesetterSuggestLineBreak(typesetter, i, textContainer.lineFragmentWidth)
            let bnext = buffer.utf16.index(bi, offsetBy: next - i)
            let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: i, length: next - i))

            let origin = CGPoint(x: textContainer.lineFragmentPadding, y: height)
            let (glyphOrigin, typographicBounds) = metrics(for: ctLine)

            let frag = LineFragment(
                ctLine: ctLine,
                glyphOrigin: glyphOrigin,
                origin: origin,
                typographicBounds: typographicBounds,
                range: bi..<bnext,
                utf16Count: next - i //isEmptyLastLine ? 0 : next - i
            )
            lineFragments.append(frag)

            i = next
            bi = bnext
            width = min(max(width, typographicBounds.width), textContainer.lineFragmentWidth)
            height += typographicBounds.height
        }

        return Line(
            origin: point,
            typographicBounds: CGRect(x: 0, y: 0, width: width + 2*textContainer.lineFragmentPadding, height: height),
            range: range,
            lineFragments: lineFragments
        )
    }

    func makeEmptyLastLine(using buffer: Buffer, at point: CGPoint) -> Line {
        let attrs: AttributedRope.Attributes
        if buffer.isEmpty {
            attrs = delegate?.defaultAttributes(for: self) ?? AttributedRope.Attributes()
        } else {
            let last = buffer.index(before: buffer.endIndex)
            attrs = buffer.getAttributes(at: last)
        }

        let origin = CGPoint(x: textContainer.lineFragmentPadding, y: 0)

        // An empty NSAttributedString can't have attributes, so we render a dummy
        // to get the correct line height.
        let dummy = CTLineCreateWithAttributedString(NSAttributedString(string: " ", attributes: .init(attrs)))
        var (glyphOrigin, typographicBounds) = metrics(for: dummy)
        typographicBounds.size.width = 0

        let emptyLine = CTLineCreateWithAttributedString(NSAttributedString(string: ""))

        let frag = LineFragment(
            ctLine: emptyLine,
            glyphOrigin: glyphOrigin,
            origin: origin,
            typographicBounds: typographicBounds,
            range: buffer.endIndex..<buffer.endIndex,
            utf16Count: 0
        )

        return Line(
            origin: point,
            typographicBounds: CGRect(x: 0, y: 0, width: 2*textContainer.lineFragmentPadding, height: typographicBounds.height),
            range: buffer.endIndex..<buffer.endIndex,
            lineFragments: [frag]
        )
    }

    // returns glyphOrigin, typographicBounds
    func metrics(for ctLine: CTLine) -> (CGPoint, CGRect) {
        let ctTypographicBounds = CTLineGetBoundsWithOptions(ctLine, [])

        // ctTypographicBounds's coordinate system has the glyph origin at (0,0).
        // Here, we assume that the glyph origin lies on the left edge of
        // ctTypographicBounds. If it doesn't, we'd have to change our calculation
        // of typographicBounds's origin, though everything else should just work.
        assert(ctTypographicBounds.minX == 0)

        // defined to have the origin in the upper left corner
        let typographicBounds = CGRect(x: 0, y: 0, width: ctTypographicBounds.width, height: round(ctTypographicBounds.height))

        let glyphOrigin = CGPoint(
            x: ctTypographicBounds.minX,
            y: round(ctTypographicBounds.height + ctTypographicBounds.minY)
        )

        return (glyphOrigin, typographicBounds)
    }

    // Returns the range of the buffer contained by rect. The start
    // and end of the range are rounded down and up to the nearest line
    // boundary respectively, so that if you were to lay out those lines,
    // you'd fill the entire rect.
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
    func contentsDidChange(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) {
        // TODO: this returns the entire invalidated range. Once we support multiple cursors, this could be much larger than necessary – imagine two cursors, one at the beginning of the document, and the other at the end. In that case we'd unnecessarily invalidate the entire document.
        let (oldRange, count) = delta.summary()

        let newRange = Range(oldRange.lowerBound..<(oldRange.lowerBound + count), in: new)

        heights.replaceSubrange(oldRange, with: new[newRange])

        lineCache.invalidate(delta: delta)
        delegate?.didInvalidateLayout(for: self)

        if old.lines.count != new.lines.count {
            lineNumberDelegate?.layoutManager(self, lineCountDidChangeFrom: old.lines.count, to: new.lines.count)
        }
    }

    func attributesDidChange(in range: Range<Buffer.Index>) {
        attributesDidChange(in: [range])
    }

    func attributesDidChange(in ranges: [Range<Buffer.Index>]) {
        for r in ranges {
            lineCache.invalidate(range: Range(intRangeFor: r))
        }
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
