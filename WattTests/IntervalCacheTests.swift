//
//  IntervalCacheTests.swift
//  WattTests
//
//  Created by David Albert on 7/31/23.
//

import XCTest
@testable import Watt

final class IntervalCacheTests: XCTestCase {
    func testStoreAndLoad() {
        var cache = IntervalCache<Int>(upperBound: 20)
        cache.set(20, forRange: 5..<10)

        XCTAssert(cache.count == 1)

        XCTAssertNil(cache[4])
        XCTAssertEqual(cache[5], 20)
        XCTAssertEqual(cache[9], 20)
        XCTAssertNil(cache[10])
    }

    func testSubscript() {
        var cache = IntervalCache<Int>(upperBound: 50)

        cache.set(1, forRange: 5..<10)
        cache.set(2, forRange: 15..<20)
        cache.set(3, forRange: 25..<30)

        XCTAssertEqual(cache.count, 3)

        XCTAssertEqual(cache[5], 1)
        XCTAssertEqual(cache[15], 2)
        XCTAssertEqual(cache[25], 3)

        cache = cache[8..<23]

        XCTAssertEqual(cache.count, 2)

        XCTAssertEqual(cache[5], 1)
        XCTAssertEqual(cache[15], 2)
        XCTAssertNil(cache[25])
    }

