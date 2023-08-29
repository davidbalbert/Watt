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

    func testBasicAttributeLookup() {
        var r = AttributedRope("Hello, world!")
        r[AttributedRope.AttributeKeys.FontAttribute.self] = .systemFont(ofSize: 12)
        XCTAssertEqual(r[AttributedRope.AttributeKeys.FontAttribute.self], .systemFont(ofSize: 12))
    }

    func testEmptyAttributedRope() {
        var r = AttributedRope("")
        XCTAssertEqual(r.runs.count, 0)

        XCTAssertNil(r.font)
        XCTAssertNil(r.foregroundColor)
        XCTAssertNil(r.backgroundColor)
        XCTAssertNil(r.underlineStyle)
        XCTAssertNil(r.underlineColor)

        // setting attributes has no effect
        r.font = .systemFont(ofSize: 12)
        r.foregroundColor = .red
        r.backgroundColor = .blue
        r.underlineStyle = .single
        r.underlineColor = .green

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
        r.foregroundColor = .red
        r.backgroundColor = .blue
        r.underlineStyle = .single
        r.underlineColor = .green

        XCTAssertEqual(r.runs.count, 1)

        XCTAssertEqual(r.font, NSFont.systemFont(ofSize: 12))
        XCTAssertEqual(r.foregroundColor, .red)
        XCTAssertEqual(r.backgroundColor, .blue)
        XCTAssertEqual(r.underlineStyle, .single)
        XCTAssertEqual(r.underlineColor, .green)

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

        // unsetting attributes
        r.font = nil
        r.foregroundColor = nil
        r.backgroundColor = nil
        r.underlineStyle = nil
        r.underlineColor = nil

        XCTAssertEqual(r.runs.count, 1)

        XCTAssertNil(r.font)
        XCTAssertNil(r.foregroundColor)
        XCTAssertNil(r.backgroundColor)
        XCTAssertNil(r.underlineStyle)
        XCTAssertNil(r.underlineColor)
    }

    func testAttributesOnAPortionOfTheRope() {
        var r = AttributedRope("Hello, world!")

        r.font = NSFont.systemFont(ofSize: 12)
        r.foregroundColor = .red
        r.backgroundColor = .blue
        r.underlineStyle = .single
        r.underlineColor = .green

        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 14)
        r[r.startIndex..<r.index(at: 5)].foregroundColor = .yellow

        XCTAssertEqual(r.runs.count, 2)

        XCTAssertNil(r.font)
        XCTAssertNil(r.foregroundColor)
        XCTAssertEqual(r.backgroundColor, .blue)
        XCTAssertEqual(r.underlineStyle, .single)
        XCTAssertEqual(r.underlineColor, .green)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))
        XCTAssertEqual(r0.foregroundColor, .yellow)
        XCTAssertEqual(r0.backgroundColor, .blue)
        XCTAssertEqual(r0.underlineStyle, .single)
        XCTAssertEqual(r0.underlineColor, .green)

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 5)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))
        XCTAssertEqual(r1.foregroundColor, .red)
        XCTAssertEqual(r1.backgroundColor, .blue)
        XCTAssertEqual(r1.underlineStyle, .single)
        XCTAssertEqual(r1.underlineColor, .green)

        let s = NSAttributedString(r)
        XCTAssertEqual(s.string, "Hello, world!")
        XCTAssertEqual(s.length, 13)
        assertRunCountEquals(s, 2)

        var range = NSRange(location: 0, length: 0)
        var attrs = s.attributes(at: 0, longestEffectiveRange: &range, in: NSRange(location: 0, length: s.length))
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, 5)
        XCTAssertEqual(attrs.count, 5)
        XCTAssertEqual(attrs[.font] as? NSFont, .systemFont(ofSize: 14))
        XCTAssertEqual(attrs[.foregroundColor] as? NSColor, .yellow)
        XCTAssertEqual(attrs[.backgroundColor] as? NSColor, .blue)
        XCTAssertEqual(attrs[.underlineStyle] as? NSUnderlineStyle, .single)
        XCTAssertEqual(attrs[.underlineColor] as? NSColor, .green)

        range = NSRange(location: 0, length: 0)
        attrs = s.attributes(at: 5, longestEffectiveRange: &range, in: NSRange(location: 0, length: s.length))
        XCTAssertEqual(range.location, 5)
        XCTAssertEqual(range.length, 8)
        XCTAssertEqual(attrs.count, 5)
        XCTAssertEqual(attrs[.font] as? NSFont, .systemFont(ofSize: 12))
        XCTAssertEqual(attrs[.foregroundColor] as? NSColor, .red)
        XCTAssertEqual(attrs[.backgroundColor] as? NSColor, .blue)
        XCTAssertEqual(attrs[.underlineStyle] as? NSUnderlineStyle, .single)
        XCTAssertEqual(attrs[.underlineColor] as? NSColor, .green)

        // merging ranges
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        r[r.startIndex..<r.index(at: 5)].foregroundColor = .red

        XCTAssertEqual(r.runs.count, 1)
        XCTAssertEqual(r.font, .systemFont(ofSize: 12))
        XCTAssertEqual(r.foregroundColor, .red)
        XCTAssertEqual(r.backgroundColor, .blue)
        XCTAssertEqual(r.underlineStyle, .single)
        XCTAssertEqual(r.underlineColor, .green)
    }

    func assertRunCountEquals(_ s: NSAttributedString, _ runCount: Int) {
        var c = 0
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { _, _, _ in
            c += 1
        }

        XCTAssertEqual(c, runCount)
    }
}
