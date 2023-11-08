//
//  SelectionNavigatorTests.swift
//  Watt
//
//  Created by David Albert on 11/2/23.
//

import XCTest
@testable import StandardKeyBindingResponder

extension StringProtocol {
    func index(at offset: Int) -> Index {
        index(startIndex, offsetBy: offset)
    }
}

extension Collection {
    func index(after i: Index, clampedTo upperBound: Index) -> Index {
        index(i, offsetBy: 1, limitedBy: upperBound) ?? upperBound
    }

    func index(_ i: Index, offsetBy distance: Int, clampedTo limit: Index) -> Index {
        index(i, offsetBy: distance, limitedBy: limit) ?? limit
    }
}

extension BidirectionalCollection {
    func index(before i: Index, clampedTo lowerBound: Index) -> Index {
        index(i, offsetBy: -1, limitedBy: lowerBound) ?? lowerBound
    }
}

struct SimpleSelection: Equatable {
    enum Affinity: InitializableFromSelectionAffinity {
        case upstream
        case downstream

        init(_ affinity: SelectionAffinity) {
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

    var caret: String.Index? {
        if isCaret {
            range.lowerBound
        } else {
            nil
        }
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
    
    var anchor: String.Index {
        if affinity == .upstream {
            range.upperBound
        } else {
            range.lowerBound
        }
    }

    var head: String.Index {
        if affinity == .upstream {
            range.lowerBound
        } else {
            range.upperBound
        }
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

    func index(beforeCharacter i: String.Index) -> String.Index {
        string.index(before: i)
    }

    func index(afterCharacter i: String.Index) -> String.Index {
        string.index(after: i)
    }

    func distance(from start: String.Index, to end: String.Index) -> Int {
        string.distance(from: start, to: end)
    }

    subscript(index: String.Index) -> Character {
        string[index]
    }

    func lineFragmentRange(containing i: String.Index) -> Range<String.Index> {
        let paraStart = index(roundedDownToParagraph: i)
        let paraEnd = index(afterParagraph: paraStart, clampedTo: string.endIndex)
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

    func enumerateCaretOffsetsInLineFragment(containing index: String.Index, using block: (CGFloat, String.Index, Bool) -> Bool) {
        let fragRange = lineFragmentRange(containing: index)

        let endsInNewline = string[fragRange].last == "\n"
        let count = string.distance(from: fragRange.lowerBound, to: fragRange.upperBound)

        if fragRange.isEmpty || endsInNewline && count == 1 {
            _ = block(0, fragRange.lowerBound, true)
            return
        }


        var i = fragRange.lowerBound
        var offset: CGFloat = 0
        var leadingEdge = true
        while i < fragRange.upperBound {
            if endsInNewline && i == string.index(before: fragRange.upperBound) {
                return
            }

            if !block(offset, i, leadingEdge) {
                return
            }

            if leadingEdge {
                offset += Self.charWidth
            } else {
                i = string.index(after: i)
            }
            leadingEdge = !leadingEdge
        }
    }
}

// Helpers

struct CaretOffset: Equatable {
    var offset: CGFloat
    var index: String.Index
    var leadingEdge: Bool

    init(_ offset: CGFloat, _ index: String.Index, _ leadingEdge: Bool) {
        self.offset = offset
        self.index = index
        self.leadingEdge = leadingEdge
    }
}

extension SimpleSelectionDataSource {
    func carretOffsetsInLineFragment(containing index: String.Index) -> [CaretOffset] {
        var offsets: [CaretOffset] = []
        enumerateCaretOffsetsInLineFragment(containing: index) { offset, i, leadingEdge in
            offsets.append(CaretOffset(offset, i, leadingEdge))
            return true
        }
        return offsets
    }
}

// MARK: - Sanity checks for SimpleSelectionDataSource

final class SimpleSelectionDataSourceTests: XCTestCase {
    // MARK: lineFragmentRange(containing:affinity:)

    func testLineFragmentRangesEmptyBuffer() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.lineFragmentRange(containing: s.startIndex)

        XCTAssertEqual(0..<0, intRange(r, in: s))
    }

    func testLineFragmentRangesStartOfFrags() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: charsPerFrag)

        let start0 = s.index(s.startIndex, offsetBy: 0*charsPerFrag)
        let start1 = s.index(s.startIndex, offsetBy: 1*charsPerFrag)
        let start2 = s.index(s.startIndex, offsetBy: 2*charsPerFrag)
        let start3 = s.index(s.startIndex, offsetBy: 3*charsPerFrag)
        let start4 = s.index(s.startIndex, offsetBy: 4*charsPerFrag)

        let r0 = dataSource.lineFragmentRange(containing: start0)
        let r1 = dataSource.lineFragmentRange(containing: start1)
        let r2 = dataSource.lineFragmentRange(containing: start2)
        let r3 = dataSource.lineFragmentRange(containing: start3)
        let r4 = dataSource.lineFragmentRange(containing: start4)
        let r5 = dataSource.lineFragmentRange(containing: s.endIndex)

        XCTAssertEqual(0..<10,  intRange(r0, in: s))
        XCTAssertEqual(10..<20, intRange(r1, in: s))
        XCTAssertEqual(20..<30, intRange(r2, in: s))
        XCTAssertEqual(30..<40, intRange(r3, in: s))
        XCTAssertEqual(40..<42, intRange(r4, in: s))
        XCTAssertEqual(40..<42, intRange(r5, in: s))
    }


    func testLineFragmentRangesMiddleOfFrags() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: charsPerFrag)

