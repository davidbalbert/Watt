//
//  TransposerTests.swift
//  
//
//  Created by David Albert on 12/6/23.
//

import XCTest
@testable import StandardKeyBindingResponder

fileprivate extension DocumentContentDataSource {
    func index(at offset: Int) -> Index {
        index(startIndex, offsetBy: offset)
    }
}

final class TransposerTests: XCTestCase {
    func testIndicesForTranspose() {
        let tests: [(SimpleContentDataSource, Range<Int>, (Int, Int)?)] = [
            ("", 0..<0, nil),          // empty document
            ("abcde", 0..<0, (0, 1)),  // caret at beginning
            ("abcde", 1..<1, (0, 1)),  // caret in between
            ("abcde", 4..<4, (3, 4)),  // caret in between (before end)
            ("abcde", 5..<5, (3, 4)),  // caret at end (picks previous 2)
            ("abcde", 1..<2, nil),     // single selected character
            ("abcde", 1..<3, (1, 2)),  // two selected characters
            ("abcde", 1..<4, nil),     // 3+ selected characters
        ]

        for (dataSource, range, expected) in tests {
            let r = dataSource.index(at: range.lowerBound)..<dataSource.index(at: range.upperBound)
            let result = Transposer.indicesForTranspose(inSelectedRange: r, dataSource: dataSource)

            if let expected {
                XCTAssertNotNil(result)
                XCTAssertEqual(result!.0, dataSource.index(at: expected.0))
                XCTAssertEqual(result!.1, dataSource.index(at: expected.1))
            } else {
                XCTAssertNil(result)
            }
        }
    }

    func testRangesForTransposeWords() {
        func t(_ dataSource: SimpleContentDataSource, _ range: Range<Int>, _ expected: (Range<Int>, Range<Int>)?, file: StaticString = #file, line: UInt = #line) {
            let r = dataSource.index(at: range.lowerBound)..<dataSource.index(at: range.upperBound)
            let result = Transposer.rangesForTransposeWords(inSelectedRange: r, dataSource: dataSource)

            if let (e1, e2) = expected {
                XCTAssertNotNil(result, "expected (\(e1), \(e2)), got nil", file: file, line: line)
                guard let (w1, w2) = result else {
                    return
                }
                XCTAssertEqual(w1, dataSource.index(at: e1.lowerBound)..<dataSource.index(at: e1.upperBound), file: file, line: line)
                XCTAssertEqual(w2, dataSource.index(at: e2.lowerBound)..<dataSource.index(at: e2.upperBound), file: file, line: line)
            } else {
                XCTAssertNil(result, file: file, line: line)
            }
        }

        // empty document
        t("", 0..<0, nil)

        // single word document (caret)
        t("foo", 0..<0, nil)
        t("foo", 1..<1, nil)
        t("foo", 3..<3, nil)

        // single word document (selection)
        t("foo", 0..<1, nil)
        t("foo", 2..<3, nil)
        t("foo", 0..<3, nil)

        // multi word document (caret)
        t("foo bar baz", 0..<0, (0..<3, 4..<7))
        t("foo bar baz", 1..<1, (0..<3, 4..<7))
        t("foo bar baz", 3..<3, (0..<3, 4..<7))
        // at the start of "bar" picks "foo" and "bar"
        t("foo bar baz", 4..<4, (0..<3, 4..<7))
        // inside "bar" picks "bar" and "baz"
        t("foo bar baz", 5..<5, (4..<7, 8..<11))
        t("foo bar baz", 7..<7, (4..<7, 8..<11))
        t("foo bar baz", 8..<8, (4..<7, 8..<11))
        // inside the last word picks the last two words
        t("foo bar baz", 9..<9, (4..<7, 8..<11))
        t("foo bar baz", 11..<11, (4..<7, 8..<11))

        // leading or trailing whitespace is no-op
        t("  foo bar baz  ", 0..<0, nil)
        t("  foo bar baz  ", 1..<1, nil)
        t("  foo bar baz  ", 2..<2, (2..<5, 6..<9))
        t("  foo bar baz  ", 13..<13, (6..<9, 10..<13))
        t("  foo bar baz  ", 14..<14, nil)
        t("  foo bar baz  ", 15..<15, nil)


        // TODO: leading/trailing whitespace
        // TODO: commas, apostrophes, decimal points
        // TODO: selections
        // TODO: newlines

    }
}
