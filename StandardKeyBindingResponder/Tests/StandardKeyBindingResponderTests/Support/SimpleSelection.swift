//
//  SimpleSelection.swift
//
//
//  Created by David Albert on 11/8/23.
//

import Foundation
@testable import StandardKeyBindingResponder

// Implementations of NavigableSelection, SelectionNavigationDataSource, and InitializableFromAffinity
// used for testing.

struct SimpleSelection: Equatable {
    enum Affinity: InitializableFromAffinity {
        case upstream
        case downstream

        init(_ affinity: StandardKeyBindingResponder.Affinity) {
           switch affinity {
           case .upstream: self = .upstream
           case .downstream: self = .downstream
           }
        }
    }

    let range: Range<String.Index>
    let affinity: Affinity
    let xOffset: CGFloat?

    init(range: Range<String.Index>, affinity: Affinity, xOffset: CGFloat?) {
        self.range = range
        self.affinity = affinity
        self.xOffset = xOffset
    }
}

extension SimpleSelection: NavigableSelection {
    init(caretAt index: String.Index, affinity: Affinity, xOffset: CGFloat? = nil) {
        self.init(range: index..<index, affinity: affinity, xOffset: xOffset)
    }

    init(anchor: String.Index, head: String.Index, xOffset: CGFloat? = nil) {
        precondition(anchor != head, "anchor and head must be different")

        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: xOffset)
    }
}

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
struct SimpleSelectionDataSource {
    let string: String

    // Number of visual characters in a line fragment. Does
    // not include a trailing newline character at a hard
    // line break.
    let charsPerLine: Int

    static var charWidth: CGFloat {
        8
    }

    static var lineHeight: CGFloat {
        14
    }
}

extension SimpleSelectionDataSource: SelectionNavigationDataSource {
    var documentRange: Range<String.Index> {
        string.startIndex..<string.endIndex
    }

    func index(_ i: String.Index, offsetBy offset: Int) -> String.Index {
        string.index(i, offsetBy: offset)
    }

    func distance(from start: String.Index, to end: String.Index) -> Int {
        string.distance(from: start, to: end)
    }

    subscript(index: String.Index) -> Character {
        string[index]
    }

    func lineFragmentRange(containing i: String.Index) -> Range<String.Index> {
        let paraStart = index(roundedDownToParagraph: i)
        let paraEnd = paraStart == string.endIndex ? paraStart : index(afterParagraph: paraStart)
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

    func enumerateCaretOffsetsInLineFragment(containing index: String.Index, using block: (CGFloat, String.Index, Edge) -> Bool) {
        let fragRange = lineFragmentRange(containing: index)

        let endsInNewline = string[fragRange].last == "\n"
        let count = string.distance(from: fragRange.lowerBound, to: fragRange.upperBound)

        if fragRange.isEmpty || endsInNewline && count == 1 {
            _ = block(0, fragRange.lowerBound, .trailing)
            return
        }

        var i = fragRange.lowerBound
        var offset: CGFloat = 0
        var edge: Edge = .leading
        while i < fragRange.upperBound {
            if endsInNewline && i == string.index(before: fragRange.upperBound) {
                return
            }

            if !block(offset, i, edge) {
                return
            }

            if edge == .leading {
                offset += Self.charWidth
            } else {
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

extension SimpleSelectionDataSource {
    func carretOffsetsInLineFragment(containing index: String.Index) -> [CaretOffset] {
        var offsets: [CaretOffset] = []
        enumerateCaretOffsetsInLineFragment(containing: index) { offset, i, edge in
            offsets.append(CaretOffset(offset, i, edge))
            return true
        }
        return offsets
    }
}

func intRange(_ r: Range<String.Index>, in string: String) -> Range<Int> {
    string.utf8.distance(from: string.startIndex, to: r.lowerBound)..<string.utf8.distance(from: string.startIndex, to: r.upperBound)
}