        let i0 = string.index(string.startIndex, offsetBy: 0*charsPerFrag + 1)
        let i1 = string.index(string.startIndex, offsetBy: 1*charsPerFrag + 1)
        let i2 = string.index(string.startIndex, offsetBy: 2*charsPerFrag + 1)
        let i3 = string.index(string.startIndex, offsetBy: 3*charsPerFrag + 1)
        let i4 = string.index(string.startIndex, offsetBy: 4*charsPerFrag + 1)

        let r0 = dataSource.lineFragmentRange(containing: i0)
        let r1 = dataSource.lineFragmentRange(containing: i1)
        let r2 = dataSource.lineFragmentRange(containing: i2)
        let r3 = dataSource.lineFragmentRange(containing: i3)
        let r4 = dataSource.lineFragmentRange(containing: i4)

        XCTAssertEqual(0..<10,  intRange(r0, in: string))
        XCTAssertEqual(10..<20, intRange(r1, in: string))
        XCTAssertEqual(20..<30, intRange(r2, in: string))
        XCTAssertEqual(30..<40, intRange(r3, in: string))
        XCTAssertEqual(40..<42, intRange(r4, in: string))
    }


    func testLineFragmentRangesMultipleLines() {
        // 4 lines, 5 line fragments, no trailing newline
        let charsPerFrag = 10

        let string = """
        hello
        0123456789
        0123456789wrap
        world
        """

        XCTAssertEqual(4, string.filter { $0 == "\n" }.count + 1)
        XCTAssertNotEqual("\n", string.last)

        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: charsPerFrag)

        // First line: a single fragment that takes up less than the entire width.
        let start0 = string.index(string.startIndex, offsetBy: 0)
        var r = dataSource.lineFragmentRange(containing: start0)
        XCTAssertEqual(0..<6, intRange(r, in: string))

        // between "o" and "\n"
        let last0 = string.index(string.startIndex, offsetBy: 5)
        r = dataSource.lineFragmentRange(containing: last0)
        XCTAssertEqual(0..<6, intRange(r, in: string))


        // Second line: a fragment that takes up the entire width and ends in a newline.
        let start1 = string.index(string.startIndex, offsetBy: 6)
        r = dataSource.lineFragmentRange(containing: start1)
        XCTAssertEqual(6..<17, intRange(r, in: string))

        // between "9" and "\n"
        let last1 = string.index(string.startIndex, offsetBy: 16)
        r = dataSource.lineFragmentRange(containing: last1)
        XCTAssertEqual(6..<17, intRange(r, in: string))


        // Third line wraps, with two fragments
        //
        // First fragment
        let start2 = string.index(string.startIndex, offsetBy: 17)
        r = dataSource.lineFragmentRange(containing: start2)
        XCTAssertEqual(17..<27, intRange(r, in: string))

        // between "9" and "w"
        let boundary2 = string.index(string.startIndex, offsetBy: 27)
        r = dataSource.lineFragmentRange(containing: boundary2)
        XCTAssertEqual(27..<32, intRange(r, in: string))

        // between "p" and "\n"
        let last2 = string.index(string.startIndex, offsetBy: 31)
        r = dataSource.lineFragmentRange(containing: last2)
        XCTAssertEqual(27..<32, intRange(r, in: string))

        // Fourth line
        let start3 = string.index(string.startIndex, offsetBy: 32)
        r = dataSource.lineFragmentRange(containing: start3)
        XCTAssertEqual(32..<37, intRange(r, in: string))

        // At the end of the buffer
        let last3 = string.index(string.startIndex, offsetBy: 37)
        XCTAssertEqual(last3, string.endIndex)

