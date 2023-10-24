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
struct SimpleSelectionDataSource: SelectionLayoutDataSource {
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

        let offsetInFrag = Int(xOffset/Self.charWidth)

        let hasHardBreak = buffer[fragRange].characters.last == "\n"

        var i = buffer.characters.index(fragRange.lowerBound, offsetBy: offsetInFrag, clampedTo: fragRange.upperBound)
        if i == fragRange.upperBound && hasHardBreak {
            i = buffer.index(before: i)
        }

        return i
    }

    func point(forCharacterAt index: Buffer.Index, affinity: Selection.Affinity) -> CGPoint {
        guard let fragRange = lineFragmentRange(containing: index, affinity: affinity) else {
            return .zero
        }

        let offsetOfFrag = buffer.characters.distance(from: buffer.startIndex, to: fragRange.lowerBound)
        let offsetInFrag = buffer.characters.distance(from: fragRange.lowerBound, to: index)

        let x = CGFloat(offsetInFrag)*Self.charWidth
        let y = CGFloat(offsetOfFrag/charsPerFrag)*Self.lineHeight

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Sanity checks for SimpleSelectionDataSource

final class SimpleSelectionDataSourceTests: XCTestCase {
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
}
