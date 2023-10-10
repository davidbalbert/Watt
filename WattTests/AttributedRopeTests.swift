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
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
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
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attrs[.underlineColor] as? NSColor, .green)

        range = NSRange(location: 0, length: 0)
        attrs = s.attributes(at: 5, longestEffectiveRange: &range, in: NSRange(location: 0, length: s.length))
        XCTAssertEqual(range.location, 5)
        XCTAssertEqual(range.length, 8)
        XCTAssertEqual(attrs.count, 5)
        XCTAssertEqual(attrs[.font] as? NSFont, .systemFont(ofSize: 12))
        XCTAssertEqual(attrs[.foregroundColor] as? NSColor, .red)
        XCTAssertEqual(attrs[.backgroundColor] as? NSColor, .blue)
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
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
        var s = AttributedRope("")
        XCTAssertEqual(s.runs.count, 0)

        var new = AttributedRope("Hello, world!")
        new.font = .systemFont(ofSize: 12)

        s.insert(new, at: s.startIndex)
        XCTAssertEqual(String(s.text), "Hello, world!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testInsertIntoBeginningOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.insert(new, at: s.startIndex)
        XCTAssertEqual(String(s.text), "!Hello, world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 1)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testInsertIntoMiddleOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.insert(new, at: s.index(at: 5))
        XCTAssertEqual(String(s.text), "Hello!, world!")

        XCTAssertEqual(s.runs.count, 3)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 5)..<s.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s.index(at: 6)..<s.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testInsertIntoEndOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.insert(new, at: s.endIndex)
        XCTAssertEqual(String(s.text), "Hello, world!!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 13))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 13)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    // MARK: - Replacing in AttributedRope

    func testReplaceAtBeginningOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.replaceSubrange(s.startIndex..<s.index(at: 2), with: new)
        XCTAssertEqual(String(s.text), "!llo, world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 1)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testReplaceInMiddleOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.replaceSubrange(s.index(at: 5)..<s.index(at: 7), with: new)
        XCTAssertEqual(String(s.text), "Hello!world!")

        XCTAssertEqual(s.runs.count, 3)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 5)..<s.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s.index(at: 6)..<s.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testReplaceAtEndOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.replaceSubrange(s.index(at: 11)..<s.endIndex, with: new)
        XCTAssertEqual(String(s.text), "Hello, worl!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 11))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 11)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testReplaceEntireRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.replaceSubrange(s.startIndex..<s.endIndex, with: new)
        XCTAssertEqual(String(s.text), "!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    // MARK: - Deleting from AttributedRope

    func testDeleteAtBeginingOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        s.removeSubrange(s.startIndex..<s.index(at: 2))
        XCTAssertEqual(String(s.text), "llo, world!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeleteInMiddleOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        s.removeSubrange(s.index(at: 5)..<s.index(at: 7))
        XCTAssertEqual(String(s.text), "Helloworld!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeleteAtEndOfRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        s.removeSubrange(s.index(at: 11)..<s.endIndex)
        XCTAssertEqual(String(s.text), "Hello, worl")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    // MARK: - Appending to AttributedRope

    func testAppendToEmptyRope() {
        var s = AttributedRope("")
        XCTAssertEqual(s.runs.count, 0)

        var new = AttributedRope("Hello, world!")
        new.font = .systemFont(ofSize: 12)

        s.append(new)
        XCTAssertEqual(String(s.text), "Hello, world!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testAppendToNonEmptyRope() {
        var s = AttributedRope("Hello, world!")
        s.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)

        s.append(new)
        XCTAssertEqual(String(s.text), "Hello, world!!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 13))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 13)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    // MARK: - Inserting into CharacterView

    func testCharacterViewInsertIntoEmptyRope() {
        var s = AttributedRope("")
        XCTAssertEqual(s.runs.count, 0)

        s.characters.insert(contentsOf: "Hello, world!", at: s.startIndex)
        XCTAssertEqual(String(s.text), "Hello, world!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.attributes.count, 0)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewInsertAtBeginningInsertsIntoFirstRun() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.insert(contentsOf: "!", at: s.startIndex)
        XCTAssertEqual(String(s.text), "!Hello, world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 6))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 6)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewInsertingIntoTheMiddleOfARunInsertsIntoThatRun() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.insert(contentsOf: "!", at: s.index(at: 3))
        XCTAssertEqual(String(s.text), "Hel!lo, world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 6))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 6)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewInsertingIntoTheBeginningOfANonFirstRunInsertsIntoThePreviousRun() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.insert(contentsOf: "!", at: s.index(at: 5))
        XCTAssertEqual(String(s.text), "Hello!, world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 6))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 6)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    // MARK: - Replacing in CharacterView

    func testCharacterViewReplacingInsideARunAtTheBeginning() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.replaceSubrange(s.index(at: 5)..<s.index(at: 7), with: "!")
        XCTAssertEqual(String(s.text), "Hello!world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 5)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingInsideRunInTheMiddle() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.replaceSubrange(s.index(at: 6)..<s.index(at: 8), with: "!")
        XCTAssertEqual(String(s.text), "Hello,!orld!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 5)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingInsideRunAtTheEnd() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.replaceSubrange(s.index(at: 4)..<s.index(at: 5), with: "!")
        XCTAssertEqual(String(s.text), "Hell!, world!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 5)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingMultipleRunsFromStartOfARun() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.replaceSubrange(s.startIndex..<s.index(at: 10), with: "!")
        XCTAssertEqual(String(s.text), "!z")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 1)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingMultipleRunsFromMiddleOfRun() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.replaceSubrange(s.index(at: 1)..<s.index(at: 10), with: "!")
        XCTAssertEqual(String(s.text), "f!z")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 2)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingMultipleRunsThroughEndOfRun() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.replaceSubrange(s.index(at: 2)..<s.endIndex, with: "!")
        XCTAssertEqual(String(s.text), "fo!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewReplacingEntireString() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.replaceSubrange(s.startIndex..<s.endIndex, with: "!")
        XCTAssertEqual(String(s.text), "!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    // MARK: - Deleting from CharacterView

    func testCharacterViewDeletingEmptyRangeIsANoop() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.removeSubrange(s.startIndex..<s.startIndex)
        XCTAssertEqual(String(s.text), "foo bar baz")

        XCTAssertEqual(s.runs.count, 3)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 4)..<s.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s.index(at: 8)..<s.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingFromBeginningOfRun() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.removeSubrange(s.startIndex..<s.index(at: 2))
        XCTAssertEqual(String(s.text), "o bar baz")

        XCTAssertEqual(s.runs.count, 3)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.index(at: 0)..<s.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 2)..<s.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s.index(at: 6)..<s.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingFromMiddleOfRun() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.removeSubrange(s.index(at: 2)..<s.index(at: 10))
        XCTAssertEqual(String(s.text), "foz")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.index(at: 0)..<s.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 2)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingASingleRun() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.removeSubrange(s.index(at: 4)..<s.index(at: 8))
        XCTAssertEqual(String(s.text), "foo baz")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.index(at: 0)..<s.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 4)..<s.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testCharacterViewDeletingEntireString() {
        var s = AttributedRope("foo bar baz")
        s[s.startIndex..<s.index(at: 4)].font = .systemFont(ofSize: 12)
        s[s.index(at: 4)..<s.index(at: 8)].font = .systemFont(ofSize: 14)
        s[s.index(at: 8)..<s.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s.runs.count, 3)

        s.characters.removeSubrange(s.startIndex..<s.endIndex)
        XCTAssertEqual(String(s.text), "")

        XCTAssertEqual(s.runs.count, 0)
    }

    // MARK: - Appending to a CharacterView

    func testCharacterViewAppendingToEmptyRope() {
        var s = AttributedRope("")
        XCTAssertEqual(s.runs.count, 0)

        s.characters.append(contentsOf: "Hello, world!")
        XCTAssertEqual(String(s.text), "Hello, world!")

        XCTAssertEqual(s.runs.count, 1)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.endIndex)
        XCTAssertEqual(r0.attributes.count, 0)

        XCTAssertNil(iter.next())
    }

    func testCharacterViewAppendingToNonEmptyRope() {
        var s = AttributedRope("Hello, world!")
        s[s.startIndex..<s.index(at: 5)].font = .systemFont(ofSize: 12)
        XCTAssertEqual(s.runs.count, 2)

        s.characters.append(contentsOf: "!")
        XCTAssertEqual(String(s.text), "Hello, world!!")

        XCTAssertEqual(s.runs.count, 2)

        var iter = s.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s.startIndex..<s.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s.index(at: 5)..<s.endIndex)
        XCTAssertNil(r1.font)

        XCTAssertNil(iter.next())
    }

    func assertRunCountEquals(_ s: NSAttributedString, _ runCount: Int) {
        var c = 0
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { _, _, _ in
            c += 1
        }

        XCTAssertEqual(c, runCount)
    }

    // MARK: - Deltas

    func testDeltaInsertStringIntoEmptyRope() {
        let s1 = AttributedRope("")
        XCTAssertEqual(s1.runs.count, 0)

        let new = String("Hello, world!")

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.startIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 1)
        XCTAssertTrue(d.ropeDelta.elements[0].isInsert)

        XCTAssertEqual(d.spansDelta.elements.count, 1)
        XCTAssertTrue(d.spansDelta.elements[0].isInsert)

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.attributes.count, 0)

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertAttributedRopeIntoEmptyRope() {
        let s1 = AttributedRope("")
        XCTAssertEqual(s1.runs.count, 0)

        var new = AttributedRope("Hello, world!")
        new.font = .systemFont(ofSize: 12)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.startIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 1)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 1)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertStringIntoBeginningOfRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        let new = String("!")
        XCTAssertEqual(new.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.startIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertTrue(d.ropeDelta.elements[0].isInsert)
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(0, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertTrue(d.spansDelta.elements[0].isInsert)
        XCTAssertEqual(d.spansDelta.elements[1], .copy(0, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!Hello, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertAttributedRopeIntoBeginningOfRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.startIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(0, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(0, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!Hello, world!")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 1)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertAttributedRopeIntoBeginningOfRopeMergingAttributes() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 12)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.startIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(0, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(0, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!Hello, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertStringIntoMiddleOfRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 5)..<s1.index(at: 5), with: "!")
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 5))
        XCTAssertTrue(d.ropeDelta.elements[1].isInsert)
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(5, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 5))
        XCTAssertTrue(d.spansDelta.elements[1].isInsert)
        XCTAssertEqual(d.spansDelta.elements[2], .copy(5, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello!, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertAttributedRopeIntoMiddleOfRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 5)..<s1.index(at: 5), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 5))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(5, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 5))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[2], .copy(5, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello!, world!")
        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 5)..<s2.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 6)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 12))
        
        XCTAssertNil(iter.next())
    }

    func testDeltaInsertStringAtEndOfRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.endIndex..<s1.endIndex, with: "!")
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 13))
        XCTAssertTrue(d.ropeDelta.elements[1].isInsert)

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 13))
        XCTAssertTrue(d.spansDelta.elements[1].isInsert)

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, world!!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertAttributedRopeAtEndOfRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.endIndex..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 13))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 13))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, world!!")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 13))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 13)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testDeltaInsertAttributedRopeAtEndOfRopeMergingAttributes() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 12)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.endIndex..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 13))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 13))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, world!!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceBeginningOfRopeWithString() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        let new = String("!")
        XCTAssertEqual(new.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.index(at: 2), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertTrue(d.ropeDelta.elements[0].isInsert)
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(2, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertTrue(d.spansDelta.elements[0].isInsert)
        XCTAssertEqual(d.spansDelta.elements[1], .copy(2, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!llo, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceBeginningOfRopeWithAttributedRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.index(at: 2), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(2, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(2, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!llo, world!")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 1)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceBeginningOfRopeWithAttributedRopeMergingAttributes() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 14)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.index(at: 2), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(2, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(2, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!llo, world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMiddleOfRopeWithString() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 5)..<s1.index(at: 7), with: "!")
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 5))
        XCTAssertTrue(d.ropeDelta.elements[1].isInsert)
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(7, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 5))
        XCTAssertTrue(d.spansDelta.elements[1].isInsert)
        XCTAssertEqual(d.spansDelta.elements[2], .copy(7, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello!world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMiddleOfRopeWithAttributedRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 5)..<s1.index(at: 7), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 5))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(7, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 5))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[2], .copy(7, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello!world!")
        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 5))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 5)..<s2.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 6)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMiddleOfRopeWithAttributedRopeMergingAttributes() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 14)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 5)..<s1.index(at: 7), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 5))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(7, 13))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 5))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[2], .copy(7, 13))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello!world!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceAtEndOfRopeWithString() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        let new = String("!")
        XCTAssertEqual(new.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 11)..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 11))
        XCTAssertTrue(d.ropeDelta.elements[1].isInsert)

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 11))
        XCTAssertTrue(d.spansDelta.elements[1].isInsert)

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, worl!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceAtEndOfRopeWithAttributedRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 12)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 11)..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 11))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 11))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, worl!")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 11))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 11)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceAtEndOfRopeWithAttributedRopeMergingAttributes() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 14)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 14)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 11)..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 11))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 11))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "Hello, worl!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceEntireRopeWithString() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 14)
        XCTAssertEqual(s1.runs.count, 1)

        let new = String("!")
        XCTAssertEqual(new.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 1)
        XCTAssertTrue(d.ropeDelta.elements[0].isInsert)

        XCTAssertEqual(d.spansDelta.elements.count, 1)
        XCTAssertTrue(d.spansDelta.elements[0].isInsert)

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceEntireRopeWithAttributedRope() {
        var s1 = AttributedRope("Hello, world!")
        s1.font = .systemFont(ofSize: 14)
        XCTAssertEqual(s1.runs.count, 1)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 12)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 1)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 1)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsFromStartOfARunWithString() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.index(at: 10), with: "!")
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertTrue(d.ropeDelta.elements[0].isInsert)
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertTrue(d.spansDelta.elements[0].isInsert)
        XCTAssertEqual(d.spansDelta.elements[1], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!z")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 1)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsFromStartOfARunWithAttributedRope() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 18)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.index(at: 10), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!z")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 18))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 1)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsFromStartOfARunWithAttributedRopeMergingAttributes() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 16)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.startIndex..<s1.index(at: 10), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "!z")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsFromMiddleOfRunWithString() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 1)..<s1.index(at: 10), with: "!")
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 1))
        XCTAssertTrue(d.ropeDelta.elements[1].isInsert)
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 1))
        XCTAssertTrue(d.spansDelta.elements[1].isInsert)
        XCTAssertEqual(d.spansDelta.elements[2], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "f!z")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 2)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsFromMiddleOfRunWithAttributedRope() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 18)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 1)..<s1.index(at: 10), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 1))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 1))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[2], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "f!z")
        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 1)..<s2.index(at: 2))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 18))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 2)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsFromMiddleOfRunWithAttributedRopeMergingAttributes() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 16)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 1)..<s1.index(at: 10), with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 3)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 1))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))
        XCTAssertEqual(d.ropeDelta.elements[2], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 3)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 1))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))
        XCTAssertEqual(d.spansDelta.elements[2], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "f!z")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 1))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 1)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsThroughEndOfRunWithString() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 2)..<s1.endIndex, with: "!")
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 2))
        XCTAssertTrue(d.ropeDelta.elements[1].isInsert)

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 2))
        XCTAssertTrue(d.spansDelta.elements[1].isInsert)

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "fo!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsThroughEndOfRunWithAttributedRope() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 18)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 2)..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "fo!")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 2)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 18))

        XCTAssertNil(iter.next())
    }

    func testDeltaReplaceMultipleRunsThroughEndOfRunWithAttributedRopeMergingAttributes() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var new = AttributedRope("!")
        new.font = .systemFont(ofSize: 12)
        XCTAssertEqual(new.runs.count, 1)

        var b = AttributedRope.DeltaBuilder(s1)
        b.replaceSubrange(s1.index(at: 2)..<s1.endIndex, with: new)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.ropeDelta.elements[1], .insert(new.text.root))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.spansDelta.elements[1], .insert(new.spans.root))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "fo!")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeleteEmptyRangeIsANoop() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.startIndex..<s1.startIndex)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 1)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 1)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "foo bar baz")
        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 4)..<s2.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 8)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeleteFromBeginningOfRun() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.startIndex..<s1.index(at: 2))
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 1)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(2, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 1)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(2, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "o bar baz")
        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.index(at: 0)..<s2.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 2)..<s2.index(at: 6))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 6)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeleteFromMiddleOfRun() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 2)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 2)..<s1.index(at: 6)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 6)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.index(at: 2)..<s1.index(at: 10))
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "foz")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 2))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 2)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeleteFromMiddleOfRunMergingAttributes() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 2)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 2)..<s1.index(at: 6)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 6)..<s1.endIndex].font = .systemFont(ofSize: 12)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.index(at: 2)..<s1.index(at: 10))
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(10, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 2))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(10, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "foz")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeletASingleRun() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.index(at: 4)..<s1.index(at: 8))
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 4))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(8, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 4))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(8, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "foo baz")
        XCTAssertEqual(s2.runs.count, 2)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 4)..<s2.endIndex)
        XCTAssertEqual(r1.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeleteASingleRunMergingAttributes() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 12)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.index(at: 4)..<s1.index(at: 8))
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 2)
        XCTAssertEqual(d.ropeDelta.elements[0], .copy(0, 4))
        XCTAssertEqual(d.ropeDelta.elements[1], .copy(8, 11))

        XCTAssertEqual(d.spansDelta.elements.count, 2)
        XCTAssertEqual(d.spansDelta.elements[0], .copy(0, 4))
        XCTAssertEqual(d.spansDelta.elements[1], .copy(8, 11))

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "foo baz")
        XCTAssertEqual(s2.runs.count, 1)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.endIndex)
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        XCTAssertNil(iter.next())
    }

    func testDeltaDeleteEntireString() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 12)

        XCTAssertEqual(s1.runs.count, 3)

        var b = AttributedRope.DeltaBuilder(s1)
        b.removeSubrange(s1.startIndex..<s1.endIndex)
        let d = b.build()

        XCTAssertEqual(d.ropeDelta.elements.count, 0)
        XCTAssertEqual(d.spansDelta.elements.count, 0)

        let s2 = s1.applying(delta: d)
        XCTAssertEqual(String(s2.text), "")
        XCTAssertEqual(s2.runs.count, 0)
    }

    // MARK: - Transforming attributes

    func testTransformAttributeSetValue() {
        var s1 = AttributedRope("foo bar baz")
        s1.font = .systemFont(ofSize: 12)

        let s2 = s1.transformingAttributes(\.font) { attr in
            XCTAssertEqual(attr.value, .systemFont(ofSize: 12))
            attr.value = .systemFont(ofSize: 14)
        }

        XCTAssertEqual(s1.runs.count, 1)
        XCTAssertEqual(s1.font, .systemFont(ofSize: 12))

        XCTAssertEqual(s2.runs.count, 1)
        XCTAssertEqual(s2.font, .systemFont(ofSize: 14))
    }

    func testTransformAttributeSetValueMultipleRuns() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        let s2 = s1.transformingAttributes(\.font) { attr in
            attr.value = .systemFont(ofSize: 18)
        }

        XCTAssertEqual(s1.runs.count, 3)

        var iter = s1.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s1.startIndex..<s1.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s1.index(at: 4)..<s1.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s1.index(at: 8)..<s1.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())

        XCTAssertEqual(s2.runs.count, 1)
        XCTAssertEqual(s2.font, .systemFont(ofSize: 18))
    }

    func testTransformAttributesSetValueOneRun() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        let s2 = s1.transformingAttributes(\.font) { attr in
            if attr.value == .systemFont(ofSize: 14) {
                attr.value = .systemFont(ofSize: 18)
            }
        }

        XCTAssertEqual(s1.runs.count, 3)

        var iter = s1.runs.makeIterator()
        var r0 = iter.next()!
        XCTAssertEqual(r0.range, s1.startIndex..<s1.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        var r1 = iter.next()!
        XCTAssertEqual(r1.range, s1.index(at: 4)..<s1.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))

        var r2 = iter.next()!
        XCTAssertEqual(r2.range, s1.index(at: 8)..<s1.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())


        XCTAssertEqual(s2.runs.count, 3)

        iter = s2.runs.makeIterator()
        r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))

        r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 4)..<s2.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 18))

        r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 8)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))

        XCTAssertNil(iter.next())
    }

    func testTransformAttributesDontOverwriteOtherValues() {
        var s1 = AttributedRope("foo bar baz")
        s1.font = .systemFont(ofSize: 12)
        s1[s1.startIndex..<s1.index(at: 4)].foregroundColor = .red
        s1[s1.index(at: 4)..<s1.index(at: 8)].foregroundColor = .green
        s1[s1.index(at: 8)..<s1.endIndex].foregroundColor = .blue

        let s2 = s1.transformingAttributes(\.font) { attr in
            attr.value = .systemFont(ofSize: 14)
        }

        XCTAssertEqual(s1.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 14))
        XCTAssertEqual(r0.foregroundColor, .red)

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 4)..<s2.index(at: 8))
        XCTAssertEqual(r1.font, .systemFont(ofSize: 14))
        XCTAssertEqual(r1.foregroundColor, .green)

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 8)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 14))
        XCTAssertEqual(r2.foregroundColor, .blue)

        XCTAssertNil(iter.next())
    }

    func testTransformAttributesReplace() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        let s2 = s1.transformingAttributes(\.font) { attr in
            if attr.value == .systemFont(ofSize: 14) {
                attr.replace(with: \.foregroundColor, value: .red)
            }
        }

        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))
        XCTAssertNil(r0.foregroundColor)

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 4)..<s2.index(at: 8))
        XCTAssertNil(r1.font)
        XCTAssertEqual(r1.foregroundColor, .red)

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 8)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))
        XCTAssertNil(r2.foregroundColor)

        XCTAssertNil(iter.next())
    }

    func testTransformReplaceWithMultipleAttributes() {
        var s1 = AttributedRope("foo bar baz")
        s1[s1.startIndex..<s1.index(at: 4)].font = .systemFont(ofSize: 12)
        s1[s1.index(at: 4)..<s1.index(at: 8)].font = .systemFont(ofSize: 14)
        s1[s1.index(at: 8)..<s1.endIndex].font = .systemFont(ofSize: 16)

        let s2 = s1.transformingAttributes(\.font) { attr in
            if attr.value == .systemFont(ofSize: 14) {
                var newAttrs = AttributedRope.Attributes()
                newAttrs.foregroundColor = .red
                newAttrs.backgroundColor = .blue
                attr.replace(with: newAttrs)
            }
        }

        XCTAssertEqual(s2.runs.count, 3)

        var iter = s2.runs.makeIterator()
        let r0 = iter.next()!
        XCTAssertEqual(r0.range, s2.startIndex..<s2.index(at: 4))
        XCTAssertEqual(r0.font, .systemFont(ofSize: 12))
        XCTAssertNil(r0.foregroundColor)
        XCTAssertNil(r0.backgroundColor)

        let r1 = iter.next()!
        XCTAssertEqual(r1.range, s2.index(at: 4)..<s2.index(at: 8))
        XCTAssertNil(r1.font)
        XCTAssertEqual(r1.foregroundColor, .red)
        XCTAssertEqual(r1.backgroundColor, .blue)

        let r2 = iter.next()!
        XCTAssertEqual(r2.range, s2.index(at: 8)..<s2.endIndex)
        XCTAssertEqual(r2.font, .systemFont(ofSize: 16))
        XCTAssertNil(r2.foregroundColor)
        XCTAssertNil(r2.backgroundColor)

        XCTAssertNil(iter.next())
    }
}
