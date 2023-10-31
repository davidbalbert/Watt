//
//  SelectionTests.swift
//  WattTests
//
//  Created by David Albert on 10/22/23.
//

import XCTest
@testable import Watt

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
    let buffer: Buffer

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

extension SimpleSelectionDataSource: SelectionLayoutDataSource {
    func lineFragmentRange(containing index: Buffer.Index, affinity: Selection.Affinity) -> Range<Buffer.Index>? {
        if index == buffer.endIndex && affinity != .upstream {
            return nil
        }

        let lineStart = buffer.lines.index(roundingDown: index)
        let lineEnd = buffer.lines.index(after: lineStart, clampedTo: buffer.endIndex)
        let lineLen = buffer.characters.distance(from: lineStart, to: lineEnd)
        let offsetInLine = buffer.characters.distance(from: lineStart, to: index)

        // A trailing "\n", which is present in all but the last line, doesn't
        // contribute to the number of fragments a line takes up.
        let visualLineLen = lineEnd == buffer.endIndex ? lineLen : lineLen - 1
        let nfrags = max(1, Int(ceil(Double(visualLineLen) / Double(charsPerFrag))))

        let onTrailingBoundary = offsetInLine > 0 && offsetInLine % charsPerFrag == 0
        let beforeTrailingNewline = lineEnd < buffer.endIndex && offsetInLine == lineLen - 1

        let fragIndex: Int
        if onTrailingBoundary && (affinity == .upstream || beforeTrailingNewline) {
            fragIndex = (offsetInLine/charsPerFrag) - 1
        } else {
            fragIndex = offsetInLine/charsPerFrag
        }

        let inLastFrag = fragIndex == nfrags - 1

        let fragOffset = fragIndex * charsPerFrag
        let fragLen = inLastFrag ? lineLen - fragOffset : charsPerFrag
        let fragStart = buffer.index(lineStart, offsetBy: fragOffset)
        let fragEnd = buffer.index(fragStart, offsetBy: fragLen)

        return fragStart..<fragEnd
    }

    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: Buffer.Index, affinity: Selection.Affinity) -> Buffer.Index? {
        guard let fragRange = lineFragmentRange(containing: index, affinity: affinity) else {
            return nil
        }

        let offsetInFrag = Int(round(xOffset/Self.charWidth))

        let hasHardBreak = buffer[fragRange].characters.last == "\n"

        var i = buffer.characters.index(fragRange.lowerBound, offsetBy: offsetInFrag, clampedTo: fragRange.upperBound)
        if i == fragRange.upperBound && hasHardBreak {
            i = buffer.index(before: i)
        }

        return i
    }

    func point(forCharacterAt index: Buffer.Index, affinity: Selection.Affinity) -> CGPoint {
        var (lineRange, y) = lineRangeAndVerticalOffset(forCharacterAt: index)

        // we iterate rather than just asking for the line fragment range containing index
        // so that we can calculate y in text container coordinates.
        var range: Range<Buffer.Index>?
        var i = lineRange.lowerBound
        while let r = lineFragmentRange(containing: i, affinity: affinity) {
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

        let offsetInFrag = buffer.characters.distance(from: range.lowerBound, to: index)
        let x = CGFloat(offsetInFrag)*Self.charWidth

        return CGPoint(x: x, y: y)
    }

    func lineRangeAndVerticalOffset(forCharacterAt index: Buffer.Index) -> (Range<Buffer.Index>, CGFloat) {
        let lineStart = buffer.lines.index(roundingDown: index)
        let lineEnd = buffer.lines.index(after: lineStart, clampedTo: buffer.endIndex)

        var y: CGFloat = 0
        var i = buffer.startIndex
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
        let buffer = Buffer("", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        let r0 = dataSource.lineFragmentRange(containing: buffer.startIndex, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: buffer.startIndex, affinity: .downstream)

        XCTAssertEqual(0..<0, intRange(r0, in: buffer))
        XCTAssertNil(r1)
    }

    func testLineFragmentRangesStartOfFragsDownstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let buffer = Buffer(s, language: .plainText)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        let start0 = buffer.index(buffer.startIndex, offsetBy: 0*charsPerFrag)
        let start1 = buffer.index(buffer.startIndex, offsetBy: 1*charsPerFrag)
        let start2 = buffer.index(buffer.startIndex, offsetBy: 2*charsPerFrag)
        let start3 = buffer.index(buffer.startIndex, offsetBy: 3*charsPerFrag)
        let start4 = buffer.index(buffer.startIndex, offsetBy: 4*charsPerFrag)

        let r0 = dataSource.lineFragmentRange(containing: start0, affinity: .downstream)!
        let r1 = dataSource.lineFragmentRange(containing: start1, affinity: .downstream)!
        let r2 = dataSource.lineFragmentRange(containing: start2, affinity: .downstream)!
        let r3 = dataSource.lineFragmentRange(containing: start3, affinity: .downstream)!
        let r4 = dataSource.lineFragmentRange(containing: start4, affinity: .downstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: buffer))
        XCTAssertEqual(10..<20, intRange(r1, in: buffer))
        XCTAssertEqual(20..<30, intRange(r2, in: buffer))
        XCTAssertEqual(30..<40, intRange(r3, in: buffer))
        XCTAssertEqual(40..<42, intRange(r4, in: buffer))
    }

    func testLineFragmentRangesStartOfFragsUpstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let buffer = Buffer(s, language: .plainText)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        let start0 = buffer.index(buffer.startIndex, offsetBy: 0*charsPerFrag)
        let start1 = buffer.index(buffer.startIndex, offsetBy: 1*charsPerFrag)
        let start2 = buffer.index(buffer.startIndex, offsetBy: 2*charsPerFrag)
        let start3 = buffer.index(buffer.startIndex, offsetBy: 3*charsPerFrag)
        let start4 = buffer.index(buffer.startIndex, offsetBy: 4*charsPerFrag)

        let r0 = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: start2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: start3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: start4, affinity: .upstream)!

        XCTAssertEqual(0..<10, intRange(r0, in: buffer)) // beginning of line matches .upstream or .downstream
        XCTAssertEqual(0..<10, intRange(r1, in: buffer))
        XCTAssertEqual(10..<20, intRange(r2, in: buffer))
        XCTAssertEqual(20..<30, intRange(r3, in: buffer))
        XCTAssertEqual(30..<40, intRange(r4, in: buffer))
    }

    func testLineFragmentRangesMiddleOfFragsDownstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let buffer = Buffer(s, language: .plainText)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        let i0 = buffer.index(buffer.startIndex, offsetBy: 0*charsPerFrag + 1)
        let i1 = buffer.index(buffer.startIndex, offsetBy: 1*charsPerFrag + 1)
        let i2 = buffer.index(buffer.startIndex, offsetBy: 2*charsPerFrag + 1)
        let i3 = buffer.index(buffer.startIndex, offsetBy: 3*charsPerFrag + 1)
        let i4 = buffer.index(buffer.startIndex, offsetBy: 4*charsPerFrag + 1)

        let r0 = dataSource.lineFragmentRange(containing: i0, affinity: .downstream)!
        let r1 = dataSource.lineFragmentRange(containing: i1, affinity: .downstream)!
        let r2 = dataSource.lineFragmentRange(containing: i2, affinity: .downstream)!
        let r3 = dataSource.lineFragmentRange(containing: i3, affinity: .downstream)!
        let r4 = dataSource.lineFragmentRange(containing: i4, affinity: .downstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: buffer))
        XCTAssertEqual(10..<20, intRange(r1, in: buffer))
        XCTAssertEqual(20..<30, intRange(r2, in: buffer))
        XCTAssertEqual(30..<40, intRange(r3, in: buffer))
        XCTAssertEqual(40..<42, intRange(r4, in: buffer))
    }

    func testLineFragmentRangesMiddleOfFragsUpstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let buffer = Buffer(s, language: .plainText)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        let i0 = buffer.index(buffer.startIndex, offsetBy: 0*charsPerFrag + 1)
        let i1 = buffer.index(buffer.startIndex, offsetBy: 1*charsPerFrag + 1)
        let i2 = buffer.index(buffer.startIndex, offsetBy: 2*charsPerFrag + 1)
        let i3 = buffer.index(buffer.startIndex, offsetBy: 3*charsPerFrag + 1)
        let i4 = buffer.index(buffer.startIndex, offsetBy: 4*charsPerFrag + 1)

        let r0 = dataSource.lineFragmentRange(containing: i0, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: i1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: i2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: i3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: i4, affinity: .upstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: buffer))
        XCTAssertEqual(10..<20, intRange(r1, in: buffer))
        XCTAssertEqual(20..<30, intRange(r2, in: buffer))
        XCTAssertEqual(30..<40, intRange(r3, in: buffer))
        XCTAssertEqual(40..<42, intRange(r4, in: buffer))
    }

    func testLineFragmentRangesEndOfFragsDownstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let buffer = Buffer(s, language: .plainText)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        let end0 = buffer.index(buffer.startIndex, offsetBy: 0*charsPerFrag + 10)
        let end1 = buffer.index(buffer.startIndex, offsetBy: 1*charsPerFrag + 10)
        let end2 = buffer.index(buffer.startIndex, offsetBy: 2*charsPerFrag + 10)
        let end3 = buffer.index(buffer.startIndex, offsetBy: 3*charsPerFrag + 10)
        let end4 = buffer.index(buffer.startIndex, offsetBy: 4*charsPerFrag + 2)

        let r0 = dataSource.lineFragmentRange(containing: end0, affinity: .downstream)!
        let r1 = dataSource.lineFragmentRange(containing: end1, affinity: .downstream)!
        let r2 = dataSource.lineFragmentRange(containing: end2, affinity: .downstream)!
        let r3 = dataSource.lineFragmentRange(containing: end3, affinity: .downstream)!
        let r4 = dataSource.lineFragmentRange(containing: end4, affinity: .downstream)

        XCTAssertEqual(10..<20,  intRange(r0, in: buffer))
        XCTAssertEqual(20..<30, intRange(r1, in: buffer))
        XCTAssertEqual(30..<40, intRange(r2, in: buffer))
        XCTAssertEqual(40..<42, intRange(r3, in: buffer))
        XCTAssertNil(r4)
    }

    func testLineFragmentRangesEndOfFragsUpstream() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let charsPerFrag = 10
        let s = String(repeating: "a", count: charsPerFrag*4 + 2)
        let buffer = Buffer(s, language: .plainText)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        let end0 = buffer.index(buffer.startIndex, offsetBy: 0*charsPerFrag + 10)
        let end1 = buffer.index(buffer.startIndex, offsetBy: 1*charsPerFrag + 10)
        let end2 = buffer.index(buffer.startIndex, offsetBy: 2*charsPerFrag + 10)
        let end3 = buffer.index(buffer.startIndex, offsetBy: 3*charsPerFrag + 10)
        let end4 = buffer.index(buffer.startIndex, offsetBy: 4*charsPerFrag + 2)

        let r0 = dataSource.lineFragmentRange(containing: end0, affinity: .upstream)!
        let r1 = dataSource.lineFragmentRange(containing: end1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: end2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: end3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: end4, affinity: .upstream)!

        XCTAssertEqual(0..<10,  intRange(r0, in: buffer))
        XCTAssertEqual(10..<20, intRange(r1, in: buffer))
        XCTAssertEqual(20..<30, intRange(r2, in: buffer))
        XCTAssertEqual(30..<40, intRange(r3, in: buffer))
        XCTAssertEqual(40..<42, intRange(r4, in: buffer))
    }

    func testLineFragmentRangesMultipleLines() {
        // 4 lines, 5 line fragments, no trailing newline
        let charsPerFrag = 10

        let s = """
        hello
        0123456789
        0123456789wrap
        world
        """

        let buffer = Buffer(s, language: .plainText)

        XCTAssertEqual(4, buffer.lines.count)
        XCTAssertNotEqual("\n", buffer.characters.last)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        // First line: a single fragment that takes up less than the entire width.
        let start0 = buffer.index(buffer.startIndex, offsetBy: 0)
        var r = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)!
        XCTAssertEqual(0..<6, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: start0, affinity: .downstream)!
        XCTAssertEqual(0..<6, intRange(r, in: buffer))

        // between "o" and "\n"
        let last0 = buffer.index(buffer.startIndex, offsetBy: 5)
        r = dataSource.lineFragmentRange(containing: last0, affinity: .upstream)!
        XCTAssertEqual(0..<6, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: last0, affinity: .downstream)!
        XCTAssertEqual(0..<6, intRange(r, in: buffer))


        // Second line: a fragment that takes up the entire width and ends in a newline.
        let start1 = buffer.index(buffer.startIndex, offsetBy: 6)
        r = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        XCTAssertEqual(6..<17, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: start1, affinity: .downstream)!
        XCTAssertEqual(6..<17, intRange(r, in: buffer))

        // between "9" and "\n"
        let last1 = buffer.index(buffer.startIndex, offsetBy: 16)
        r = dataSource.lineFragmentRange(containing: last1, affinity: .upstream)!
        XCTAssertEqual(6..<17, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: last1, affinity: .downstream)!
        XCTAssertEqual(6..<17, intRange(r, in: buffer))


        // Third line wraps, with two fragments
        //
        // First fragment
        let start2 = buffer.index(buffer.startIndex, offsetBy: 17)
        r = dataSource.lineFragmentRange(containing: start2, affinity: .upstream)!
        XCTAssertEqual(17..<27, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: start2, affinity: .downstream)!
        XCTAssertEqual(17..<27, intRange(r, in: buffer))

        // between "9" and "w"
        let boundary2 = buffer.index(buffer.startIndex, offsetBy: 27)
        r = dataSource.lineFragmentRange(containing: boundary2, affinity: .upstream)!
        XCTAssertEqual(17..<27, intRange(r, in: buffer))

        // Second fragment
        r = dataSource.lineFragmentRange(containing: boundary2, affinity: .downstream)!
        XCTAssertEqual(27..<32, intRange(r, in: buffer))
        
        // between "w" and "\n"
        let last2 = buffer.index(buffer.startIndex, offsetBy: 31)
        r = dataSource.lineFragmentRange(containing: last2, affinity: .upstream)!
        XCTAssertEqual(27..<32, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: last2, affinity: .downstream)!
        XCTAssertEqual(27..<32, intRange(r, in: buffer))


        // Fourth line
        let start3 = buffer.index(buffer.startIndex, offsetBy: 32)
        r = dataSource.lineFragmentRange(containing: start3, affinity: .upstream)!
        XCTAssertEqual(32..<37, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: start3, affinity: .downstream)!
        XCTAssertEqual(32..<37, intRange(r, in: buffer))

        // At the end of the buffer
        let last3 = buffer.index(buffer.startIndex, offsetBy: 37)
        XCTAssertEqual(last3, buffer.endIndex)

        r = dataSource.lineFragmentRange(containing: last3, affinity: .upstream)!
        XCTAssertEqual(32..<37, intRange(r, in: buffer))

        XCTAssertNil(dataSource.lineFragmentRange(containing: last3, affinity: .downstream))
    }

    func testLineFragmentRangesEndingInNewline() {
        // 2 lines, 3 line fragments
        let charsPerFrag = 10

        let s = """
        0123456789wrap

        """

        let buffer = Buffer(s, language: .plainText)

        XCTAssertEqual(2, buffer.lines.count)
        XCTAssertEqual("\n", buffer.characters.last)

        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: charsPerFrag)

        // First line: two fragments
        let start0 = buffer.index(buffer.startIndex, offsetBy: 0)
        var r = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)!
        XCTAssertEqual(0..<10, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: start0, affinity: .downstream)!
        XCTAssertEqual(0..<10, intRange(r, in: buffer))

        // between "9" and "w"
        let boundary0 = buffer.index(buffer.startIndex, offsetBy: 10)
        r = dataSource.lineFragmentRange(containing: boundary0, affinity: .upstream)!
        XCTAssertEqual(0..<10, intRange(r, in: buffer))

        // Second fragment
        r = dataSource.lineFragmentRange(containing: boundary0, affinity: .downstream)!
        XCTAssertEqual(10..<15, intRange(r, in: buffer))

        // between "w" and "\n"
        let last0 = buffer.index(buffer.startIndex, offsetBy: 14)
        r = dataSource.lineFragmentRange(containing: last0, affinity: .upstream)!
        XCTAssertEqual(10..<15, intRange(r, in: buffer))

        r = dataSource.lineFragmentRange(containing: last0, affinity: .downstream)!
        XCTAssertEqual(10..<15, intRange(r, in: buffer))

        // Second line, a single empty fragment
        let start1 = buffer.index(buffer.startIndex, offsetBy: 15)
        r = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        XCTAssertEqual(15..<15, intRange(r, in: buffer))

        XCTAssertNil(dataSource.lineFragmentRange(containing: start1, affinity: .downstream))
    }

    func intRange(_ r: Range<Buffer.Index>, in buffer: Buffer) -> Range<Int> {
        buffer.characters.distance(from: buffer.startIndex, to: r.lowerBound)..<buffer.characters.distance(from: buffer.startIndex, to: r.upperBound)
    }


    // MARK: index(forHorizontalOffset:inLineFragmentContaining:affinity:)

    func testIndexForHorizontalOffsetEmptyBuffer() {
        let buffer = Buffer("", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // Only upstream finds an index because the buffer is empty. No matter
        // how far to the right we go, we always get buffer.startIndex.

        var i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 4.001, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.startIndex, i)
        i = dataSource.index(forHorizontalOffset: 4.001, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertNil(i)
    }

    func testIndexForHorizontalOffsetNoTrailingNewline() {
        let buffer = Buffer("abc\ndef", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        var i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 0), i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 0), i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 1), i)

        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 1), i)

        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 2), i)
        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 2), i)

        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 2), i)
        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 2), i)

        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 3), i)

        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 3), i)

        // can't click past the end of the "\n" in line 1

        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 3), i)

        i = dataSource.index(forHorizontalOffset: 28.001, inLineFragmentContaining: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 28.001, inLineFragmentContaining: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 3), i)

        // next line

        let line2Start = buffer.index(buffer.startIndex, offsetBy: 4)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 4), i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 4), i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 5), i)

        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 5), i)

        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 6), i)
        i = dataSource.index(forHorizontalOffset: 12, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 6), i)

        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 6), i)
        i = dataSource.index(forHorizontalOffset: 19.999, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 6), i)

        // end of buffer

        i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.endIndex, i)

        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.endIndex, i)
    }

    func testIndexForHorizontalOffsetTrailingNewline() {
        let buffer = Buffer("abc\ndef\n", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // can't click past the end of the "\n" in line 2
        let line2Start = buffer.index(buffer.startIndex, offsetBy: 4)
        var i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 7), i)
        i = dataSource.index(forHorizontalOffset: 24, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 7), i)

        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 7), i)
        i = dataSource.index(forHorizontalOffset: 24.001, inLineFragmentContaining: line2Start, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 7), i)

        // end of buffer - downstream is nil because line3start == endIndex

        let line3start = buffer.index(buffer.startIndex, offsetBy: 8)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line3start, affinity: .upstream)
        XCTAssertEqual(buffer.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: line3start, affinity: .downstream)
        XCTAssertNil(i)

        i = dataSource.index(forHorizontalOffset: 50, inLineFragmentContaining: line3start, affinity: .upstream)
        XCTAssertEqual(buffer.endIndex, i)
        i = dataSource.index(forHorizontalOffset: 50, inLineFragmentContaining: line3start, affinity: .downstream)
        XCTAssertNil(i)
    }

    func testIndexForHorizontalOffsetWithWrapping() {
        let s = """
        0123456789wrap
        """

        let buffer = Buffer(s, language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)


        let boundary = buffer.index(buffer.startIndex, offsetBy: 10)

        var i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 0, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 10), i)

        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 0), i)
        i = dataSource.index(forHorizontalOffset: 3.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 10), i)

        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 4, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 11), i)

        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 1), i)
        i = dataSource.index(forHorizontalOffset: 11.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 11), i)

        // jump forward a bit to just before the wrap

        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 20, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 13), i)

        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 3), i)
        i = dataSource.index(forHorizontalOffset: 27.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 13), i)

        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 28, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 14), i)

        i = dataSource.index(forHorizontalOffset: 35.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 4), i)
        i = dataSource.index(forHorizontalOffset: 35.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 14), i)

        // can't click past the end of the "\n" in line 2

        i = dataSource.index(forHorizontalOffset: 36, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 36, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 14), i)

        i = dataSource.index(forHorizontalOffset: 36.001, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 5), i)
        i = dataSource.index(forHorizontalOffset: 36.001, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 14), i)

        // end of the first fragment

        i = dataSource.index(forHorizontalOffset: 75.999, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 9), i)
        i = dataSource.index(forHorizontalOffset: 75.999, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 14), i)

        i = dataSource.index(forHorizontalOffset: 76, inLineFragmentContaining: boundary, affinity: .upstream)
        XCTAssertEqual(buffer.index(at: 10), i)
        i = dataSource.index(forHorizontalOffset: 76, inLineFragmentContaining: boundary, affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 14), i)
    }


    // MARK: point(forCharacterAt:affinity:)

    func testPointForCharacterAtEmptyBuffer() {
        let buffer = Buffer("", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // Upstream results are .zero because the fragment contains no characters.
        // Downstream results are .zero because there's no fragment.

        var p = dataSource.point(forCharacterAt: buffer.startIndex, affinity: .upstream)
        XCTAssertEqual(.zero, p)
        p = dataSource.point(forCharacterAt: buffer.startIndex, affinity: .downstream)
        XCTAssertEqual(.zero, p)

        p = dataSource.point(forCharacterAt: buffer.endIndex, affinity: .upstream)
        XCTAssertEqual(.zero, p)
        p = dataSource.point(forCharacterAt: buffer.endIndex, affinity: .downstream)
        XCTAssertEqual(.zero, p)
    }

    func testPointForCharacterAtNoTrailingNewline() {
        let buffer = Buffer("abc\ndef", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)
        
        var p = dataSource.point(forCharacterAt: buffer.index(at: 0), affinity: .upstream)
        XCTAssertEqual(.zero, p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 0), affinity: .downstream)
        XCTAssertEqual(.zero, p)
        
        p = dataSource.point(forCharacterAt: buffer.index(at: 3), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 24, y: 0), p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 3), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 24, y: 0), p)

        p = dataSource.point(forCharacterAt: buffer.index(at: 4), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 0, y: 14), p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 4), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 0, y: 14), p)

        p = dataSource.point(forCharacterAt: buffer.index(at: 6), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 16, y: 14), p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 6), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 16, y: 14), p)

        p = dataSource.point(forCharacterAt: buffer.index(at: 7), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 24, y: 14), p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 7), affinity: .downstream)
        XCTAssertEqual(.zero, p)
    }

    func testPointForCharacterAtTrailingNewline() {
        let buffer = Buffer("abc\ndef\n", language: .plainText)
        let dataSource = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // let's start right before the second newline. We tested everything else above.

        var p = dataSource.point(forCharacterAt: buffer.index(at: 7), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 24, y: 14), p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 7), affinity: .downstream)
        XCTAssertEqual(CGPoint(x: 24, y: 14), p)

        p = dataSource.point(forCharacterAt: buffer.index(at: 8), affinity: .upstream)
        XCTAssertEqual(CGPoint(x: 0, y: 28), p)
        p = dataSource.point(forCharacterAt: buffer.index(at: 8), affinity: .downstream)
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
        let buffer = Buffer("ab\ncd\n", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        var s = Selection(caretAt: buffer.index(at: 0), affinity: .downstream)
        XCTAssertEqual(buffer.index(at: 0), s.caret)
        XCTAssertEqual(.downstream, s.affinity)

        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 1), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 2), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 3), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 4), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 5), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 6), andAffinity: .upstream, dataSource: d)
        // going right at the end doesn't move the caret
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 6), andAffinity: .upstream, dataSource: d)

        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 5), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 4), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 3), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 2), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 1), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        // going left at the beginning doesn't move the caret
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
    }

    func testMoveRightFromSelection() {
        let buffer = Buffer("foo bar baz", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "oo b"
        var s = Selection(anchor: buffer.index(at: 1), head: buffer.index(at: 5))
        // the caret moves to the end of the selection
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 5), andAffinity: .downstream, dataSource: d)

        // it doesn't matter if the selection is reversed
        s = Selection(anchor: buffer.index(at: 5), head: buffer.index(at: 1))
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 5), andAffinity: .downstream, dataSource: d)

        // select "baz"
        s = Selection(anchor: buffer.index(at: 8), head: buffer.index(at: 11))
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 11), andAffinity: .upstream, dataSource: d)

        // reverse
        s = Selection(anchor: buffer.index(at: 11), head: buffer.index(at: 8))
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 11), andAffinity: .upstream, dataSource: d)

        // select all
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 11))
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 11), andAffinity: .upstream, dataSource: d)

        // reverse
        s = Selection(anchor: buffer.index(at: 11), head: buffer.index(at: 0))
        s = move(s, direction: .right, andAssertCaret: buffer.index(at: 11), andAffinity: .upstream, dataSource: d)
    }

    func testMoveLeftFromSelection() {
        let buffer = Buffer("foo bar baz", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "oo b"
        var s = Selection(anchor: buffer.index(at: 1), head: buffer.index(at: 5))
        // the caret moves to the beginning of the selection
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 1), andAffinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 5), head: buffer.index(at: 1))
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 1), andAffinity: .downstream, dataSource: d)

        // select "foo"
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 3))
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // reverse
        s = Selection(anchor: buffer.index(at: 3), head: buffer.index(at: 0))
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // select all
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 11))
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // reverse
        s = Selection(anchor: buffer.index(at: 11), head: buffer.index(at: 0))
        s = move(s, direction: .left, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
    }

    func testMoveHorizontallyByWord() {
        let buffer = Buffer("  hello, world; this is (a test) ", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        var s = Selection(caretAt: buffer.index(at: 0), affinity: .downstream)

        // between "o" and ","
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 7), andAffinity: .downstream, dataSource: d)
        // between "d" and ";"
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 14), andAffinity: .downstream, dataSource: d)
        // after "this"
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 20), andAffinity: .downstream, dataSource: d)
        // after "is"
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 23), andAffinity: .downstream, dataSource: d)
        // after "a"
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 26), andAffinity: .downstream, dataSource: d)
        // after "test"
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 31), andAffinity: .downstream, dataSource: d)
        // end of buffer
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)
        // doesn't move right
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)


        // beginning of "test"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 27), andAffinity: .downstream, dataSource: d)
        // beginning of "a"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 25), andAffinity: .downstream, dataSource: d)
        // beginning of "is"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 21), andAffinity: .downstream, dataSource: d)
        // beginning of "this"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 16), andAffinity: .downstream, dataSource: d)
        // beginning of "world"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 9), andAffinity: .downstream, dataSource: d)
        // beginning of "hello"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 2), andAffinity: .downstream, dataSource: d)
        // beginning of buffer
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        // doesn't move left
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
    }

    func testMoveRightWordFromSelection() {
        let buffer = Buffer("  hello, world; this is (a test) ", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "ello, w"
        var s = Selection(anchor: buffer.index(at: 3), head: buffer.index(at: 10))
        // the caret moves to the end of "world"
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 14), andAffinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 10), head: buffer.index(at: 3))
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 14), andAffinity: .downstream, dataSource: d)

        // select "(a test"
        s = Selection(anchor: buffer.index(at: 24), head: buffer.index(at: 31))
        // the caret moves to the end of the buffer
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 31), head: buffer.index(at: 24))
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // select all
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 33))
        // the caret moves to the end of the buffer
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 33), head: buffer.index(at: 0))
        s = move(s, direction: .rightWord, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)
    }

    func testMoveLeftWordFromSelection() {
        let buffer = Buffer("  hello, world; this is (a test) ", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "lo, w"
        var s = Selection(anchor: buffer.index(at: 5), head: buffer.index(at: 10))
        // the caret moves to the beginning of "hello"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 2), andAffinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 10), head: buffer.index(at: 5))
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 2), andAffinity: .downstream, dataSource: d)

        // select "(a test"
        s = Selection(anchor: buffer.index(at: 24), head: buffer.index(at: 31))
        // the caret moves to the beginning of "is"
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 21), andAffinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 31), head: buffer.index(at: 24))
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 21), andAffinity: .downstream, dataSource: d)

        // select all
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 33))
        // the caret moves to the beginning of the buffer
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // reverse the selection
        s = Selection(anchor: buffer.index(at: 33), head: buffer.index(at: 0))
        s = move(s, direction: .leftWord, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
    }

    func testMoveLineSingleFragments() {
        let buffer = Buffer("foo bar\nbaz qux\n", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // between "a" and "r"
        var s = Selection(caretAt: buffer.index(at: 6), affinity: .downstream)
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        // moving again is a no-op
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // end of line
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 7), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 7), andAffinity: .downstream, dataSource: d)

        // from end to beginning
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = Selection(caretAt: buffer.index(at: 2), affinity: .downstream)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 7), andAffinity: .downstream, dataSource: d)



        // between "r" and "\n"
        s = Selection(caretAt: buffer.index(at: 7), affinity: .downstream)
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // between "z" and " "
        s = Selection(caretAt: buffer.index(at: 11), affinity: .downstream)
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 8), andAffinity: .downstream, dataSource: d)
        // no-op
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 8), andAffinity: .downstream, dataSource: d)
        
        // end of line
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 15), andAffinity: .downstream, dataSource: d)
        // no-op
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 15), andAffinity: .downstream, dataSource: d)

        // end of buffer
        s = Selection(caretAt: buffer.index(at: 16), affinity: .upstream)
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 16), andAffinity: .upstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 16), andAffinity: .upstream, dataSource: d)
    }

    func testMoveLineMultipleFragments() {
        let str = """
        0123456789abcdefghijwrap
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // between "0" and "1"
        var s = Selection(caretAt: buffer.index(at: 1), affinity: .downstream)
        // end of line
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // reset
        s = Selection(caretAt: buffer.index(at: 1), affinity: .downstream)
        // beginning of line
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)

        // no-op
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // between "a" and "b"
        s = Selection(caretAt: buffer.index(at: 11), affinity: .downstream)
        // end of line
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .upstream, dataSource: d)

        // reset
        s = Selection(caretAt: buffer.index(at: 11), affinity: .downstream)
        // beginning of line
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .downstream, dataSource: d)

        // no-op
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .upstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .upstream, dataSource: d)

        // between "w" and "r"
        s = Selection(caretAt: buffer.index(at: 21), affinity: .downstream)
        // end of line
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .upstream, dataSource: d)

        // reset
        s = Selection(caretAt: buffer.index(at: 21), affinity: .downstream)
        // beginning of line
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .downstream, dataSource: d)

        // no-op
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .downstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .upstream, dataSource: d)
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .upstream, dataSource: d)
    }

    func testMoveLineMultipleFragmentsOnFragmentBoundary() {
        let str = """
        0123456789abcdefghijwrap
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)
    
        // upstream between "9" and "a"
        var s = Selection(caretAt: buffer.index(at: 10), affinity: .upstream)
        // left
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        // reset
        s = Selection(caretAt: buffer.index(at: 10), affinity: .upstream)
        // moving right is a no-op
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // downstream between "9" and "a"
        s = Selection(caretAt: buffer.index(at: 10), affinity: .downstream)
        // right
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .upstream, dataSource: d)
        // reset
        s = Selection(caretAt: buffer.index(at: 10), affinity: .downstream)
        // moving left is a no-op
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .downstream, dataSource: d)
    }

    func testMoveLineFromSelection() {
        let str = """
        0123456789abcdefghijwrap
        bar
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "0123"
        var s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 4))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 4))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 4), head: buffer.index(at: 0))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 4), head: buffer.index(at: 0))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // select "1234"
        s = Selection(anchor: buffer.index(at: 1), head: buffer.index(at: 5))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 1), head: buffer.index(at: 5))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 5), head: buffer.index(at: 1))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 5), head: buffer.index(at: 1))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .upstream, dataSource: d)

        // select "9abc"
        s = Selection(anchor: buffer.index(at: 9), head: buffer.index(at: 13))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 9), head: buffer.index(at: 13))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 13), head: buffer.index(at: 9))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 13), head: buffer.index(at: 9))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .upstream, dataSource: d)

        // select "9abcdefghijw"
        s = Selection(anchor: buffer.index(at: 9), head: buffer.index(at: 21))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 9), head: buffer.index(at: 21))
        // downstream because we're before a hard line break
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 21), head: buffer.index(at: 9))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 21), head: buffer.index(at: 9))
        // ditto
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // select "ijwr"
        s = Selection(anchor: buffer.index(at: 18), head: buffer.index(at: 22))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 18), head: buffer.index(at: 22))
        // ditto
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 22), head: buffer.index(at: 18))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 10), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 22), head: buffer.index(at: 18))
        // ditto
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // select "ap\nba"
        s = Selection(anchor: buffer.index(at: 22), head: buffer.index(at: 27))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 22), head: buffer.index(at: 27))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 28), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 27), head: buffer.index(at: 22))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 20), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 27), head: buffer.index(at: 22))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 28), andAffinity: .upstream, dataSource: d)

        // select "a"
        s = Selection(anchor: buffer.index(at: 26), head: buffer.index(at: 27))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 25), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 26), head: buffer.index(at: 27))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 28), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 27), head: buffer.index(at: 26))
        s = move(s, direction: .beginningOfLine, andAssertCaret: buffer.index(at: 25), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 27), head: buffer.index(at: 26))
        s = move(s, direction: .endOfLine, andAssertCaret: buffer.index(at: 28), andAffinity: .upstream, dataSource: d)
    }

    func testMoveBeginningOfParagraph() {
        let str = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // no-ops
        var s = Selection(caretAt: buffer.index(at: 0), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 24), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)        

        // no-op around "baz"
        s = Selection(caretAt: buffer.index(at: 30), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 30), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 33), affinity: .upstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // no-op in blank line
        s = Selection(caretAt: buffer.index(at: 29), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 29), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 29), affinity: .downstream)

        // between "0" and "1"
        s = Selection(caretAt: buffer.index(at: 1), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 1), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // between "9" and "a" upstream
        s = Selection(caretAt: buffer.index(at: 10), affinity: .upstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 10), affinity: .upstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // between "9" and "a" downstream
        s = Selection(caretAt: buffer.index(at: 10), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 10), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // between "a" and "b"
        s = Selection(caretAt: buffer.index(at: 11), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 11), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // between "w" and "r"
        s = Selection(caretAt: buffer.index(at: 21), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 21), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = Selection(caretAt: buffer.index(at: 27), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 25), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 27), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 28), andAffinity: .downstream, dataSource: d)

        // between "a" and "z"
        s = Selection(caretAt: buffer.index(at: 32), affinity: .downstream)
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 30), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 32), affinity: .downstream)
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)
    }

    func testMoveParagraphFromSelection() {
        let str = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "0123"
        var s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 4))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 0), head: buffer.index(at: 4))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 4), head: buffer.index(at: 0))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 4), head: buffer.index(at: 0))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // select "9abcdefghi"
        s = Selection(anchor: buffer.index(at: 9), head: buffer.index(at: 19))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 9), head: buffer.index(at: 19))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 19), head: buffer.index(at: 9))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 19), head: buffer.index(at: 9))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 24), andAffinity: .downstream, dataSource: d)

        // select "rap\nfo"
        s = Selection(anchor: buffer.index(at: 21), head: buffer.index(at: 27))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 21), head: buffer.index(at: 27))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 28), andAffinity: .downstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 27), head: buffer.index(at: 21))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 27), head: buffer.index(at: 21))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 28), andAffinity: .downstream, dataSource: d)

        // select "o\n\nba"
        s = Selection(anchor: buffer.index(at: 26), head: buffer.index(at: 32))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 25), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 26), head: buffer.index(at: 32))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 32), head: buffer.index(at: 26))
        s = move(s, direction: .beginningOfParagraph, andAssertCaret: buffer.index(at: 25), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 32), head: buffer.index(at: 26))
        s = move(s, direction: .endOfParagraph, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)
    }

    func testMoveDocument() {
        let str = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // no-ops
        var s = Selection(caretAt: buffer.index(at: 0), affinity: .downstream)
        s = move(s, direction: .beginningOfDocument, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 33), affinity: .upstream)
        s = move(s, direction: .endOfDocument, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // between "f" and "o"
        s = Selection(caretAt: buffer.index(at: 26), affinity: .downstream)
        s = move(s, direction: .beginningOfDocument, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(caretAt: buffer.index(at: 26), affinity: .downstream)
        s = move(s, direction: .endOfDocument, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)
    }

    func testMoveDocumentFromSelection() {
        let str = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let buffer = Buffer(str, language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // select "ijwrap\nfoo\n\nb"
        var s = Selection(anchor: buffer.index(at: 18), head: buffer.index(at: 31))
        s = move(s, direction: .beginningOfDocument, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 18), head: buffer.index(at: 31))
        s = move(s, direction: .endOfDocument, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)

        // swap anchor and head
        s = Selection(anchor: buffer.index(at: 31), head: buffer.index(at: 18))
        s = move(s, direction: .beginningOfDocument, andAssertCaret: buffer.index(at: 0), andAffinity: .downstream, dataSource: d)
        s = Selection(anchor: buffer.index(at: 31), head: buffer.index(at: 18))
        s = move(s, direction: .endOfDocument, andAssertCaret: buffer.index(at: 33), andAffinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByCharacter() {
        let buffer = Buffer("Hello, world!", language: .plainText)
        let d = SimpleSelectionDataSource(buffer: buffer, charsPerFrag: 10)

        // caret at "!"
        var s = Selection(caretAt: buffer.index(at: 12), affinity: .downstream)
        s = extendAndAssert(s, direction: .right, selected: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, caret: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, selected: "d", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, caret: "!", affinity: .downstream, dataSource: d)

        // caret at "e"
        s = Selection(caretAt: buffer.index(at: 1), affinity: .downstream)
        s = extendAndAssert(s, direction: .left, selected: "H", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, caret: "e", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, selected: "e", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, caret: "e", affinity: .downstream, dataSource: d)
    }

    func extendAndAssert(_ s: Selection, direction: Selection.Movement, caret c: Character, affinity: Selection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection {
        let s2 = Selection(fromExisting: s, movement: direction, extending: true, buffer: dataSource.buffer, layoutDataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssert(_ s: Selection, direction: Selection.Movement, selected string: String, affinity: Selection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection {
        let s2 = Selection(fromExisting: s, movement: direction, extending: true, buffer: dataSource.buffer, layoutDataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func move(_ s: Selection, direction: Selection.Movement, andAssertCaret caret: Buffer.Index, andAffinity affinity: Selection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) -> Selection {
        let s2 = Selection(fromExisting: s, movement: direction, extending: false, buffer: dataSource.buffer, layoutDataSource: dataSource)
        assert(selection: s2, hasCaret: caret, andAffinity: affinity, file: file, line: line)
        return s2
    }

    func assert(selection: Selection, hasCaretBefore c: Character, affinity: Selection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(selection.isCaret)
        XCTAssertEqual(dataSource.buffer[selection.range.lowerBound], c, file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }

    func assert(selection: Selection, hasRangeCovering string: String, affinity: Selection.Affinity, dataSource: SimpleSelectionDataSource, file: StaticString = #file, line: UInt = #line) {
        let range = selection.range
        XCTAssertEqual(String(dataSource.buffer[range]), string, file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }

    func assert(selection: Selection, hasCaret caret: Buffer.Index, andAffinity affinity: Selection.Affinity, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(selection.caret, caret, file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
    }
}
