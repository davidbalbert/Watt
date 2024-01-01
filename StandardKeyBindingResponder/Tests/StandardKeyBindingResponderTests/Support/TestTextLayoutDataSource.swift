//
//  TestTextLayoutDataSource.swift
//  
//
//  Created by David Albert on 11/9/23.
//

import Foundation
import StandardKeyBindingResponder

// Simple monospaced grid-of-characters layout:
// - All characters are 8 points wide
// - All lines are 14 points high
// - No line fragment padding
// - Does not do any word breaking. A word that extends beyond
//   a line fragment is not moved down to the next line. It stays
//   in the same place and is broken in the middle, right after
//   it hits the line fragment boundary.
// - Whitespace is treated just like normal characters. If you add
//   a space after the end of a line fragment, no fancy wrapping
//   happens. The next line fragment just starts with a space.
struct TestTextLayoutDataSource {
    let string: String

    // Number of visual characters in a line fragment. Does
    // not include a trailing newline character at a hard
    // line break.
    let charsPerLine: Int
    let linesInViewport: Int

    init(string: String, charsPerLine: Int, linesInViewport: Int) {
        self.string = string
        self.charsPerLine = charsPerLine
        self.linesInViewport = linesInViewport
    }

    init(string: String, charsPerLine: Int) {
        self.init(string: string, charsPerLine: charsPerLine, linesInViewport: 10)
    }

    static var charWidth: CGFloat {
        8
    }

    static var lineHeight: CGFloat {
        14
    }
}

extension TestTextLayoutDataSource: TextLayoutDataSource {
    var characterCount: Int {
        string.count
    }
    
    var documentRange: Range<String.Index> {
        string.startIndex..<string.endIndex
    }

    func index(_ i: String.Index, offsetBy distance: Int) -> String.Index {
        string.index(i, offsetBy: distance)
    }

    func distance(from start: String.Index, to end: String.Index) -> Int {
        string.distance(from: start, to: end)
    }

    subscript(index: String.Index) -> Character {
        string[index]
    }

    func lineFragmentRange(containing i: String.Index) -> Range<String.Index> {
        let paraStart = index(roundingDownToParagraph: i)
        let paraEnd = paraStart == string.endIndex ? paraStart : index(ofParagraphBoundaryAfter: paraStart)
        let paraLen = string.distance(from: paraStart, to: paraEnd)
        let offsetInParagraph = string.distance(from: paraStart, to: i)

        let endsWithNewline = string[paraStart..<paraEnd].last == "\n"

        // A trailing "\n", doesn't contribute to the number of fragments a
        // paragraph takes up.
        let visualParaLen = endsWithNewline ? paraLen - 1 : paraLen
        let nfrags = max(1, Int(ceil(Double(visualParaLen) / Double(charsPerLine))))

        let onTrailingBoundary = offsetInParagraph > 0 && offsetInParagraph % charsPerLine == 0
        let beforeTrailingNewline = endsWithNewline && offsetInParagraph == paraLen - 1

        let fragIndex: Int
        if onTrailingBoundary && (beforeTrailingNewline || i == string.endIndex) {
            fragIndex = (offsetInParagraph/charsPerLine) - 1
        } else {
            fragIndex = offsetInParagraph/charsPerLine
        }

        let inLastFrag = fragIndex == nfrags - 1

        let fragOffset = fragIndex * charsPerLine
        let fragLen = inLastFrag ? paraLen - fragOffset : charsPerLine
        let fragStart = string.index(paraStart, offsetBy: fragOffset)
        let fragEnd = string.index(fragStart, offsetBy: fragLen)

        return fragStart..<fragEnd
    }

    func lineFragmentRange(for point: CGPoint) -> Range<String.Index>? {
        if point.y < 0 {
            return nil
        }

        var y: CGFloat = 0
        var i = string.startIndex
        while i < string.endIndex {
            let fragRange = lineFragmentRange(containing: i)
            if y <= point.y && point.y < y + Self.lineHeight {
                return fragRange
            }
            y += Self.lineHeight
            i = fragRange.upperBound
        }

        assert(i == string.endIndex)
        let fragRange = lineFragmentRange(containing: i)
        // empty last line
        if fragRange.isEmpty && y <= point.y && point.y < y + Self.lineHeight {
            return fragRange
        }

        return nil
    }

    func verticalOffset(forLineFragmentContaining i: String.Index) -> CGFloat {
        var y: CGFloat = 0
        var j = string.startIndex
        while j < string.endIndex {
            let fragRange = lineFragmentRange(containing: j)
            if fragRange.contains(i) {
                break
            }
            y += Self.lineHeight
            j = fragRange.upperBound
        }
        return y
    }

    var viewportSize: CGSize {
        CGSize(width: CGFloat(charsPerLine) * Self.charWidth, height: CGFloat(linesInViewport) * Self.lineHeight)
    }

    func enumerateCaretOffsetsInLineFragment(containing index: String.Index, using block: (CGFloat, String.Index, Edge) -> Bool) {
        let fragRange = lineFragmentRange(containing: index)

        if fragRange.isEmpty {
            if !block(0, fragRange.lowerBound, .leading) {
                return
            }
            _ = block(0, fragRange.lowerBound, .trailing)
            return
        }

        let endsInNewline = string[fragRange].last == "\n"

        var i = fragRange.lowerBound
        var offset: CGFloat = 0
        var edge: Edge = .leading
        while i < fragRange.upperBound {
            if !block(offset, i, edge) {
                return
            }

            let isNewline = endsInNewline && i == string.index(before: fragRange.upperBound)

            if edge == .leading && !isNewline {
                offset += Self.charWidth
            }
            if edge == .trailing {
                i = string.index(after: i)
            }
            edge = edge == .leading ? .trailing : .leading
        }
    }
}

// Helpers

struct CaretOffset: Equatable {
    var offset: CGFloat
    var index: String.Index
    var edge: Edge

    init(_ offset: CGFloat, _ index: String.Index, _ edge: Edge) {
        self.offset = offset
        self.index = index
        self.edge = edge
    }
}

extension TestTextLayoutDataSource {
    func carretOffsetsInLineFragment(containing index: String.Index) -> [CaretOffset] {
        var offsets: [CaretOffset] = []
        enumerateCaretOffsetsInLineFragment(containing: index) { offset, i, edge in
            offsets.append(CaretOffset(offset, i, edge))
            return true
        }
        return offsets
    }

    func index(roundingDownToParagraph i: Index) -> Index {
        if i == string.startIndex || self[string.index(before: i)] == "\n" {
            return i
        }
        return index(ofParagraphBoundaryBefore: i)
    }
}

