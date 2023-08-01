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

    func testInvalidate() {
        var cache = IntervalCache<Int>(upperBound: 20)
        cache.set(20, forRange: 5..<10)

        XCTAssert(cache.count == 1)
        XCTAssertEqual(cache[5], 20)
        cache.invalidate(range: 6..<7)
        XCTAssertNil(cache[5])
        XCTAssert(cache.isEmpty)
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
}
