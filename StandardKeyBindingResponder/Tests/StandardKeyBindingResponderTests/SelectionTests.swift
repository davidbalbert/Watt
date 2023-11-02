//
//  SelectionTests.swift
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
    let charsPerFrag: Int

    static var charWidth: CGFloat {
        8
    }

    static var lineHeight: CGFloat {
        14
    }
}

extension SimpleSelectionDataSource: SelectionDataSource {
    var documentRange: Range<String.Index> {
        string.startIndex..<string.endIndex
    }

    func index(beforeCharacter i: String.Index) -> String.Index {
        string.index(before: i)
    }

    func index(afterCharacter i: String.Index) -> String.Index {
        string.index(after: i)
    }

    subscript(index: String.Index) -> Character {
        string[index]
    }

    func lineFragmentRange(containing i: String.Index, affinity: SelectionAffinity) -> Range<String.Index>? {
        if i == string.endIndex && affinity != .upstream {
            return nil
        }

        let lineStart = index(roundingDownToLine: i)
        let lineEnd = index(afterLine: lineStart, clampedTo: string.endIndex)
        let lineLen = string.distance(from: lineStart, to: lineEnd)
        let offsetInLine = string.distance(from: lineStart, to: i)

        // A trailing "\n", which is present in all but the last line, doesn't
        // contribute to the number of fragments a line takes up.
        let visualLineLen = lineEnd == string.endIndex ? lineLen : lineLen - 1
        let nfrags = max(1, Int(ceil(Double(visualLineLen) / Double(charsPerFrag))))

        let onTrailingBoundary = offsetInLine > 0 && offsetInLine % charsPerFrag == 0
        let beforeTrailingNewline = lineEnd < string.endIndex && offsetInLine == lineLen - 1

        let fragIndex: Int
        if onTrailingBoundary && (affinity == .upstream || beforeTrailingNewline) {
            fragIndex = (offsetInLine/charsPerFrag) - 1
        } else {
            fragIndex = offsetInLine/charsPerFrag
        }

        let inLastFrag = fragIndex == nfrags - 1

        let fragOffset = fragIndex * charsPerFrag
        let fragLen = inLastFrag ? lineLen - fragOffset : charsPerFrag
        let fragStart = string.index(lineStart, offsetBy: fragOffset)
        let fragEnd = string.index(fragStart, offsetBy: fragLen)

        return fragStart..<fragEnd
    }

    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: String.Index, affinity: SelectionAffinity) -> String.Index? {
        guard let fragRange = lineFragmentRange(containing: index, affinity: affinity) else {
            return nil
        }

        let offsetInFrag = Int(round(xOffset/Self.charWidth))

        let hasHardBreak = string[fragRange].last == "\n"

        var i = string.index(fragRange.lowerBound, offsetBy: offsetInFrag, clampedTo: fragRange.upperBound)
        if i == fragRange.upperBound && hasHardBreak {
            i = string.index(before: i)
        }

        return i
    }

    func point(forCharacterAt index: String.Index, affinity: SelectionAffinity) -> CGPoint {
        if index == string.endIndex && affinity == .downstream {
            return .zero
        }

        var (lineRange, y) = lineRangeAndVerticalOffset(forCharacterAt: index)

        // we iterate rather than just asking for the line fragment range containing index
        // so that we can calculate y in text container coordinates.
        var range: Range<String.Index>?
        var i = lineRange.lowerBound

        // i always the beginning of a line fragment, so downstream is the appropriate affinity, but if the
        // line fragment is empty (i.e. we're at an empty last line), we need to use upstream affinity to find
        // the range, which will be i..<i.
        while let r = lineFragmentRange(containing: i, affinity: i == string.endIndex ? .upstream : .downstream) {
            if r.contains(index) || (r.upperBound == index && affinity == .upstream) {
                range = r
                break
            }

            y += Self.lineHeight
            i = r.upperBound
        }

        guard let range else {
            return .zero
        }

        let offsetInFrag = string.distance(from: range.lowerBound, to: index)
        let x = CGFloat(offsetInFrag)*Self.charWidth

        return CGPoint(x: x, y: y)
    }

    func lineRangeAndVerticalOffset(forCharacterAt index: String.Index) -> (Range<String.Index>, CGFloat) {
        let lineStart = self.index(roundingDownToLine: index)
        let lineEnd = self.index(afterLine: lineStart, clampedTo: string.endIndex)

        var y: CGFloat = 0
        var i = string.startIndex
        while let r = lineFragmentRange(containing: i, affinity: .downstream) {
            if r.contains(lineStart) {
                break
            }

            y += Self.lineHeight
            i = r.upperBound
        }

        return (lineStart..<lineEnd, y)
    }
}

