//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText
import StandardKeyBindingResponder

protocol LayoutManagerDelegate: AnyObject {
    // Text container coordinates. Includes overdraw.
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect
    // Text container coordinates. No overdraw.
    func visibleRect(for layoutManager: LayoutManager) -> CGRect
    func didInvalidateLayout(for layoutManager: LayoutManager)
    func defaultAttributes(for layoutManager: LayoutManager) -> AttributedRope.Attributes

    func selections(for layoutManager: LayoutManager) -> [Selection]

    // An opportunity for the delegate to return a custom AttributedRope.
    func layoutManager(_ layoutManager: LayoutManager, attributedRopeFor attrRope: consuming AttributedRope) -> AttributedRope

    func layoutManager(_ layoutManager: LayoutManager, bufferDidReload buffer: Buffer)
    func layoutManager(_ layoutManager: LayoutManager, buffer: Buffer, contentsDidChangeFrom old: Rope, to new: Rope, withDelta delta: BTreeDelta<Rope>)

    func layoutManager(_ layoutManager: LayoutManager, createLayerForLine line: Line) -> LineLayer
    func layoutManager(_ layoutManager: LayoutManager, positionLineLayer layer: LineLayer)
}

extension LayoutManagerDelegate {
    func layoutManager(_ layoutManager: LayoutManager, attributedRopeFor attrRope: AttributedRope) -> AttributedRope {
        attrRope
    }
}

class LayoutManager {
    weak var delegate: LayoutManagerDelegate?

    var buffer: Buffer {
        didSet {
            // addDelegate triggers highlighting, so we need to reload first
            // so that hights and lineCache are the correct length.
            reloadFromBuffer()

            oldValue.removeDelegate(self)
            buffer.addDelegate(self)
        }
    }

    var heights: Heights

    // invariant: sorted by line.range.lowerBound
    var lineLayers: [LineLayer]

    var textContainer: TextContainer {
        didSet {
            if textContainer != oldValue {
                invalidateLayout()
            }
        }
    }

    init() {
        heights = Heights()
        lineLayers = []
        textContainer = TextContainer()
        buffer = Buffer()

        buffer.addDelegate(self)
    }

    var contentHeight: CGFloat {
        heights.contentHeight
    }

    func layoutText(using block: (_ layer: LineLayer, _ prevAlignmentFrame: CGRect) -> Void) {
        guard let delegate else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let viewportRange = characterRange(intersecting: viewportBounds)

        var layers: [LineLayer] = []
        enumerateLines(in: viewportRange) { line, existingLayer, prevAlignmentFrame in
            let layer = existingLayer ?? delegate.layoutManager(self, createLayerForLine: line)
            delegate.layoutManager(self, positionLineLayer: layer)
            layers.append(layer)
            block(layer, prevAlignmentFrame)
            return true
        }
        lineLayers = layers
    }

