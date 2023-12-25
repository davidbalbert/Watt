//
//  SelectionNavigationDataSource.swift
//
//
//  Created by David Albert on 11/8/23.
//

import Foundation

public protocol SelectionNavigationDataSource: DocumentContentDataSource {
    func lineFragmentRange(containing index: Index) -> Range<Index>
    func lineFragmentRange(for point: CGPoint) -> Range<Index>?
    func verticalOffset(forLineFragmentContaining index: Index) -> CGFloat
    var viewportSize: CGSize { get }

    // Enumerating over the first line fragment of each string:
    // ""    -> [(0.0, 0, leading), (0.0, 0, trailing)]
    // "\n"  -> [(0.0, 0, leading), (0.0, 0, trailing)]
    // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
    // "a\n" -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (8.0, 1, trailing)]
    // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]
    //
    // This is the same behavior as CTLineEnumerateCaretOffsets, except the trailing
    // offset of "" has an index of startIndex, rather than -1.
    // For reference, here's what CTLineEnumerateCaretOffsets reports for "":
    // ""    -> [(0.0, 0, leadingEdge=true), (0.0, -1, leadingEdge=false)]
    //
    func enumerateCaretOffsetsInLineFragment(containing index: Index, using block: (_ offset: CGFloat, _ i: Index, _ edge: Edge) -> Bool)
}


// MARK: - Internal helpers
extension SelectionNavigationDataSource {
    func range(for granularity: Granularity, enclosing i: Index) -> Range<Index> {
        if isEmpty {
            return startIndex..<startIndex
        }

        switch granularity {
        case .character:
            var start = i
            if i == endIndex {
                start = index(before: start)
            }

            return start..<index(after: start)
        case .word:
            return wordGranuleRange(containing: i)
        case .line:
            return lineFragmentRange(containing: i)
        case .paragraph:
            return paragraph(containing: i)
        }
    }

    func caretOffset(forCharacterAt target: Index, inLineFragmentWithRange fragRange: Range<Index>) -> CGFloat {
        precondition(fragRange.contains(target) || fragRange.upperBound == target)
        assert(fragRange == lineFragmentRange(containing: fragRange.lowerBound))

        let count = distance(from: fragRange.lowerBound, to: fragRange.upperBound)
        let endsInNewline = lastCharacter(inRange: fragRange) == "\n"
        let targetIsAfterNewline = endsInNewline && target == fragRange.upperBound

        let leadingTarget: Index
        if count == 1 && endsInNewline {
            // Special case for frag == "\n" && target == 1. We won't get
            // a trailing target for a "\n" character, so we need to
            // adjust the leading target down by 1.
            leadingTarget = fragRange.lowerBound
        } else {
            leadingTarget = target
        }

        let trailingTarget: Index
        if targetIsAfterNewline && count > 1 {
            trailingTarget = index(fragRange.upperBound, offsetBy: -2)
        } else if target > fragRange.lowerBound && (target == fragRange.upperBound || (endsInNewline && target == index(before: fragRange.upperBound))) {
            trailingTarget = index(before: target)
        } else {
            trailingTarget = target
        }

        var caretOffset: CGFloat?
        enumerateCaretOffsetsInLineFragment(containing: fragRange.lowerBound) { offset, i, edge in
            // Enumerating over the first line fragment of each string:
            // ""    -> [(0.0, 0, leading), (0.0, 0, trailing)]
            // "\n"  -> [(0.0, 0, leading), (0.0, 0, trailing)]
            // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
            // "a\n" -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (8.0, 1, trailing)]
            // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]

            // The common case.
            if edge == .leading && leadingTarget == i {
                caretOffset = offset
                return false
            }

            if edge == .trailing && trailingTarget == i {
                caretOffset = offset
                return false
            }

            return true
        }

        return caretOffset!
    }

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character) as well
    // as the actual caret offset of the glyph.
    func index(forCaretOffset targetOffset: CGFloat, inLineFragmentWithRange fragRange: Range<Index>) -> (index: Index, offset: CGFloat) {
        assert(fragRange == lineFragmentRange(containing: fragRange.lowerBound))

        let endsInNewline = lastCharacter(inRange: fragRange) == "\n"

        var res: (index: Index, offset: CGFloat)?
        var prev: (index: Index, offset: CGFloat)?
        enumerateCaretOffsetsInLineFragment(containing: fragRange.lowerBound) { offset, i, edge in
            // Enumerating over the first line fragment of each string:
            // ""    -> [(0.0, 0, leading), (0.0, 0, trailing)]
            // "\n"  -> [(0.0, 0, leading), (0.0, 0, trailing)]
            // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
            // "a\n" -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (8.0, 1, trailing)]
            // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]

            let nleft = distance(from: i, to: fragRange.upperBound)
            let isFinal = edge == .trailing && (fragRange.isEmpty || nleft == 1)

            // skip all but the last trailing edge
            if edge == .trailing && !isFinal {
                return true
            }

            // We haven't reached our goal yet, so just keep going.
            //
            // An exception: if this is the last caretOffset, we use it whether or
            // not we've reached our goal so we can handle the case where targetOffset
            // is beyond the end of the fragment.
            if targetOffset > offset && !isFinal {
                prev = (i, offset)
                return true
            }

            // If the offset we were looking for is the first one, just use it.
            guard let prev else {
                res = (i, offset)
                return false
            }

            let prevDistance = abs(prev.offset - targetOffset)
            let thisDistance = abs(offset - targetOffset)

            if prevDistance < thisDistance {
                // The previous offset is closer.
                res = prev
            } else if edge == .leading {
                res = (i, offset)
            } else if fragRange.isEmpty || endsInNewline {
                assert(isFinal && (i == fragRange.lowerBound || self[i] == "\n"))
                // Even though we're on a trailing edge, you can't click to the
                // right of "" or "\n", so we don't increment i.
                res = (i, offset)
            } else {
                assert(isFinal)
                // We're on a trailing edge, which means our target index is the one
                // after the current one.
                res = (index(after: i), offset)
            }

            return false
        }

        return res!
    }

    func lastCharacter(inRange range: Range<Index>) -> Character? {
        if range.isEmpty {
            return nil
        }

        return self[index(before: range.upperBound)]
    }

    // "granule" because in addition to expanding to cover a word
    // this will also expand to cover one or more space characters
    // or any other non-word character.
    func wordGranuleRange(containing i: Index) -> Range<Index> {
        assert(!isEmpty)

        var i = i
        if i == endIndex {
            i = index(before: i)
        }

        if self[i] == " " {
            var j = index(after: i)

            while i > startIndex && self[index(before: i)] == " " {
                i = index(before: i)
            }

            while j < endIndex && self[j] == " " {
                j = index(after: j)
            }

            return i..<j
        }

        if let r = wordRange(containing: i) {
            return r
        }

        return i..<index(after: i)
    }
}