// MARK: - Sanity checks for SimpleSelectionDataSource

final class SimpleSelectionDataSourceTests: XCTestCase {
    // MARK: lineFragmentRange(containing:affinity:)

    func testLineFragmentRangesEmptyBuffer() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerFrag: 10)

        let r0 = dataSource.lineFragmentRange(containing: s.startIndex, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: s.startIndex, affinity: .downstream)

        XCTAssertEqual(0..<0, intRange(r0, in: s))
        XCTAssertNil(r1)
    }

    func testLineFragmentRangesStartOfFragsDownstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let dataSource = SimpleSelectionDataSource(string: s, charsPerFrag: charsPerFrag)

        let start0 = s.index(s.startIndex, offsetBy: 0*charsPerFrag)
        let start1 = s.index(s.startIndex, offsetBy: 1*charsPerFrag)
        let start2 = s.index(s.startIndex, offsetBy: 2*charsPerFrag)
        let start3 = s.index(s.startIndex, offsetBy: 3*charsPerFrag)
        let start4 = s.index(s.startIndex, offsetBy: 4*charsPerFrag)

        let r0 = dataSource.lineFragmentRange(containing: start0, affinity: .downstream)!
        let r1 = dataSource.lineFragmentRange(containing: start1, affinity: .downstream)!
        let r2 = dataSource.lineFragmentRange(containing: start2, affinity: .downstream)!
        let r3 = dataSource.lineFragmentRange(containing: start3, affinity: .downstream)!
        let r4 = dataSource.lineFragmentRange(containing: start4, affinity: .downstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: s))
        XCTAssertEqual(10..<20, intRange(r1, in: s))
        XCTAssertEqual(20..<30, intRange(r2, in: s))
        XCTAssertEqual(30..<40, intRange(r3, in: s))
        XCTAssertEqual(40..<42, intRange(r4, in: s))
    }

    func testLineFragmentRangesStartOfFragsUpstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let dataSource = SimpleSelectionDataSource(string: s, charsPerFrag: charsPerFrag)

        let start0 = s.index(s.startIndex, offsetBy: 0*charsPerFrag)
        let start1 = s.index(s.startIndex, offsetBy: 1*charsPerFrag)
        let start2 = s.index(s.startIndex, offsetBy: 2*charsPerFrag)
        let start3 = s.index(s.startIndex, offsetBy: 3*charsPerFrag)
        let start4 = s.index(s.startIndex, offsetBy: 4*charsPerFrag)

        let r0 = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: start2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: start3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: start4, affinity: .upstream)!

        XCTAssertEqual(0..<10, intRange(r0, in: s)) // beginning of line matches .upstream or .downstream
        XCTAssertEqual(0..<10, intRange(r1, in: s))
        XCTAssertEqual(10..<20, intRange(r2, in: s))
        XCTAssertEqual(20..<30, intRange(r3, in: s))
        XCTAssertEqual(30..<40, intRange(r4, in: s))
    }

    func testLineFragmentRangesMiddleOfFragsDownstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: charsPerFrag)

        let i0 = string.index(string.startIndex, offsetBy: 0*charsPerFrag + 1)
        let i1 = string.index(string.startIndex, offsetBy: 1*charsPerFrag + 1)
        let i2 = string.index(string.startIndex, offsetBy: 2*charsPerFrag + 1)
        let i3 = string.index(string.startIndex, offsetBy: 3*charsPerFrag + 1)
        let i4 = string.index(string.startIndex, offsetBy: 4*charsPerFrag + 1)

        let r0 = dataSource.lineFragmentRange(containing: i0, affinity: .downstream)!
        let r1 = dataSource.lineFragmentRange(containing: i1, affinity: .downstream)!
        let r2 = dataSource.lineFragmentRange(containing: i2, affinity: .downstream)!
        let r3 = dataSource.lineFragmentRange(containing: i3, affinity: .downstream)!
        let r4 = dataSource.lineFragmentRange(containing: i4, affinity: .downstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: string))
        XCTAssertEqual(10..<20, intRange(r1, in: string))
        XCTAssertEqual(20..<30, intRange(r2, in: string))
        XCTAssertEqual(30..<40, intRange(r3, in: string))
        XCTAssertEqual(40..<42, intRange(r4, in: string))
    }

    func testLineFragmentRangesMiddleOfFragsUpstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)

        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: charsPerFrag)

        let i0 = string.index(string.startIndex, offsetBy: 0*charsPerFrag + 1)
        let i1 = string.index(string.startIndex, offsetBy: 1*charsPerFrag + 1)
        let i2 = string.index(string.startIndex, offsetBy: 2*charsPerFrag + 1)
        let i3 = string.index(string.startIndex, offsetBy: 3*charsPerFrag + 1)
        let i4 = string.index(string.startIndex, offsetBy: 4*charsPerFrag + 1)

        let r0 = dataSource.lineFragmentRange(containing: i0, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: i1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: i2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: i3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: i4, affinity: .upstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: string))
        XCTAssertEqual(10..<20, intRange(r1, in: string))
        XCTAssertEqual(20..<30, intRange(r2, in: string))
        XCTAssertEqual(30..<40, intRange(r3, in: string))
        XCTAssertEqual(40..<42, intRange(r4, in: string))
    }

    func testLineFragmentRangesEndOfFragsDownstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)

        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: charsPerFrag)

        let end0 = string.index(string.startIndex, offsetBy: 0*charsPerFrag + 10)
        let end1 = string.index(string.startIndex, offsetBy: 1*charsPerFrag + 10)
        let end2 = string.index(string.startIndex, offsetBy: 2*charsPerFrag + 10)
        let end3 = string.index(string.startIndex, offsetBy: 3*charsPerFrag + 10)
        let end4 = string.index(string.startIndex, offsetBy: 4*charsPerFrag + 2)

        let r0 = dataSource.lineFragmentRange(containing: end0, affinity: .downstream)!
        let r1 = dataSource.lineFragmentRange(containing: end1, affinity: .downstream)!
        let r2 = dataSource.lineFragmentRange(containing: end2, affinity: .downstream)!
        let r3 = dataSource.lineFragmentRange(containing: end3, affinity: .downstream)!
        let r4 = dataSource.lineFragmentRange(containing: end4, affinity: .downstream)

        XCTAssertEqual(10..<20,  intRange(r0, in: string))
        XCTAssertEqual(20..<30, intRange(r1, in: string))
        XCTAssertEqual(30..<40, intRange(r2, in: string))
        XCTAssertEqual(40..<42, intRange(r3, in: string))
        XCTAssertNil(r4)
    }

    func testLineFragmentRangesEndOfFragsUpstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)

        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: charsPerFrag)

        let end0 = string.index(string.startIndex, offsetBy: 0*charsPerFrag + 10)
        let end1 = string.index(string.startIndex, offsetBy: 1*charsPerFrag + 10)
        let end2 = string.index(string.startIndex, offsetBy: 2*charsPerFrag + 10)
        let end3 = string.index(string.startIndex, offsetBy: 3*charsPerFrag + 10)
        let end4 = string.index(string.startIndex, offsetBy: 4*charsPerFrag + 2)

        let r0 = dataSource.lineFragmentRange(containing: end0, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: end1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: end2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: end3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: end4, affinity: .upstream)!

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

        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: charsPerFrag)

        // First line: a single fragment that takes up less than the entire width.
        let start0 = string.index(string.startIndex, offsetBy: 0)
        var r = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)!
        XCTAssertEqual(0..<6, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: start0, affinity: .downstream)!
        XCTAssertEqual(0..<6, intRange(r, in: string))

        // between "o" and "\n"
        let last0 = string.index(string.startIndex, offsetBy: 5)
        r = dataSource.lineFragmentRange(containing: last0, affinity: .upstream)!
        XCTAssertEqual(0..<6, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: last0, affinity: .downstream)!
        XCTAssertEqual(0..<6, intRange(r, in: string))


        // Second line: a fragment that takes up the entire width and ends in a newline.
        let start1 = string.index(string.startIndex, offsetBy: 6)
        r = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        XCTAssertEqual(6..<17, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: start1, affinity: .downstream)!
        XCTAssertEqual(6..<17, intRange(r, in: string))

        // between "9" and "\n"
        let last1 = string.index(string.startIndex, offsetBy: 16)
        r = dataSource.lineFragmentRange(containing: last1, affinity: .upstream)!
        XCTAssertEqual(6..<17, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: last1, affinity: .downstream)!
        XCTAssertEqual(6..<17, intRange(r, in: string))


        // Third line wraps, with two fragments
        //
        // First fragment
        let start2 = string.index(string.startIndex, offsetBy: 17)
        r = dataSource.lineFragmentRange(containing: start2, affinity: .upstream)!
        XCTAssertEqual(17..<27, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: start2, affinity: .downstream)!
        XCTAssertEqual(17..<27, intRange(r, in: string))

        // between "9" and "w"
        let boundary2 = string.index(string.startIndex, offsetBy: 27)
        r = dataSource.lineFragmentRange(containing: boundary2, affinity: .upstream)!
        XCTAssertEqual(17..<27, intRange(r, in: string))

        // Second fragment
        r = dataSource.lineFragmentRange(containing: boundary2, affinity: .downstream)!
        XCTAssertEqual(27..<32, intRange(r, in: string))

        // between "w" and "\n"
        let last2 = string.index(string.startIndex, offsetBy: 31)
        r = dataSource.lineFragmentRange(containing: last2, affinity: .upstream)!
        XCTAssertEqual(27..<32, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: last2, affinity: .downstream)!
        XCTAssertEqual(27..<32, intRange(r, in: string))


        // Fourth line
        let start3 = string.index(string.startIndex, offsetBy: 32)
        r = dataSource.lineFragmentRange(containing: start3, affinity: .upstream)!
        XCTAssertEqual(32..<37, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: start3, affinity: .downstream)!
        XCTAssertEqual(32..<37, intRange(r, in: string))

        // At the end of the buffer
        let last3 = string.index(string.startIndex, offsetBy: 37)
        XCTAssertEqual(last3, string.endIndex)

        r = dataSource.lineFragmentRange(containing: last3, affinity: .upstream)!
        XCTAssertEqual(32..<37, intRange(r, in: string))

        XCTAssertNil(dataSource.lineFragmentRange(containing: last3, affinity: .downstream))
    }

    func testLineFragmentRangesEndingInNewline() {
        // 2 lines, 3 line fragments
        let charsPerFrag = 10

        let string = """
        0123456789wrap

        """

        XCTAssertEqual(2, string.filter { $0 == "\n" }.count + 1)
        XCTAssertEqual("\n", string.last)

        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: charsPerFrag)

        // First line: two fragments
        let start0 = string.index(string.startIndex, offsetBy: 0)
        var r = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)!
        XCTAssertEqual(0..<10, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: start0, affinity: .downstream)!
        XCTAssertEqual(0..<10, intRange(r, in: string))

        // between "9" and "w"
        let boundary0 = string.index(string.startIndex, offsetBy: 10)
        r = dataSource.lineFragmentRange(containing: boundary0, affinity: .upstream)!
        XCTAssertEqual(0..<10, intRange(r, in: string))

        // Second fragment
        r = dataSource.lineFragmentRange(containing: boundary0, affinity: .downstream)!
        XCTAssertEqual(10..<15, intRange(r, in: string))

        // between "w" and "\n"
        let last0 = string.index(string.startIndex, offsetBy: 14)
        r = dataSource.lineFragmentRange(containing: last0, affinity: .upstream)!
        XCTAssertEqual(10..<15, intRange(r, in: string))

        r = dataSource.lineFragmentRange(containing: last0, affinity: .downstream)!
        XCTAssertEqual(10..<15, intRange(r, in: string))

        // Second line, a single empty fragment
        let start1 = string.index(string.startIndex, offsetBy: 15)
        r = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        XCTAssertEqual(15..<15, intRange(r, in: string))

        XCTAssertNil(dataSource.lineFragmentRange(containing: start1, affinity: .downstream))
    }

    func intRange(_ r: Range<String.Index>, in string: String) -> Range<Int> {
        string.utf8.distance(from: string.startIndex, to: r.lowerBound)..<string.utf8.distance(from: string.startIndex, to: r.upperBound)
    }


    // MARK: index(forHorizontalOffset:inLineFragmentContaining:affinity:)

    func testIndexForHorizontalOffsetEmptyBuffer() {
        let string = ""
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // Only upstream finds an index because the buffer is empty. No matter
        // how far to the right we go, we always get string.startIndex.

        var i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 4.001, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 4.001, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertNil(i)
    }

    func testIndexForHorizontalOffsetNoTrailingNewline() {
        let string = "abc\ndef"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        var i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 0), i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 0), i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 1), i)

        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 1), i)

        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 2), i)
        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 2), i)

        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 2), i)
        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 2), i)

        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 3), i)

        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 3), i)

        // can't click past the end of the "\n" in line 1

        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 3), i)

        i = dataSource.index(forHorizontalOffset: 28.001, inLineFragmentContaining: string.startIndex, affinity: .upstream)
        XCTAssertEqual(string.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 28.001, inLineFragmentContaining: string.startIndex, affinity: .downstream)
        XCTAssertEqual(string.index(at: 3), i)

        // next line

        let line2Start = string.index(string.startIndex, offsetBy: 4)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 4), i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 4), i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 5), i)

        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 5), i)

        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 6), i)
        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 6), i)

        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 6), i)
        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 6), i)

        // end of buffer

        i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.endIndex, i)

        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.endIndex, i)
    }

    func testIndexForHorizontalOffsetTrailingNewline() {
        let string = "abc\ndef\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // can't click past the end of the "\n" in line 2
        let line2Start = string.index(string.startIndex, offsetBy: 4)
        var i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 7), i)
        i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 7), i)

        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(string.index(at: 7), i)
        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(string.index(at: 7), i)

        // end of buffer - downstream is nil because line3start == endIndex

        let line3start = string.index(string.startIndex, offsetBy: 8)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line3start, affinity: .upstream)
        XCTAssertEqual(string.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line3start, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 50, inLineFragmentContaining: line3start, affinity: .upstream)
        XCTAssertEqual(string.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 50, inLineFragmentContaining: line3start, affinity: .downstream)
        XCTAssertNil(i)
    }

    func testIndexForHorizontalOffsetWithWrapping() {
        let string = """
        0123456789wrap
        """

        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        let boundary = string.index(string.startIndex, offsetBy: 10)

        var i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 10), i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 10), i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 11), i)

        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 11), i)

        // jump forward a bit to just before the wrap

        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 13), i)

        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 13), i)

        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 14), i)

        i = dataSource.index(forHorizontalOffset: 35.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 35.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 14), i)

        // can't click past the end of the "\n" in line 2

        i = dataSource.index(forHorizontalOffset: 36, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 36, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 14), i)

        i = dataSource.index(forHorizontalOffset: 36.001, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 36.001, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 14), i)

        // end of the first fragment

        i = dataSource.index(forHorizontalOffset: 75.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 9), i)
        i = dataSource.index(forHorizontalOffset: 75.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 14), i)

        i = dataSource.index(forHorizontalOffset: 76, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(string.index(at: 10), i)
        i = dataSource.index(forHorizontalOffset: 76, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(string.index(at: 14), i)
    }


    // MARK: point(forCharacterAt:affinity:)

    func testPointForCharacterAtEmptyBuffer() {
        let string = ""
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // Upstream results are .zero because the fragment contains no characters.
        // Downstream results are .zero because there's no fragment.

        var p = dataSource.point(forCharacterAt: string.startIndex, affinity: .upstream)
        XCTAssertEqual(.zero, p)
        p = dataSource.point(forCharacterAt: string.startIndex, affinity: .downstream)
        XCTAssertEqual(.zero, p)

        p = dataSource.point(forCharacterAt: string.endIndex, affinity: .upstream)
        XCTAssertEqual(.zero, p)
        p = dataSource.point(forCharacterAt: string.endIndex, affinity: .downstream)
        XCTAssertEqual(.zero, p)
    }

    func testPointForCharacterAtNoTrailingNewline() {
        let string = "abc\ndef"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        var p = dataSource.point(forCharacterAt: string.index(at: 0), affinity: .upstream)
        XCTAssertEqual(.zero, p)
        p = dataSource.point(forCharacterAt: string.index(at: 0), affinity: .downstream)
        XCTAssertEqual(.zero, p)

        p = dataSource.point(forCharacterAt: string.index(at: 3), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 24, y: 0), p)
        p = dataSource.point(forCharacterAt: string.index(at: 3), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 24, y: 0), p)

        p = dataSource.point(forCharacterAt: string.index(at: 4), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 0, y: 14), p)
        p = dataSource.point(forCharacterAt: string.index(at: 4), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 0, y: 14), p)

        p = dataSource.point(forCharacterAt: string.index(at: 6), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 16, y: 14), p)
        p = dataSource.point(forCharacterAt: string.index(at: 6), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 16, y: 14), p)

        p = dataSource.point(forCharacterAt: string.index(at: 7), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 24, y: 14), p)
        p = dataSource.point(forCharacterAt: string.index(at: 7), affinity: .downstream)
        XCTAssertEqual(.zero, p)
    }

    func testPointForCharacterAtTrailingNewline() {
        let string = "abc\ndef\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // let's start right before the second newline. We tested everything else above.

        var p = dataSource.point(forCharacterAt: string.index(at: 7), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 24, y: 14), p)
        p = dataSource.point(forCharacterAt: string.index(at: 7), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 24, y: 14), p)

        p = dataSource.point(forCharacterAt: string.index(at: 8), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 0, y: 28), p)
        p = dataSource.point(forCharacterAt: string.index(at: 8), affinity: .downstream)
        XCTAssertEqual(.zero, p)
    }

    func testPointForCharacterAtWrappedLine() {
        let string = """
        0123456789wrap
        """
        let dataSource = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        var p = dataSource.point(forCharacterAt: string.index(at: 10), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 80, y: 0), p)
        p = dataSource.point(forCharacterAt: string.index(at: 10), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 0, y: 14), p)

        p = dataSource.point(forCharacterAt: string.index(at: 14), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 32, y: 14), p)
        p = dataSource.point(forCharacterAt: string.index(at: 14), affinity: .downstream)
        XCTAssertEqual(.zero, p)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        var s = Selection(caretAt: string.index(at: 0), affinity: .downstream)
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

    func testMoveRightFromSelection() {
        let string = "foo bar baz"
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "oo b"
        var s = Selection(anchor: string.index(at: 1), head: string.index(at: 5))
        // the caret moves to the end of the selection
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)

        // it doesn't matter if the selection is reversed
        s = Selection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)

        // select "baz"
        s = Selection(anchor: string.index(at: 8), head: string.index(at: 11))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // reverse
        s = Selection(anchor: string.index(at: 11), head: string.index(at: 8))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // select all
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 11))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // reverse
        s = Selection(anchor: string.index(at: 11), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)
    }

    func testMoveLeftFromSelection() {
        let string = "foo bar baz"
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "oo b"
        var s = Selection(anchor: string.index(at: 1), head: string.index(at: 5))
        // the caret moves to the beginning of the selection
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // select "foo"
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 3))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse
        s = Selection(anchor: string.index(at: 3), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // select all
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 11))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse
        s = Selection(anchor: string.index(at: 11), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveVertically() {
        let string = """
        qux
        0123456789abcdefghijwrap
        xyz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at "1"
        var s = Selection(caretAt: string.index(at: 5), affinity: .downstream)
        s = moveAndAssert(s, direction: .up, caret: "u", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "q", affinity: .downstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .up, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "0", affinity: .downstream, dataSource: d)

        // caret at "1"
        s = Selection(caretAt: string.index(at: 5), affinity: .downstream)
        s = moveAndAssert(s, direction: .down, caret: "b", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "r", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "y", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .down, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "p", affinity: .downstream, dataSource: d)


        // caret at "5"
        s = Selection(caretAt: string.index(at: 9), affinity: .downstream)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        var s = Selection(caretAt: string.index(at: 0), affinity: .downstream)

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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "ello, w"
        var s = Selection(anchor: string.index(at: 3), head: string.index(at: 10))
        // the caret moves to the end of "world"
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 10), head: string.index(at: 3))
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)

        // select "(a test"
        s = Selection(anchor: string.index(at: 24), head: string.index(at: 31))
        // the caret moves to the end of the buffer
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 31), head: string.index(at: 24))
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // select all
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 33))
        // the caret moves to the end of the buffer
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 33), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .rightWord, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveLeftWordFromSelection() {
        let string = "  hello, world; this is (a test) "
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "lo, w"
        var s = Selection(anchor: string.index(at: 5), head: string.index(at: 10))
        // the caret moves to the beginning of "hello"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 10), head: string.index(at: 5))
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)

        // select "(a test"
        s = Selection(anchor: string.index(at: 24), head: string.index(at: 31))
        // the caret moves to the beginning of "is"
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 31), head: string.index(at: 24))
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)

        // select all
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 33))
        // the caret moves to the beginning of the buffer
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: string.index(at: 33), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .leftWord, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveLineSingleFragments() {
        let string = "foo bar\nbaz qux\n"
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // between "a" and "r"
        var s = Selection(caretAt: string.index(at: 6), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // moving again is a no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)

        // from end to beginning
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = Selection(caretAt: string.index(at: 2), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)



        // between "r" and "\n"
        s = Selection(caretAt: string.index(at: 7), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // between "z" and " "
        s = Selection(caretAt: string.index(at: 11), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 8), affinity: .downstream, dataSource: d)
        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 8), affinity: .downstream, dataSource: d)

        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 15), affinity: .downstream, dataSource: d)
        // no-op
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 15), affinity: .downstream, dataSource: d)

        // end of buffer
        s = Selection(caretAt: string.index(at: 16), affinity: .upstream)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 16), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 16), affinity: .upstream, dataSource: d)
    }

    func testMoveLineMultipleFragments() {
        let string = """
        0123456789abcdefghijwrap
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // between "0" and "1"
        var s = Selection(caretAt: string.index(at: 1), affinity: .downstream)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // reset
        s = Selection(caretAt: string.index(at: 1), affinity: .downstream)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // between "a" and "b"
        s = Selection(caretAt: string.index(at: 11), affinity: .downstream)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // reset
        s = Selection(caretAt: string.index(at: 11), affinity: .downstream)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // between "w" and "r"
        s = Selection(caretAt: string.index(at: 21), affinity: .downstream)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .upstream, dataSource: d)

        // reset
        s = Selection(caretAt: string.index(at: 21), affinity: .downstream)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // upstream between "9" and "a"
        var s = Selection(caretAt: string.index(at: 10), affinity: .upstream)
        // left
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // reset
        s = Selection(caretAt: string.index(at: 10), affinity: .upstream)
        // moving right is a no-op
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // downstream between "9" and "a"
        s = Selection(caretAt: string.index(at: 10), affinity: .downstream)
        // right
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)
        // reset
        s = Selection(caretAt: string.index(at: 10), affinity: .downstream)
        // moving left is a no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
    }

    func testMoveLineFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        bar
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "0123"
        var s = Selection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // select "1234"
        s = Selection(anchor: string.index(at: 1), head: string.index(at: 5))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 1), head: string.index(at: 5))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 5), head: string.index(at: 1))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // select "9abc"
        s = Selection(anchor: string.index(at: 9), head: string.index(at: 13))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 9), head: string.index(at: 13))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 13), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 13), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // select "9abcdefghijw"
        s = Selection(anchor: string.index(at: 9), head: string.index(at: 21))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 9), head: string.index(at: 21))
        // downstream because we're before a hard line break
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 21), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 21), head: string.index(at: 9))
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "ijwr"
        s = Selection(anchor: string.index(at: 18), head: string.index(at: 22))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 18), head: string.index(at: 22))
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 22), head: string.index(at: 18))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 22), head: string.index(at: 18))
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "ap\nba"
        s = Selection(anchor: string.index(at: 22), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 22), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 27), head: string.index(at: 22))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 27), head: string.index(at: 22))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // select "a"
        s = Selection(anchor: string.index(at: 26), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 26), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 27), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 27), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)
    }

    func testMoveBeginningOfParagraph() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // no-ops
        var s = Selection(caretAt: string.index(at: 0), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 24), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // no-op around "baz"
        s = Selection(caretAt: string.index(at: 30), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 30), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 33), affinity: .upstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // no-op in blank line
        s = Selection(caretAt: string.index(at: 29), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 29), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 29), affinity: .downstream)

        // between "0" and "1"
        s = Selection(caretAt: string.index(at: 1), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 1), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "9" and "a" upstream
        s = Selection(caretAt: string.index(at: 10), affinity: .upstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 10), affinity: .upstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "9" and "a" downstream
        s = Selection(caretAt: string.index(at: 10), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 10), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "a" and "b"
        s = Selection(caretAt: string.index(at: 11), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 11), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "w" and "r"
        s = Selection(caretAt: string.index(at: 21), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 21), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = Selection(caretAt: string.index(at: 27), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 27), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // between "a" and "z"
        s = Selection(caretAt: string.index(at: 32), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 30), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 32), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveParagraphFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "0123"
        var s = Selection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 0), head: string.index(at: 4))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 4), head: string.index(at: 0))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "9abcdefghi"
        s = Selection(anchor: string.index(at: 9), head: string.index(at: 19))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 9), head: string.index(at: 19))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 19), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 19), head: string.index(at: 9))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "rap\nfo"
        s = Selection(anchor: string.index(at: 21), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 21), head: string.index(at: 27))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 27), head: string.index(at: 21))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 27), head: string.index(at: 21))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // select "o\n\nba"
        s = Selection(anchor: string.index(at: 26), head: string.index(at: 32))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 26), head: string.index(at: 32))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 32), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 32), head: string.index(at: 26))
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveDocument() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // no-ops
        var s = Selection(caretAt: string.index(at: 0), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 33), affinity: .upstream)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // between "f" and "o"
        s = Selection(caretAt: string.index(at: 26), affinity: .downstream)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(caretAt: string.index(at: 26), affinity: .downstream)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveDocumentFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // select "ijwrap\nfoo\n\nb"
        var s = Selection(anchor: string.index(at: 18), head: string.index(at: 31))
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 18), head: string.index(at: 31))
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: string.index(at: 31), head: string.index(at: 18))
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = Selection(anchor: string.index(at: 31), head: string.index(at: 18))
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByCharacter() {
        let string = "Hello, world!"
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at "!"
        var s = Selection(caretAt: string.index(at: 12), affinity: .downstream)
        s = extendAndAssert(s, direction: .right, selected: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .right, dataSource: d)
        s = extendAndAssert(s, direction: .left, caret: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, selected: "d", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, caret: "!", affinity: .downstream, dataSource: d)

        // caret at "e"
        s = Selection(caretAt: string.index(at: 1), affinity: .downstream)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at "b"
        var s = Selection(caretAt: string.index(at: 15), affinity: .downstream)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at "a"
        var s = Selection(caretAt: string.index(at: 7), affinity: .downstream)
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

    func testExtendSelectionByLineSoftWrap() {
        let string = "Hello, world!"
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10) // Wraps after "r"

        // caret at "o"
        var s = Selection(caretAt: string.index(at: 8), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfLine, selected: "or", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "Hello, wor", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)

        // caret at "o"
        s = Selection(caretAt: string.index(at: 8), affinity: .downstream)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "Hello, w", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .endOfLine, selected: "Hello, wor", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
    }

    func testExtendSelectionByLineHardWrap() {
        let string = "foo\nbar\nqux"
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at first "a"
        var s = Selection(caretAt: string.index(at: 5), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfLine, selected: "ar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "bar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)

        // caret at first "a"
        s = Selection(caretAt: string.index(at: 5), affinity: .downstream)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at "5"
        var s = Selection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfParagraph, selected: "56789wrap", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfParagraph, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfParagraph, selected: "0123456789wrap", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfParagraph, dataSource: d)

        // caret at "5"
        s = Selection(caretAt: string.index(at: 9), affinity: .downstream)
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
        let d = SimpleSelectionDataSource(string: string, charsPerFrag: 10)

        // caret at "5"
        var s = Selection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .endOfDocument, selected: "56789wrap\nbar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfDocument, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfDocument, selected: "foo\n0123456789wrap\nbar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfDocument, dataSource: d)

        // caret at "5"
        s = Selection(caretAt: string.index(at: 9), affinity: .downstream)
        s = extendAndAssert(s, direction: .beginningOfDocument, selected: "foo\n01234", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfDocument, dataSource: d)
        s = extendAndAssert(s, direction: .endOfDocument, selected: "foo\n0123456789wrap\nbar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfDocument, dataSource: d)
    }

    func extendAndAssert(_ s: Selection<String.Index>, direction: SelectionMovement, caret c: Character, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection<String.Index>(fromExisting: s, movement: direction, extending: true, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssert(_ s: Selection<String.Index>, direction: SelectionMovement, selected string: String, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection<String.Index>(fromExisting: s, movement: direction, extending: true, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssertNoop(_ s: Selection<String.Index>, direction: SelectionMovement, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection<String.Index>(fromExisting: s, movement: direction, extending: true, dataSource: dataSource)
        XCTAssertEqual(s, s2, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: Selection<String.Index>, direction: SelectionMovement, caret c: Character, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection<String.Index>(fromExisting: s, movement: direction, extending: false, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: Selection<String.Index>, direction: SelectionMovement, selected string: String, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection(fromExisting: s, movement: direction, extending: false, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssertNoop(_ s: Selection<String.Index>, direction: SelectionMovement, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection(fromExisting: s, movement: direction, extending: false, dataSource: dataSource)
        XCTAssertEqual(s, s2, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: Selection<String.Index>, direction: SelectionMovement, caretAt caret: String.Index, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection<String.Index> {
        let s2 = Selection<String.Index>(fromExisting: s, movement: direction, extending: false, dataSource: dataSource)
        assert(selection: s2, hasCaret: caret, andSelectionAffinity: affinity, file: file, line: line)
        return s2
    }

    func assert(selection: Selection<String.Index>, hasCaretBefore c: Character, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(selection.isCaret, "selection is not a caret", file: file, line: line)
        XCTAssertEqual(dataSource.string[selection.range.lowerBound], c, "caret is not at '\(c)'", file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }

    func assert(selection: Selection<String.Index>, hasRangeCovering string: String, affinity: SelectionAffinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) {
        let range = selection.range
        XCTAssert(selection.isRange, "selection is not a range", file: file, line: line)
        XCTAssertEqual(String(dataSource.string[range]), string, "selection does not contain \"\(string)\"", file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }

    func assert(selection: Selection<String.Index>, hasCaret caret: String.Index, andSelectionAffinity affinity: SelectionAffinity, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(selection.caret, caret, file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }
}
