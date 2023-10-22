//
//  SelectionTests.swift
//  WattTests
//
//  Created by David Albert on 10/22/23.
//

import XCTest
@testable import Watt

// Simple monospaced layout:
// - All characters are 8 points wide
// - All lines are 14 points high
// - No line fragment padding
struct SimpleSelectionDataSource: SelectionLayoutDataSource {
    let buffer: Buffer
    let charsPerFrag: Int

    static var charWidth: CGFloat {
        8
    }

    static var lineHeight: CGFloat {
        14
    }

    func lineFragmentRange(containing index: Buffer.Index, affinity: Selection.Affinity) -> Range<Buffer.Index>? {
        let lineStart = buffer.lines.index(roundingDown: index)
        let lineEnd = buffer.lines.index(after: lineStart, clampedTo: buffer.endIndex)
        let lineLen = buffer.characters.distance(from: lineStart, to: lineEnd)

        // find the line fragment range containing index
        // calculate the fragment range based on containerSize and the fact that all characters are 8 points wide
        let offset = buffer.characters.distance(from: lineStart, to: index)

        let onBoundary = offset % charsPerFrag == 0
        let atStart = offset == 0
        let atEnd = offset == lineLen

        let fragIndex: Int

        if atStart && !buffer.isEmpty && affinity == .upstream {
            return nil
        } else if atEnd && affinity == .upstream {
            fragIndex = lineLen/charsPerFrag
        } else if atEnd {
            return nil
        } else if onBoundary && affinity == .upstream {
            fragIndex = offset/charsPerFrag - 1
        } else {
            fragIndex = offset/charsPerFrag
        }

        let fragLen = min(charsPerFrag, lineLen - fragIndex*charsPerFrag)
        let fragStart = buffer.index(lineStart, offsetBy: fragIndex*charsPerFrag)
        let fragEnd = buffer.index(fragStart, offsetBy: fragLen)

        return fragStart..<fragEnd
    }

    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: Buffer.Index, affinity: Selection.Affinity) -> Buffer.Index? {
        let fragRange = lineFragmentRange(containing: index, affinity: affinity)!
        let offsetInFrag = Int(xOffset/Self.charWidth)

        let hasHardBreak = buffer[fragRange].characters.last == "\n"

        var i = buffer.characters.index(fragRange.lowerBound, offsetBy: offsetInFrag, clampedTo: fragRange.upperBound)
        if i == fragRange.upperBound && hasHardBreak {
            i = buffer.index(before: i)
        }

        return i
    }

    func point(forCharacterAt index: Buffer.Index, affinity: Selection.Affinity) -> CGPoint {
        let fragRange = lineFragmentRange(containing: index, affinity: affinity)!
        let offsetOfFrag = buffer.characters.distance(from: buffer.startIndex, to: fragRange.lowerBound)
        let offsetInFrag = buffer.characters.distance(from: fragRange.lowerBound, to: index)

        let x = CGFloat(offsetInFrag)*Self.charWidth
        let y = CGFloat(offsetOfFrag/charsPerFrag)*Self.lineHeight

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Sanity checks for SimpleDataSource

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

        let r0 = dataSource.lineFragmentRange(containing: start0, affinity: .upstream)
        let r1 = dataSource.lineFragmentRange(containing: start1, affinity: .upstream)!
        let r2 = dataSource.lineFragmentRange(containing: start2, affinity: .upstream)!
        let r3 = dataSource.lineFragmentRange(containing: start3, affinity: .upstream)!
        let r4 = dataSource.lineFragmentRange(containing: start4, affinity: .upstream)!

        XCTAssertNil(r0)
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

    func intRange(_ r: Range<Buffer.Index>, in buffer: Buffer) -> Range<Int> {
        buffer.characters.distance(from: buffer.startIndex, to: r.lowerBound)..<buffer.characters.distance(from: buffer.startIndex, to: r.upperBound)
    }
}
