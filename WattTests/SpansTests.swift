//
//  SpansTests.swift
//  WattTests
//
//  Created by David Albert on 8/23/23.
//

import XCTest

@testable import Watt
final class SpansTests: XCTestCase {
    // MARK: - Regressions

    func testOverlappingMerge() {
        var b1 = SpansBuilder<Int>(totalCount: 3)
        b1.add(1, covering: 0..<3)

        var b2 = SpansBuilder<Int>(totalCount: 3)
        b2.add(2, covering: 2..<3)

        let s1 = b1.build()
        XCTAssertEqual(3, s1.upperBound)
        XCTAssertEqual(1, s1.count)

        var iter = s1.makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertNil(iter.next())

        let s2 = b2.build()
        XCTAssertEqual(3, s2.upperBound)
        XCTAssertEqual(1, s2.count)

        iter = s2.makeIterator()
        XCTAssertEqual(Span(range: 2..<3, data: 2), iter.next())
        XCTAssertNil(iter.next())

        let merged = s1.merging(s2) { left, right in
            if right == nil {
                return 3
            } else {
                return 4
            }
        }

        XCTAssertEqual(3, merged.upperBound)
        XCTAssertEqual(2, merged.count)

        iter = merged.makeIterator()
        XCTAssertEqual(Span(range: 0..<2, data: 3), iter.next())
        XCTAssertEqual(Span(range: 2..<3, data: 4), iter.next())
        XCTAssertNil(iter.next())
    }
}
