//
//  AttributedRopeTests.swift
//  WattTests
//
//  Created by David Albert on 8/27/23.
//

import XCTest
@testable import Watt

final class AttributedRopeTests: XCTestCase {
    // MARK: - AttributedSubrope conversion

    func testCreateFromAttributedSubrope() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        let subrope = r[r.index(at: 1)..<r.index(at: 10)]

        let new = AttributedRope(subrope)
        XCTAssertEqual(new.runs.count, 3)

        var iter = new.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, new.startIndex..<new.index(at: 3))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, new.index(at: 3)..<new.index(at: 7))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, new.index(at: 7)..<new.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

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

    // MARK: - Inserting into AttributedRope

    func testInsertIntoEmptyRope() {
        var r = AttributedRope("")
        XCTAssertEqual(r.runs.count, 0)

        var rr = AttributedRope("Hello, world!")
        rr.font = .systemFont(ofSize: 12)

        r.insert(rr, at: r.startIndex)
        XCTAssertEqual(String(r.text), "Hello, world!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testInsertIntoBeginningOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.insert(rr, at: r.startIndex)
        XCTAssertEqual(String(r.text), "!Hello, world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 1)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testInsertIntoMiddleOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.insert(rr, at: r.index(at: 5))
        XCTAssertEqual(String(r.text), "Hello!, world!")

        XCTAssertEqual(r.runs.count, 3)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 5)..<r.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, r.index(at: 6)..<r.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testInsertIntoAndOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.insert(rr, at: r.endIndex)
        XCTAssertEqual(String(r.text), "Hello, world!!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 13))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 13)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    // MARK: - Replacing in AttributedRope

    func testReplaceAtBeginningOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.replaceSubrange(r.startIndex..<r.index(at: 2), with: rr)
        XCTAssertEqual(String(r.text), "!llo, world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 1)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testReplaceInMiddleOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.replaceSubrange(r.index(at: 5)..<r.index(at: 7), with: rr)
        XCTAssertEqual(String(r.text), "Hello!world!")

        XCTAssertEqual(r.runs.count, 3)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 5)..<r.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, r.index(at: 6)..<r.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testReplaceAtEndOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.replaceSubrange(r.index(at: 11)..<r.endIndex, with: rr)
        XCTAssertEqual(String(r.text), "Hello, worl!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 11))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 11)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testReplaceEntireRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.replaceSubrange(r.startIndex..<r.endIndex, with: rr)
        XCTAssertEqual(String(r.text), "!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    // MARK: - Deleting from AttributedRope

    func testDeleteAtBeginingOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        r.removeSubrange(r.startIndex..<r.index(at: 2))
        XCTAssertEqual(String(r.text), "llo, world!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeleteInMiddleOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        r.removeSubrange(r.index(at: 5)..<r.index(at: 7))
        XCTAssertEqual(String(r.text), "Helloworld!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeleteAtEndOfRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        r.removeSubrange(r.index(at: 11)..<r.endIndex)
        XCTAssertEqual(String(r.text), "Hello, worl")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    // MARK: - Appending to AttributedRope

    func testAppendToEmptyRope() {
        var r = AttributedRope("")
        XCTAssertEqual(r.runs.count, 0)

        var rr = AttributedRope("Hello, world!")
        rr.font = .systemFont(ofSize: 12)

        r.append(rr)
        XCTAssertEqual(String(r.text), "Hello, world!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testAppendToNonEmptyRope() {
        var r = AttributedRope("Hello, world!")
        r.font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 1)

        var rr = AttributedRope("!")
        rr.font = .systemFont(ofSize: 14)

        r.append(rr)
        XCTAssertEqual(String(r.text), "Hello, world!!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 13))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 13)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    // MARK: - Inserting into CharacterView

    func testCharacterViewInsertIntoEmptyRope() {
        var r = AttributedRope("")
        XCTAssertEqual(r.runs.count, 0)

        r.characters.insert(contentsOf: "Hello, world!", at: r.startIndex)
        XCTAssertEqual(String(r.text), "Hello, world!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.attributes.count, 0)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewInsertAtBeginningInsertsIntoFirstRun() {
        var r = AttributedRope("Hello, world!")
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 2)

        r.characters.insert(contentsOf: "!", at: r.startIndex)
        XCTAssertEqual(String(r.text), "!Hello, world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 6))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 6)..<r.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewInsertingIntoTheMiddleOfARunInsertsIntoThatRun() {
        var r = AttributedRope("Hello, world!")
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 2)

        r.characters.insert(contentsOf: "!", at: r.index(at: 3))
        XCTAssertEqual(String(r.text), "Hel!lo, world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 6))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 6)..<r.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewInsertingIntoTheBeginningOfANonFirstRunInsertsIntoThePreviousRun() {
        var r = AttributedRope("Hello, world!")
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 2)

        r.characters.insert(contentsOf: "!", at: r.index(at: 5))
        XCTAssertEqual(String(r.text), "Hello!, world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 6))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 6)..<r.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    // MARK: - Replacing in CharacterView

    func testCharacterViewReplacingInsideARunAtTheBeginning() {
        var r = AttributedRope("Hello, world!")
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 2)

        r.characters.replaceSubrange(r.index(at: 5)..<r.index(at: 7), with: "!")
        XCTAssertEqual(String(r.text), "Hello!world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 5)..<r.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingInsideRunInTheMiddle() {
        var r = AttributedRope("Hello, world!")
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 2)

        r.characters.replaceSubrange(r.index(at: 6)..<r.index(at: 8), with: "!")
        XCTAssertEqual(String(r.text), "Hello,!orld!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 5)..<r.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingInsideRunAtTheEnd() {
        var r = AttributedRope("Hello, world!")
        r[r.startIndex..<r.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(r.runs.count, 2)

        r.characters.replaceSubrange(r.index(at: 4)..<r.index(at: 5), with: "!")
        XCTAssertEqual(String(r.text), "Hell!, world!")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 5)..<r.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingMultipleRunsFromStartOfARun() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.replaceSubrange(r.startIndex..<r.index(at: 10), with: "!")
        XCTAssertEqual(String(r.text), "!z")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 1)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingMultipleRunsFromMiddleOfRun() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.replaceSubrange(r.index(at: 1)..<r.index(at: 10), with: "!")
        XCTAssertEqual(String(r.text), "f!z")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 2)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingMultipleRunsThroughEndOfRun() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.replaceSubrange(r.index(at: 2)..<r.endIndex, with: "!")
        XCTAssertEqual(String(r.text), "fo!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingEntireString() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.replaceSubrange(r.startIndex..<r.endIndex, with: "!")
        XCTAssertEqual(String(r.text), "!")

        XCTAssertEqual(r.runs.count, 1)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    // MARK: - Deleting from CharacterView

    func testCharacterViewDeletingEmptyRangeIsANoop() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.removeSubrange(r.startIndex..<r.startIndex)
        XCTAssertEqual(String(r.text), "foo bar baz")

        XCTAssertEqual(r.runs.count, 3)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.startIndex..<r.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 4)..<r.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, r.index(at: 8)..<r.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingFromBeginningOfRun() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.removeSubrange(r.startIndex..<r.index(at: 2))
        XCTAssertEqual(String(r.text), "o bar baz")

        XCTAssertEqual(r.runs.count, 3)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.index(at: 0)..<r.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 2)..<r.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, r.index(at: 6)..<r.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingFromMiddleOfRun() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.removeSubrange(r.index(at: 2)..<r.index(at: 10))
        XCTAssertEqual(String(r.text), "foz")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.index(at: 0)..<r.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 2)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingASingleRun() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.removeSubrange(r.index(at: 4)..<r.index(at: 8))
        XCTAssertEqual(String(r.text), "foo baz")

        XCTAssertEqual(r.runs.count, 2)

        var iter = r.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, r.index(at: 0)..<r.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, r.index(at: 4)..<r.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingEntireString() {
        var r = AttributedRope("foo bar baz")
        r[r.startIndex..<r.index(at: 4)].font = .systemFont(ofSize: 12)
        r[r.index(at: 4)..<r.index(at: 8)].font = .systemFont(ofSize: 14)
        r[r.index(at: 8)..<r.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(r.runs.count, 3)

        r.characters.removeSubrange(r.startIndex..<r.endIndex)
        XCTAssertEqual(String(r.text), "")

        XCTAssertEqual(r.runs.count, 0)
    }

    // TODO: Appending to a CharacterView

    func assertRunCountEquals(_ s: NSAttributedString, _ runCount: Int) {
        var c = 0
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { _, _, _ in
            c += 1
        }

        XCTAssertEqual(c, runCount)
    }
}