        r = dataSource.lineFragmentRange(containing: last3)
        XCTAssertEqual(32..<37, intRange(r, in: string))
    }

    func testLineFragmentRangesEndingInNewline() {
        // 2 lines, 3 line fragments
        let charsPerFrag = 10

        let string = """
        0123456789wrap

        """

        XCTAssertEqual(2, string.filter { $0 == "\n" }.count + 1)
        XCTAssertEqual("\n", string.last)

        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: charsPerFrag)

        // First line: two fragments
        let start0 = string.index(string.startIndex, offsetBy: 0)
        var r = dataSource.lineFragmentRange(containing: start0)
        XCTAssertEqual(0..<10, intRange(r, in: string))


        // between "9" and "w"
        let boundary0 = string.index(string.startIndex, offsetBy: 10)
        r = dataSource.lineFragmentRange(containing: boundary0)
        XCTAssertEqual(10..<15, intRange(r, in: string))

        // between "p" and "\n"
        let last0 = string.index(string.startIndex, offsetBy: 14)
        r = dataSource.lineFragmentRange(containing: last0)
        XCTAssertEqual(10..<15, intRange(r, in: string))

        // Second line, a single empty fragment
        let start1 = string.index(string.startIndex, offsetBy: 15)
        r = dataSource.lineFragmentRange(containing: start1)
        XCTAssertEqual(15..<15, intRange(r, in: string))
    }

    func testLineFragmentRangeFullFragAndNewline() {
        let string = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        var r = dataSource.lineFragmentRange(containing: string.index(at: 0))
        XCTAssertEqual(0..<11, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: string.index(at: 5))
        XCTAssertEqual(0..<11, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: string.index(at: 10))
        XCTAssertEqual(0..<11, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: string.index(at: 11))
        XCTAssertEqual(11..<11, intRange(r, in: string))
    }

    func testLineFragmentRangeEndIndex() {
        let string = "abc"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // End index returns the last line
        let r = dataSource.lineFragmentRange(containing: string.index(at: 3))
        XCTAssertEqual(0..<3, intRange(r, in: string))
    }

    // MARK: enumerateCaretOffsetsInLineFragment(containing:using:)

    typealias O = CaretOffset

    func testEnumerateCaretOffsetsEmptyLine() {
        let string = ""
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        let offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, string.startIndex, true), offsets[0])
    }

    func testEnumerateCaretOffsetsOnlyNewline() {
        let string = "\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, string.index(at: 0), true), offsets[0])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 1))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, string.index(at: 1), true), offsets[0])
    }

    func testEnumerateCaretOffsetOneLine() {
        let string = "abc"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        let offsets = dataSource.carretOffsetsInLineFragment(containing: string.startIndex)

        XCTAssertEqual(6, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), true), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), false), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), true), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), false), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), true), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), false), offsets[5])
    }

    func testEnumerateCaretOffsetWithNewline() {
        let string = "abc\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(6, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), true), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), false), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), true), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), false), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), true), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), false), offsets[5])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 4))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 4), true), offsets[0])
    }

    func testEnumerateCaretOffsetsWithWrap() {
        let string = "0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(20, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), true), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), false), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), true), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), false), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), true), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), false), offsets[5])
        XCTAssertEqual(O(24, string.index(at: 3), true), offsets[6])
        XCTAssertEqual(O(32, string.index(at: 3), false), offsets[7])
        XCTAssertEqual(O(32, string.index(at: 4), true), offsets[8])
        XCTAssertEqual(O(40, string.index(at: 4), false), offsets[9])
        XCTAssertEqual(O(40, string.index(at: 5), true), offsets[10])
        XCTAssertEqual(O(48, string.index(at: 5), false), offsets[11])
        XCTAssertEqual(O(48, string.index(at: 6), true), offsets[12])
        XCTAssertEqual(O(56, string.index(at: 6), false), offsets[13])
        XCTAssertEqual(O(56, string.index(at: 7), true), offsets[14])
        XCTAssertEqual(O(64, string.index(at: 7), false), offsets[15])
        XCTAssertEqual(O(64, string.index(at: 8), true), offsets[16])
        XCTAssertEqual(O(72, string.index(at: 8), false), offsets[17])
        XCTAssertEqual(O(72, string.index(at: 9), true), offsets[18])
        XCTAssertEqual(O(80, string.index(at: 9), false), offsets[19])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 10))

        XCTAssertEqual(8, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 10), true), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 10), false), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 11), true), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 11), false), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 12), true), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 12), false), offsets[5])
        XCTAssertEqual(O(24, string.index(at: 13), true), offsets[6])
        XCTAssertEqual(O(32, string.index(at: 13), false), offsets[7])
    }

    func testEnumerateCaretOffsetFullLineFragmentPlusNewline() {
        let string = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(20, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), true), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), false), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), true), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), false), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), true), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), false), offsets[5])
        XCTAssertEqual(O(24, string.index(at: 3), true), offsets[6])
        XCTAssertEqual(O(32, string.index(at: 3), false), offsets[7])
        XCTAssertEqual(O(32, string.index(at: 4), true), offsets[8])
        XCTAssertEqual(O(40, string.index(at: 4), false), offsets[9])
        XCTAssertEqual(O(40, string.index(at: 5), true), offsets[10])
        XCTAssertEqual(O(48, string.index(at: 5), false), offsets[11])
        XCTAssertEqual(O(48, string.index(at: 6), true), offsets[12])
        XCTAssertEqual(O(56, string.index(at: 6), false), offsets[13])
        XCTAssertEqual(O(56, string.index(at: 7), true), offsets[14])
        XCTAssertEqual(O(64, string.index(at: 7), false), offsets[15])
        XCTAssertEqual(O(64, string.index(at: 8), true), offsets[16])
        XCTAssertEqual(O(72, string.index(at: 8), false), offsets[17])
        XCTAssertEqual(O(72, string.index(at: 9), true), offsets[18])
        XCTAssertEqual(O(80, string.index(at: 9), false), offsets[19])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 11))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 11), true), offsets[0])
    }

    func testEnumerateCaretOffsetsUpperBound() {
        let string = "a"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        let offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 1))

        // endIndex returns the last line
        XCTAssertEqual(2, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), true), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), false), offsets[1])
    }

    func testEnumerateCaretOffsetsUpperBoundOfEmptyLine() {
        let string = "\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        let offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 1))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 1), true), offsets[0])
    }
}

