//
//  AttributedRopeTests.swift
//  WattTests
//
//  Created by David Albert on 8/27/23.
//

import XCTest
@testable import Watt

final class AttributedRopeTests: XCTestCase {
    // MARK: - NSAttributedString conversion

    func testEmptyAttributedRope() {
        let r = AttributedRope("")
        XCTAssertEqual(r.runs.count, 0)

        XCTAssertNil(r.font)
        XCTAssertNil(r.foregroundColor)
        XCTAssertNil(r.backgroundColor)
        XCTAssertNil(r.underlineStyle)
        XCTAssertNil(r.underlineColor)

        let s = NSAttributedString(r)
        XCTAssertEqual(s.string, "")
        XCTAssertEqual(s.length, 0)
        assertRunCountEquals(s, 0)
    }

    func testRopeWithNoAttributes() {
        let r = AttributedRope("Hello, world!")
        XCTAssertEqual(r.runs.count, 1)

        XCTAssertNil(r.font)
        XCTAssertNil(r.foregroundColor)
        XCTAssertNil(r.backgroundColor)
        XCTAssertNil(r.underlineStyle)
        XCTAssertNil(r.underlineColor)

        let s = NSAttributedString(r)
        XCTAssertEqual(s.string, "Hello, world!")
        XCTAssertEqual(s.length, 13)
        assertRunCountEquals(s, 1)

        var range = NSRange(location: 0, length: 0)
        let attrs = s.attributes(at: 0, longestEffectiveRange: &range, in: NSRange(location: 0, length: s.length))
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, 13)
        XCTAssertEqual(attrs.count, 0)
    }

    func testRopeWithAttributes() {
        var r = AttributedRope("Hello, world!")
        r.font = NSFont.systemFont(ofSize: 12)
        r.foregroundColor = NSColor.red
        r.backgroundColor = NSColor.blue
        r.underlineStyle = .single
        r.underlineColor = NSColor.green

        XCTAssertEqual(r.runs.count, 1)

        XCTAssertEqual(r.font, NSFont.systemFont(ofSize: 12))
        XCTAssertEqual(r.foregroundColor, NSColor.red)
        XCTAssertEqual(r.backgroundColor, NSColor.blue)
        XCTAssertEqual(r.underlineStyle, .single)
        XCTAssertEqual(r.underlineColor, NSColor.green)

        let s = NSAttributedString(r)
        XCTAssertEqual(s.string, "Hello, world!")
        XCTAssertEqual(s.length, 13)
        assertRunCountEquals(s, 1)

        var range = NSRange(location: 0, length: 0)
        let attrs = s.attributes(at: 0, longestEffectiveRange: &range, in: NSRange(location: 0, length: s.length))
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, 13)
        XCTAssertEqual(attrs.count, 5)
        XCTAssertEqual(attrs[.font] as? NSFont, .systemFont(ofSize: 12))
        XCTAssertEqual(attrs[.foregroundColor] as? NSColor, .red)
        XCTAssertEqual(attrs[.backgroundColor] as? NSColor, .blue)
        XCTAssertEqual(attrs[.underlineStyle] as? NSUnderlineStyle, .single)
        XCTAssertEqual(attrs[.underlineColor] as? NSColor, .green)
    }

    func assertRunCountEquals(_ s: NSAttributedString, _ runCount: Int) {
        var c = 0
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { _, _, _ in
            c += 1
        }

        XCTAssertEqual(c, runCount)
    }
}
