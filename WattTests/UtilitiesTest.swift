//
//  UtilitiesTest.swift
//  WattTests
//
//  Created by David Albert on 8/30/23.
//

import XCTest
@testable import Watt

final class UtilitiesTest: XCTestCase {
    func testIsEqualTrue() {
        XCTAssertTrue(Watt.isEqual(1, 1))
        XCTAssertTrue(Watt.isEqual(1.0, 1.0))
        XCTAssertTrue(Watt.isEqual("hello", "hello"))
    }

    func testIsEqualSameTypeFalse() {
        XCTAssertFalse(Watt.isEqual(1, 2))
        XCTAssertFalse(Watt.isEqual(1.0, 2.0))
        XCTAssertFalse(Watt.isEqual("hello", "world"))
    }

    func testIsEqualDifferentTypeFalse() {
        XCTAssertFalse(Watt.isEqual(1, 1.0))
        XCTAssertFalse(Watt.isEqual(1.0, 1))
        XCTAssertFalse(Watt.isEqual(1, "hello"))
        XCTAssertFalse(Watt.isEqual("hello", 1))
        XCTAssertFalse(Watt.isEqual(1.0, "hello"))
        XCTAssertFalse(Watt.isEqual("hello", 1.0))
    }

    func testIsEqualBothNilTrue() {
        XCTAssertTrue(Watt.isEqual(nil, nil))
    }

    func testIsEqualOneNilFalse() {
        XCTAssertFalse(Watt.isEqual(1, nil))
        XCTAssertFalse(Watt.isEqual(nil, 1))
        XCTAssertFalse(Watt.isEqual(1.0, nil))
        XCTAssertFalse(Watt.isEqual(nil, 1.0))
        XCTAssertFalse(Watt.isEqual("hello", nil))
        XCTAssertFalse(Watt.isEqual(nil, "hello"))
    }

    func testIsEqualNonEquatable() {
        struct NonEquatable {}

        XCTAssertFalse(Watt.isEqual(NonEquatable(), NonEquatable()))
    }
}
