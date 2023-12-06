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
    // MARK: - transpose:

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
}