// MARK: - SelectionNavigationDataSource extension tests
final class SelectionNavigationDataSourceTests: XCTestCase {
    // MARK: index(forCaretOffset:inLineFragmentWithRange:)

    func testIndexForCaretOffsetEmpty() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 0)

        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 0, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetOnlyNewline() {
        let s = "\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 1)

        // can't go past newline
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 0, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetSingleCharacter() {
        let s = "a"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 1)

        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 7.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 8, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetSingleCharacterWithNewline() {
        let s = "a\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 2)

        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        // can't go past the newline
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 16, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetSingleLine() {
        let s = "abc"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 3)

        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 2), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 2), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 24, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetWrap() {
        let s = "0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = s.index(at: 0)..<s.index(at: 10)

        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 2), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 2), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 27.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 4), dataSource.index(forCaretOffset: 28, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 4), dataSource.index(forCaretOffset: 35.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 5), dataSource.index(forCaretOffset: 36, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 5), dataSource.index(forCaretOffset: 43.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 6), dataSource.index(forCaretOffset: 44, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 6), dataSource.index(forCaretOffset: 51.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 7), dataSource.index(forCaretOffset: 52, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 7), dataSource.index(forCaretOffset: 59.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 8), dataSource.index(forCaretOffset: 60, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 8), dataSource.index(forCaretOffset: 67.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 9), dataSource.index(forCaretOffset: 68, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 9), dataSource.index(forCaretOffset: 75.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 10), dataSource.index(forCaretOffset: 76, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 10), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))

        r = s.index(at: 10)..<s.index(at: 14)

        XCTAssertEqual(s.index(at: 10), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 10), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 11), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 11), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 12), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 12), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 13), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 13), dataSource.index(forCaretOffset: 27.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 14), dataSource.index(forCaretOffset: 28, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 14), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetFullFragWithNewline() {
        let s = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = s.index(at: 0)..<s.index(at: 11)

        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 1), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 2), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 2), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 3), dataSource.index(forCaretOffset: 27.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 4), dataSource.index(forCaretOffset: 28, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 4), dataSource.index(forCaretOffset: 35.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 5), dataSource.index(forCaretOffset: 36, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 5), dataSource.index(forCaretOffset: 43.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 6), dataSource.index(forCaretOffset: 44, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 6), dataSource.index(forCaretOffset: 51.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 7), dataSource.index(forCaretOffset: 52, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 7), dataSource.index(forCaretOffset: 59.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 8), dataSource.index(forCaretOffset: 60, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 8), dataSource.index(forCaretOffset: 67.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 9), dataSource.index(forCaretOffset: 68, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 9), dataSource.index(forCaretOffset: 75.999, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 10), dataSource.index(forCaretOffset: 76, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 10), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))

        r = s.index(at: 11)..<s.index(at: 11)

        XCTAssertEqual(s.index(at: 11), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 11), dataSource.index(forCaretOffset: 0, inLineFragmentWithRange: r))
        XCTAssertEqual(s.index(at: 11), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    // MARK: caretOffset(forCharacterAt:inLineFragmentWithRange)

    func testCaretOffsetForCharacterAtEmpty() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 0)

        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 0), inLineFragmentWithRange: r))
    }

    func testCaretOffsetForCharacterAtNewline() {
        let s = "\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = s.index(at: 0)..<s.index(at: 1)
        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 0), inLineFragmentWithRange: r))
        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 1), inLineFragmentWithRange: r))

        r = s.index(at: 1)..<s.index(at: 1)
        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 1), inLineFragmentWithRange: r))
    }

    func testCaretOffsetForCharacterAtSingleCharacter() {
        let s = "a"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 1)

        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 0), inLineFragmentWithRange: r))
        XCTAssertEqual(8, dataSource.caretOffset(forCharacterAt: s.index(at: 1), inLineFragmentWithRange: r))
    }

    func testCaretOffsetForCharacterAtNonEmptyWithNewline() {
        let s = "a\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = s.index(at: 0)..<s.index(at: 2)

        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 0), inLineFragmentWithRange: r))
        XCTAssertEqual(8, dataSource.caretOffset(forCharacterAt: s.index(at: 1), inLineFragmentWithRange: r))
        XCTAssertEqual(8, dataSource.caretOffset(forCharacterAt: s.index(at: 2), inLineFragmentWithRange: r))

        r = s.index(at: 2)..<s.index(at: 2)

        XCTAssertEqual(0, dataSource.caretOffset(forCharacterAt: s.index(at: 2), inLineFragmentWithRange: r))
    }

    // MARK: range(for:enclosing:)

    func testRangeForCharacterEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .character, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, intRange(r, in: s))
    }

    func testRangeForWordEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, intRange(r, in: s))
    }

    func testRangeForLineEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, intRange(r, in: s))
    }

    func testRangeForParagraphEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .paragraph, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, intRange(r, in: s))
    }

    func testRangeForCharacter() {
        let s = "abc"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .character, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<1, intRange(r, in: s))

        r = dataSource.range(for: .character, enclosing: s.index(at: 1))
        XCTAssertEqual(1..<2, intRange(r, in: s))

        r = dataSource.range(for: .character, enclosing: s.index(at: 2))
        XCTAssertEqual(2..<3, intRange(r, in: s))

        r = dataSource.range(for: .character, enclosing: s.index(at: 3))
        XCTAssertEqual(2..<3, intRange(r, in: s))
    }

    func testRangeForWordCharactersAtEdges() {
        let s = "abc   def"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 3))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 4))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 5))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 6))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 7))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 8))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 9))
        XCTAssertEqual(6..<9, intRange(r, in: s))
    }

    func testRangeForWordWhitespaceAtEdges() {
        let s = "   abc   "
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 3))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 4))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 5))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 6))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 7))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 8))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 9))
        XCTAssertEqual(6..<9, intRange(r, in: s))
    }

    func testRangeForWordWithNewline() {
        let s = "abc \n def"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 3))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 4))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 5))
        XCTAssertEqual(3..<6, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 6))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 7))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 8))
        XCTAssertEqual(6..<9, intRange(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 9))
        XCTAssertEqual(6..<9, intRange(r, in: s))
    }

    func testRangeForLineSingleFragment() {
        let s = "abc"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 3))
        XCTAssertEqual(0..<3, intRange(r, in: s))
    }

    func testRangeForLineWithNewline() {
        let s = "abc\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<4, intRange(r, in: s))
        
        r = dataSource.range(for: .line, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<4, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<4, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 3))
        XCTAssertEqual(0..<4, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 4))
        XCTAssertEqual(4..<4, intRange(r, in: s))
    }

    func testRangeForFullLine() {
        let s = "0123456789"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<10, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 5))
        XCTAssertEqual(0..<10, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 9))
        XCTAssertEqual(0..<10, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 10))
        XCTAssertEqual(0..<10, intRange(r, in: s))
    }

    func testRangeForFullLineWithTrailingNewline() {
        let s = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<11, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 5))
        XCTAssertEqual(0..<11, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 9))
        XCTAssertEqual(0..<11, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 10))
        XCTAssertEqual(0..<11, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 11))
        XCTAssertEqual(11..<11, intRange(r, in: s))
    }

    func testRangeForWrappedLine() {
        let s = "0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<10, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 5))
        XCTAssertEqual(0..<10, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 9))
        XCTAssertEqual(0..<10, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 10))
        XCTAssertEqual(10..<14, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 11))
        XCTAssertEqual(10..<14, intRange(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 14))
        XCTAssertEqual(10..<14, intRange(r, in: s))    
    }

    func testRangeForParagraph() {
        let s = "0123456789wrap\n0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .paragraph, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<15, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 14))
        XCTAssertEqual(0..<15, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 15))
        XCTAssertEqual(15..<29, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 28))
        XCTAssertEqual(15..<29, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 29))
        XCTAssertEqual(15..<29, intRange(r, in: s))
    }

    func testRangeForParagraphWithTrailingNewline() {
        let s = "foo\nbar\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .paragraph, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<4, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 3))
        XCTAssertEqual(0..<4, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 4))
        XCTAssertEqual(4..<8, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 7))
        XCTAssertEqual(4..<8, intRange(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 8))
        XCTAssertEqual(8..<8, intRange(r, in: s))
    }
}