    func testInvalidateDeleteBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(10..<12)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.copy(12, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(98, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 18..<28, data: 2), iter.next())
        XCTAssertEqual(Span(range: 28..<38, data: 3), iter.next())
        XCTAssertEqual(Span(range: 38..<48, data: 4), iter.next())
        XCTAssertEqual(Span(range: 48..<58, data: 5), iter.next())
        XCTAssertEqual(Span(range: 58..<68, data: 6), iter.next())
        XCTAssertEqual(Span(range: 68..<78, data: 7), iter.next())
        XCTAssertEqual(Span(range: 78..<88, data: 8), iter.next())
        XCTAssertEqual(Span(range: 88..<98, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(15..<17)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 15), delta.elements[0])
        XCTAssertEqual(.copy(17, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(98, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 18..<28, data: 2), iter.next())
        XCTAssertEqual(Span(range: 28..<38, data: 3), iter.next())
        XCTAssertEqual(Span(range: 38..<48, data: 4), iter.next())
        XCTAssertEqual(Span(range: 48..<58, data: 5), iter.next())
        XCTAssertEqual(Span(range: 58..<68, data: 6), iter.next())
        XCTAssertEqual(Span(range: 68..<78, data: 7), iter.next())
        XCTAssertEqual(Span(range: 78..<88, data: 8), iter.next())
        XCTAssertEqual(Span(range: 88..<98, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(18..<20)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.copy(20, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(98, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 18..<28, data: 2), iter.next())
        XCTAssertEqual(Span(range: 28..<38, data: 3), iter.next())
        XCTAssertEqual(Span(range: 38..<48, data: 4), iter.next())
        XCTAssertEqual(Span(range: 48..<58, data: 5), iter.next())
        XCTAssertEqual(Span(range: 58..<68, data: 6), iter.next())
        XCTAssertEqual(Span(range: 68..<78, data: 7), iter.next())
        XCTAssertEqual(Span(range: 78..<88, data: 8), iter.next())
        XCTAssertEqual(Span(range: 88..<98, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteAcrossSpans() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(18..<32)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.copy(32, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(86, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 26..<36, data: 4), iter.next())
        XCTAssertEqual(Span(range: 36..<46, data: 5), iter.next())
        XCTAssertEqual(Span(range: 46..<56, data: 6), iter.next())
        XCTAssertEqual(Span(range: 56..<66, data: 7), iter.next())
        XCTAssertEqual(Span(range: 66..<76, data: 8), iter.next())
        XCTAssertEqual(Span(range: 76..<86, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteBeginningAndEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(0..<8)
        b.removeSubrange(92..<100)
        let delta = b.build()

        XCTAssertEqual(1, delta.elements.count)
        XCTAssertEqual(.copy(8, 92), delta.elements[0])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(84, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 2..<12, data: 1), iter.next())
        XCTAssertEqual(Span(range: 12..<22, data: 2), iter.next())
        XCTAssertEqual(Span(range: 22..<32, data: 3), iter.next())
        XCTAssertEqual(Span(range: 32..<42, data: 4), iter.next())
        XCTAssertEqual(Span(range: 42..<52, data: 5), iter.next())
        XCTAssertEqual(Span(range: 52..<62, data: 6), iter.next())
        XCTAssertEqual(Span(range: 62..<72, data: 7), iter.next())
        XCTAssertEqual(Span(range: 72..<82, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(321..<339)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 321), delta.elements[0])
        XCTAssertEqual(.copy(339, 660), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(642, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        // initial copy + 2nd copy prefix = 321 + 1
        XCTAssertEqual(322, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(320, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 300..<310, data: 30), iter.next())
        XCTAssertEqual(Span(range: 310..<320, data: 31), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 322..<332, data: 34), iter.next())
        XCTAssertEqual(Span(range: 332..<342, data: 35), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 622..<632, data: 64), iter.next())
        XCTAssertEqual(Span(range: 632..<642, data: 65), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteBeginningAndEndOfTreeAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(0..<8)
        b.removeSubrange(652..<660)
        let delta = b.build()

        XCTAssertEqual(1, delta.elements.count)
        XCTAssertEqual(.copy(8, 652), delta.elements[0])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(644, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(322, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(322, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 2..<12, data: 1), iter.next())
        XCTAssertEqual(Span(range: 12..<22, data: 2), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 302..<312, data: 31), iter.next())
        XCTAssertEqual(Span(range: 312..<322, data: 32), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 322..<332, data: 33), iter.next())
        XCTAssertEqual(Span(range: 332..<342, data: 34), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 622..<632, data: 63), iter.next())
        XCTAssertEqual(Span(range: 632..<642, data: 64), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertBeginningOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(0..<0, with: abc)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.insert(abc.root), delta.elements[0])
        XCTAssertEqual(.copy(0, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(103, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 13..<23, data: 1), iter.next())
        XCTAssertEqual(Span(range: 23..<33, data: 2), iter.next())
        XCTAssertEqual(Span(range: 33..<43, data: 3), iter.next())
        XCTAssertEqual(Span(range: 43..<53, data: 4), iter.next())
        XCTAssertEqual(Span(range: 53..<63, data: 5), iter.next())
        XCTAssertEqual(Span(range: 63..<73, data: 6), iter.next())
        XCTAssertEqual(Span(range: 73..<83, data: 7), iter.next())
        XCTAssertEqual(Span(range: 83..<93, data: 8), iter.next())
        XCTAssertEqual(Span(range: 93..<103, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(10..<10, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(10, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(103, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 23..<33, data: 2), iter.next())
        XCTAssertEqual(Span(range: 33..<43, data: 3), iter.next())
        XCTAssertEqual(Span(range: 43..<53, data: 4), iter.next())
        XCTAssertEqual(Span(range: 53..<63, data: 5), iter.next())
        XCTAssertEqual(Span(range: 63..<73, data: 6), iter.next())
        XCTAssertEqual(Span(range: 73..<83, data: 7), iter.next())
        XCTAssertEqual(Span(range: 83..<93, data: 8), iter.next())
        XCTAssertEqual(Span(range: 93..<103, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(15..<15, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 15), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(15, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(103, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 23..<33, data: 2), iter.next())
        XCTAssertEqual(Span(range: 33..<43, data: 3), iter.next())
        XCTAssertEqual(Span(range: 43..<53, data: 4), iter.next())
        XCTAssertEqual(Span(range: 53..<63, data: 5), iter.next())
        XCTAssertEqual(Span(range: 63..<73, data: 6), iter.next())
        XCTAssertEqual(Span(range: 73..<83, data: 7), iter.next())
        XCTAssertEqual(Span(range: 83..<93, data: 8), iter.next())
        XCTAssertEqual(Span(range: 93..<103, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(19..<19, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 19), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(19, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(103, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 23..<33, data: 2), iter.next())
        XCTAssertEqual(Span(range: 33..<43, data: 3), iter.next())
        XCTAssertEqual(Span(range: 43..<53, data: 4), iter.next())
        XCTAssertEqual(Span(range: 53..<63, data: 5), iter.next())
        XCTAssertEqual(Span(range: 63..<73, data: 6), iter.next())
        XCTAssertEqual(Span(range: 73..<83, data: 7), iter.next())
        XCTAssertEqual(Span(range: 83..<93, data: 8), iter.next())
        XCTAssertEqual(Span(range: 93..<103, data: 9), iter.next())
    }

    func testInvalidateInsertBeginningAndEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(10..<10, with: abc)
        b.replaceSubrange(20..<20, with: abc)
        let delta = b.build()

        XCTAssertEqual(5, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(10, 20), delta.elements[2])
        XCTAssertEqual(.insert(abc.root), delta.elements[3])
        XCTAssertEqual(.copy(20, 100), delta.elements[4])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(106, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 36..<46, data: 3), iter.next())
        XCTAssertEqual(Span(range: 46..<56, data: 4), iter.next())
        XCTAssertEqual(Span(range: 56..<66, data: 5), iter.next())
        XCTAssertEqual(Span(range: 66..<76, data: 6), iter.next())
        XCTAssertEqual(Span(range: 76..<86, data: 7), iter.next())
        XCTAssertEqual(Span(range: 86..<96, data: 8), iter.next())
        XCTAssertEqual(Span(range: 96..<106, data: 9), iter.next())
    }

    func testInvalidateInsertEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(100..<100, with: abc)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 100), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(103, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertEndOfTreeWithTrailingBlankRange() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        XCTAssertEqual(11, cache.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(100..<100, with: abc)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 100), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])

        cache.invalidate(delta: delta)

        // Even though the tree ends with a blank range, and in theory we only have to
        // invalidate the last range, we invalidate the last two ranges because
        // invalidating just the final one would be a pain.
        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(103, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertMultipleTimesInASpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(10..<10, with: a)
        b.replaceSubrange(14..<14, with: a)
        b.replaceSubrange(18..<18, with: a)
        b.replaceSubrange(20..<20, with: a)
        let delta = b.build()

        XCTAssertEqual(9, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(10, 14), delta.elements[2])
        XCTAssertEqual(.insert(a.root), delta.elements[3])
        XCTAssertEqual(.copy(14, 18), delta.elements[4])
        XCTAssertEqual(.insert(a.root), delta.elements[5])
        XCTAssertEqual(.copy(18, 20), delta.elements[6])
        XCTAssertEqual(.insert(a.root), delta.elements[7])
        XCTAssertEqual(.copy(20, 100), delta.elements[8])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(104, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 34..<44, data: 3), iter.next())
        XCTAssertEqual(Span(range: 44..<54, data: 4), iter.next())
        XCTAssertEqual(Span(range: 54..<64, data: 5), iter.next())
        XCTAssertEqual(Span(range: 64..<74, data: 6), iter.next())
        XCTAssertEqual(Span(range: 74..<84, data: 7), iter.next())
        XCTAssertEqual(Span(range: 84..<94, data: 8), iter.next())
        XCTAssertEqual(Span(range: 94..<104, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    // TODO: I forgot to name this. What is it doing and what's a good name?
    func testHmm() {
        var cache = makeContiguousCache(upperBound: 20, stride: 10)
        cache.set(0, forRange: 0..<10)
        cache.set(1, forRange: 10..<20)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(4..<11)
        b.removeSubrange(15..<20)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 4), delta.elements[0])
        XCTAssertEqual(.copy(11, 15), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(0, cache.count)
        XCTAssertEqual(8, cache.upperBound)
    }

    // This is a bit of a misnomer, because you can't actually do an insert
    // (replace into an empty range) across leaves.
    func testInvalidateInsertAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(329..<329, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 329), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(329, 660), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(65, cache.count)
        XCTAssertEqual(663, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        // initial copy + insert + 2nd copy prefix = 329 + 3 + 1
        XCTAssertEqual(333, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 300..<310, data: 30), iter.next())
        XCTAssertEqual(Span(range: 310..<320, data: 31), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 333..<343, data: 33), iter.next())
        XCTAssertEqual(Span(range: 343..<353, data: 34), iter.next())

        for _ in 0..<29 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 643..<653, data: 64), iter.next())
        XCTAssertEqual(Span(range: 653..<663, data: 65), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateInsertBeginningAndEndOfTreeAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(0..<0, with: abc)
        b.replaceSubrange(660..<660, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(abc.root), delta.elements[0])
        XCTAssertEqual(.copy(0, 660), delta.elements[1])
        XCTAssertEqual(.insert(abc.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(666, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(333, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(333, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 13..<23, data: 1), iter.next())
        XCTAssertEqual(Span(range: 23..<33, data: 2), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 313..<323, data: 31), iter.next())
        XCTAssertEqual(Span(range: 323..<333, data: 32), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 333..<343, data: 33), iter.next())
        XCTAssertEqual(Span(range: 343..<353, data: 34), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 633..<643, data: 63), iter.next())
        XCTAssertEqual(Span(range: 643..<653, data: 64), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateDeleteMultipleRanges() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        b.removeSubrange(0..<8)
        b.removeSubrange(23..<35)
        b.removeSubrange(62..<78)
        b.removeSubrange(92..<99)
        let delta = b.build()

        XCTAssertEqual(4, delta.elements.count)
        XCTAssertEqual(.copy(8, 23), delta.elements[0])
        XCTAssertEqual(.copy(35, 62), delta.elements[1])
        XCTAssertEqual(.copy(78, 92), delta.elements[2])
        XCTAssertEqual(.copy(99, 100), delta.elements[3])

        cache.invalidate(delta: delta)

        XCTAssertEqual(4, cache.count)
        XCTAssertEqual(57, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 2..<12, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 4), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 5), iter.next())
        XCTAssertEqual(Span(range: 44..<54, data: 8), iter.next())
    }

    func testInvalidateReplaceShrinkBeginningOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(0..<2, with: a)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.insert(a.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(99, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 9..<19, data: 1), iter.next())
        XCTAssertEqual(Span(range: 19..<29, data: 2), iter.next())
        XCTAssertEqual(Span(range: 29..<39, data: 3), iter.next())
        XCTAssertEqual(Span(range: 39..<49, data: 4), iter.next())
        XCTAssertEqual(Span(range: 49..<59, data: 5), iter.next())
        XCTAssertEqual(Span(range: 59..<69, data: 6), iter.next())
        XCTAssertEqual(Span(range: 69..<79, data: 7), iter.next())
        XCTAssertEqual(Span(range: 79..<89, data: 8), iter.next())
        XCTAssertEqual(Span(range: 89..<99, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthBeginningOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(0..<2, with: ab)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.insert(ab.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowBeginningOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(0..<2, with: abc)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.insert(abc.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 100), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(101, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 11..<21, data: 1), iter.next())
        XCTAssertEqual(Span(range: 21..<31, data: 2), iter.next())
        XCTAssertEqual(Span(range: 31..<41, data: 3), iter.next())
        XCTAssertEqual(Span(range: 41..<51, data: 4), iter.next())
        XCTAssertEqual(Span(range: 51..<61, data: 5), iter.next())
        XCTAssertEqual(Span(range: 61..<71, data: 6), iter.next())
        XCTAssertEqual(Span(range: 71..<81, data: 7), iter.next())
        XCTAssertEqual(Span(range: 81..<91, data: 8), iter.next())
        XCTAssertEqual(Span(range: 91..<101, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(10..<12, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(12, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(99, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 19..<29, data: 2), iter.next())
        XCTAssertEqual(Span(range: 29..<39, data: 3), iter.next())
        XCTAssertEqual(Span(range: 39..<49, data: 4), iter.next())
        XCTAssertEqual(Span(range: 49..<59, data: 5), iter.next())
        XCTAssertEqual(Span(range: 59..<69, data: 6), iter.next())
        XCTAssertEqual(Span(range: 69..<79, data: 7), iter.next())
        XCTAssertEqual(Span(range: 79..<89, data: 8), iter.next())
        XCTAssertEqual(Span(range: 89..<99, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(10..<12, with: ab)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(ab.root), delta.elements[1])
        XCTAssertEqual(.copy(12, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(10..<12, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(12, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(101, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 21..<31, data: 2), iter.next())
        XCTAssertEqual(Span(range: 31..<41, data: 3), iter.next())
        XCTAssertEqual(Span(range: 41..<51, data: 4), iter.next())
        XCTAssertEqual(Span(range: 51..<61, data: 5), iter.next())
        XCTAssertEqual(Span(range: 61..<71, data: 6), iter.next())
        XCTAssertEqual(Span(range: 71..<81, data: 7), iter.next())
        XCTAssertEqual(Span(range: 81..<91, data: 8), iter.next())
        XCTAssertEqual(Span(range: 91..<101, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(15..<17, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 15), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(17, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(99, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 19..<29, data: 2), iter.next())
        XCTAssertEqual(Span(range: 29..<39, data: 3), iter.next())
        XCTAssertEqual(Span(range: 39..<49, data: 4), iter.next())
        XCTAssertEqual(Span(range: 49..<59, data: 5), iter.next())
        XCTAssertEqual(Span(range: 59..<69, data: 6), iter.next())
        XCTAssertEqual(Span(range: 69..<79, data: 7), iter.next())
        XCTAssertEqual(Span(range: 79..<89, data: 8), iter.next())
        XCTAssertEqual(Span(range: 89..<99, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(15..<17, with: ab)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 15), delta.elements[0])
        XCTAssertEqual(.insert(ab.root), delta.elements[1])
        XCTAssertEqual(.copy(17, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(15..<17, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 15), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(17, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(101, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 21..<31, data: 2), iter.next())
        XCTAssertEqual(Span(range: 31..<41, data: 3), iter.next())
        XCTAssertEqual(Span(range: 41..<51, data: 4), iter.next())
        XCTAssertEqual(Span(range: 51..<61, data: 5), iter.next())
        XCTAssertEqual(Span(range: 61..<71, data: 6), iter.next())
        XCTAssertEqual(Span(range: 71..<81, data: 7), iter.next())
        XCTAssertEqual(Span(range: 81..<91, data: 8), iter.next())
        XCTAssertEqual(Span(range: 91..<101, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(18..<20, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(20, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(99, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 29..<39, data: 3), iter.next())
        XCTAssertEqual(Span(range: 39..<49, data: 4), iter.next())
        XCTAssertEqual(Span(range: 49..<59, data: 5), iter.next())
        XCTAssertEqual(Span(range: 59..<69, data: 6), iter.next())
        XCTAssertEqual(Span(range: 69..<79, data: 7), iter.next())
        XCTAssertEqual(Span(range: 79..<89, data: 8), iter.next())
        XCTAssertEqual(Span(range: 89..<99, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(18..<20, with: ab)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.insert(ab.root), delta.elements[1])
        XCTAssertEqual(.copy(20, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(18..<20, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(20, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(101, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 31..<41, data: 3), iter.next())
        XCTAssertEqual(Span(range: 41..<51, data: 4), iter.next())
        XCTAssertEqual(Span(range: 51..<61, data: 5), iter.next())
        XCTAssertEqual(Span(range: 61..<71, data: 6), iter.next())
        XCTAssertEqual(Span(range: 71..<81, data: 7), iter.next())
        XCTAssertEqual(Span(range: 81..<91, data: 8), iter.next())
        XCTAssertEqual(Span(range: 91..<101, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthBeginningAndEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(10..<13, with: abc)
        b.replaceSubrange(20..<23, with: abc)
        let delta = b.build()

        XCTAssertEqual(5, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(13, 20), delta.elements[2])
        XCTAssertEqual(.insert(abc.root), delta.elements[3])
        XCTAssertEqual(.copy(23, 100), delta.elements[4])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
    }

    func testInvalidateReplaceSameLengthOverAlmostAllOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abcdefgh = Rope("abcdefgh")
        b.replaceSubrange(11..<19, with: abcdefgh)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 11), delta.elements[0])
        XCTAssertEqual(.insert(abcdefgh.root), delta.elements[1])
        XCTAssertEqual(.copy(19, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
    }



    func testInvalidateReplaceShrinkAcrossSpans() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope(String(repeating: "a", count: 13))
        b.replaceSubrange(18..<32, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(32, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(99, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 39..<49, data: 4), iter.next())
        XCTAssertEqual(Span(range: 49..<59, data: 5), iter.next())
        XCTAssertEqual(Span(range: 59..<69, data: 6), iter.next())
        XCTAssertEqual(Span(range: 69..<79, data: 7), iter.next())
        XCTAssertEqual(Span(range: 79..<89, data: 8), iter.next())
        XCTAssertEqual(Span(range: 89..<99, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthAcrossSpans() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope(String(repeating: "a", count: 14))
        b.replaceSubrange(18..<32, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(32, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowAcrossSpans() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope(String(repeating: "a", count: 15))
        b.replaceSubrange(18..<32, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 18), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(32, 100), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(7, cache.count)
        XCTAssertEqual(101, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 41..<51, data: 4), iter.next())
        XCTAssertEqual(Span(range: 51..<61, data: 5), iter.next())
        XCTAssertEqual(Span(range: 61..<71, data: 6), iter.next())
        XCTAssertEqual(Span(range: 71..<81, data: 7), iter.next())
        XCTAssertEqual(Span(range: 81..<91, data: 8), iter.next())
        XCTAssertEqual(Span(range: 91..<101, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(98..<100, with: a)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 98), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(99, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(98..<100, with: ab)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 98), delta.elements[0])
        XCTAssertEqual(.insert(ab.root), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(98..<100, with: abc)
        let delta = b.build()

        XCTAssertEqual(2, delta.elements.count)
        XCTAssertEqual(.copy(0, 98), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])

        cache.invalidate(delta: delta)

        XCTAssertEqual(9, cache.count)
        XCTAssertEqual(101, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkBeginningAndEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(0..<2, with: a)
        b.replaceSubrange(98..<100, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(a.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 98), delta.elements[1])
        XCTAssertEqual(.insert(a.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(98, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 9..<19, data: 1), iter.next())
        XCTAssertEqual(Span(range: 19..<29, data: 2), iter.next())
        XCTAssertEqual(Span(range: 29..<39, data: 3), iter.next())
        XCTAssertEqual(Span(range: 39..<49, data: 4), iter.next())
        XCTAssertEqual(Span(range: 49..<59, data: 5), iter.next())
        XCTAssertEqual(Span(range: 59..<69, data: 6), iter.next())
        XCTAssertEqual(Span(range: 69..<79, data: 7), iter.next())
        XCTAssertEqual(Span(range: 79..<89, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthBeginningAndEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(0..<2, with: ab)
        b.replaceSubrange(98..<100, with: ab)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(ab.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 98), delta.elements[1])
        XCTAssertEqual(.insert(ab.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(100, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowBeginningAndEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(0..<2, with: abc)
        b.replaceSubrange(98..<100, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(abc.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 98), delta.elements[1])
        XCTAssertEqual(.insert(abc.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(8, cache.count)
        XCTAssertEqual(102, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 11..<21, data: 1), iter.next())
        XCTAssertEqual(Span(range: 21..<31, data: 2), iter.next())
        XCTAssertEqual(Span(range: 31..<41, data: 3), iter.next())
        XCTAssertEqual(Span(range: 41..<51, data: 4), iter.next())
        XCTAssertEqual(Span(range: 51..<61, data: 5), iter.next())
        XCTAssertEqual(Span(range: 61..<71, data: 6), iter.next())
        XCTAssertEqual(Span(range: 71..<81, data: 7), iter.next())
        XCTAssertEqual(Span(range: 81..<91, data: 8), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(329..<331, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 329), delta.elements[0])
        XCTAssertEqual(.insert(a.root), delta.elements[1])
        XCTAssertEqual(.copy(331, 660), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(659, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        // initial copy + insert + 2nd copy prefix = 329 + 1 + 9 = 331
        XCTAssertEqual(339, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(320, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 300..<310, data: 30), iter.next())
        XCTAssertEqual(Span(range: 310..<320, data: 31), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 339..<349, data: 34), iter.next())
        XCTAssertEqual(Span(range: 349..<359, data: 35), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 639..<649, data: 64), iter.next())
        XCTAssertEqual(Span(range: 649..<659, data: 65), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(329..<331, with: ab)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 329), delta.elements[0])
        XCTAssertEqual(.insert(ab.root), delta.elements[1])
        XCTAssertEqual(.copy(331, 660), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        // initial copy + insert + 2nd copy prefix = 329 + 2 + 9 = 340
        XCTAssertEqual(340, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(320, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 300..<310, data: 30), iter.next())
        XCTAssertEqual(Span(range: 310..<320, data: 31), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 340..<350, data: 34), iter.next())
        XCTAssertEqual(Span(range: 350..<360, data: 35), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 640..<650, data: 64), iter.next())
        XCTAssertEqual(Span(range: 650..<660, data: 65), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceGrowAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(329..<331, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 329), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(331, 660), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(661, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        // initial copy + insert + 2nd copy prefix = 329 + 3 + 9 = 341
        XCTAssertEqual(341, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(320, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 300..<310, data: 30), iter.next())
        XCTAssertEqual(Span(range: 310..<320, data: 31), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 341..<351, data: 34), iter.next())
        XCTAssertEqual(Span(range: 351..<361, data: 35), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 641..<651, data: 64), iter.next())
        XCTAssertEqual(Span(range: 651..<661, data: 65), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceShrinkBeginningAndEndOfTreeAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let a = Rope("a")
        b.replaceSubrange(0..<2, with: a)
        b.replaceSubrange(658..<660, with: a)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(a.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 658), delta.elements[1])
        XCTAssertEqual(.insert(a.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(658, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(329, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(329, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 9..<19, data: 1), iter.next())
        XCTAssertEqual(Span(range: 19..<29, data: 2), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 309..<319, data: 31), iter.next())
        XCTAssertEqual(Span(range: 319..<329, data: 32), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 329..<339, data: 33), iter.next())
        XCTAssertEqual(Span(range: 339..<349, data: 34), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 629..<639, data: 63), iter.next())
        XCTAssertEqual(Span(range: 639..<649, data: 64), iter.next())
        XCTAssertNil(iter.next())
    }

    func testInvalidateReplaceSameLengthBeginningAndEndOfTreeAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let ab = Rope("ab")
        b.replaceSubrange(0..<2, with: ab)
        b.replaceSubrange(658..<660, with: ab)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(ab.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 658), delta.elements[1])
        XCTAssertEqual(.insert(ab.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 310..<320, data: 31), iter.next())
        XCTAssertEqual(Span(range: 320..<330, data: 32), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 330..<340, data: 33), iter.next())
        XCTAssertEqual(Span(range: 340..<350, data: 34), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 630..<640, data: 63), iter.next())
        XCTAssertEqual(Span(range: 640..<650, data: 64), iter.next())
    }

    func testInvalidateReplaceGrowBeginningAndEndOfTreeAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(330, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.root.children[1].leaf.spans.count)

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let abc = Rope("abc")
        b.replaceSubrange(0..<2, with: abc)
        b.replaceSubrange(658..<660, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(abc.root), delta.elements[0])
        XCTAssertEqual(.copy(2, 658), delta.elements[1])
        XCTAssertEqual(.insert(abc.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(662, cache.upperBound)

        XCTAssertEqual(1, cache.spans.root.height)
        XCTAssertEqual(2, cache.spans.root.children.count)
        XCTAssertEqual(331, cache.spans.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[0].leaf.spans.count)
        XCTAssertEqual(331, cache.spans.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.root.children[1].leaf.spans.count)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 11..<21, data: 1), iter.next())
        XCTAssertEqual(Span(range: 21..<31, data: 2), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 311..<321, data: 31), iter.next())
        XCTAssertEqual(Span(range: 321..<331, data: 32), iter.next())
        // next leaf
        XCTAssertEqual(Span(range: 331..<341, data: 33), iter.next())
        XCTAssertEqual(Span(range: 341..<351, data: 34), iter.next())

        for _ in 0..<28 {
            _ = iter.next()
        }

        XCTAssertEqual(Span(range: 631..<641, data: 63), iter.next())
        XCTAssertEqual(Span(range: 641..<651, data: 64), iter.next())
        XCTAssertNil(iter.next())
    }

    // MARK: - Regressions

    func testReplaceOnlyNewline() {
        // "a\nc" => "azc"
        var cache = IntervalCache<Int>(upperBound: 3)
        cache.set(1, forRange: 0..<2)
        cache.set(2, forRange: 2..<3)

        XCTAssertEqual(2, cache.count)
        XCTAssertEqual(3, cache.upperBound)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<2, data: 1), iter.next())
        XCTAssertEqual(Span(range: 2..<3, data: 2), iter.next())
        XCTAssertNil(iter.next())

        var b = BTreeDeltaBuilder<Rope>(cache.upperBound)
        let z = Rope("z")
        b.replaceSubrange(1..<2, with: z)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 1), delta.elements[0])
        XCTAssertEqual(.insert(z.root), delta.elements[1])
        XCTAssertEqual(.copy(2, 3), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(0, cache.count)
        XCTAssertEqual(3, cache.upperBound)

        cache.set(3, forRange: 0..<3)

        XCTAssertEqual(1, cache.count)
        XCTAssertEqual(3, cache.upperBound)

        iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<3, data: 3), iter.next())
        XCTAssertNil(iter.next())
    }

    // MARK: - Utilities

    func makeContiguousCache(upperBound: Int, stride: Int, includeEmptyLine: Bool = false) -> IntervalCache<Int> {
        precondition(upperBound % stride == 0)

        var cache = IntervalCache<Int>(upperBound: upperBound)
        var i = 0
        while i < upperBound/stride {
            cache.set(i, forRange: i*stride..<(i+1)*stride)
            i += 1
        }

        if includeEmptyLine {
            cache.set(i, forRange: upperBound..<upperBound)
        }

        return cache
    }

    // sanity checks for the tests below
    func testMakeContiguousCache() {
        let cache = makeContiguousCache(upperBound: 100, stride: 10)

        XCTAssertEqual(cache.count, 10)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertNil(iter.next())
    }

    func testMakeContiguousCacheWithEmptyLine() {
        let cache = makeContiguousCache(upperBound: 100, stride: 10, includeEmptyLine: true)

        XCTAssertEqual(cache.count, 11)

        var iter = cache.spans.makeIterator()
        XCTAssertEqual(Span(range: 0..<10, data: 0), iter.next())
        XCTAssertEqual(Span(range: 10..<20, data: 1), iter.next())
        XCTAssertEqual(Span(range: 20..<30, data: 2), iter.next())
        XCTAssertEqual(Span(range: 30..<40, data: 3), iter.next())
        XCTAssertEqual(Span(range: 40..<50, data: 4), iter.next())
        XCTAssertEqual(Span(range: 50..<60, data: 5), iter.next())
        XCTAssertEqual(Span(range: 60..<70, data: 6), iter.next())
        XCTAssertEqual(Span(range: 70..<80, data: 7), iter.next())
        XCTAssertEqual(Span(range: 80..<90, data: 8), iter.next())
        XCTAssertEqual(Span(range: 90..<100, data: 9), iter.next())
        XCTAssertEqual(Span(range: 100..<100, data: 10), iter.next())
        XCTAssertNil(iter.next())
    }
}
