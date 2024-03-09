//
//  SpansTests.swift
//  WattTests
//
//  Created by David Albert on 8/23/23.
//

import XCTest

@testable import Watt

extension Spans {
    subscript(baseBounds bounds: Range<Int>) -> SpansSlice<T> {
        let start = index(withBaseOffset: bounds.lowerBound)
        let end = index(withBaseOffset: bounds.upperBound)
        return self[start..<end]
    }
}

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

    func testSpansSlice() {
        var b = SpansBuilder<Int>(totalCount: 10)
        b.add(1, covering: 1..<3)
        b.add(2, covering: 5..<7)
        b.add(3, covering: 7..<8)
        let s = b.build()

        XCTAssertEqual(10, s.upperBound)

        XCTAssertEqual(3, s.count)
        XCTAssertEqual(10, s.upperBound)
        XCTAssertEqual(1, s.startIndex.position)
        XCTAssertEqual(8, s.endIndex.position)

        XCTAssertEqual(3, s[baseBounds: 0..<10].count)
        XCTAssertEqual(10, s[baseBounds: 0..<10].upperBound)
        XCTAssertEqual(1, s[baseBounds: 0..<10].startIndex.position)
        XCTAssertEqual(8, s[baseBounds: 0..<10].endIndex.position)

        XCTAssertEqual(3, s[baseBounds: 1..<9].count)
        XCTAssertEqual(9, s[baseBounds: 1..<9].upperBound)
        XCTAssertEqual(1, s[baseBounds: 1..<9].startIndex.position)
        XCTAssertEqual(8, s[baseBounds: 1..<9].endIndex.position)

        XCTAssertEqual(3, s[baseBounds: 2..<8].count)
        XCTAssertEqual(8, s[baseBounds: 2..<8].upperBound)
        XCTAssertEqual(2, s[baseBounds: 2..<8].startIndex.position)
        XCTAssertEqual(8, s[baseBounds: 2..<8].endIndex.position)

        XCTAssertEqual(2, s[baseBounds: 3..<8].count)
        XCTAssertEqual(8, s[baseBounds: 3..<8].upperBound)
        XCTAssertEqual(5, s[baseBounds: 3..<8].startIndex.position)
        XCTAssertEqual(8, s[baseBounds: 3..<8].endIndex.position)

        XCTAssertEqual(1, s[baseBounds: 3..<7].count)
        XCTAssertEqual(7, s[baseBounds: 3..<7].upperBound)
        XCTAssertEqual(5, s[baseBounds: 3..<7].startIndex.position)
        XCTAssertEqual(7, s[baseBounds: 3..<7].endIndex.position)

        XCTAssertEqual(1, s[baseBounds: 4..<6].count)
        XCTAssertEqual(6, s[baseBounds: 4..<6].upperBound)
        XCTAssertEqual(5, s[baseBounds: 4..<6].startIndex.position)
        XCTAssertEqual(6, s[baseBounds: 4..<6].endIndex.position)

        XCTAssertEqual(1, s[baseBounds: 5..<6].count)
        XCTAssertEqual(6, s[baseBounds: 5..<6].upperBound)
        XCTAssertEqual(5, s[baseBounds: 5..<6].startIndex.position)
        XCTAssertEqual(6, s[baseBounds: 5..<6].endIndex.position)

        // Empty, so startIndex and endIndex start at bounds.lowerBound
        XCTAssertEqual(0, s[baseBounds: 4..<5].count)
        XCTAssertEqual(5, s[baseBounds: 4..<5].upperBound)
        XCTAssertEqual(4, s[baseBounds: 4..<5].startIndex.position)
        XCTAssertEqual(4, s[baseBounds: 4..<5].endIndex.position)

        XCTAssertEqual(0, s[baseBounds: 5..<5].count)
        XCTAssertEqual(5, s[baseBounds: 5..<5].upperBound)
        XCTAssertEqual(5, s[baseBounds: 5..<5].startIndex.position)
        XCTAssertEqual(5, s[baseBounds: 5..<5].endIndex.position)
    }

    func testSubscriptRange() {
        var b = SpansBuilder<Int>(totalCount: 6)
        b.add(1, covering: 0..<3)
        b.add(2, covering: 3..<6)
        let s = b.build()

        XCTAssertEqual(6, s.upperBound)
        XCTAssertEqual(2, s.count)

        var iter = s[baseBounds: 0..<6].makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertEqual(Span(range: 3..<6, data: 2), iter.next())
        XCTAssertNil(iter.next())

        iter = s[baseBounds: 0..<3].makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 1), iter.next())
        XCTAssertNil(iter.next())

        iter = s[baseBounds: 3..<6].makeIterator()
        XCTAssertEqual(Span(range: 3..<6, data: 2), iter.next())
        XCTAssertNil(iter.next())

        iter = s[baseBounds: 0..<0].makeIterator()
        XCTAssertNil(iter.next())

        iter = s[baseBounds: 0..<1].makeIterator()
        XCTAssertEqual(Span(range: 0..<1, data: 1), iter.next())
        XCTAssertNil(iter.next())

        iter = s[baseBounds: 5..<6].makeIterator()
        XCTAssertEqual(Span(range: 5..<6, data: 2), iter.next())
        XCTAssertNil(iter.next())

        iter = s[baseBounds: 6..<6].makeIterator()
        XCTAssertNil(iter.next())
    }

    func testIteration() {
        var sb = SpansBuilder<Int>(totalCount: 256)
        for i in stride(from: 0, through: 255, by: 2) {
            sb.add(i, covering: i..<i+2)
        }
        let spans = sb.build()

        var i = 0
        for span in spans {
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i, span.data)
            i += 2
        }

        // reverse
        i = 254
        for span in spans.reversed() {
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i, span.data)
            i -= 2
        }
    }

    func testBuilderFixupPushSlicedByEmptyBuilder() {
        var sb = SpansBuilder<Int>(totalCount: 256)
        for i in stride(from: 0, through: 255, by: 2) {
            sb.add(i, covering: i..<i+2)
        }
        var s1 = sb.build()

        XCTAssertEqual(256, s1.upperBound)
        XCTAssertEqual(128, s1.count)

        var b = BTreeBuilder<Spans<Int>>()
        b.push(&s1.root, slicedBy: 1..<255)
        let s2 = b.build()

        XCTAssertEqual(254, s2.upperBound)
        XCTAssertEqual(128, s2.count)

        var iter = s2.makeIterator()
        let first = iter.next()!
        XCTAssertEqual(0..<1, first.range)
        XCTAssertEqual(0, first.data)

        for i in stride(from: 1, through: 251, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i+1, span.data)
        }

        let last = iter.next()!
        XCTAssertEqual(253..<254, last.range)
        XCTAssertEqual(254, last.data)

        XCTAssertNil(iter.next())
    }

    func testBuilderFixupPushSlicedByNonEmptyBuilder() {
        var sb1 = SpansBuilder<Int>(totalCount: 256)
        for i in stride(from: 0, through: 255, by: 2) {
            sb1.add(i, covering: i..<i+2)
        }
        var s1 = sb1.build()

        XCTAssertEqual(256, s1.upperBound)
        XCTAssertEqual(128, s1.count)

        var sb2 = SpansBuilder<Int>(totalCount: 3)
        sb2.add(-1, covering: 0..<3)
        var s2 = sb2.build()

        var b = BTreeBuilder<Spans<Int>>()
        b.push(&s2.root)
        b.push(&s1.root, slicedBy: 1..<255)
        let s3 = b.build()

        XCTAssertEqual(257, s3.upperBound)
        XCTAssertEqual(129, s3.count)

        var iter = s3.makeIterator()
        let first = iter.next()!
        XCTAssertEqual(0..<3, first.range)
        XCTAssertEqual(-1, first.data)

        let second = iter.next()!
        XCTAssertEqual(3..<4, second.range)
        XCTAssertEqual(0, second.data)

        for i in stride(from: 4, through: 254, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i-2, span.data)
        }

        let last = iter.next()!
        XCTAssertEqual(256..<257, last.range)
        XCTAssertEqual(254, last.data)

        XCTAssertNil(iter.next())
    }

    func testBuilderFixupPushSlicedByCombineSpans() {
        var sb1 = SpansBuilder<Int>(totalCount: 256)
        for i in stride(from: 0, through: 255, by: 2) {
            sb1.add(i, covering: i..<i+2)
        }
        var s1 = sb1.build()

        XCTAssertEqual(256, s1.upperBound)
        XCTAssertEqual(128, s1.count)

        var sb2 = SpansBuilder<Int>(totalCount: 3)
        sb2.add(0, covering: 0..<3)
        var s2 = sb2.build()

        var b = BTreeBuilder<Spans<Int>>()
        b.push(&s2.root)
        b.push(&s1.root, slicedBy: 1..<255)
        let s3 = b.build()

        XCTAssertEqual(257, s3.upperBound)
        XCTAssertEqual(128, s3.count)

        var iter = s3.makeIterator()
        let first = iter.next()!
        XCTAssertEqual(0..<4, first.range)
        XCTAssertEqual(0, first.data)

        for i in stride(from: 4, through: 254, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i-2, span.data)
        }

        let last = iter.next()!
        XCTAssertEqual(256..<257, last.range)
        XCTAssertEqual(254, last.data)

        XCTAssertNil(iter.next())
    }

    func testBuilderFixupPushSlicedWithFullLeaf() {
        XCTAssertEqual(64, SpansLeaf<Int>.maxSize)

        var sb1 = SpansBuilder<Int>(totalCount: 128)
        for i in stride(from: 0, through: 127, by: 2) {
            sb1.add(i, covering: i..<i+2)
        }
        var s1 = sb1.build()

        XCTAssertEqual(128, s1.upperBound)
        XCTAssertEqual(64, s1.count)
        XCTAssertEqual(0, s1.root.height)
        XCTAssertEqual(64, s1.root.leaf.spans.count)

        var sb2 = SpansBuilder<Int>(totalCount: 64)
        for i in stride(from: 0, through: 63, by: 2) {
            sb2.add(i, covering: i..<i+2)
        }
        var s2 = sb2.build()

        XCTAssertEqual(64, s2.upperBound)
        XCTAssertEqual(32, s2.count)
        XCTAssertEqual(0, s2.root.height)
        XCTAssertEqual(32, s2.root.leaf.spans.count)

        var b = BTreeBuilder<Spans<Int>>()
        b.push(&s1.root, slicedBy: 0..<128)
        b.push(&s2.root, slicedBy: 1..<63)
        let s3 = b.build()

        XCTAssertEqual(190, s3.upperBound)
        XCTAssertEqual(96, s3.count)

        var iter = s3.makeIterator()
        for i in stride(from: 0, through: 127, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i, span.data)
        }

        let next = iter.next()!
        XCTAssertEqual(128..<129, next.range)
        XCTAssertEqual(0, next.data)

        for i in stride(from: 1, through: 60, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(128+i..<128+i+2, span.range)
            XCTAssertEqual(i+1, span.data)
        }

        let last = iter.next()!
        XCTAssertEqual(189..<190, last.range)
        XCTAssertEqual(62, last.data)

        XCTAssertNil(iter.next())
    }

    func testBuilderFixupPushSlicedWithFullLeafCombineSpans() {
        XCTAssertEqual(64, SpansLeaf<Int>.maxSize)

        var sb1 = SpansBuilder<Int>(totalCount: 128)
        for i in stride(from: 0, through: 127, by: 2) {
            sb1.add(i, covering: i..<i+2)
        }
        var s1 = sb1.build()

        XCTAssertEqual(128, s1.upperBound)
        XCTAssertEqual(64, s1.count)
        XCTAssertEqual(0, s1.root.height)
        XCTAssertEqual(64, s1.root.leaf.spans.count)

        var sb2 = SpansBuilder<Int>(totalCount: 64)
        for i in stride(from: 0, through: 63, by: 2) {
            sb2.add(126+i, covering: i..<i+2)
        }
        var s2 = sb2.build()

        XCTAssertEqual(64, s2.upperBound)
        XCTAssertEqual(32, s2.count)
        XCTAssertEqual(0, s2.root.height)
        XCTAssertEqual(32, s2.root.leaf.spans.count)

        var b = BTreeBuilder<Spans<Int>>()
        b.push(&s1.root, slicedBy: 0..<128)
        b.push(&s2.root, slicedBy: 1..<63)
        let s3 = b.build()

        XCTAssertEqual(190, s3.upperBound)
        XCTAssertEqual(95, s3.count)

        var iter = s3.makeIterator()
        for i in stride(from: 0, through: 125, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(i..<i+2, span.range)
            XCTAssertEqual(i, span.data)
        }

        let combined = iter.next()!
        XCTAssertEqual(126..<129, combined.range)
        XCTAssertEqual(126, combined.data)

        for i in stride(from: 1, through: 60, by: 2) {
            let span = iter.next()!
            XCTAssertEqual(128+i..<128+i+2, span.range)
            XCTAssertEqual(126+i+1, span.data)
        }

        let last = iter.next()!
        XCTAssertEqual(189..<190, last.range)
        XCTAssertEqual(188, last.data)

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