// MARK: - Selection tests

final class SelectionTests: XCTestCase {
    // MARK: Creating selections

    // TODO: creating carets
    // TODO: creating ranges – make sure affinity gets set correctly


    // MARK: Selection navigation

    func testMoveHorizontallyByCharacter() {
        let string = "ab\ncd\n"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        var s = SimpleSelection(caretAt: string.index(at: 0), affinity: .downstream)
        XCTAssertEqual(string.index(at: 0), s.caret)
        XCTAssertEqual(.downstream, s.affinity)

        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 3), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 4), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 6), affinity: .upstream, dataSource: d)
        // going right at the end doesn't move the caret
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 6), affinity: .upstream, dataSource: d)

        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 4), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 3), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // going left at the beginning doesn't move the caret
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveRightToEndOfFrag() {
        let string = "a"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        var s = SimpleSelection(caretAt: string.index(at: 0), affinity: .downstream)

        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
    }

    func testMoveRightFromSelection() {
        let string = "foo bar baz"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "oo b"
        var s = SimpleSelection(anchor: string.index(at: 1), head: string.index(at: 5))
        // the caret moves to the end of the selection
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)

        // it doesn't matter if the selection is reversed
        s = SimpleSelection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)

        // select "baz"
        s = SimpleSelection(anchor: string.index(at: 8), head: string.index(at: 11))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // reverse
        s = SimpleSelection(anchor: string.index(at: 11), head: string.index(at: 8))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // select all
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 11))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // reverse
        s = SimpleSelection(anchor: string.index(at: 11), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)
    }

    func testMoveLeftFromSelection() {
        let string = "foo bar baz"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "oo b"
        var s = SimpleSelection(anchor: string.index(at: 1), head: string.index(at: 5))
        // the caret moves to the beginning of the selection
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // select "foo"
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 3))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse
        s = SimpleSelection(anchor: string.index(at: 3), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // select all
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 11))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse
        s = SimpleSelection(anchor: string.index(at: 11), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveVertically() {
        let string = """
        qux
        0123456789abcdefghijwrap
        xyz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at "1"
        var s = SimpleSelection(caretAt: string.index(at: 5), affinity: .downstream)
        s = moveAndAssert(s, direction: .up, caret: "u", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "q", affinity: .downstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .up, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "0", affinity: .downstream, dataSource: d)

        // caret at "1"
        s = SimpleSelection(caretAt: string.index(at: 5), affinity: .downstream)
        s = moveAndAssert(s, direction: .down, caret: "b", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "r", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "y", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .down, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "p", affinity: .downstream, dataSource: d)


        // caret at "5"
        s = SimpleSelection(caretAt: string.index(at: 9), affinity: .downstream)
        // after "qux"
        s = moveAndAssert(s, direction: .up, caret: "\n", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "5", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "f", affinity: .downstream, dataSource: d)
        // after "wrap"
        s = moveAndAssert(s, direction: .down, caret: "\n", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .down, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "\n", affinity: .downstream, dataSource: d)
    }

    func testMoveHorizontallyByWord() {
        let string = "  hello, world; this is (a test) "
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        var s = SimpleSelection(caretAt: string.index(at: 0), affinity: .downstream)

        // between "o" and ","
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)
        // between "d" and ";"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)
        // after "this"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        // after "is"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 23), affinity: .downstream, dataSource: d)
        // after "a"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 26), affinity: .downstream, dataSource: d)
        // after "test"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 31), affinity: .downstream, dataSource: d)
        // end of buffer
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
        // doesn't move right
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)


        // beginning of "test"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 27), affinity: .downstream, dataSource: d)
        // beginning of "a"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        // beginning of "is"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)
        // beginning of "this"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 16), affinity: .downstream, dataSource: d)
        // beginning of "world"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 9), affinity: .downstream, dataSource: d)
        // beginning of "hello"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)
        // beginning of buffer
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // doesn't move left
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveRightWordFromSelection() {
        let string = "  hello, world; this is (a test) "
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "ello, w"
        var s = SimpleSelection(anchor: string.index(at: 3), head: string.index(at: 10))
        // the caret moves to the end of "world"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 10), head: string.index(at: 3))
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)

        // select "(a test"
        s = SimpleSelection(anchor: string.index(at: 24), head: string.index(at: 31))
        // the caret moves to the end of the buffer
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 31), head: string.index(at: 24))
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // select all
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 33))
        // the caret moves to the end of the buffer
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 33), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveLeftWordFromSelection() {
        let string = "  hello, world; this is (a test) "
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "lo, w"
        var s = SimpleSelection(anchor: string.index(at: 5), head: string.index(at: 10))
        // the caret moves to the beginning of "hello"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 10), head: string.index(at: 5))
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)

        // select "(a test"
        s = SimpleSelection(anchor: string.index(at: 24), head: string.index(at: 31))
        // the caret moves to the beginning of "is"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 31), head: string.index(at: 24))
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)

        // select all
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 33))
        // the caret moves to the beginning of the buffer
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = SimpleSelection(anchor: string.index(at: 33), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveLineEmpty() {
        let string = ""
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        var s = SimpleSelection(caretAt: string.startIndex, affinity: .upstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
    }

    func testMoveLineSingleFragments() {
        let string = "foo bar\nbaz qux\n"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // between "a" and "r"
        var s = SimpleSelection(caretAt: string.index(at: 6), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // moving again is a no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)

        // from end to beginning
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = SimpleSelection(caretAt: string.index(at: 2), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)



        // between "r" and "\n"
        s = SimpleSelection(caretAt: string.index(at: 7), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // between "z" and " "
        s = SimpleSelection(caretAt: string.index(at: 11), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 8), affinity: .downstream, dataSource: d)
        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 8), affinity: .downstream, dataSource: d)

        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 15), affinity: .downstream, dataSource: d)
        // no-op
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 15), affinity: .downstream, dataSource: d)

        // end of buffer
        s = SimpleSelection(caretAt: string.index(at: 16), affinity: .upstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 16), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 16), affinity: .upstream, dataSource: d)
    }

    func testMoveLineMultipleFragments() {
        let string = """
        0123456789abcdefghijwrap
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // between "0" and "1"
        var s = SimpleSelection(caretAt: string.index(at: 1), affinity: .downstream)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // reset
        s = SimpleSelection(caretAt: string.index(at: 1), affinity: .downstream)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // between "a" and "b"
        s = SimpleSelection(caretAt: string.index(at: 11), affinity: .downstream)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // reset
        s = SimpleSelection(caretAt: string.index(at: 11), affinity: .downstream)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // between "w" and "r"
        s = SimpleSelection(caretAt: string.index(at: 21), affinity: .downstream)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .upstream, dataSource: d)

        // reset
        s = SimpleSelection(caretAt: string.index(at: 21), affinity: .downstream)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .upstream, dataSource: d)
    }

    func testMoveLineMultipleFragmentsOnFragmentBoundary() {
        let string = """
        0123456789abcdefghijwrap
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // upstream between "9" and "a"
        var s = SimpleSelection(caretAt: string.index(at: 10), affinity: .upstream)
        // left
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // reset
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .upstream)
        // moving right is a no-op
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // downstream between "9" and "a"
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .downstream)
        // right
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)
        // reset
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .downstream)
        // moving left is a no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
    }

    func testMoveLineFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        bar
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "0123"
        var s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // select "1234"
        s = SimpleSelection(anchor: string.index(at: 1), head: string.index(at: 5))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 1), head: string.index(at: 5))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // select "9abc"
        s = SimpleSelection(anchor: string.index(at: 9), head: string.index(at: 13))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 9), head: string.index(at: 13))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 13), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 13), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // select "9abcdefghijw"
        s = SimpleSelection(anchor: string.index(at: 9), head: string.index(at: 21))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 9), head: string.index(at: 21))
        // downstream because we're before a hard line break
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 21), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 21), head: string.index(at: 9))
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "ijwr"
        s = SimpleSelection(anchor: string.index(at: 18), head: string.index(at: 22))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 18), head: string.index(at: 22))
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 22), head: string.index(at: 18))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 22), head: string.index(at: 18))
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "ap\nba"
        s = SimpleSelection(anchor: string.index(at: 22), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 22), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 27), head: string.index(at: 22))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 27), head: string.index(at: 22))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // select "a"
        s = SimpleSelection(anchor: string.index(at: 26), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 26), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 27), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 27), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)
    }

    func testMoveBeginningOfParagraph() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // no-ops
        var s = SimpleSelection(caretAt: string.index(at: 0), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 24), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // no-op around "baz"
        s = SimpleSelection(caretAt: string.index(at: 30), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 30), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 33), affinity: .upstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // no-op in blank line
        s = SimpleSelection(caretAt: string.index(at: 29), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 29), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 29), affinity: .downstream)

        // between "0" and "1"
        s = SimpleSelection(caretAt: string.index(at: 1), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 1), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "9" and "a" upstream
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .upstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .upstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "9" and "a" downstream
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 10), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "a" and "b"
        s = SimpleSelection(caretAt: string.index(at: 11), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 11), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "w" and "r"
        s = SimpleSelection(caretAt: string.index(at: 21), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 21), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = SimpleSelection(caretAt: string.index(at: 27), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 27), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // between "a" and "z"
        s = SimpleSelection(caretAt: string.index(at: 32), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 30), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 32), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveParagraphFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "0123"
        var s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "9abcdefghi"
        s = SimpleSelection(anchor: string.index(at: 9), head: string.index(at: 19))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 9), head: string.index(at: 19))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 19), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 19), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "rap\nfo"
        s = SimpleSelection(anchor: string.index(at: 21), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 21), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 27), head: string.index(at: 21))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 27), head: string.index(at: 21))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // select "o\n\nba"
        s = SimpleSelection(anchor: string.index(at: 26), head: string.index(at: 32))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 26), head: string.index(at: 32))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 32), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 32), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveDocument() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // no-ops
        var s = SimpleSelection(caretAt: string.index(at: 0), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 33), affinity: .upstream)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // between "f" and "o"
        s = SimpleSelection(caretAt: string.index(at: 26), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(caretAt: string.index(at: 26), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveDocumentFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // select "ijwrap\nfoo\n\nb"
        var s = SimpleSelection(anchor: string.index(at: 18), head: string.index(at: 31))
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 18), head: string.index(at: 31))
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = SimpleSelection(anchor: string.index(at: 31), head: string.index(at: 18))
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = SimpleSelection(anchor: string.index(at: 31), head: string.index(at: 18))
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByCharacter() {
        let string = "Hello, world!"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at "!"
        var s = SimpleSelection(caretAt: string.index(at: 12), affinity: .downstream)
        s = extendAndAssert(s, direction: .right, selected: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .right, dataSource: d)
        s = extendAndAssert(s, direction: .left, caret: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, selected: "d", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, caret: "!", affinity: .downstream, dataSource: d)

        // caret at "e"
        s = SimpleSelection(caretAt: string.index(at: 1), affinity: .downstream)
        s = extendAndAssert(s, direction: .left, selected: "H", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .left, dataSource: d)
        s = extendAndAssert(s, direction: .right, caret: "e", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, selected: "e", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, caret: "e", affinity: .downstream, dataSource: d)
    }

    func testExtendSelectionVertically() {
        let string = """
        qux
        0123456789abcdefghijwrap
        xyz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at "b"
        var s = SimpleSelection(caretAt: string.index(at: 15), affinity: .downstream)
        s = extendAndAssert(s, direction: .up, selected: "123456789a", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .up, selected: "ux\n0123456789a", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .up, selected: "qux\n0123456789a", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .up, dataSource: d)
        // Even though we went left to the start of the document, we don't adjust xOffset while extending.
        s = extendAndAssert(s, direction: .down, selected: "123456789a", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .down, caret: "b", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .down, selected: "bcdefghijw", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .down, selected: "bcdefghijwrap\nx", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .down, selected: "bcdefghijwrap\nxyz", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .down, dataSource: d)
        s = extendAndAssert(s, direction: .up, selected: "bcdefghijw", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .up, caret: "b", affinity: .downstream, dataSource: d)
    }

    func testExtendSelectionByWord() {
        let string = "foo; (bar) qux"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at "a"
        var s = SimpleSelection(caretAt: string.index(at: 7), affinity: .downstream)
        s = extendAndAssert(s, direction: .rightWord, selected: "ar", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .rightWord, selected: "ar) qux", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .rightWord, dataSource: d)
        s = extendAndAssert(s, direction: .leftWord, selected: "ar) ", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .leftWord, caret: "a", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .leftWord, selected: "b", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .leftWord, selected: "foo; (b", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .leftWord, dataSource: d)
        s = extendAndAssert(s, direction: .rightWord, selected: "; (b", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .rightWord, caret: "a", affinity: .downstream, dataSource: d)
    }

    func testExtendSelectionByLineEmpty() {
        let string = ""
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        var s = SimpleSelection(caretAt: string.startIndex, affinity: .upstream)
        s = extendAndAssert(s, direction: .endOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByLineSoftWrap() {
        let string = "Hello, world!"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10) // Wraps after "r"

        // caret at "o"
        var s = SimpleSelection(caretAt: string.index(at: 8), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfLine, selected: "or", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "Hello, wor", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)

        // caret at "o"
        s = SimpleSelection(caretAt: string.index(at: 8), affinity: .downstream)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "Hello, w", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .endOfLine, selected: "Hello, wor", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
    }

    func testExtendSelectionByLineHardWrap() {
        let string = "foo\nbar\nqux"
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at first "a"
        var s = SimpleSelection(caretAt: string.index(at: 5), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfLine, selected: "ar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "bar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)

        // caret at first "a"
        s = SimpleSelection(caretAt: string.index(at: 5), affinity: .downstream)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "b", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .endOfLine, selected: "bar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
    }

    func testExtendSelectionByParagraph() {
        let string = """
        foo
        0123456789wrap
        bar
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at "5"
        var s = SimpleSelection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfParagraph, selected: "56789wrap", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfParagraph, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfParagraph, selected: "0123456789wrap", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfParagraph, dataSource: d)

        // caret at "5"
        s = SimpleSelection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .beginningOfParagraph, selected: "01234", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfParagraph, dataSource: d)
        s = extendAndAssert(s, direction: .endOfParagraph, selected: "0123456789wrap", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfParagraph, dataSource: d)
    }

    func testExtendSelectionByDocument() {
        let string = """
        foo
        0123456789wrap
        bar
        """
        let d = SimpleSelectionDataSource(string: string, charsPerLine: 10)

        // caret at "5"
        var s = SimpleSelection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfDocument, selected: "56789wrap\nbar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfDocument, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfDocument, selected: "foo\n0123456789wrap\nbar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfDocument, dataSource: d)

        // caret at "5"
        s = SimpleSelection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .beginningOfDocument, selected: "foo\n01234", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfDocument, dataSource: d)
        s = extendAndAssert(s, direction: .endOfDocument, selected: "foo\n0123456789wrap\nbar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfDocument, dataSource: d)
    }

    func extendAndAssert(_ s: SimpleSelection, direction: SelectionMovement, caret c: Character, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).extend(direction, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssert(_ s: SimpleSelection, direction: SelectionMovement, selected string: String, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).extend(direction, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssertNoop(_ s: SimpleSelection, direction: SelectionMovement, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).extend(direction, dataSource: dataSource)
        XCTAssertEqual(s, s2, file: file, line: line)
        return s2
    }

    func extendAndAssert(_ s: SimpleSelection, direction: SelectionMovement, caretAt caret: String.Index, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).extend(direction, dataSource: dataSource)
        assert(selection: s2, hasCaretAt: caret, andSelectionAffinity: affinity, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: SimpleSelection, direction: SelectionMovement, caret c: Character, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).move(direction, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: SimpleSelection, direction: SelectionMovement, selected string: String, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).move(direction, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssertNoop(_ s: SimpleSelection, direction: SelectionMovement, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).move(direction, dataSource: dataSource)
        XCTAssertEqual(s, s2, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: SimpleSelection, direction: SelectionMovement, caretAt caret: String.Index, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> SimpleSelection {
        let s2 = SelectionNavigator(selection: s).move(direction, dataSource: dataSource)
        assert(selection: s2, hasCaretAt: caret, andSelectionAffinity: affinity, file: file, line: line)
        return s2
    }

    func assert(selection: SimpleSelection, hasCaretBefore c: Character, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(selection.isCaret, "selection is not a caret", file: file, line: line)
        XCTAssertEqual(dataSource.string[selection.range.lowerBound], c, "caret is not at '\(c)'", file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }

    func assert(selection: SimpleSelection, hasRangeCovering string: String, affinity: SimpleSelection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) {
        let range = selection.range
        XCTAssert(selection.isRange, "selection is not a range", file: file, line: line)
        XCTAssertEqual(String(dataSource.string[range]), string, "selection does not contain \"\(string)\"", file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }

    func assert(selection: SimpleSelection, hasCaretAt caret: String.Index, andSelectionAffinity affinity: SimpleSelection.Affinity, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(selection.caret, caret, file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }
}

fileprivate func intRange(_ r: Range<String.Index>, in string: String) -> Range<Int> {
    string.utf8.distance(from: string.startIndex, to: r.lowerBound)..<string.utf8.distance(from: string.startIndex, to: r.upperBound)
}