    func layoutSelections(using block: (CGRect) -> Void) {
        guard let delegate else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let viewportRange = characterRange(intersecting: viewportBounds)

        for selection in delegate.selections(for: self) {
            let rangeInViewport = selection.range.clamped(to: viewportRange)

            if rangeInViewport.isEmpty {
                continue
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
    }

    func layoutInsertionPoints(using block: (CGRect) -> Void) {
        guard let delegate else {
            return
        }

        let viewportBounds = delegate.viewportBounds(for: self)
        let viewportRange = characterRange(intersecting: viewportBounds)

        for selection in delegate.selections(for: self) {
            guard selection.isCaret else {
                continue
            }

            guard viewportRange.contains(selection.lowerBound) || viewportRange.upperBound == selection.upperBound else {
                continue
            }

            let leadingCaretIndex = selection.lowerBound
            let trailingCaretIndex = buffer.index(selection.lowerBound, offsetBy: -1, limitedBy: buffer.startIndex)

            var rect: CGRect?
            enumerateCaretRects(containing: selection.lowerBound, affinity: selection.affinity) { caretRect, i, edge in
                let leadingMatch = edge == .leading && i == leadingCaretIndex
                let trailingMatch = edge == .trailing && i == trailingCaretIndex

                guard leadingMatch || trailingMatch else {
                    return true
                }

                rect = CGRect(
                    x: round(min(caretRect.minX, textContainer.width - textContainer.lineFragmentPadding)) - 0.5,
                    y: caretRect.minY,
                    width: caretRect.width,
                    height: caretRect.height
                )
                return false
            }

            guard let rect else {
                // should never be nil
                continue
            }

            block(rect)
        }
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
        enumerateLines(in: range) { line, _, _ in
            for frag in line.lineFragments {
                let rangesOverlap = range.overlaps(frag.range) || range.isEmpty && frag.range.contains(range.lowerBound)
                let atEndOfDocument = frag.range.upperBound == buffer.endIndex && frag.range.upperBound == range.lowerBound
                assert(!atEndOfDocument || (atEndOfDocument && range.isEmpty))

                guard rangesOverlap || atEndOfDocument else {
                    continue
                }

                let rangeInFrag = range.clamped(to: frag.range)

                let start = buffer.utf16.distance(from: line.range.lowerBound, to: rangeInFrag.lowerBound)
                let xStart = frag.caretOffset(forUTF16OffsetInLine: start)

                let shouldExtendSegment: Bool
                if type == .selection && !frag.range.isEmpty {
                    let c = buffer[frag.range].characters.last
                    shouldExtendSegment = (range.upperBound == frag.range.upperBound && c == "\n") || range.upperBound > frag.range.upperBound
                } else {
                    shouldExtendSegment = false
                }

                let xEnd: CGFloat
                if shouldExtendSegment {
                    xEnd = textContainer.lineFragmentWidth
                } else {
                    let end = buffer.utf16.distance(from: line.range.lowerBound, to: rangeInFrag.upperBound)
                    let x0 = frag.caretOffset(forUTF16OffsetInLine: end)
                    let x1 = textContainer.lineFragmentWidth
                    xEnd = min(x0, x1)
                }

                // segment rect in line fragment coordinates
                let rect = CGRect(x: xStart, y: 0, width: xEnd - xStart, height: frag.alignmentFrame.height)

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
    func enumerateLines(in range: Range<Buffer.Index>, using block: (_ line: Line, _ layer: LineLayer?, _ prevAlignmentFrame: CGRect) -> Bool) {
        var i = buffer.lines.index(roundingDown: range.lowerBound)

        let end: Buffer.Index
        if range.upperBound == buffer.endIndex {
            end = buffer.endIndex
        } else if buffer.lines.isBoundary(range.upperBound) && range.upperBound > i {
            end = range.upperBound
        } else {
            end = buffer.lines.index(after: range.upperBound)
        }

        var y = heights.yOffset(upThroughPosition: i.position)

        while i < end {
            let next = buffer.lines.index(after: i)
            let (line, layer, prevAlignmentFrame) = layoutLineIfNecessary(from: buffer, inRange: i..<next, atPoint: CGPoint(x: 0, y: y))

            let stop = !block(line, layer, prevAlignmentFrame)

            if stop {
                return
            }

            y += line.alignmentFrame.height
            i = next
        }

        if i == buffer.endIndex && buffer.lines.isBoundary(i) {
            let (line, layer, prevAlignmentFrame) = layoutLineIfNecessary(from: buffer, inRange: i..<i, atPoint: CGPoint(x: 0, y: y))

            _ = block(line, layer, prevAlignmentFrame)
        }
    }

    func caretRect(for i: Buffer.Index, affinity: Selection.Affinity) -> CGRect? {
        let line = line(containing: i)
        guard let frag = line.fragment(containing: i, affinity: affinity) else {
            return nil
        }

        let offset = buffer.utf16.distance(from: line.range.lowerBound, to: i)
        let caretOffset = frag.caretOffset(forUTF16OffsetInLine: offset)

        let fragRect = CGRect(x: caretOffset, y: 0, width: 1, height: frag.alignmentFrame.height)
        let lineRect = convert(fragRect, from: frag)
        let rect = convert(lineRect, from: line)

        return rect
    }

    // Rects are in text container coordinates
    func enumerateCaretRects(containing index: Buffer.Index, affinity: Affinity, using block: (_ rect: CGRect, _ i: Buffer.Index, _ edge: Edge) -> Bool) {
        let line = line(containing: index)
        guard let frag = line.fragment(containing: index, affinity: affinity) else {
            assertionFailure("no frag")
            return
        }

        assert(line.lineFragments.contains { $0.range == frag.range })

        // hardcode empty last line because it was created from a dummy non-empty CTLine
        if frag.range.isEmpty {
            let fragRect = CGRect(x: 0, y: 0, width: 1, height: frag.alignmentFrame.height)
            let lineRect = convert(fragRect, from: frag)
            let rect = convert(lineRect, from: line)
            if !block(rect, frag.range.lowerBound, .leading) {
                return
            }
            _ = block(rect, frag.range.lowerBound, .trailing)
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

        var i = frag.range.lowerBound
        var prevOffsetInLine = CTLineGetStringRange(frag.ctLine).location

        withoutActuallyEscaping(block) { block in
            CTLineEnumerateCaretOffsets(frag.ctLine) { [weak self] caretOffset, offsetInLine, leadingEdge, stop in
                guard let self else {
                    stop.pointee = true
                    return
                }

                let edge: Edge = leadingEdge ? .leading : .trailing

                let isTrailingSurrogate = edge == .trailing && prevOffsetInLine != offsetInLine
                if !isTrailingSurrogate {
                    i = buffer.utf16.index(i, offsetBy: offsetInLine - prevOffsetInLine)
                    prevOffsetInLine = offsetInLine
                }

                let fragRect = CGRect(x: caretOffset, y: 0, width: 1, height: frag.alignmentFrame.height)
                let lineRect = convert(fragRect, from: frag)
                let rect = convert(lineRect, from: line)

                if !block(rect, i, edge) {
                    stop.pointee = true
                    return
                }
            }
        }
    }

    // TODO: maybe re-implement this in terms of enumerateCaretOffsets.
    func index(for point: CGPoint) -> Buffer.Index {
        let line = line(forVerticalOffset: point.y)
        guard let frag = line.fragment(forVerticalOffset: point.y) else {
            return buffer.startIndex
        }

        let fragPoint = convert(convert(point, to: line), to: frag)
        guard let i = index(for: fragPoint, inLineFragment: frag) else {
            return buffer.startIndex
        }

        return i
    }

    func index(for pointInLineFragment: CGPoint, inLineFragment frag: LineFragment) -> Buffer.Index? {
        guard let u16Offset = frag.utf16OffsetInLine(for: pointInLineFragment) else {
            return nil
        }

        var i = buffer.utf16.index(frag.lineStart, offsetBy: u16Offset)

        // If you call CTLineGetStringIndexForPosition with an X value that's large
        // enough on a CTLine that ends in a "\n", you'll get the index after
        // the "\n", which we don't want (it's the start of the next line).
        if i == frag.range.upperBound && buffer[frag.range].characters.last == "\n" {
            i = buffer.index(before: i)
        }

        return i
    }

    func line(forVerticalOffset verticalOffset: CGFloat) -> Line {
        let offset = heights.position(upThroughYOffset: verticalOffset)

        let lineStart = buffer.utf8.index(at: offset)
        assert(lineStart == buffer.lines.index(roundingDown: lineStart))

        return line(containing: lineStart)
    }

    func line(containing index: Buffer.Index) -> Line {
        let content: Subrope
        if index == buffer.endIndex && !buffer.isEmpty && buffer.last != "\n" {
            content = buffer.lines[buffer.index(before: index)]
        } else {
            content = buffer.lines[index]
        }

        let y = heights.yOffset(upThroughPosition: content.startIndex.position)

        let (line, existingLayer, _) = layoutLineIfNecessary(from: buffer, inRange: content.startIndex..<content.endIndex, atPoint: CGPoint(x: 0, y: y))

        if existingLayer == nil, let delegate {
            let viewportBounds = delegate.viewportBounds(for: self)
            let viewportRange = characterRange(intersecting: viewportBounds)
            
            if viewportRange.overlaps(line.range) || (line.range.isEmpty && viewportRange.contains(line.range.lowerBound)) {
                let layer = delegate.layoutManager(self, createLayerForLine: line)
                delegate.layoutManager(self, positionLineLayer: layer)

                let i = lineLayers.firstIndex(where: { $0.line.range.lowerBound > line.range.lowerBound }) ?? lineLayers.count
                lineLayers.insert(layer, at: i)
            }
        }

        return line
    }

    // If range.lowerBound or range.upperBound coincides with the beginning or end of a line
    // we also invalidate that line, even though it doesn't overlap with range. This is why
    // range is named "touching" rather than "in".
    //
    // To understand why, consider "foo\nbar" where we delete the "\n". The newline is part of
    // the line containing "foo\n", so we have to invalidate that, but we also have to invalidate
    // the line containing "bar" because it will cease to exist. We've gone from a document
    // containing two lines to a document containing 1.
    //
    // Another way to say this is that if an edit contains the last character of a line, we also
    // also have to invalidate the next line.
    //
    // I don't remember why we have to invalidate the previous line if an edit contains the first
    // character of a line. Maybe we don't?
    func removeLineLayers(touching range: Range<Buffer.Index>) {
        let empty = range.isEmpty

        lineLayers.removeAll { layer in
            let line = layer.line
            if empty {
                return line.range.contains(range.lowerBound) || line.range.upperBound == range.lowerBound
            } else {
                return line.range.overlaps(range) || line.range.upperBound == range.lowerBound || range.upperBound == line.range.lowerBound
            }
        }
    }

    func layoutLineIfNecessary(from buffer: Buffer, inRange range: Range<Buffer.Index>, atPoint point: CGPoint) -> (line: Line, layer: LineLayer?, prevAlignmentFrame: CGRect) {
        assert(range.lowerBound == buffer.lines.index(roundingDown: range.lowerBound))
        assert(range.upperBound == buffer.endIndex || range.upperBound == buffer.lines.index(roundingDown: range.upperBound))

        let intRange = Range(unvalidatedRange: range)
        let (i, found) = lineLayers.map { Range(unvalidatedRange: $0.line.range).lowerBound }.binarySearch(for: intRange.lowerBound)
        if found {
            let layer = lineLayers[i]
            assert(Range(unvalidatedRange: layer.line.range) == intRange)

            layer.line.origin.y = point.y
            return (layer.line, layer, layer.line.alignmentFrame)
        } else {
            assert(lineLayers.allSatisfy { !$0.line.range.overlaps(range) })

            let line = makeLine(from: range, in: buffer, at: point)

            let hi = heights.index(at: range.lowerBound.position)
            let oldHeight = heights[hi]
            let newHeight = line.alignmentFrame.height

            if oldHeight != newHeight {
                heights[hi] = newHeight
            }

            var old = line.alignmentFrame
            old.size.height = oldHeight

            return (line, nil, old)
        }
    }

    func nsAttributedString(for range: Range<Buffer.Index>) -> NSAttributedString {
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

        let attrStr = nsAttributedString(for: range)

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

            // Fragment origins are always integer aligned
            assert(round(height) == height)
            let origin = CGPoint(x: textContainer.lineFragmentPadding, y: height)

            let (glyphOrigin, typographicBounds) = metrics(for: ctLine)

            let frag = LineFragment(
                ctLine: ctLine,
                origin: origin, 
                typographicBounds: typographicBounds,
                glyphOrigin: glyphOrigin,
                lineStart: range.lowerBound,
                range: bi..<bnext,
                utf16Count: next - i
            )
            lineFragments.append(frag)

            i = next
            bi = bnext
            width = min(max(width, typographicBounds.width), textContainer.lineFragmentWidth)

            // We round heights because fragments are aligned on integer values. We
            // don't round the last height because we don't want to cut off the final
            // fragment if the majority of fragment heights round down.
            if next == attrStr.length {
                height += typographicBounds.height
            } else {
                height += round(typographicBounds.height)
            }
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
            attrs = buffer.runs[last].attributes
        }

        let origin = CGPoint(x: textContainer.lineFragmentPadding, y: 0)

        // An empty NSAttributedString can't have attributes, so we render a dummy
        // to get the correct line height.
        let dummy = CTLineCreateWithAttributedString(NSAttributedString(string: " ", attributes: .init(attrs)))
        var (dummyGlyphOrigin, dummyTypographicBounds) = metrics(for: dummy)
        dummyTypographicBounds.size.width = 0

        let emptyLine = CTLineCreateWithAttributedString(NSAttributedString(string: ""))

        let frag = LineFragment(
            ctLine: emptyLine,
            origin: origin, 
            typographicBounds: dummyTypographicBounds,
            glyphOrigin: dummyGlyphOrigin,
            lineStart: buffer.endIndex,
            range: buffer.endIndex..<buffer.endIndex,
            utf16Count: 0
        )

        return Line(
            origin: point,
            typographicBounds: CGRect(x: 0, y: 0, width: 2*textContainer.lineFragmentPadding, height: dummyTypographicBounds.height),
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

        // Translate the Core Text's typographic bounds so that the origin of the
        // rectangle and the origin of the coordinate space are coincident.
        let typographicBounds = CGRect(x: 0, y: 0, width: ctTypographicBounds.width, height: ctTypographicBounds.height)

        // The glyph origin in ctTypographicBounds's coordinate space is (0, 0).
        // Here, we calculate the glyph origin in typographicBounds's coordinate
        // space, which is flipped and has the coordinate space's origin
        // coincident with typographicBounds.origin. I.e. typographicBounds's
        // is a flipped coordinate space with the upper left corner of the
        // rectangle at (0, 0).
        let glyphOrigin = CGPoint(
            x: ctTypographicBounds.minX,
            y: ctTypographicBounds.height + ctTypographicBounds.minY
        )

        return (glyphOrigin, typographicBounds)
    }

    // Returns the range of the buffer contained by rect. The start
    // and end of the range are rounded down and up to the nearest line
    // boundary respectively, so that if you were to lay out those lines,
    // you'd fill the entire rect.
    func characterRange(intersecting rect: CGRect) -> Range<Buffer.Index> {
        let byteStart = heights.position(upThroughYOffset: rect.minY)
        let byteEnd = heights.position(upThroughYOffset: rect.maxY)

        let start = buffer.utf8.index(at: byteStart)
        var end = buffer.utf8.index(at: byteEnd)

        // At this point, end is the beginning of the last line contained within
        // rect. We want to return a range that contains that line. It's possible
        // for end == buffer.endIndex even though end is the beginning of a line
        // if end is the start of the empty last line.
        if end < buffer.endIndex {
            end = buffer.lines.index(after: end)
        }

        assert(buffer.lines.isBoundary(start))
        assert(end == buffer.endIndex || buffer.lines.isBoundary(end))

        return start..<end
    }

    func invalidateLayout() {
        lineLayers = []
        delegate?.didInvalidateLayout(for: self)
    }

    func reloadFromBuffer() {
        heights = Heights(rope: buffer.text)
        lineLayers = []
        delegate?.layoutManager(self, bufferDidReload: buffer)
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
            x: line.origin.x + point.x,
            y: line.origin.y + point.y
        )
    }

    func convert(_ point: CGPoint, to line: Line) -> CGPoint {
        CGPoint(
            x: point.x - line.origin.x,
            y: point.y - line.origin.y
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
            x: frag.origin.x + point.x,
            y: frag.origin.y + point.y
        )
    }

    func convert(_ point: CGPoint, to frag: LineFragment) -> CGPoint {
        CGPoint(
            x: point.x - frag.origin.x,
            y: point.y - frag.origin.y
        )
    }
}

// MARK: - BufferDelegate

extension LayoutManager: BufferDelegate {
    func bufferDidReload(_ buffer: Buffer) {
        reloadFromBuffer()
    }

    func buffer(_ buffer: Buffer, contentsDidChangeFrom old: Rope, to new: Rope, withDelta delta: BTreeDelta<Rope>) {
        // We should never be called with an empty delta (this would imply that contents didn't actually change).
        assert(!delta.isEmpty)

        // TODO: this returns the entire invalidated range. Once we support multiple cursors, this could be much larger than necessary – imagine two cursors, one at the beginning of the document, and the other at the end. In that case we'd unnecessarily invalidate the entire document.
        let (r, count) = delta.summary()

        let oldRange = Range(r, in: old)
        let newRange = Range(r.lowerBound..<(r.lowerBound + count), in: new)

        heights.replaceSubrange(r, with: new[newRange])

        removeLineLayers(touching: oldRange)

        // Offset line ranges that fall after the edit
        let byteDelta = count - (r.upperBound - r.lowerBound)

        for i in 0..<lineLayers.count {
            let layer = lineLayers[i]
            let oldLineRange = layer.line.range

            // there are no ranges that touch the edit
            assert(oldLineRange.upperBound < oldRange.lowerBound || oldLineRange.lowerBound > oldRange.upperBound)

            let needsOffset = oldLineRange.lowerBound.position > r.lowerBound

            let oldByteRange = oldLineRange.lowerBound.position..<oldLineRange.upperBound.position
            let newByteRange = oldByteRange.offset(by: needsOffset ? byteDelta : 0)
            let newLineRange = Range(newByteRange, in: new)

            layer.line.range = newLineRange
            var start = newLineRange.lowerBound
            for i in 0..<layer.line.lineFragments.count {
                let end = buffer.utf16.index(start, offsetBy: layer.line.lineFragments[i].utf16Count)
                layer.line.lineFragments[i].lineStart = layer.line.range.lowerBound
                layer.line.lineFragments[i].range = start..<end
                start = end
            }
            assert(start == newLineRange.upperBound)
        }

        delegate?.layoutManager(self, buffer: buffer, contentsDidChangeFrom: old, to: new, withDelta: delta)
        delegate?.didInvalidateLayout(for: self)
    }

    func buffer(_ buffer: Buffer, attributesDidChangeIn ranges: [Range<Buffer.Index>]) {
        for r in ranges {
            // This probably could just remove lines that contain r (including an empty last line)
            // rather than also removing an adjacent layer that ends at r.lowerBound.
            removeLineLayers(touching: r)
        }
        delegate?.didInvalidateLayout(for: self)
    }
}

// MARK: - Selection navigation

extension LayoutManager: TextLayoutDataSource {
    var content: Buffer {
        buffer
    }

    func lineFragmentRange(containing index: Buffer.Index) -> Range<Buffer.Index> {
        let line = line(containing: index)
        return line.fragment(containing: index, affinity: index == buffer.endIndex ? .upstream : .downstream)!.range
    }

    func lineFragmentRange(for point: CGPoint) -> Range<Buffer.Index>? {
        let line = line(forVerticalOffset: point.y)
        return line.fragment(forVerticalOffset: point.y)?.range
    }

    func verticalOffset(forLineFragmentContaining index: Buffer.Index) -> CGFloat {
        let line = line(containing: index)
        let frag = line.fragment(containing: index, affinity: index == buffer.endIndex ? .upstream : .downstream)!
        return convert(frag.origin, from: line).y
    }

    var viewportSize: CGSize {
        delegate?.visibleRect(for: self).size ?? .zero
    }

    // Enumerating over the first line fragment of each string:
    // ""    -> [(0.0, 0, leading), (0.0, 0, trailing)]
    // "\n"  -> [(0.0, 0, leading), (0.0, 0, trailing)]
    // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
    // "a\n" -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (8.0, 1, trailing)]
    // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]
    func enumerateCaretOffsetsInLineFragment(containing index: Buffer.Index, using block: (_ xOffset: CGFloat, _ i: Buffer.Index, _ edge: Edge) -> Bool) {
        enumerateCaretRects(containing: index, affinity: index == buffer.endIndex ? .upstream : .downstream) { rect, i, edge in
            block(rect.minX, i, edge)
        }
    }
}
