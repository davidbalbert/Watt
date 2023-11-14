//
//  SelectionNavigationDataSourceTests.swift
//  
//
//  Created by David Albert on 11/8/23.
//

import XCTest
@testable import StandardKeyBindingResponder

final class SelectionNavigationDataSourceTests: XCTestCase {
    // MARK: index(forCaretOffset:inLineFragmentWithRange:)

    func testIndexForCaretOffsetEmpty() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 0)

        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 0, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetOnlyNewline() {
        let s = "\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 1)

        // can't go past newline
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 0, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetSingleCharacter() {
        let s = "a"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 1)

        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 7.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 8, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetSingleCharacterWithNewline() {
        let s = "a\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 2)

        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        // can't go past the newline
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 16, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetSingleLine() {
        let s = "abc"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = s.index(at: 0)..<s.index(at: 3)

        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 2), 16), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 2), 16), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 24, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetWrap() {
        let s = "0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = s.index(at: 0)..<s.index(at: 10)

        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 2), 16), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 2), 16), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 27.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 4), 32), dataSource.index(forCaretOffset: 28, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 4), 32), dataSource.index(forCaretOffset: 35.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 5), 40), dataSource.index(forCaretOffset: 36, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 5), 40), dataSource.index(forCaretOffset: 43.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 6), 48), dataSource.index(forCaretOffset: 44, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 6), 48), dataSource.index(forCaretOffset: 51.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 7), 56), dataSource.index(forCaretOffset: 52, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 7), 56), dataSource.index(forCaretOffset: 59.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 8), 64), dataSource.index(forCaretOffset: 60, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 8), 64), dataSource.index(forCaretOffset: 67.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 9), 72), dataSource.index(forCaretOffset: 68, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 9), 72), dataSource.index(forCaretOffset: 75.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 10), 80), dataSource.index(forCaretOffset: 76, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 10), 80), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))

        r = s.index(at: 10)..<s.index(at: 14)

        assertIndexAndOffsetEqual((s.index(at: 10), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 10), 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 11), 8), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 11), 8), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 12), 16), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 12), 16), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 13), 24), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 13), 24), dataSource.index(forCaretOffset: 27.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 14), 32), dataSource.index(forCaretOffset: 28, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 14), 32), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func testIndexForCaretOffsetFullFragWithNewline() {
        let s = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = s.index(at: 0)..<s.index(at: 11)

        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 0), 0), dataSource.index(forCaretOffset: 3.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 4, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 1), 8), dataSource.index(forCaretOffset: 11.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 2), 16), dataSource.index(forCaretOffset: 12, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 2), 16), dataSource.index(forCaretOffset: 19.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 20, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 3), 24), dataSource.index(forCaretOffset: 27.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 4), 32), dataSource.index(forCaretOffset: 28, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 4), 32), dataSource.index(forCaretOffset: 35.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 5), 40), dataSource.index(forCaretOffset: 36, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 5), 40), dataSource.index(forCaretOffset: 43.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 6), 48), dataSource.index(forCaretOffset: 44, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 6), 48), dataSource.index(forCaretOffset: 51.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 7), 56), dataSource.index(forCaretOffset: 52, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 7), 56), dataSource.index(forCaretOffset: 59.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 8), 64), dataSource.index(forCaretOffset: 60, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 8), 64), dataSource.index(forCaretOffset: 67.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 9), 72), dataSource.index(forCaretOffset: 68, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 9), 72), dataSource.index(forCaretOffset: 75.999, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 10), 80), dataSource.index(forCaretOffset: 76, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 10), 80), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))

        r = s.index(at: 11)..<s.index(at: 11)

        assertIndexAndOffsetEqual((s.index(at: 11), 0), dataSource.index(forCaretOffset: -5, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 11), 0), dataSource.index(forCaretOffset: 0, inLineFragmentWithRange: r))
        assertIndexAndOffsetEqual((s.index(at: 11), 0), dataSource.index(forCaretOffset: 100, inLineFragmentWithRange: r))
    }

    func assertIndexAndOffsetEqual(_ a: (String.Index, CGFloat), _ b: (String.Index, CGFloat), file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(a.0, b.0, file: file, line: line)
        XCTAssertEqual(a.1, b.1, file: file, line: line)
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
        XCTAssertEqual(0..<0, Range(r, in: s))
    }

    func testRangeForWordEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, Range(r, in: s))
    }

    func testRangeForLineEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, Range(r, in: s))
    }

    func testRangeForParagraphEmptyString() {
        let s = ""
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        let r = dataSource.range(for: .paragraph, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<0, Range(r, in: s))
    }

    func testRangeForCharacter() {
        let s = "abc"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .character, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<1, Range(r, in: s))

        r = dataSource.range(for: .character, enclosing: s.index(at: 1))
        XCTAssertEqual(1..<2, Range(r, in: s))

        r = dataSource.range(for: .character, enclosing: s.index(at: 2))
        XCTAssertEqual(2..<3, Range(r, in: s))

        r = dataSource.range(for: .character, enclosing: s.index(at: 3))
        XCTAssertEqual(2..<3, Range(r, in: s))
    }

    func testRangeForWordCharactersAtEdges() {
        let s = "abc   def"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 3))
        XCTAssertEqual(3..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 4))
        XCTAssertEqual(3..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 5))
        XCTAssertEqual(3..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 6))
        XCTAssertEqual(6..<9, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 7))
        XCTAssertEqual(6..<9, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 8))
        XCTAssertEqual(6..<9, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 9))
        XCTAssertEqual(6..<9, Range(r, in: s))
    }

    func testRangeForWordWhitespaceAtEdges() {
        let s = "   abc   "
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 3))
        XCTAssertEqual(3..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 4))
        XCTAssertEqual(3..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 5))
        XCTAssertEqual(3..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 6))
        XCTAssertEqual(6..<9, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 7))
        XCTAssertEqual(6..<9, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 8))
        XCTAssertEqual(6..<9, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 9))
        XCTAssertEqual(6..<9, Range(r, in: s))
    }

    func testRangeForWordWithNewline() {
        let s = "abc  \n def"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .word, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 3))
        XCTAssertEqual(3..<5, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 4))
        XCTAssertEqual(3..<5, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 5))
        XCTAssertEqual(5..<6, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 6))
        XCTAssertEqual(6..<7, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 7))
        XCTAssertEqual(7..<10, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 8))
        XCTAssertEqual(7..<10, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 9))
        XCTAssertEqual(7..<10, Range(r, in: s))

        r = dataSource.range(for: .word, enclosing: s.index(at: 10))
        XCTAssertEqual(7..<10, Range(r, in: s))
    }

    func testRangeForLineSingleFragment() {
        let s = "abc"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<3, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 3))
        XCTAssertEqual(0..<3, Range(r, in: s))
    }

    func testRangeForLineWithNewline() {
        let s = "abc\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<4, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 1))
        XCTAssertEqual(0..<4, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 2))
        XCTAssertEqual(0..<4, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 3))
        XCTAssertEqual(0..<4, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 4))
        XCTAssertEqual(4..<4, Range(r, in: s))
    }

    func testRangeForFullLine() {
        let s = "0123456789"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<10, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 5))
        XCTAssertEqual(0..<10, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 9))
        XCTAssertEqual(0..<10, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 10))
        XCTAssertEqual(0..<10, Range(r, in: s))
    }

    func testRangeForFullLineWithTrailingNewline() {
        let s = "0123456789\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<11, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 5))
        XCTAssertEqual(0..<11, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 9))
        XCTAssertEqual(0..<11, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 10))
        XCTAssertEqual(0..<11, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 11))
        XCTAssertEqual(11..<11, Range(r, in: s))
    }

    func testRangeForWrappedLine() {
        let s = "0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .line, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<10, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 5))
        XCTAssertEqual(0..<10, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 9))
        XCTAssertEqual(0..<10, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 10))
        XCTAssertEqual(10..<14, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 11))
        XCTAssertEqual(10..<14, Range(r, in: s))

        r = dataSource.range(for: .line, enclosing: s.index(at: 14))
        XCTAssertEqual(10..<14, Range(r, in: s))
    }

    func testRangeForParagraph() {
        let s = "0123456789wrap\n0123456789wrap"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .paragraph, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<15, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 14))
        XCTAssertEqual(0..<15, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 15))
        XCTAssertEqual(15..<29, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 28))
        XCTAssertEqual(15..<29, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 29))
        XCTAssertEqual(15..<29, Range(r, in: s))
    }

    func testRangeForParagraphWithTrailingNewline() {
        let s = "foo\nbar\n"
        let dataSource = SimpleSelectionDataSource(string: s, charsPerLine: 10)

        var r = dataSource.range(for: .paragraph, enclosing: s.index(at: 0))
        XCTAssertEqual(0..<4, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 3))
        XCTAssertEqual(0..<4, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 4))
        XCTAssertEqual(4..<8, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 7))
        XCTAssertEqual(4..<8, Range(r, in: s))

        r = dataSource.range(for: .paragraph, enclosing: s.index(at: 8))
        XCTAssertEqual(8..<8, Range(r, in: s))
    }
}
