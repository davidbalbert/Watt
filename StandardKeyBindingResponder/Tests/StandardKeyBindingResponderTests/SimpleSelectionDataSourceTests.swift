//
//  SimpleSelectionDataSourceTests.swift
//
//
//  Created by David Albert on 11/8/23.
//

import XCTest

// Sanity checks to make sure we can rely on SimpleSelectionDataSource
// for use in the rest of our tests.

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

        XCTAssertEqual(O(0, string.startIndex, .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetsOnlyNewline() {
        let string = "\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, string.index(at: 0), .trailing), offsets[0])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 1))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, string.index(at: 1), .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetOneLine() {
        let string = "abc"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        let offsets = dataSource.carretOffsetsInLineFragment(containing: string.startIndex)

        XCTAssertEqual(6, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), .trailing), offsets[5])
    }

    func testEnumerateCaretOffsetWithNewline() {
        let string = "abc\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(6, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), .trailing), offsets[5])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 4))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 4), .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetsWithWrap() {
        let string = "0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(20, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), .trailing), offsets[5])
        XCTAssertEqual(O(24, string.index(at: 3), .leading), offsets[6])
        XCTAssertEqual(O(32, string.index(at: 3), .trailing), offsets[7])
        XCTAssertEqual(O(32, string.index(at: 4), .leading), offsets[8])
        XCTAssertEqual(O(40, string.index(at: 4), .trailing), offsets[9])
        XCTAssertEqual(O(40, string.index(at: 5), .leading), offsets[10])
        XCTAssertEqual(O(48, string.index(at: 5), .trailing), offsets[11])
        XCTAssertEqual(O(48, string.index(at: 6), .leading), offsets[12])
        XCTAssertEqual(O(56, string.index(at: 6), .trailing), offsets[13])
        XCTAssertEqual(O(56, string.index(at: 7), .leading), offsets[14])
        XCTAssertEqual(O(64, string.index(at: 7), .trailing), offsets[15])
        XCTAssertEqual(O(64, string.index(at: 8), .leading), offsets[16])
        XCTAssertEqual(O(72, string.index(at: 8), .trailing), offsets[17])
        XCTAssertEqual(O(72, string.index(at: 9), .leading), offsets[18])
        XCTAssertEqual(O(80, string.index(at: 9), .trailing), offsets[19])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 10))

        XCTAssertEqual(8, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 10), .leading), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 10), .trailing), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 11), .leading), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 11), .trailing), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 12), .leading), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 12), .trailing), offsets[5])
        XCTAssertEqual(O(24, string.index(at: 13), .leading), offsets[6])
        XCTAssertEqual(O(32, string.index(at: 13), .trailing), offsets[7])
    }

    func testEnumerateCaretOffsetFullLineFragmentPlusNewline() {
        let string = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        var offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 0))

        XCTAssertEqual(20, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(8, string.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(16, string.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(16, string.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(24, string.index(at: 2), .trailing), offsets[5])
        XCTAssertEqual(O(24, string.index(at: 3), .leading), offsets[6])
        XCTAssertEqual(O(32, string.index(at: 3), .trailing), offsets[7])
        XCTAssertEqual(O(32, string.index(at: 4), .leading), offsets[8])
        XCTAssertEqual(O(40, string.index(at: 4), .trailing), offsets[9])
        XCTAssertEqual(O(40, string.index(at: 5), .leading), offsets[10])
        XCTAssertEqual(O(48, string.index(at: 5), .trailing), offsets[11])
        XCTAssertEqual(O(48, string.index(at: 6), .leading), offsets[12])
        XCTAssertEqual(O(56, string.index(at: 6), .trailing), offsets[13])
        XCTAssertEqual(O(56, string.index(at: 7), .leading), offsets[14])
        XCTAssertEqual(O(64, string.index(at: 7), .trailing), offsets[15])
        XCTAssertEqual(O(64, string.index(at: 8), .leading), offsets[16])
        XCTAssertEqual(O(72, string.index(at: 8), .trailing), offsets[17])
        XCTAssertEqual(O(72, string.index(at: 9), .leading), offsets[18])
        XCTAssertEqual(O(80, string.index(at: 9), .trailing), offsets[19])

        offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 11))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 11), .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetsUpperBound() {
        let string = "a"
        let dataSource = SimpleSelectionDataSource(string: string, charsPerLine: 10)
        let offsets = dataSource.carretOffsetsInLineFragment(containing: string.index(at: 1))

        // endIndex returns the last line
        XCTAssertEqual(2, offsets.count)

        XCTAssertEqual(O(0, string.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(8, string.index(at: 0), .trailing), offsets[1])
    }
}

