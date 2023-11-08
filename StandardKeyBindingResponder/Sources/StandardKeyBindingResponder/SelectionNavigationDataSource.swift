//
//  SelectionNavigationDataSource.swift
//
//
//  Created by David Albert on 11/8/23.
//

import Foundation

public protocol SelectionNavigationDataSource {
    // MARK: Storage info
    associatedtype Index: Comparable

    var documentRange: Range<Index> { get }

    func index(_ i: Index, offsetBy offset: Int) -> Index
    func distance(from start: Index, to end: Index) -> Int

    subscript(index: Index) -> Character { get }

    // MARK: Layout info
    func lineFragmentRange(containing index: Index) -> Range<Index>

    // Enumerating over the first line fragment of each string:
    // ""    -> [(0.0, 0, trailing)]
    // "\n"  -> [(0.0, 0, trailing)]
    // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
    // "a\n" -> [[0.0, 0, leading), (8.0, 0, trailing)]
    // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]
    func enumerateCaretOffsetsInLineFragment(containing index: Index, using block: (_ offset: CGFloat, _ i: Index, _ edge: Edge) -> Bool)

    // MARK: Word navigation
    func isWordStart(_ i: Index) -> Bool
    func isWordEnd(_ i: Index) -> Bool

    // MARK: Paragraph navigation
    func index(beforeParagraph i: Index) -> Index
    func index(afterParagraph i: Index) -> Index
}

// MARK: - Default implementations
public extension SelectionNavigationDataSource {
    func isWordStart(_ i: Index) -> Bool {
        if isEmpty || i == endIndex {
            return false
        }

        if i == startIndex {
            return !isWhitespace(i)
        }
        let prev = index(before: i)
        return isWhitespace(prev) && !isWhitespace(i)
    }

    func isWordEnd(_ i: Index) -> Bool {
        if isEmpty || i == startIndex {
            return false
        }

        let prev = index(before: i)
        if i == endIndex {
            return !isWhitespace(prev)
        }
        return !isWhitespace(prev) && isWhitespace(i)
    }

    func index(beforeParagraph i: Index) -> Index {
        precondition(i > startIndex)

        var j = i
        if self[index(before: j)] == "\n" {
            j = index(before: j)
        }

        while j > startIndex && self[index(before: j)] != "\n" {
            j = index(before: j)
        }

        return j
    }

    func index(afterParagraph i: Index) -> Index {
        precondition(i < endIndex)

        var j = i
        while j < endIndex && self[j] != "\n" {
            j = index(after: j)
        }

        if j < endIndex {
            j = index(after: j)
        }

        return j
    }
}

// MARK: - Internal helpers
extension SelectionNavigationDataSource {
    var isEmpty: Bool {
        documentRange.isEmpty
    }

    var startIndex: Index {
        documentRange.lowerBound
    }

    var endIndex: Index {
        documentRange.upperBound
    }

    func index(before i: Index) -> Index {
        index(i, offsetBy: -1)
    }

    func index(after i: Index) -> Index {
        index(i, offsetBy: 1)
    }

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
            let start: Index
            let end: Index

            if i == endIndex {
                start = index(ofWordBoundaryBefore: i)
                end = endIndex
            } else if isWordBoundary(i) {
                start = i
                end = index(ofWordBoundaryAfter: i)
            } else {
                start = index(roundedDownToWordBoundary: i)
                end = index(roundedUpToWordBoundary: i)
            }

