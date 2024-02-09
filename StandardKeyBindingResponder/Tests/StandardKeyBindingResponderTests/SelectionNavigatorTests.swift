//
//  SelectionNavigatorTests.swift
//  Watt
//
//  Created by David Albert on 11/2/23.
//

import XCTest
@testable import StandardKeyBindingResponder

final class SelectionNavigatorTests: XCTestCase {
    // MARK: - Keyboard navigation

    func testMoveHorizontallyByCharacter() {
        let string = "ab\ncd\n"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        var s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)
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
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        var s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)

        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
    }

    func testMoveRightFromSelection() {
        let string = "foo bar baz"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "oo b"
        var s = TestSelection(anchor: string.index(at: 1), head: string.index(at: 5), granularity: .character)
        // the caret moves to the end of the selection
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)

        // it doesn't matter if the selection is reversed
        s = TestSelection(anchor: string.index(at: 5), head: string.index(at: 1), granularity: .character)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 5), affinity: .downstream, dataSource: d)

        // select "baz"
        s = TestSelection(anchor: string.index(at: 8), head: string.index(at: 11), granularity: .character)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // select "bar ba" - upperBound is at the end of the line fragment, so moving right should set our affinity
        // to upstream
        s = TestSelection(anchor: string.index(at: 4), head: string.index(at: 10), granularity: .character)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // reverse
        s = TestSelection(anchor: string.index(at: 11), head: string.index(at: 8), granularity: .character)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // select all
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 11), granularity: .character)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)

        // reverse
        s = TestSelection(anchor: string.index(at: 11), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .right, caretAt: string.index(at: 11), affinity: .upstream, dataSource: d)
    }

    func testMoveLeftFromSelection() {
        let string = "foo bar baz"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "oo b"
        var s = TestSelection(anchor: string.index(at: 1), head: string.index(at: 5), granularity: .character)
        // the caret moves to the beginning of the selection
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 5), head: string.index(at: 1), granularity: .character)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // select "foo"
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 3), granularity: .character)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse
        s = TestSelection(anchor: string.index(at: 3), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // select all
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 11), granularity: .character)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse
        s = TestSelection(anchor: string.index(at: 11), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .left, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveVertically() {
        let string = """
        qux
        0123456789abcdefghijwrap
        xyz
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "1"
        var s = TestSelection(caretAt: string.index(at: 5), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .up, caret: "u", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "q", affinity: .downstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .up, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "0", affinity: .downstream, dataSource: d)

        // caret at "1"
        s = TestSelection(caretAt: string.index(at: 5), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .down, caret: "b", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "r", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caret: "y", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .down, caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .down, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "p", affinity: .downstream, dataSource: d)


        // caret at "5"
        s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
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

    func testMoveVerticallyWithEmptyLastLine() {
        let string = "abc\n"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // after "\n"
        var s = TestSelection(caretAt: string.endIndex, affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .up, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // after "c"
        s = TestSelection(caretAt: string.index(at: 3), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .down, caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .up, caret: "\n", affinity: .downstream, dataSource: d)
    }

    func testMoveVerticallyFromSelection() {
        let string = """
        abcd
        efgh
        ijkl
        mnop
        0123456789wrap
        qrst
        uvwx
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // "f" through "k"
        var s = TestSelection(anchor: string.index(at: 6), head: string.index(at: 13), granularity: .character)
        // at "b"
        s = moveAndAssert(s, direction: .up, caretAt: string.index(at: 1), affinity: .downstream, dataSource: d)

        // "f" through "k"
        s = TestSelection(anchor: string.index(at: 6), head: string.index(at: 13), granularity: .character)
        // at "n"
        s = moveAndAssert(s, direction: .down, caretAt: string.index(at: 16), affinity: .downstream, dataSource: d)

        // "a" through "d" (upstream)
        s = TestSelection(anchor: string.index(at: 4), head: string.index(at: 0), granularity: .character)
        // at "a"
        s = moveAndAssert(s, direction: .up, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // 0-9
        s = TestSelection(anchor: string.index(at: 20), head: string.index(at: 30), granularity: .character)
        s = moveAndAssert(s, direction: .down, caret: "w", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 20), head: string.index(at: 30), granularity: .character)
        s = moveAndAssert(s, direction: .up, caret: "m", affinity: .downstream, dataSource: d)

        // "wrap"
        s = TestSelection(anchor: string.index(at: 30), head: string.index(at: 34), granularity: .character)
        s = moveAndAssert(s, direction: .down, caret: "q", affinity: .downstream, dataSource: d)
    }

    func testMoveHorizontallyByWord() {
        let string = "  hello, world; this is (a test) "
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        var s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)

        // between "o" and ","
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)
        // between "d" and ";"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)
        // after "this"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        // after "is"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 23), affinity: .downstream, dataSource: d)
        // after "a"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 26), affinity: .downstream, dataSource: d)
        // after "test"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 31), affinity: .downstream, dataSource: d)
        // end of buffer
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
        // doesn't move right
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)


        // beginning of "test"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 27), affinity: .downstream, dataSource: d)
        // beginning of "a"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        // beginning of "is"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)
        // beginning of "this"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 16), affinity: .downstream, dataSource: d)
        // beginning of "world"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 9), affinity: .downstream, dataSource: d)
        // beginning of "hello"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)
        // beginning of buffer
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // doesn't move left
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveByWordApostrophe() {
        let string = "foo bar's  '' baz"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        var s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)

        // end of "foo"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 3), affinity: .downstream, dataSource: d)
        // end of "bar's"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 9), affinity: .downstream, dataSource: d)
        // end of "baz"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 17), affinity: .upstream, dataSource: d)

        // beginning of "baz"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)
        // beginning of "bar's"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 4), affinity: .downstream, dataSource: d)
        // beginning of "foo"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveRightWordFromSelection() {
        let string = "  hello, world; this is (a test) "
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "ello, w"
        var s = TestSelection(anchor: string.index(at: 3), head: string.index(at: 10), granularity: .character)
        // the caret moves to the end of "world"
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 10), head: string.index(at: 3), granularity: .character)
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 14), affinity: .downstream, dataSource: d)

        // select "(a test"
        s = TestSelection(anchor: string.index(at: 24), head: string.index(at: 31), granularity: .character)
        // the caret moves to the end of the buffer
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 31), head: string.index(at: 24), granularity: .character)
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // select all
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 33), granularity: .character)
        // the caret moves to the end of the buffer
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 33), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .wordRight, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveLeftWordFromSelection() {
        let string = "  hello, world; this is (a test) "
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "lo, w"
        var s = TestSelection(anchor: string.index(at: 5), head: string.index(at: 10), granularity: .character)
        // the caret moves to the beginning of "hello"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 10), head: string.index(at: 5), granularity: .character)
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 2), affinity: .downstream, dataSource: d)

        // select "(a test"
        s = TestSelection(anchor: string.index(at: 24), head: string.index(at: 31), granularity: .character)
        // the caret moves to the beginning of "is"
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 31), head: string.index(at: 24), granularity: .character)
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 21), affinity: .downstream, dataSource: d)

        // select all
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 33), granularity: .character)
        // the caret moves to the beginning of the buffer
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // reverse the selection
        s = TestSelection(anchor: string.index(at: 33), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .wordLeft, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
    }

    func testMoveLineEmpty() {
        let string = ""
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        var s = TestSelection(caretAt: string.startIndex, affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
    }

    func testMoveLineSingleFragments() {
        let string = "foo bar\nbaz qux\n"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // between "a" and "r"
        var s = TestSelection(caretAt: string.index(at: 6), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // moving again is a no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)

        // from end to beginning
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = TestSelection(caretAt: string.index(at: 2), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 7), affinity: .downstream, dataSource: d)



        // between "r" and "\n"
        s = TestSelection(caretAt: string.index(at: 7), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // between "z" and " "
        s = TestSelection(caretAt: string.index(at: 11), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 8), affinity: .downstream, dataSource: d)
        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 8), affinity: .downstream, dataSource: d)

        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 15), affinity: .downstream, dataSource: d)
        // no-op
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 15), affinity: .downstream, dataSource: d)

        // end of buffer
        s = TestSelection(caretAt: string.index(at: 16), affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 16), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 16), affinity: .upstream, dataSource: d)
    }

    func testMoveLineMultipleFragments() {
        let string = """
        0123456789abcdefghijwrap
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // between "0" and "1"
        var s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // reset
        s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // between "a" and "b"
        s = TestSelection(caretAt: string.index(at: 11), affinity: .downstream, granularity: .character)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // reset
        s = TestSelection(caretAt: string.index(at: 11), affinity: .downstream, granularity: .character)
        // beginning of line
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)

        // no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // between "w" and "r"
        s = TestSelection(caretAt: string.index(at: 21), affinity: .downstream, granularity: .character)
        // end of line
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .upstream, dataSource: d)

        // reset
        s = TestSelection(caretAt: string.index(at: 21), affinity: .downstream, granularity: .character)
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
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // upstream between "9" and "a"
        var s = TestSelection(caretAt: string.index(at: 10), affinity: .upstream, granularity: .character)
        // left
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        // reset
        s = TestSelection(caretAt: string.index(at: 10), affinity: .upstream, granularity: .character)
        // moving right is a no-op
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // downstream between "9" and "a"
        s = TestSelection(caretAt: string.index(at: 10), affinity: .downstream, granularity: .character)
        // right
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)
        // reset
        s = TestSelection(caretAt: string.index(at: 10), affinity: .downstream, granularity: .character)
        // moving left is a no-op
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
    }

    func testMoveLineFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        bar
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "0123"
        var s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 4), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 4), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 4), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 4), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // select "1234"
        s = TestSelection(anchor: string.index(at: 1), head: string.index(at: 5), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 1), head: string.index(at: 5), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 5), head: string.index(at: 1), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 5), head: string.index(at: 1), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 10), affinity: .upstream, dataSource: d)

        // select "9abc"
        s = TestSelection(anchor: string.index(at: 9), head: string.index(at: 13), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 9), head: string.index(at: 13), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 13), head: string.index(at: 9), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 13), head: string.index(at: 9), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 20), affinity: .upstream, dataSource: d)

        // select "9abcdefghijw"
        s = TestSelection(anchor: string.index(at: 9), head: string.index(at: 21), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 9), head: string.index(at: 21), granularity: .character)
        // downstream because we're before a hard line break
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 21), head: string.index(at: 9), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 21), head: string.index(at: 9), granularity: .character)
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "ijwr"
        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 22), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 22), granularity: .character)
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 22), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 10), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 22), head: string.index(at: 18), granularity: .character)
        // ditto
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "ap\nba"
        s = TestSelection(anchor: string.index(at: 22), head: string.index(at: 27), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 22), head: string.index(at: 27), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 27), head: string.index(at: 22), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 20), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 27), head: string.index(at: 22), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // select "a"
        s = TestSelection(anchor: string.index(at: 26), head: string.index(at: 27), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 26), head: string.index(at: 27), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 27), head: string.index(at: 26), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfLine, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 27), head: string.index(at: 26), granularity: .character)
        s = moveAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 28), affinity: .upstream, dataSource: d)
    }

    func testMoveBeginningOfParagraph() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // no-ops
        var s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 24), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // no-op around "baz"
        s = TestSelection(caretAt: string.index(at: 30), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 30), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 33), affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // no-op in blank line
        s = TestSelection(caretAt: string.index(at: 29), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 29), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 29), affinity: .downstream, granularity: .character)

        // between "0" and "1"
        s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "9" and "a" upstream
        s = TestSelection(caretAt: string.index(at: 10), affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 10), affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "9" and "a" downstream
        s = TestSelection(caretAt: string.index(at: 10), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 10), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "a" and "b"
        s = TestSelection(caretAt: string.index(at: 11), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 11), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "w" and "r"
        s = TestSelection(caretAt: string.index(at: 21), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 21), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // between "o" and "o"
        s = TestSelection(caretAt: string.index(at: 27), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 27), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // between "a" and "z"
        s = TestSelection(caretAt: string.index(at: 32), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 30), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 32), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveParagraphFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "0123"
        var s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 4), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 4), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 4), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 4), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "9abcdefghi"
        s = TestSelection(anchor: string.index(at: 9), head: string.index(at: 19), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 9), head: string.index(at: 19), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 19), head: string.index(at: 9), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 19), head: string.index(at: 9), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 24), affinity: .downstream, dataSource: d)

        // select "rap\nfo"
        s = TestSelection(anchor: string.index(at: 21), head: string.index(at: 27), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 21), head: string.index(at: 27), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 27), head: string.index(at: 21), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 27), head: string.index(at: 21), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 28), affinity: .downstream, dataSource: d)

        // select "o\n\nba"
        s = TestSelection(anchor: string.index(at: 26), head: string.index(at: 32), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 26), head: string.index(at: 32), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 32), head: string.index(at: 26), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 25), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 32), head: string.index(at: 26), granularity: .character)
        s = moveAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveDocument() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // no-ops
        var s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 33), affinity: .upstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // between "f" and "o"
        s = TestSelection(caretAt: string.index(at: 26), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(caretAt: string.index(at: 26), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMoveDocumentFromSelection() {
        let string = """
        0123456789abcdefghijwrap
        foo

        baz
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // select "ijwrap\nfoo\n\nb"
        var s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 31), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 31), granularity: .character)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)

        // swap anchor and head
        s = TestSelection(anchor: string.index(at: 31), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .beginningOfDocument, caretAt: string.index(at: 0), affinity: .downstream, dataSource: d)
        s = TestSelection(anchor: string.index(at: 31), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 33), affinity: .upstream, dataSource: d)
    }

    func testMovePage() {
        let string = """
        abc
        def
        0123456789wrap
        ghi
        !@#$%^&*()
        mno
        pqr
        stu
        vwx
        """
        let d = TestTextLayoutDataSource(content: string, charsPerLine: 10, linesInViewport: 3)

        var s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "r", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .pageDown, caret: "n", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .pageDown, caret: "w", affinity: .downstream, dataSource: d)
        s = moveAndAssert(s, direction: .pageDown, caretAt:  string.endIndex, affinity: .upstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .pageDown, dataSource: d)
        s = moveAndAssert(s, direction: .pageUp, caretAfter: "o", affinity: .downstream, dataSource: d)

        // Going to a line wrap boundary yields an upstream caret. Start after ")"
        s = TestSelection(caretAt: string.index(at: 37), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "w", affinity: .upstream, dataSource: d)

        s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)
        s = moveAndAssertNoop(s, direction: .pageUp, dataSource: d)
        s = moveAndAssert(s, direction: .pageDown, caret: "w", affinity: .downstream, dataSource: d)
    }

    func testMovePageFromSelection() {
        let string = """
        abc
        def
        0123456789wrap
        ghi
        !@#$%^&*()
        mno
        pqr
        stu
        vwx
        """
        let d = TestTextLayoutDataSource(content: string, charsPerLine: 10, linesInViewport: 3)

        // "abc" downstream
        var s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 3), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "w", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 0), head: string.index(at: 3), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)

        // "abc" upstream
        s = TestSelection(anchor: string.index(at: 3), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "w", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 3), head: string.index(at: 0), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)

        // "0123456789" downstream
        s = TestSelection(anchor: string.index(at: 8), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "!", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 8), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)

        // "0123456789" upstream
        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 8), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "!", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 8), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)

        // "wrap" downstream
        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 22), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "m", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 18), head: string.index(at: 22), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)

        // "wrap" upstream
        s = TestSelection(anchor: string.index(at: 22), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "m", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 22), head: string.index(at: 18), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "a", affinity: .downstream, dataSource: d)

        // "ra" downstream
        s = TestSelection(anchor: string.index(at: 19), head: string.index(at: 21), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "n", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 19), head: string.index(at: 21), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "b", affinity: .downstream, dataSource: d)

        // "ra" upstream
        s = TestSelection(anchor: string.index(at: 21), head: string.index(at: 19), granularity: .character)
        s = moveAndAssert(s, direction: .pageDown, caret: "n", affinity: .downstream, dataSource: d)

        s = TestSelection(anchor: string.index(at: 21), head: string.index(at: 19), granularity: .character)
        s = moveAndAssert(s, direction: .pageUp, caret: "b", affinity: .downstream, dataSource: d)
    }

    func testExtendSelectionByCharacter() {
        let string = "Hello, world!"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "!"
        var s = TestSelection(caretAt: string.index(at: 12), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .right, selected: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .right, dataSource: d)
        s = extendAndAssert(s, direction: .left, caret: "!", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .left, selected: "d", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .right, caret: "!", affinity: .downstream, dataSource: d)

        // caret at "e"
        s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
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
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "b"
        var s = TestSelection(caretAt: string.index(at: 15), affinity: .downstream, granularity: .character)
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
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "a"
        var s = TestSelection(caretAt: string.index(at: 7), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .wordRight, selected: "ar", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .wordRight, selected: "ar) qux", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .wordRight, dataSource: d)
        s = extendAndAssert(s, direction: .wordLeft, selected: "ar) ", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .wordLeft, caret: "a", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .wordLeft, selected: "b", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .wordLeft, selected: "foo; (b", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .wordLeft, dataSource: d)
        s = extendAndAssert(s, direction: .wordRight, selected: "; (b", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .wordRight, caret: "a", affinity: .downstream, dataSource: d)
    }

    func testExtendSelectionByLineEmpty() {
        let string = ""
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        var s = TestSelection(caretAt: string.startIndex, affinity: .upstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, caretAt: string.startIndex, affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByLineSoftWrap() {
        let string = "Hello, world!"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10) // Wraps after "r"

        // caret at "o"
        var s = TestSelection(caretAt: string.index(at: 8), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfLine, selected: "or", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "Hello, wor", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)

        // caret at "o"
        s = TestSelection(caretAt: string.index(at: 8), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "Hello, w", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .endOfLine, selected: "Hello, wor", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)

        // caret at "H" - can't expand to beginning
        s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfLine, caret: "H", affinity: .downstream, dataSource: d)

        // caret at end - can't expand to end
        s = TestSelection(caretAt: string.index(at: 13), affinity: .upstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfLine, caretAt: string.index(at: 13), affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByLineHardWrap() {
        let string = "foo\nbar\nqux"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at first "a"
        var s = TestSelection(caretAt: string.index(at: 5), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfLine, selected: "ar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "bar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)

        // caret at first "a"
        s = TestSelection(caretAt: string.index(at: 5), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfLine, selected: "b", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfLine, dataSource: d)
        s = extendAndAssert(s, direction: .endOfLine, selected: "bar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfLine, dataSource: d)
    }

    func testExtendSelectionByParagraph() {
        var string = """
        foo
        0123456789wrap
        bar
        """
        var d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "5"
        var s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfParagraph, selected: "56789wrap", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfParagraph, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfParagraph, selected: "0123456789wrap", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfParagraph, dataSource: d)

        // caret at "5"
        s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfParagraph, selected: "01234", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfParagraph, dataSource: d)
        s = extendAndAssert(s, direction: .endOfParagraph, selected: "0123456789wrap", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfParagraph, dataSource: d)

        // caret at "f" - nothing to select left
        s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfParagraph, caret: "f", affinity: .downstream, dataSource: d)

        // caret at "r" - nothing to select right
        s = TestSelection(caretAt: string.index(at: 22), affinity: .upstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 22), affinity: .upstream, dataSource: d)

        string = """
        foo

        """
        d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "\n"
        s = TestSelection(caretAt: string.index(at: 4), affinity: .upstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfParagraph, caretAt: string.index(at: 4), affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .endOfParagraph, caretAt: string.index(at: 4), affinity: .upstream, dataSource: d)
    }

    // paragraphBackward and paragraphForward are only used for extending selection, and
    // can select multiple paragraphs.
    func testExtendSelectionByParagraphBackwardForwards() {
        let string = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "5"
        var s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "01234", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "foo\n01234", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .paragraphBackward, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "01234", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "0123456789wrap\n", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "0123456789wrap\nbar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .paragraphForward, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "0123456789wrap\n", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "foo\n0123456789wrap\n", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "0123456789wrap\n", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "0123456789wrap\nbar", affinity: .downstream, dataSource: d)

        // caret at "5"
        s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "56789wrap\n", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "0123456789wrap\n", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "0123456789wrap\nbar", affinity: .downstream, dataSource: d)

        // caret at "5"
        s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "01234", affinity: .upstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphForward, selected: "0123456789wrap\n", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .paragraphBackward, selected: "foo\n0123456789wrap\n", affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByDocument() {
        let string = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // caret at "5"
        var s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfDocument, selected: "56789wrap\nbar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfDocument, dataSource: d)
        s = extendAndAssert(s, direction: .beginningOfDocument, selected: "foo\n0123456789wrap\nbar", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfDocument, dataSource: d)

        // caret at "5"
        s = TestSelection(caretAt: string.index(at: 9), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfDocument, selected: "foo\n01234", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .beginningOfDocument, dataSource: d)
        s = extendAndAssert(s, direction: .endOfDocument, selected: "foo\n0123456789wrap\nbar", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .endOfDocument, dataSource: d)

        // caret at "f" - nothing to select left
        s = TestSelection(caretAt: string.index(at: 0), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .beginningOfDocument, caret: "f", affinity: .downstream, dataSource: d)

        // caret at "r" - nothing to select right
        s = TestSelection(caretAt: string.index(at: 22), affinity: .upstream, granularity: .character)
        s = extendAndAssert(s, direction: .endOfDocument, caretAt: string.index(at: 22), affinity: .upstream, dataSource: d)
    }

    func testExtendSelectionByPage() {
        let string = """
        abc
        def
        0123456789wrap
        ghi
        !@#$%^&*()
        mno
        pqr
        stu
        vwx
        """
        let d = TestTextLayoutDataSource(content: string, charsPerLine: 10, linesInViewport: 3)

        var s = TestSelection(caretAt: string.index(at: 1), affinity: .downstream, granularity: .character)
        s = extendAndAssert(s, direction: .pageDown, selected: "bc\ndef\n0123456789w", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .pageDown, selected: "bc\ndef\n0123456789wrap\nghi\n!@#$%^&*()\nm", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .pageDown, selected: "bc\ndef\n0123456789wrap\nghi\n!@#$%^&*()\nmno\npqr\nstu\nv", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .pageDown, selected: "bc\ndef\n0123456789wrap\nghi\n!@#$%^&*()\nmno\npqr\nstu\nvwx", affinity: .downstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .pageDown, dataSource: d)
        s = extendAndAssert(s, direction: .pageUp, selected: "bc\ndef\n0123456789wrap\nghi\n!@#$%^&*()\nm", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .pageUp, selected: "bc\ndef\n0123456789w", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .pageUp, caret: "b", affinity: .downstream, dataSource: d)
        s = extendAndAssert(s, direction: .pageUp, selected: "a", affinity: .upstream, dataSource: d)
        s = extendAndAssertNoop(s, direction: .pageUp, dataSource: d)
        s = extendAndAssert(s, direction: .pageDown, selected: "bc\ndef\n0123456789w", affinity: .downstream, dataSource: d)
    }

    func extendAndAssert(_ s: TestSelection, direction: Movement, caret c: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extending: direction, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssert(_ s: TestSelection, direction: Movement, selected string: String, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extending: direction, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func extendAndAssertNoop(_ s: TestSelection, direction: Movement, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extending: direction, dataSource: dataSource)
        XCTAssertEqual(s, s2, file: file, line: line)
        return s2
    }

    func extendAndAssert(_ s: TestSelection, direction: Movement, caretAt caret: String.Index, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extending: direction, dataSource: dataSource)
        assert(selection: s2, hasCaretAt: caret, affinity: affinity, granularity: granularity, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: TestSelection, direction: Movement, caret c: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(moving: direction, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: c, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: TestSelection, direction: Movement, caretAfter c: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(moving: direction, dataSource: dataSource)
        assert(selection: s2, hasCaretAfter: c, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: TestSelection, direction: Movement, selected string: String, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(moving: direction, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func moveAndAssertNoop(_ s: TestSelection, direction: Movement, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(moving: direction, dataSource: dataSource)
        XCTAssertEqual(s, s2, file: file, line: line)
        return s2
    }

    func moveAndAssert(_ s: TestSelection, direction: Movement, caretAt caret: String.Index, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(moving: direction, dataSource: dataSource)
        assert(selection: s2, hasCaretAt: caret, affinity: affinity, granularity: granularity, file: file, line: line)
        return s2
    }


    // MARK: - Deletion

    func testDeleteBackward() {
        let s = "abc def ghi"
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "f"
        var sel = TestSelection(caretAt: s.index(at: 6), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .left, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 6))

        // "def"
        sel = TestSelection(anchor: s.index(at: 4), head: s.index(at: 7), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .left, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 7))
    }

    func testDeleteBackwardWithDecomposition() {
        func t(_ s: String, _ selectedRange: Range<Int>, _ expectedRange: Range<Int>, _ expectedString: String, file: StaticString = #file, line: UInt = #line) {
            let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)
            let sel: TestSelection
            if selectedRange.isEmpty {
                sel = TestSelection(caretAt: s.index(at: selectedRange.lowerBound), affinity: .downstream, granularity: .character)
            } else {
                sel = TestSelection(anchor: s.index(at: selectedRange.lowerBound), head: s.index(at: selectedRange.upperBound), granularity: .character)
            }

            let (range, string) = SelectionNavigator(sel).replacementForDeleteBackwardsByDecomposing(dataSource: d)
            XCTAssertEqual(range, s.index(at: expectedRange.lowerBound)..<s.index(at: expectedRange.upperBound), file: file, line: line)
            XCTAssertEqual(string, expectedString, file: file, line: line)
        }

        t("a", 0..<0, 0..<0, "")
        t("a", 0..<1, 0..<1, "")
        t("a", 1..<1, 0..<1, "")

        t("a\u{0301}", 0..<0, 0..<0, "")
        t("a\u{0301}", 0..<1, 0..<1, "")
        t("a\u{0301}", 1..<1, 0..<1, "a")

        t("á", 0..<0, 0..<0, "")
        t("á", 0..<1, 0..<1, "")
        t("á", 1..<1, 0..<1, "a")

        t("ṩ", 0..<0, 0..<0, "")
        t("ṩ", 0..<1, 0..<1, "")
        t("ṩ", 1..<1, 0..<1, "s\u{0323}") // ṣ
        t("s\u{0323}", 1..<1, 0..<1, "s")

        t("s\u{0323}\u{0307}", 0..<0, 0..<0, "") // ṩ
        t("s\u{0323}\u{0307}", 0..<1, 0..<1, "")
        t("s\u{0323}\u{0307}", 1..<1, 0..<1, "s\u{0323}") // ṣ

        t("👨‍👩‍👧‍👦", 0..<0, 0..<0, "")
        t("👨‍👩‍👧‍👦", 0..<1, 0..<1, "")
        t("👨‍👩‍👧‍👦", 1..<1, 0..<1, "👨‍👩‍👧")
        t("👨‍👩‍👧", 1..<1, 0..<1, "👨‍👩")
        t("👨‍👩", 1..<1, 0..<1, "👨")
        t("👨", 1..<1, 0..<1, "")

        t("🇺🇸", 0..<0, 0..<0, "")
        t("🇺🇸", 0..<1, 0..<1, "")
        t("🇺🇸", 1..<1, 0..<1, "🇺")
        t("🇺", 1..<1, 0..<1, "")
    }

    func testDeleteForward() {
        let s = "abc def ghi"
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "f"
        var sel = TestSelection(caretAt: s.index(at: 6), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .right, dataSource: d)
        XCTAssertEqual(r, s.index(at: 6)..<s.index(at: 7))

        // "def"
        sel = TestSelection(anchor: s.index(at: 4), head: s.index(at: 7), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .right, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 7))
    }

    func testDeleteWordForward() {
        let s = "abc def ghi"
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "e"
        var sel = TestSelection(caretAt: s.index(at: 5), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .wordRight, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 7))

        // "e"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 6), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .wordRight, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 6))
    }

    func testDeleteWordBackward() {
        let s = "abc def ghi"
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "f"
        var sel = TestSelection(caretAt: s.index(at: 6), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .wordLeft, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 6))

        // "e"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 6), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .wordLeft, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 6))
    }

    func testDeleteToBeginningOfLine() {
        let s = "0123456789wrap"
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 5), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 0)..<s.index(at: 5))

        // caret at "0"
        sel = TestSelection(caretAt: s.index(at: 0), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 0)..<s.index(at: 0))

        // caret after "9" (upstream)
        sel = TestSelection(caretAt: s.index(at: 10), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 0)..<s.index(at: 10))

        // caret at "w"
        sel = TestSelection(caretAt: s.index(at: 10), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 10)..<s.index(at: 10))

        // caret at "p"
        sel = TestSelection(caretAt: s.index(at: 13), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 10)..<s.index(at: 13))

        // "123"
        sel = TestSelection(anchor: s.index(at: 1), head: s.index(at: 4), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 1)..<s.index(at: 4))
    }

    func testDeleteToEndOfLine() {
        let s = "0123456789wrap"
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 5), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 10))

        // caret at "0"
        sel = TestSelection(caretAt: s.index(at: 0), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 0)..<s.index(at: 10))

        // caret after "9" (upstream)
        sel = TestSelection(caretAt: s.index(at: 10), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 10)..<s.index(at: 10))

        // caret at "w"
        sel = TestSelection(caretAt: s.index(at: 10), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 10)..<s.index(at: 14))

        // caret at "p"
        sel = TestSelection(caretAt: s.index(at: 13), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 13)..<s.index(at: 14))

        // caret after "p"
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 14)..<s.index(at: 14))

        // "123"
        sel = TestSelection(anchor: s.index(at: 1), head: s.index(at: 4), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d)
        XCTAssertEqual(r, s.index(at: 1)..<s.index(at: 4))


        // don't delete trailing newline
        let s2 = "foo\nbar"
        let d2 = TestTextLayoutDataSource(string: s2, charsPerLine: 10)

        // caret at second "o"
        sel = TestSelection(caretAt: s2.index(at: 2), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d2)
        XCTAssertEqual(r, s2.index(at: 2)..<s2.index(at: 3))

        // caret at "\n"
        sel = TestSelection(caretAt: s2.index(at: 3), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfLine, dataSource: d2)
        XCTAssertEqual(r, s2.index(at: 3)..<s2.index(at: 3))
    }

    func testDeleteToBeginningOfParagraph() {
        let s = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 9), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 9))

        // caret at "0"
        sel = TestSelection(caretAt: s.index(at: 4), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 4))

        // caret after "9" (upstream)
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 14))

        // caret at "w"
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 14))

        // caret at "p"
        sel = TestSelection(caretAt: s.index(at: 18), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 18))

        // "123"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 8), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 8))
    }

    func testDeleteToEndOfParagraph() {
        let s = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 9), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 9)..<s.index(at: 18))

        // caret at "0"
        sel = TestSelection(caretAt: s.index(at: 4), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 18))

        // caret after "9" (upstream)
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 14)..<s.index(at: 18))

        // caret at "w"
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 14)..<s.index(at: 18))

        // caret at "p" – we're at the end of a paragraph, so delete the trailing newline
        sel = TestSelection(caretAt: s.index(at: 18), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 18)..<s.index(at: 19))

        // caret at end
        sel = TestSelection(caretAt: s.index(at: 22), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 22)..<s.index(at: 22))

        // "123"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 8), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfParagraph, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 8))
    }

    // deletion ranges for paragraphBackward/paragraphForward are the same as for beginningOfParagraph/endOfParagraph
    func testDeleteParagraphBackward() {
        let s = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 9), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphBackward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 9))

        // caret at "0"
        sel = TestSelection(caretAt: s.index(at: 4), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphBackward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 4))

        // caret after "9" (upstream)
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphBackward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 14))

        // caret at "w"
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphBackward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 14))

        // caret at "p"
        sel = TestSelection(caretAt: s.index(at: 18), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphBackward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 18))

        // "123"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 8), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphBackward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 8))

    }

    func testDeleteParagraphForward() {
        let s = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 9), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 9)..<s.index(at: 18))

        // caret at "0"
        sel = TestSelection(caretAt: s.index(at: 4), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 4)..<s.index(at: 18))

        // caret after "9" (upstream)
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 14)..<s.index(at: 18))

        // caret at "w"
        sel = TestSelection(caretAt: s.index(at: 14), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 14)..<s.index(at: 18))

        // caret at "p" – we're at the end of a paragraph, so delete the trailing newline
        sel = TestSelection(caretAt: s.index(at: 18), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 18)..<s.index(at: 19))

        // caret at end
        sel = TestSelection(caretAt: s.index(at: 22), affinity: .upstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 22)..<s.index(at: 22))

        // "123"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 8), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .paragraphForward, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 8))
    }

    func testDeleteBeginningOfDocument() {
        let s = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 9), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfDocument, dataSource: d)
        XCTAssertEqual(r, s.index(at: 0)..<s.index(at: 9))

        // caret at "f"
        sel = TestSelection(caretAt: s.index(at: 0), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfDocument, dataSource: d)
        XCTAssertEqual(r, s.index(at: 0)..<s.index(at: 0))

        // "123"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 8), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .beginningOfDocument, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 8))
    }

    func testDeleteEndOfDocument() {
        let s = """
        foo
        0123456789wrap
        bar
        """
        let d = TestTextLayoutDataSource(string: s, charsPerLine: 10)

        // caret at "5"
        var sel = TestSelection(caretAt: s.index(at: 9), affinity: .downstream, granularity: .character)
        var r = SelectionNavigator(sel).rangeToDelete(movement: .endOfDocument, dataSource: d)
        XCTAssertEqual(r, s.index(at: 9)..<s.index(at: 22))

        // caret at end
        sel = TestSelection(caretAt: s.index(at: 22), affinity: .downstream, granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfDocument, dataSource: d)
        XCTAssertEqual(r, s.index(at: 22)..<s.index(at: 22))

        // "123"
        sel = TestSelection(anchor: s.index(at: 5), head: s.index(at: 8), granularity: .character)
        r = SelectionNavigator(sel).rangeToDelete(movement: .endOfDocument, dataSource: d)
        XCTAssertEqual(r, s.index(at: 5)..<s.index(at: 8))
    }

    // MARK: - Mouse navigation

    func testClickingOnEmptyString() {
        let string = ""
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)
        
        clickAndAssert(CGPoint(x: 0, y: -0.001), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: -0.001), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        
        clickAndAssert(CGPoint(x: 0, y: 0), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 0), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        
        clickAndAssert(CGPoint(x: 0, y: 13.999), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 13.999), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        
        clickAndAssert(CGPoint(x: 0, y: 14), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 14), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        
        clickAndAssert(CGPoint(x: 0, y: 100), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 100), caretAt: string.index(at: 0), affinity: .upstream, dataSource: d)
    }

    func testClickingOnNewline() {
        let string = "\n"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        clickAndAssert(CGPoint(x: 0, y: -0.001), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: -0.001), caret: "\n", affinity: .downstream, dataSource: d)

        clickAndAssert(CGPoint(x: 0, y: 0), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 0), caret: "\n", affinity: .downstream, dataSource: d)

        clickAndAssert(CGPoint(x: 0, y: 13.999), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 13.999), caret: "\n", affinity: .downstream, dataSource: d)

        clickAndAssert(CGPoint(x: 0, y: 14), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 14), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)

        clickAndAssert(CGPoint(x: 0, y: 27.999), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 27.999), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)

        clickAndAssert(CGPoint(x: 0, y: 28), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 28), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)

        clickAndAssert(CGPoint(x: 0, y: 100), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 100), caretAt: string.index(at: 1), affinity: .upstream, dataSource: d)
    }

    func testClicking() {
        let string = """
        0123456789wrap
        hello

        """
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // first fragment

        // before the document
        clickAndAssert(CGPoint(x: 0, y: -0.001), caret: "0", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: -0.001), caret: "0", affinity: .downstream, dataSource: d)

        // first half of "0"
        clickAndAssert(CGPoint(x: 0, y: 0), caret: "0", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 0, y: 13.999), caret: "0", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 3.999, y: 0), caret: "0", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 3.999, y: 13.999), caret: "0", affinity: .downstream, dataSource: d)

        // second half of "0"
        clickAndAssert(CGPoint(x: 4, y: 0), caret: "1", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 4, y: 13.999), caret: "1", affinity: .downstream, dataSource: d)

        // first half of "1"
        clickAndAssert(CGPoint(x: 11.999, y: 0), caret: "1", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 11.999, y: 13.999), caret: "1", affinity: .downstream, dataSource: d)

        // second half of "4"
        clickAndAssert(CGPoint(x: 36, y: 0), caret: "5", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 36, y: 13.999), caret: "5", affinity: .downstream, dataSource: d)

        // first half of "5"
        clickAndAssert(CGPoint(x: 43.999, y: 0), caret: "5", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 43.999, y: 13.999), caret: "5", affinity: .downstream, dataSource: d)

        // second half of "5"
        clickAndAssert(CGPoint(x: 44, y: 0), caret: "6", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 44, y: 13.999), caret: "6", affinity: .downstream, dataSource: d)

        // first half of "9"
        clickAndAssert(CGPoint(x: 75.999, y: 0), caret: "9", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 75.999, y: 13.999), caret: "9", affinity: .downstream, dataSource: d)

        // second half of "9"
        clickAndAssert(CGPoint(x: 76, y: 0), caret: "w", affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 76, y: 13.999), caret: "w", affinity: .upstream, dataSource: d)

        // all the way to the right
        clickAndAssert(CGPoint(x: 100, y: 0), caret: "w", affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 13.999), caret: "w", affinity: .upstream, dataSource: d)

        // second fragment

        // first half of "w"
        clickAndAssert(CGPoint(x: 0, y: 14), caret: "w", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 0, y: 27.999), caret: "w", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 3.999, y: 14), caret: "w", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 3.999, y: 27.999), caret: "w", affinity: .downstream, dataSource: d)

        // first half of "p"
        clickAndAssert(CGPoint(x: 27.999, y: 14), caret: "p", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 27.999, y: 27.999), caret: "p", affinity: .downstream, dataSource: d)

        // second half of "p"
        clickAndAssert(CGPoint(x: 28, y: 14), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 28, y: 27.999), caret: "\n", affinity: .downstream, dataSource: d)

        // all the way to the right – you can't click to the right of a newline
        clickAndAssert(CGPoint(x: 100, y: 14), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 27.999), caret: "\n", affinity: .downstream, dataSource: d)

        // third fragment

        // first half of "h"
        clickAndAssert(CGPoint(x: 0, y: 28), caret: "h", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 0, y: 41.999), caret: "h", affinity: .downstream, dataSource: d)

        // second half of "h"
        clickAndAssert(CGPoint(x: 4, y: 28), caret: "e", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 4, y: 41.999), caret: "e", affinity: .downstream, dataSource: d)

        // first half of "o"
        clickAndAssert(CGPoint(x: 35.999, y: 28), caret: "o", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 35.999, y: 41.999), caret: "o", affinity: .downstream, dataSource: d)

        // second half of "o"
        clickAndAssert(CGPoint(x: 36, y: 28), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 36, y: 41.999), caret: "\n", affinity: .downstream, dataSource: d)

        // all the way to the right – you can't click to the right of a newline
        clickAndAssert(CGPoint(x: 100, y: 28), caret: "\n", affinity: .downstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 41.999), caret: "\n", affinity: .downstream, dataSource: d)

        // fourth fragment

        // you're always upstream of the end
        clickAndAssert(CGPoint(x: 0, y: 42), caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 0, y: 100), caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 42), caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        clickAndAssert(CGPoint(x: 100, y: 100), caretAt: string.endIndex, affinity: .upstream, dataSource: d)
    }

    func testDraggingEmptyString() {
        let string = ""
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // click
        var s = clickAndAssert(CGPoint(x: 0, y: 0), caretAt: string.startIndex, affinity: .upstream, dataSource: d)
        // drag right
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 0), caretAt: string.startIndex, affinity: .upstream, dataSource: d)
        // drag left
        s = dragAndAssert(s, point: CGPoint(x: -100, y: 0), caretAt: string.startIndex, affinity: .upstream, dataSource: d)
    }

    func testDraggingNewline() {
        let string = "\n"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // click
        var s = clickAndAssert(CGPoint(x: 0, y: 0), caret: "\n", affinity: .downstream, dataSource: d)
        // drag right
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 0), caret: "\n", affinity: .downstream, dataSource: d)
        // drag left
        s = dragAndAssert(s, point: CGPoint(x: -100, y: 0), caret: "\n", affinity: .downstream, dataSource: d)
    }

    func testDragging() {
        let string = """
        0123456789wrap
        hello
        """

        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // click at "5"
        var s = clickAndAssert(CGPoint(x: 40, y: 0), caret: "5", affinity: .downstream, dataSource: d)

        // drag to "1"
        s = dragAndAssert(s, point: CGPoint(x: 11.999, y: 0), selected: "1234", affinity: .upstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 11.999, y: 13.999), selected: "1234", affinity: .upstream, dataSource: d)

        // drag to "5"
        s = dragAndAssert(s, point: CGPoint(x: 43.999, y: 0), caret: "5", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 43.999, y: 13.999), caret: "5", affinity: .downstream, dataSource: d)

        // drag far to the right
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 0), selected: "56789", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 13.999), selected: "56789", affinity: .downstream, dataSource: d)

        // drag down to next line
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 14), selected: "56789wrap", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 27.999), selected: "56789wrap", affinity: .downstream, dataSource: d)

        // drag back to "a"
        s = dragAndAssert(s, point: CGPoint(x: 19.999, y: 14), selected: "56789wr", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 19.999, y: 27.999), selected: "56789wr", affinity: .downstream, dataSource: d)

        // drag down to "h" - the newline is selected
        s = dragAndAssert(s, point: CGPoint(x: 0, y: 28), selected: "56789wrap\n", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 0, y: 41.999), selected: "56789wrap\n", affinity: .downstream, dataSource: d)

        // click after "9"
        s = clickAndAssert(CGPoint(x: 76, y: 0), caret: "w", affinity: .upstream, dataSource: d)

        // drag down to "w"
        s = dragAndAssert(s, point: CGPoint(x: 0, y: 14), caret: "w", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 0, y: 27.999), caret: "w", affinity: .downstream, dataSource: d)

        // drag right half way through "w"
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 14), selected: "w", affinity: .downstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 27.999), selected: "w", affinity: .downstream, dataSource: d)

        // drag up and left before "9"
        s = dragAndAssert(s, point: CGPoint(x: 75.999, y: 0), selected: "9", affinity: .upstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 75.999, y: 13.999), selected: "9", affinity: .upstream, dataSource: d)

        // drag right, back to "w"
        s = dragAndAssert(s, point: CGPoint(x: 76, y: 0), caret: "w", affinity: .upstream, dataSource: d)
        s = dragAndAssert(s, point: CGPoint(x: 76, y: 13.999), caret: "w", affinity: .upstream, dataSource: d)
    }

    // A regression test for a crash
    func testDraggingWordEmptyLastLine() {
        let string = """
        0123456789wrap
        hello

        """

        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // empty last line
        var s = TestSelection(caretAt: string.index(at: 21), affinity: .upstream, granularity: .word)

        // drag to the right
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 42), caretAt: string.index(at: 21), affinity: .upstream, granularity: .word, dataSource: d)
    }

    // MARK: Granularity

    func testExtendSelectionToEnclosingEmpty() {
        let string = ""
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)
        
        var s = TestSelection(caretAt: string.startIndex, affinity: .upstream, granularity: .character)
        s = SelectionNavigator(s).selection(for: .word, enclosing: CGPoint(x: 0, y: 0), dataSource: d)
        assert(selection: s, hasCaretAt: string.startIndex, affinity: .upstream, granularity: .word)

        s = SelectionNavigator(s).selection(for: .line, enclosing: CGPoint(x: 0, y: 0), dataSource: d)
        assert(selection: s, hasCaretAt: string.startIndex, affinity: .upstream, granularity: .line)

        s = SelectionNavigator(s).selection(for: .paragraph, enclosing: CGPoint(x: 0, y: 0), dataSource: d)
        assert(selection: s, hasCaretAt: string.startIndex, affinity: .upstream, granularity: .paragraph)
    }

    func testExtendSelectionToEnclosing() {
        let string = """
        01234 6789wrap
        hello
        """

        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // before "0"
        var s = clickAndAssert(CGPoint(x: -1, y: 0), caret: "0", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: -1, y: 0), selected: "01234", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: -1, y: 0), selected: "01234 6789", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: -1, y: 0), selected: "01234 6789wrap\n", affinity: .downstream, dataSource: d)

        
        // before " "
        s = clickAndAssert(CGPoint(x: 39.999, y: 0), caret: " ", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 39.999, y: 0), selected: "01234", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: 39.999, y: 0), selected: "01234 6789", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: 39.999, y: 0), selected: "01234 6789wrap\n", affinity: .downstream, dataSource: d)


        // caret at " "
        s = clickAndAssert(CGPoint(x: 40, y: 0), caret: " ", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 40, y: 0), selected: " ", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: 40, y: 0), selected: "01234 6789", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: 40, y: 0), selected: "01234 6789wrap\n", affinity: .downstream, dataSource: d)

        // after "9"
        s = clickAndAssert(CGPoint(x: 100, y: 0), caret: "w", affinity: .upstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 100, y: 0), selected: "6789wrap", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: 100, y: 0), selected: "01234 6789", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: 100, y: 0), selected: "01234 6789wrap\n", affinity: .downstream, dataSource: d)

        // before "w"
        s = clickAndAssert(CGPoint(x: -11, y: 14), caret: "w", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: -1, y: 14), selected: "6789wrap", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: -1, y: 14), selected: "wrap\n", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: -1, y: 14), selected: "01234 6789wrap\n", affinity: .downstream, dataSource: d)

        // after "p"
        s = clickAndAssert(CGPoint(x: 100, y: 14), caret: "\n", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 100, y: 14), selected: "6789wrap", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: 100, y: 14), selected: "wrap\n", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: 100, y: 14), selected: "01234 6789wrap\n", affinity: .downstream, dataSource: d)

        // before "h"
        s = clickAndAssert(CGPoint(x: -1, y: 28), caret: "h", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: -1, y: 28), selected: "hello", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: -1, y: 28), selected: "hello", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: -1, y: 28), selected: "hello", affinity: .downstream, dataSource: d)

        // after "o"
        s = clickAndAssert(CGPoint(x: 100, y: 28), caretAt: string.endIndex, affinity: .upstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 100, y: 28), selected: "hello", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: 100, y: 28), selected: "hello", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: 100, y: 28), selected: "hello", affinity: .downstream, dataSource: d)
    }

    func testExtendingSelectionToWordApostrophe() {
        let string = "foo bar's baz’s 'qux' a’'b"
        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // just before "bar's"
        var s = clickAndAssert(CGPoint(x: 31.999, y: 0), caret: "b", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 31.999, y: 0), selected: " ", affinity: .downstream, dataSource: d)

        // at "bar's"
        s = clickAndAssert(CGPoint(x: 32, y: 0), caret: "b", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 32, y: 0), selected: "bar's", affinity: .downstream, dataSource: d)

        // at "'" in "bar's"
        s = clickAndAssert(CGPoint(x: 56, y: 0), caret: "'", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 56, y: 0), selected: "bar's", affinity: .downstream, dataSource: d)

        // just before " " after "bar's"
        s = clickAndAssert(CGPoint(x: 71.999, y: 0), caret: " ", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 71.999, y: 0), selected: "bar's", affinity: .downstream, dataSource: d)

        // at " "
        s = clickAndAssert(CGPoint(x: 72, y: 0), caret: " ", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 72, y: 0), selected: " ", affinity: .downstream, dataSource: d)

        // at "baz’s"
        s = clickAndAssert(CGPoint(x: 0, y: 14), caret: "b", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 0, y: 14), selected: "baz’s", affinity: .downstream, dataSource: d)

        // at "'" before qux
        s = clickAndAssert(CGPoint(x: 48, y: 14), caret: "'", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 48, y: 14), selected: "'", affinity: .downstream, dataSource: d)

        // at "qux"
        s = clickAndAssert(CGPoint(x: 56, y: 14), caret: "q", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 56, y: 14), selected: "qux", affinity: .downstream, dataSource: d)

        // at "'" after qux
        s = clickAndAssert(CGPoint(x: 0, y: 28), caret: "'", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 0, y: 28), selected: "'", affinity: .downstream, dataSource: d)

        // at "a"
        s = clickAndAssert(CGPoint(x: 16, y: 28), caret: "a", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 16, y: 28), selected: "a", affinity: .downstream, dataSource: d)

        // at "’"
        s = clickAndAssert(CGPoint(x: 24, y: 28), caret: "’", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 24, y: 28), selected: "’", affinity: .downstream, dataSource: d)

        // at "'"
        s = clickAndAssert(CGPoint(x: 32, y: 28), caret: "'", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 32, y: 28), selected: "'", affinity: .downstream, dataSource: d)

        // at "b"
        s = clickAndAssert(CGPoint(x: 40, y: 28), caret: "b", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 40, y: 28), selected: "b", affinity: .downstream, dataSource: d)
    }

    func testExtendSelectionInteractingAtWordGranularity() {
        let string = """
        foo bar quwrap
        hello
        """

        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // at "b"
        var s = clickAndAssert(CGPoint(x: 32, y: 0), caret: "b", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .word, point: CGPoint(x: 32, y: 0), selected: "bar", affinity: .downstream, dataSource: d)

        // drag left to " "
        s = dragAndAssert(s, point: CGPoint(x: 28, y: 0), selected: "bar", affinity: .downstream, granularity: .word, dataSource: d)
        // drag left through " "
        s = dragAndAssert(s, point: CGPoint(x: 27.999, y: 0), selected: " bar", affinity: .upstream, granularity: .word, dataSource: d)
        // drag left to "o"
        s = dragAndAssert(s, point: CGPoint(x: 20, y: 0), selected: " bar", affinity: .upstream, granularity: .word, dataSource: d)
        // drag left through "o"
        s = dragAndAssert(s, point: CGPoint(x: 19.999, y: 0), selected: "foo bar", affinity: .upstream, granularity: .word, dataSource: d)
        // all the way left
        s = dragAndAssert(s, point: CGPoint(x: -1, y: 0), selected: "foo bar", affinity: .upstream, granularity: .word, dataSource: d)

        // drag right to " " after "bar"
        s = dragAndAssert(s, point: CGPoint(x: 59.999, y: 0), selected: "bar", affinity: .downstream, granularity: .word, dataSource: d)
        // drag right through " " after "bar"
        s = dragAndAssert(s, point: CGPoint(x: 60, y: 0), selected: "bar ", affinity: .downstream, granularity: .word, dataSource: d)
        // drag right to "q"
        s = dragAndAssert(s, point: CGPoint(x: 67.999, y: 0), selected: "bar ", affinity: .downstream, granularity: .word, dataSource: d)
        // drag right through "q"
        s = dragAndAssert(s, point: CGPoint(x: 68, y: 0), selected: "bar quwrap", affinity: .downstream, granularity: .word, dataSource: d)
        // all the way right
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 0), selected: "bar quwrap", affinity: .downstream, granularity: .word, dataSource: d)

        // down through "w"
        s = dragAndAssert(s, point: CGPoint(x: 3.999, y: 14), selected: "bar quwrap", affinity: .downstream, granularity: .word, dataSource: d)
        // after p
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 14), selected: "bar quwrap", affinity: .downstream, granularity: .word, dataSource: d)

        // drag down before "h"
        s = dragAndAssert(s, point: CGPoint(x: 3.999, y: 28), selected: "bar quwrap\n", affinity: .downstream, granularity: .word, dataSource: d)
        // drag down through "h"
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 28), selected: "bar quwrap\nhello", affinity: .downstream, granularity: .word, dataSource: d)
        // all the way right
        s = dragAndAssert(s, point: CGPoint(x: 100, y: 28), selected: "bar quwrap\nhello", affinity: .downstream, granularity: .word, dataSource: d)
        // drag left through "e"
        s = dragAndAssert(s, point: CGPoint(x: 12, y: 28), selected: "bar quwrap\nhello", affinity: .downstream, granularity: .word, dataSource: d)
        // drag up through "r"
        s = dragAndAssert(s, point: CGPoint(x: 12, y: 14), selected: "bar quwrap", affinity: .downstream, granularity: .word, dataSource: d)
        // drag up through first "o"
        s = dragAndAssert(s, point: CGPoint(x: 12, y: 0), selected: "foo bar", affinity: .upstream, granularity: .word, dataSource: d)
    }

    func testExtendSelectionInteractingAtLineGranularity() {
        let string = """
        foo bar quwrap
        hello
        """

        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // at "r"
        var s = clickAndAssert(CGPoint(x: 4, y: 14), caret: "r", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .line, point: CGPoint(x: 4, y: 14), selected: "wrap\n", affinity: .downstream, dataSource: d)

        // drag up to first "o"
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 0), selected: "foo bar quwrap\n", affinity: .upstream, granularity: .line, dataSource: d)

        // drag down to "e"
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 28), selected: "wrap\nhello", affinity: .downstream, granularity: .line, dataSource: d)
    }

    func testExendSelectionInteractingAtParagraphGranularity() {
        let string = """
        foo bar quwrap
        hello
        """

        let d = TestTextLayoutDataSource(string: string, charsPerLine: 10)

        // at "r"
        var s = clickAndAssert(CGPoint(x: 4, y: 14), caret: "r", affinity: .downstream, dataSource: d)
        s = encloseAndAssert(s, enclosing: .paragraph, point: CGPoint(x: 4, y: 14), selected: "foo bar quwrap\n", affinity: .downstream, dataSource: d)

        // drag up to first "o"
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 0), selected: "foo bar quwrap\n", affinity: .downstream, granularity: .paragraph, dataSource: d)

        // drag down to "e"
        s = dragAndAssert(s, point: CGPoint(x: 4, y: 28), selected: "foo bar quwrap\nhello", affinity: .downstream, granularity: .paragraph, dataSource: d)
    }

    @discardableResult
    func clickAndAssert(_ point: CGPoint, caret: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s: TestSelection = SelectionNavigator.selection(interactingAt: point, dataSource: dataSource)
        assert(selection: s, hasCaretBefore: caret, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s
    }

    @discardableResult
    func clickAndAssert(_ point: CGPoint, caretAt: String.Index, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s: TestSelection = SelectionNavigator.selection(interactingAt: point, dataSource: dataSource)
        assert(selection: s, hasCaretAt: caretAt, affinity: affinity, granularity: granularity, file: file, line: line)
        return s
    }
    
    @discardableResult
    func dragAndAssert(_ s: TestSelection, point: CGPoint, caret: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extendingTo: point, dataSource: dataSource)
        assert(selection: s2, hasCaretBefore: caret, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    @discardableResult
    func dragAndAssert(_ s: TestSelection, point: CGPoint, caretAt: String.Index, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extendingTo: point, dataSource: dataSource)
        assert(selection: s2, hasCaretAt: caretAt, affinity: affinity, granularity: granularity, file: file, line: line)
        return s2
    }

    @discardableResult
    func dragAndAssert(_ s: TestSelection, point: CGPoint, selected string: String, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity = .character, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(extendingTo: point, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func encloseAndAssert(_ s: TestSelection, enclosing granularity: TestSelection.Granularity, point: CGPoint, selected string: String, affinity: TestSelection.Affinity, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) -> TestSelection {
        let s2 = SelectionNavigator(s).selection(for: Granularity(granularity), enclosing: point, dataSource: dataSource)
        assert(selection: s2, hasRangeCovering: string, affinity: affinity, granularity: granularity, dataSource: dataSource, file: file, line: line)
        return s2
    }

    func assert(selection: TestSelection, hasCaretBefore c: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(selection.isCaret, "selection is not a caret", file: file, line: line)
        XCTAssertEqual(dataSource.content[selection.range.lowerBound], c, "caret is not at '\(c)'", file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
        XCTAssertEqual(granularity, selection.granularity, file: file, line: line)
    }

    func assert(selection: TestSelection, hasCaretAfter c: Character, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(selection.isCaret, "selection is not a caret", file: file, line: line)
        if selection.range.lowerBound == dataSource.content.endIndex {
            XCTFail("caret is not after '\(c)'", file: file, line: line)
        } else {
            XCTAssertEqual(dataSource.content[dataSource.content.index(before: selection.range.lowerBound)], c, "caret is not after '\(c)'", file: file, line: line)
        }
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
        XCTAssertEqual(granularity, selection.granularity, file: file, line: line)
    }

    func assert(selection: TestSelection, hasRangeCovering string: String, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity, dataSource: TestTextLayoutDataSource, file: StaticString = #file, line: UInt = #line) {
        let range = selection.range
        XCTAssert(selection.isRange, "selection is not a range", file: file, line: line)
        XCTAssertEqual(String(dataSource.content[range]), string, "selection does not contain \"\(string)\"", file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
        XCTAssertEqual(granularity, selection.granularity, file: file, line: line)
    }

    func assert(selection: TestSelection, hasCaretAt caretIndex: String.Index, affinity: TestSelection.Affinity, granularity: TestSelection.Granularity, file: StaticString = #file, line: UInt = #line) {
        XCTAssert(selection.isCaret)
        XCTAssertEqual(selection.lowerBound, caretIndex, file: file, line: line)
        XCTAssertEqual(affinity, selection.affinity, file: file, line: line)
        XCTAssertEqual(granularity, selection.granularity, file: file, line: line)
    }
}
