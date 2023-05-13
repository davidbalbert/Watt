//
//  LRUCacheTests.swift
//  LRUCacheTests
//
//  Created by David Albert on 4/29/23.
//

import XCTest
@testable import Watt

final class LRUCacheTests: XCTestCase {
    func testInsertAndRemove() {
        var c = LRUCache<String, String>(capacity: 10)
        XCTAssertEqual(0, c.count)
        c["foo"] = "bar"
        XCTAssertEqual(1, c.count)
        XCTAssertEqual("bar", c["foo"])
        c["foo"] = nil
        XCTAssertEqual(0, c.count)
        XCTAssertNil(c["foo"])
    }

    func testEvict() {
        var c = LRUCache<String, String>(capacity: 2)
        c["foo"] = "bar"
        XCTAssertEqual(1, c.count)
        XCTAssertEqual("bar", c["foo"])

        c["baz"] = "qux"
        XCTAssertEqual(2, c.count)
        XCTAssertEqual("bar", c["foo"])
        XCTAssertEqual("qux", c["baz"])

        c["quux"] = "quuux"
        XCTAssertEqual(2, c.count)
        XCTAssertNil(c["foo"])
        XCTAssertEqual("qux", c["baz"])
        XCTAssertEqual("quuux", c["quux"])
    }

    func testEvictSetOnly() {
        var c = LRUCache<String, String>(capacity: 2)
        c["foo"] = "bar"
        c["baz"] = "qux"
        c["baz"] = "quux"
        XCTAssertEqual(2, c.count)
        XCTAssertEqual("bar", c["foo"])
        XCTAssertEqual("quux", c["baz"])
    }

    func testEvictAfterGet() {
        var c = LRUCache<String, String>(capacity: 2)
        c["foo"] = "bar"
        c["baz"] = "qux"
        XCTAssertEqual(2, c.count)

        _ = c["foo"]

        c["quux"] = "quuux"
        XCTAssertEqual(2, c.count)
        XCTAssertNil(c["baz"])
        XCTAssertEqual("bar", c["foo"])
        XCTAssertEqual("quuux", c["quux"])
    }
}
