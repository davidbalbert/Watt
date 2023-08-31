//
//  SpansTests.swift
//  WattTests
//
//  Created by David Albert on 8/23/23.
//

import XCTest

@testable import Watt
final class SpansTests: XCTestCase {
    // MARK: - Merging adjacent equatable spans
    func testAdjacentEquatableSpansGetMerged() {
        var b = SpansBuilder<Int>(totalCount: 6)
        b.add(1, covering: 0..<3)
        b.add(1, covering: 3..<6)
        var s = b.build()

        XCTAssertEqual(6, s.upperBound)
        XCTAssertEqual(1, s.count)

        var iter = s.makeIterator()
        XCTAssertEqual(Span(range: 0..<6, data: 1), iter.next())
        XCTAssertNil(iter.next())

        b = SpansBuilder<Int>(totalCount: 6)
        b.add(1, covering: 0..<3)
        b.add(2, covering: 3..<6)
        s = b.build()

        XCTAssertEqual(6, s.upperBound)
        XCTAssertEqual(2, s.count)

        iter = s.makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertEqual(Span(range: 3..<6, data: 2), iter.next())
        XCTAssertNil(iter.next())
    }

    func testMergingEquatableSpansWithGapsDoesntMerge() {
        var b = SpansBuilder<Int>(totalCount: 6)
        b.add(1, covering: 0..<3)
        b.add(2, covering: 4..<6)
        let s = b.build()

        XCTAssertEqual(6, s.upperBound)
        XCTAssertEqual(2, s.count)

        var iter = s.makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertEqual(Span(range: 4..<6, data: 2), iter.next())
        XCTAssertNil(iter.next())
    }

    func testNonEquatableSpanDataDoesntMerge() {
        struct NonEquatable {}

        var b = SpansBuilder<NonEquatable>(totalCount: 6)
        b.add(NonEquatable(), covering: 0..<3)
        b.add(NonEquatable(), covering: 3..<6)
        let s = b.build()

        XCTAssertEqual(6, s.upperBound)
        XCTAssertEqual(2, s.count)

        var iter = s.makeIterator()
        XCTAssertEqual(0..<3, iter.next()!.range)
        XCTAssertEqual(3..<6, iter.next()!.range)
        XCTAssertNil(iter.next())
    }

    func testMergingEquatableSpansThatWouldNormallyTakeUpMultipleLeaves() {
        var b = SpansBuilder<Int>(totalCount: 256)
        for i in stride(from: 0, through: 255, by: 2) {
            b.add(1, covering: i..<i+2)
        }
        var s = b.build()

        XCTAssertEqual(256, s.upperBound)
        XCTAssertEqual(1, s.count)
        XCTAssertEqual(0, s.root.height)

        var iter = s.makeIterator()
        XCTAssertEqual(Span(range: 0..<256, data: 1), iter.next())
        XCTAssertNil(iter.next())

        b = SpansBuilder<Int>(totalCount: 256)
        for i in stride(from: 0, through: 255, by: 2) {
            b.add(i, covering: i..<i+2)
        }
        s = b.build()

        XCTAssertEqual(256, s.upperBound)
        XCTAssertEqual(128, s.count)
        XCTAssertEqual(1, s.root.height)
        XCTAssertEqual(2, s.root.children.count)

        iter = s.makeIterator()
        for i in stride(from: 0, through: 255, by: 2) {
            XCTAssertEqual(Span(range: i..<i+2, data: i), iter.next())
        }
    }

    func testSubscriptRange() {
        var b = SpansBuilder<Int>(totalCount: 6)
        b.add(1, covering: 0..<3)
        b.add(2, covering: 3..<6)
        let s = b.build()

        XCTAssertEqual(6, s.upperBound)
        XCTAssertEqual(2, s.count)

        var iter = s[0..<6].makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertEqual(Span(range: 3..<6, data: 2), iter.next())
        XCTAssertNil(iter.next())

        iter = s[0..<3].makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertNil(iter.next())

        iter = s[3..<6].makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 2), iter.next())
        XCTAssertNil(iter.next())

        iter = s[0..<0].makeIterator()
        XCTAssertNil(iter.next())

        iter = s[0..<1].makeIterator()
        XCTAssertEqual(Span(range: 0..<1, data: 1), iter.next())
        XCTAssertNil(iter.next())

        iter = s[5..<6].makeIterator()
        XCTAssertEqual(Span(range: 0..<1, data: 2), iter.next())
        XCTAssertNil(iter.next())

        iter = s[6..<6].makeIterator()
        XCTAssertNil(iter.next())
    }

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
