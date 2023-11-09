//
//  SimpleSelectionTests.swift
//  
//
//  Created by David Albert on 11/9/23.
//

import XCTest
@testable import StandardKeyBindingResponder

final class SimpleSelectionTests: XCTestCase {
    func testCreateCaret() {
        let string = "Hello, world!"
        let s = SimpleSelection(caretAt: string.index(at: 1), affinity: .upstream)
        XCTAssert(s.isCaret)
        XCTAssertEqual(string.index(at: 1), s.lowerBound)
        XCTAssertEqual(.upstream, s.affinity)
    }

    func testCreateDownstreamSelection() {
        let string = "Hello, world!"
        let s = SimpleSelection(anchor: string.index(at: 1), head: string.index(at: 5))
        XCTAssert(s.isRange)
        XCTAssertEqual(string.index(at: 1), s.lowerBound)
        XCTAssertEqual(string.index(at: 5), s.upperBound)
        XCTAssertEqual(.downstream, s.affinity)
    }

    func createUpstreamSelection() {
        let string = "Hello, world!"
        let s = SimpleSelection(anchor: string.index(at: 5), head: string.index(at: 1))
        XCTAssert(s.isRange)
        XCTAssertEqual(string.index(at: 1), s.lowerBound)
        XCTAssertEqual(string.index(at: 5), s.upperBound)
        XCTAssertEqual(.upstream, s.affinity)
    }
}