            return start..<end
        case .line:
            return lineFragmentRange(containing: i)
        case .paragraph:
            let start = index(roundedDownToParagraph: i)
            let end = i == endIndex ? endIndex : index(afterParagraph: i)
            return start..<end
        }
    }

    func caretOffset(forCharacterAt target: Index, inLineFragmentWithRange fragRange: Range<Index>) -> CGFloat {
        precondition(fragRange.contains(target) || fragRange.upperBound == target)
        assert(fragRange == lineFragmentRange(containing: fragRange.lowerBound))

        let count = distance(from: fragRange.lowerBound, to: fragRange.upperBound)
        let endsInNewline = lastCharacter(inRange: fragRange) == "\n"
        let targetIsAfterNewline = endsInNewline && target == fragRange.upperBound

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
            // ""    -> [(0.0, 0, trailing)]
            // "\n"  -> [(0.0, 0, trailing)]
            // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
            // "a\n" -> [[0.0, 0, leading), (8.0, 0, trailing)]
            // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]

            // The common case.
            if edge == .leading && target == i {
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

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character)
    func index(forCaretOffset targetOffset: CGFloat, inLineFragmentWithRange fragRange: Range<Index>) -> Index {
        assert(fragRange == lineFragmentRange(containing: fragRange.lowerBound))

        let endsInNewline = lastCharacter(inRange: fragRange) == "\n"

        var res: Index?
        var prev: (offset: CGFloat, i: Index)?
        enumerateCaretOffsetsInLineFragment(containing: fragRange.lowerBound) { offset, i, edge in
            // Enumerating over the first line fragment of each string:
            // ""    -> [(0.0, 0, trailing)]
            // "\n"  -> [(0.0, 0, trailing)]
            // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
            // "a\n" -> [[0.0, 0, leading), (8.0, 0, trailing)]
            // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 1, trailing)]

            let nleft = distance(from: i, to: fragRange.upperBound)
            let isFinalOffset = edge == .trailing && (nleft == 1 || endsInNewline && nleft == 2)

            // skip all but the last trailing edge
            if edge == .trailing && !isFinalOffset {
                return true
            }

            if targetOffset > offset {
                prev = (offset, i)
                return true
            }

            // If we've gotten to our target offset and we're at the first offset in the fragment
            // (regardless of whether it's leading or trailing), we've found our index.
            guard let prev else {
                res = i
                return false
            }

            let prevDistance = abs(prev.offset - targetOffset)
            let thisDistance = abs(offset - targetOffset)

            if prevDistance < thisDistance {
                res = prev.i
            } else if isFinalOffset {
                assert(edge == .trailing)
                // the current offset is closer, because the final offset is the trailing edge of the
                // second to last index, we need to move forward to the next index.
                res = index(after: i)
                return false
            } else {
                res = i
            }

            return false
        }

        if let res {
            return res
        }

        // If we didn't find an index, it's because we're past the end of the line fragment.
        // In that case, return the upper bound of fragRange, with one exception: if the
        // fragment ends in a newline, return the index of the newline – it's impossible
        // to be on the leading edge of a newline character.
        if lastCharacter(inRange: fragRange) == "\n" {
            return index(before: fragRange.upperBound)
        } else {
            return fragRange.upperBound
        }
    }

    func lastCharacter(inRange range: Range<Index>) -> Character? {
        if range.isEmpty {
            return nil
        }

        return self[index(before: range.upperBound)]
    }

    func index(beginningOfWordBefore i: Index) -> Index? {
        if i == startIndex {
            return nil
        }

        var i = i
        if isWordStart(i) {
            i = index(before: i)
        }

        var r = range(for: .word, enclosing: i)
        if r.lowerBound == startIndex && !isWordStart(r.lowerBound) {
            // we're at the beginning of the document, but it starts
            // with whitespace.
            return nil
        } else if !isWordStart(r.lowerBound) {
            r = range(for: .word, enclosing: index(before: r.lowerBound))
        }

        return r.lowerBound
    }

    func index(endOfWordAfter i: Index) -> Index? {
        if i == endIndex {
            return nil
        }

        // no need to check if we're at the end of a word because,
        // range(for:enclosing:) on a boundary, will return the range
        // on the right.

        var r = range(for: .word, enclosing: i)
        if r.upperBound == endIndex && !isWordEnd(r.upperBound) {
            // we're at the end of the document, but it ends
            // with whitespace.
            return nil
        } else if !isWordEnd(r.upperBound) {
            // r is whitespace, move forward to get a word
            r = range(for: .word, enclosing: r.upperBound)
        }

        return r.upperBound
    }

    func index(ofWordBoundaryBefore i: Index) -> Index {
        precondition(i > startIndex)
        var j = i
        while i > startIndex {
            j = index(before: j)
            if isWordBoundary(j) {
                break
            }
        }
        return j
    }

    func index(ofWordBoundaryAfter i: Index) -> Index {
        precondition(i < endIndex)
        var j = i
        while j < endIndex {
            j = index(after: j)
            if isWordBoundary(j) {
                break
            }
        }
        return j
    }

    func index(roundedDownToWordBoundary i: Index) -> Index {
        if isWordBoundary(i) {
            return i
        }
        return index(ofWordBoundaryBefore: i)
    }

    func index(roundedUpToWordBoundary i: Index) -> Index {
        if isWordBoundary(i) {
            return i
        }
        return index(ofWordBoundaryAfter: i)
    }

    func isWordBoundary(_ i: Index) -> Bool {
        i == startIndex || i == endIndex || isWordStart(i) || isWordEnd(i)
    }

    func index(roundedDownToParagraph i: Index) -> Index {
        if i == startIndex || self[index(before: i)] == "\n" {
            return i
        }
        return index(beforeParagraph: i)
    }

    func isWhitespace(_ i: Index) -> Bool {
        let c = self[i]
        return c.isWhitespace || c.isPunctuation
    }
}
