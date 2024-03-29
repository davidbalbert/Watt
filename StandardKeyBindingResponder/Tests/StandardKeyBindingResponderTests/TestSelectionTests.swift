//
//  TestSelectionTests.swift
//  
//
//  Created by David Albert on 11/9/23.
//

import XCTest
@testable import StandardKeyBindingResponder

final class TestSelectionTests: XCTestCase {
    func testCreateCaret() {
        let string = "Hello, world!"
        let s = TestSelection(caretAt: string.index(at: 1), affinity: .upstream, granularity: .character)
        XCTAssert(s.isCaret)
        XCTAssertEqual(string.index(at: 1), s.lowerBound)
        XCTAssertEqual(.upstream, s.affinity)
    }

    func testCreateDownstreamSelection() {
        let string = "Hello, world!"
        let s = TestSelection(anchor: string.index(at: 1), head: string.index(at: 5), granularity: .character)
        XCTAssert(s.isRange)
        XCTAssertEqual(string.index(at: 1), s.lowerBound)
        XCTAssertEqual(string.index(at: 5), s.upperBound)
        XCTAssertEqual(.downstream, s.affinity)
    }

    func createUpstreamSelection() {
        let string = "Hello, world!"
        let s = TestSelection(anchor: string.index(at: 5), head: string.index(at: 1), granularity: .character)
        XCTAssert(s.isRange)
        XCTAssertEqual(string.index(at: 1), s.lowerBound)
        XCTAssertEqual(string.index(at: 5), s.upperBound)
        XCTAssertEqual(.upstream, s.affinity)
    }
}
