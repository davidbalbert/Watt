//
//  SortedCache.swift
//  WattTests
//
//  Created by David Albert on 12/8/23.
//

import XCTest
@testable import Watt

final class SortedCacheTests: XCTestCase {
    func testSubscript() {
        var dict: SortedCache = [1: "One", 2: "Two"]
        XCTAssertEqual(dict[1], "One")
        XCTAssertEqual(dict[2], "Two")

        dict[1] = "New One"
        XCTAssertEqual(dict[1], "New One")

        dict[1] = nil
        XCTAssertNil(dict[1])

        dict[3] = "Three"
        XCTAssertEqual(dict[3], "Three")
    }

    func testRemoveAll() {
        var dict: SortedCache = [1: "One", 2: "Two"]
        dict.removeAll()
        XCTAssertNil(dict[1])
        XCTAssertNil(dict[2])
    }

    func testKeyBefore() {
        var cache: SortedCache = [1: "One", 3: "Three", 5: "Five"]

        XCTAssertEqual(cache.key(before: 6), 5)
        XCTAssertEqual(cache.key(before: 5), 3)
        XCTAssertEqual(cache.key(before: 4), 3)
        XCTAssertEqual(cache.key(before: 3), 1)
        XCTAssertEqual(cache.key(before: 2), 1)
        XCTAssertNil(cache.key(before: 1))
        XCTAssertNil(cache.key(before: 0))

        cache = [:]
        XCTAssertNil(cache.key(before: 1))
    }

    func testInvalidate() {
        func t<V>(_ range: Range<Int>, _ cache: SortedCache<V>, _ expected: SortedCache<V>, file: StaticString = #file, line: UInt = #line) where V: Equatable {
            var c = cache
            c.invalidate(range: range)
            XCTAssertEqual(c, expected, file: file, line: line)
        }

        // unchanged
        func u<V>(_ range: Range<Int>, _ cache: SortedCache<V>, file: StaticString = #file, line: UInt = #line) where V: Equatable {
            var c = cache
            c.invalidate(range: range)
            XCTAssertEqual(c, cache, file: file, line: line)
        }

        // remove middle
        t(2..<4, c(1...5, "a"..."e"), [1: "a", 4: "d", 5: "e"])
        // doesn't have to be contiguous
        t(2..<4, c(1...5, "a"..."e", without: 4), [1: "a", 5: "e"])

        // empty ranges are unchanged
        u(0..<0, c(1...4))
        u(1..<1, c(1...4))
        u(3..<3, c(1...4))
        u(4..<4, c(1...4))
        u(5..<5, c(1...4))

        // empty prefix
        u(0..<2, c(2...5))
        // empty suffix
        u(6..<10, c(2...5))
        // overlapping prefix
        t(0..<2, c(1...5), c(2...5))
        // overlapping suffix
        t(5..<10, c(1...5), c(1...4))

        // covers fully
        t(5..<10, c(5..<10), [:])
        // subsumes
        t(0..<15, c(5..<10), [:])
        // inside
        t(5..<10, c(0..<20), c(0..<5) + c(10..<20))
    }
}

extension Unicode.Scalar: Strideable {
    public func distance(to other: Unicode.Scalar) -> Int {
        Int(other.value - value)
    }

    public func advanced(by n: Int) -> Unicode.Scalar {
        Unicode.Scalar(Int(value) + n)!
    }
}

fileprivate func c(_ kr: Range<Int>, without: Int...) -> SortedCache<Int> {
    cn(kr, kr, 1, without: without)
}
fileprivate func c(_ kr: ClosedRange<Int>, without: Int...) -> SortedCache<Int> {
    cn(kr, kr, 1, without: without)
}
fileprivate func c(_ kr: Range<Int>, _ vr: Range<Unicode.Scalar>, without: Int...) -> SortedCache<Unicode.Scalar> {
    cn(kr, vr, 1, without: without)
}
fileprivate func c(_ kr: ClosedRange<Int>, _ vr: ClosedRange<Unicode.Scalar>, without: Int...) -> SortedCache<Unicode.Scalar> {
    cn(kr, vr, 1, without: without)
}

fileprivate func c2(_ kr: Range<Int>, without: Int...) -> SortedCache<Int> {
    cn(kr, kr, 2, without: without)
}
fileprivate func c2(_ kr: ClosedRange<Int>, without: Int...) -> SortedCache<Int> {
    cn(kr, kr, 2, without: without)
}
fileprivate func c2(_ kr: Range<Int>, _ vr: Range<Unicode.Scalar>) -> SortedCache<Unicode.Scalar> {
    cn(kr, vr, 2)
}
fileprivate func c2(_ kr: ClosedRange<Int>, _ vr: ClosedRange<Unicode.Scalar>) -> SortedCache<Unicode.Scalar> {
    cn(kr, vr, 2)
}

fileprivate func cn<V>(_ kr: Range<Int>, _ vr: Range<V>, _ stride: Int, without: [Int] = []) -> SortedCache<V> where V: Hashable & Strideable, V.Stride == Int {
    assert(kr.count == vr.count)
    let keys = Swift.stride(from: kr.lowerBound, to: kr.upperBound, by: stride)
    let vals = Swift.stride(from: vr.lowerBound, to: vr.upperBound, by: stride)
    var dict = SortedCache(zip(keys, vals))
    for k in without {
        dict[k] = nil
    }
    return dict
}

fileprivate func cn<V>(_ kr: ClosedRange<Int>, _ vr: ClosedRange<V>, _ stride: Int, without: [Int] = []) -> SortedCache<V> where V: Hashable & Strideable, V.Stride == Int {
    assert(kr.count == vr.count)
    let keys = Swift.stride(from: kr.lowerBound, through: kr.upperBound, by: stride)
    let vals = Swift.stride(from: vr.lowerBound, through: vr.upperBound, by: stride)
    var dict = SortedCache(zip(keys, vals))
    for k in without {
        dict[k] = nil
    }
    return dict
}
