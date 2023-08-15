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

    func testInvalidateDeltaDeleteBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        b.delete(10..<12)
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

    func testInvalidateDeltaDeleteMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        b.delete(15..<17)
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

    func testInvalidateDeltaDeleteEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        b.delete(18..<20)
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

    func testInvalidateDeltaDeleteFullSpanPlusOverflow() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        b.delete(0..<8)
        b.delete(92..<100)
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

    func testInvalidateDeltaDeleteAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.t.root.height)
        XCTAssertEqual(2, cache.spans.t.root.children.count)
        XCTAssertEqual(330, cache.spans.t.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.t.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.t.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.t.root.children[1].leaf.spans.count)

        var b = Rope.DeltaBuilder(cache.upperBound)
        b.delete(0..<8)
        b.delete(652..<660)
        let delta = b.build()

        XCTAssertEqual(1, delta.elements.count)
        XCTAssertEqual(.copy(8, 652), delta.elements[0])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(644, cache.upperBound)

        XCTAssertEqual(1, cache.spans.t.root.height)
        XCTAssertEqual(2, cache.spans.t.root.children.count)
        XCTAssertEqual(322, cache.spans.t.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.t.root.children[0].leaf.spans.count)
        XCTAssertEqual(322, cache.spans.t.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.t.root.children[1].leaf.spans.count)

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

    func testInvalidateDeltaInsertBeginningOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(0..<0, with: abc)
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


    func testInvalidateDeltaInsertBeginningOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(10..<10, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.copy(0, 10), delta.elements[0])
        XCTAssertEqual(.insert(abc.root), delta.elements[1])
        XCTAssertEqual(.copy(10, 100), delta.elements[2])

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

    func testInvalidateDeltaInsertMiddleOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(15..<15, with: abc)
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

    func testInvalidateDeltaInsertEndOfSpan() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(19..<19, with: abc)
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

    // We don't have a way to detect whether there's an empty line
    // 
    func testInvalidateDeltaInsertEndOfTree() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(100..<100, with: abc)
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

    func testInvalidateDeltaInsertAcrossLeaves() {
        var cache = makeContiguousCache(upperBound: 660, stride: 10)

        XCTAssertEqual(66, cache.count)
        XCTAssertEqual(660, cache.upperBound)

        XCTAssertEqual(1, cache.spans.t.root.height)
        XCTAssertEqual(2, cache.spans.t.root.children.count)
        XCTAssertEqual(330, cache.spans.t.root.children[0].leaf.count)
        XCTAssertEqual(33, cache.spans.t.root.children[0].leaf.spans.count)
        XCTAssertEqual(330, cache.spans.t.root.children[1].leaf.count)
        XCTAssertEqual(33, cache.spans.t.root.children[1].leaf.spans.count)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(0..<0, with: abc)
        b.replace(660..<660, with: abc)
        let delta = b.build()

        XCTAssertEqual(3, delta.elements.count)
        XCTAssertEqual(.insert(abc.root), delta.elements[0])
        XCTAssertEqual(.copy(0, 660), delta.elements[1])
        XCTAssertEqual(.insert(abc.root), delta.elements[2])

        cache.invalidate(delta: delta)

        XCTAssertEqual(64, cache.count)
        XCTAssertEqual(666, cache.upperBound)

        XCTAssertEqual(1, cache.spans.t.root.height)
        XCTAssertEqual(2, cache.spans.t.root.children.count)
        XCTAssertEqual(333, cache.spans.t.root.children[0].leaf.count)
        XCTAssertEqual(32, cache.spans.t.root.children[0].leaf.spans.count)
        XCTAssertEqual(333, cache.spans.t.root.children[1].leaf.count)
        XCTAssertEqual(32, cache.spans.t.root.children[1].leaf.spans.count)

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

    func testInvalidateDeltaReplace() {
        var cache = makeContiguousCache(upperBound: 100, stride: 10)

        var b = Rope.DeltaBuilder(cache.upperBound)
        let abc = Rope("abc")
        b.replace(15..<17, with: abc)
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
}
