//
//  RopeTests.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import XCTest
@testable import Watt

final class RopeTests: XCTestCase {
    // MARK: - Editing

    func testAppendCharacter() {
        var rope = Rope()
        rope.append("a")
        rope.append("b")
        rope.append("c")
        XCTAssertEqual(rope.count, 3)
        XCTAssertEqual("abc", String(rope))
    }

    func testInsertCharacter() {
        var rope = Rope()
        rope.insert("a", at: rope.startIndex)
        rope.insert("b", at: rope.startIndex)
        rope.insert("c", at: rope.startIndex)

        let i = rope.index(after: rope.startIndex)
        rope.insert("z", at: i)

        XCTAssertEqual(rope.count, 4)
        XCTAssertEqual("czba", String(rope))
    }

    func testInitWithString() {
        let rope = Rope("abc")
        XCTAssertEqual(rope.count, 3)
        XCTAssertEqual("abc", String(rope))
    }

    func testInitWithStringBiggerThanALeaf() {
        let string = String(repeating: "a", count: Chunk.maxSize+1)
        let rope = Rope(string)
        XCTAssertEqual(rope.count, Chunk.maxSize+1)
        XCTAssertEqual(string, String(rope))
    }

    func testAdd() {
        let s1 = String(repeating: "a", count: 2000)
        let s2 = String(repeating: "b", count: 2000)
        let rope = Rope(s1) + Rope(s2)
        XCTAssertEqual(4000, rope.count)
        XCTAssertEqual(s1 + s2, String(rope))
    }

    func testAddCopyOnWrite() {
        // Adding two can mutate the rope's underlying nodes. As of this writing,
        // it can specifically mutate the node belonging to the rope on the left
        // of the "+", though this is an implementation detail. We want to make
        // sure we don't mutate the storage of either ropes.
        let r1 = Rope("abc")
        let r2 = Rope("def")

        let r3 = r1 + r2
        XCTAssertEqual(6, r3.count)
        XCTAssertEqual("abcdef", String(r3))

        XCTAssertEqual(3, r1.count)
        XCTAssertEqual("abc", String(r1))

        XCTAssertEqual(3, r2.count)
        XCTAssertEqual("def", String(r2))
    }

    func testSlice() {
        let r = Rope(String(repeating: "a", count: 5000))
        let start = r.index(r.startIndex, offsetBy: 1000)
        let end = r.index(r.startIndex, offsetBy: 2000)

        let slice = r[start..<end]
        XCTAssertEqual(1000, slice.count)
        XCTAssertEqual(String(repeating: "a", count: 1000), String(slice))
    }

    func testSliceHuge() {
        let r = Rope(String(repeating: "a", count: 1_000_000))
        let start = r.index(r.startIndex, offsetBy: 40_000)
        let end = r.index(r.startIndex, offsetBy: 750_000)

        let slice = r[start..<end]
        XCTAssertEqual(710_000, slice.count)
        XCTAssertEqual(String(repeating: "a", count: 710_000), String(slice))
    }

    func testSliceCombiningCharactersAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))
        r.append("\u{0301}" + String(repeating: "b", count: 999))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16.count)
        XCTAssertEqual(2001, r.utf8.count)

        let i = r.index(at: 999)
        let r2 = r[i..<r.index(after: i)]

        XCTAssertEqual(0, r2.root.height)

        XCTAssertEqual(1, r2.count)
        XCTAssertEqual(2, r2.unicodeScalars.count)
        XCTAssertEqual(2, r2.utf16.count)
        XCTAssertEqual(3, r2.utf8.count)

        XCTAssertEqual("a\u{0301}", String(r2))
    }

    func testReplaceSubrangeFullRange() {
        var r = Rope("abc")
        r.replaceSubrange(r.startIndex..<r.endIndex, with: "def")
        XCTAssertEqual("def", String(r))
    }

    func testReplaceSubrangePrefix() {
        var r = Rope("Hello, world!")
        r.replaceSubrange(r.startIndex..<r.index(r.startIndex, offsetBy: 5), with: "Goodbye")
        XCTAssertEqual("Goodbye, world!", String(r))
    }

    func testReplaceSubrangeSuffix() {
        var r = Rope("Hello, world!")
        r.replaceSubrange(r.index(r.startIndex, offsetBy: 7)..<r.endIndex, with: "Moon?")
        XCTAssertEqual("Hello, Moon?", String(r))
    }

    func testReplaceSubrangeInternal() {
        var r = Rope("Hello, world!")
        r.replaceSubrange(r.index(r.startIndex, offsetBy: 7)..<r.index(r.endIndex, offsetBy: -1), with: "Earth")
        XCTAssertEqual("Hello, Earth!", String(r))
    }

    func testReplaceSubrangeVeryLong() {
        var r = Rope(String(repeating: "a", count: 1_000_000))
        let start = r.index(r.startIndex, offsetBy: 40_000)
        let end = r.index(r.startIndex, offsetBy: 750_000)

        r.replaceSubrange(start..<end, with: String(repeating: "b", count: 710_000))
        XCTAssertEqual(1_000_000, r.count)

        // use XCTAssert rather than XCTAssertEqual because Xcode chokes on showing an error
        // message that's ~1,000,000 characters long.
        XCTAssert(String(repeating: "a", count: 40_000) + String(repeating: "b", count: 710_000) + String(repeating: "a", count: 250_000) == String(r), "not equal")
    }

    func testAppendContentsOfInPlace() {
        var r = Rope("abc")
        r.append(contentsOf: "def")
        XCTAssertEqual("abcdef", String(r))
        XCTAssert(r.root.isUnique())

        #if DEBUG
        XCTAssertEqual(0, r.rootStorage.copyCount)
        #endif
    }

    func testAppendContentsOfCOW() {
        var r1 = Rope("abc")

        XCTAssert(r1.root.isUnique())

        var r2 = r1

        XCTAssertFalse(r1.root.isUnique())
        XCTAssertFalse(r2.root.isUnique())

        r1.append(contentsOf: "def")
        XCTAssertEqual("abcdef", String(r1))
        XCTAssertEqual("abc", String(r2))

        XCTAssert(r1.root.isUnique())
        XCTAssert(r2.root.isUnique())

        #if DEBUG
        XCTAssertEqual(1, r1.rootStorage.copyCount)
        #endif
    }

    func testAppendInPlace() {
        var r = Rope("abc")
        r.append("def")
        XCTAssertEqual("abcdef", String(r))
        XCTAssert(r.root.isUnique())
    }

    func testAppendCOW() {
        var r1 = Rope("abc")

        XCTAssert(r1.root.isUnique())

        var r2 = r1

        XCTAssertFalse(r1.root.isUnique())
        XCTAssertFalse(r2.root.isUnique())

        r1.append("def")
        XCTAssertEqual("abcdef", String(r1))
        XCTAssertEqual("abc", String(r2))

        XCTAssert(r1.root.isUnique())
        XCTAssert(r2.root.isUnique())
    }

    // MARK: - Summarization

    func testSummarizeASCII() {
        var r = Rope("foo\nbar\nbaz")

        XCTAssertEqual(11, r.root.count)
        XCTAssertEqual(11, r.root.summary.utf16)
        XCTAssertEqual(11, r.root.summary.scalars)
        XCTAssertEqual(11, r.root.summary.chars)
        XCTAssertEqual(2, r.root.summary.newlines)

        var i = r.utf8.index(at: 5)
        r.insert(contentsOf: "e", at: i)
        XCTAssertEqual("foo\nbear\nbaz", String(r))

        XCTAssertEqual(12, r.root.count)
        XCTAssertEqual(12, r.root.summary.utf16)
        XCTAssertEqual(12, r.root.summary.scalars)
        XCTAssertEqual(12, r.root.summary.chars)
        XCTAssertEqual(2, r.root.summary.newlines)

        i = r.utf8.index(at: 3)
        r.remove(at: i)
        XCTAssertEqual("foobear\nbaz", String(r))

        XCTAssertEqual(11, r.root.count)
        XCTAssertEqual(11, r.root.summary.utf16)
        XCTAssertEqual(11, r.root.summary.scalars)
        XCTAssertEqual(11, r.root.summary.chars)
        XCTAssertEqual(1, r.root.summary.newlines)
    }

    func testSummarizeASCIISplit() {
        let s = "foo\n"
        // 1024 == Chunk.maxSize + 1
        assert(1024 % s.utf8.count == 0)

        var r = Rope(String(repeating: s, count: 256))
        XCTAssertEqual(1024, r.root.count)
        XCTAssertEqual(1024, r.root.summary.utf16)
        XCTAssertEqual(1024, r.root.summary.scalars)
        XCTAssertEqual(1024, r.root.summary.chars)
        XCTAssertEqual(256, r.root.summary.newlines)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        // This is somewhat brittle. We're assuming that when the split happens
        // the first child ends up with 511 bytes and the second child ends up
        // with 513. We'll see how long this holds.
        //
        // The split puts a newline at the beginning of the second child.

        XCTAssertEqual(511, r.root.children[0].count)
        XCTAssertEqual(511, r.root.children[0].summary.utf16)
        XCTAssertEqual(511, r.root.children[0].summary.scalars)
        XCTAssertEqual(511, r.root.children[0].summary.chars)
        XCTAssertEqual(127, r.root.children[0].summary.newlines)

        XCTAssertEqual(513, r.root.children[1].count)
        XCTAssertEqual(513, r.root.children[1].summary.utf16)
        XCTAssertEqual(513, r.root.children[1].summary.scalars)
        XCTAssertEqual(513, r.root.children[1].summary.chars)
        XCTAssertEqual(129, r.root.children[1].summary.newlines)

        let i = r.utf8.index(at: 511)
        r.insert(contentsOf: "e", at: i)
        // counts of the root node are incremented by 1
        XCTAssertEqual(1025, r.root.count)
        XCTAssertEqual(1025, r.root.summary.utf16)
        XCTAssertEqual(1025, r.root.summary.chars)
        XCTAssertEqual(256, r.root.summary.newlines)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        // children[0] now has one more byte than it used to
        XCTAssertEqual(512, r.root.children[0].count)
        XCTAssertEqual(512, r.root.children[0].summary.utf16)
        XCTAssertEqual(512, r.root.children[0].summary.scalars)
        XCTAssertEqual(512, r.root.children[0].summary.chars)
        XCTAssertEqual(127, r.root.children[0].summary.newlines)

        // children[1] remains the same
        XCTAssertEqual(513, r.root.children[1].count)
        XCTAssertEqual(513, r.root.children[1].summary.utf16)
        XCTAssertEqual(513, r.root.children[1].summary.scalars)
        XCTAssertEqual(513, r.root.children[1].summary.chars)
        XCTAssertEqual(129, r.root.children[1].summary.newlines)
    }

    func testSummarizeASCIIHuge() {
        var r = Rope(String(repeating: "foo\n", count: 200_000))
        XCTAssertEqual(800_000, r.root.count)
        XCTAssertEqual(800_000, r.root.summary.utf16)
        XCTAssertEqual(800_000, r.root.summary.scalars)
        XCTAssertEqual(800_000, r.root.summary.chars)
        XCTAssertEqual(200_000, r.root.summary.newlines)

        let i = r.utf8.index(at: 400_000)
        r.insert(contentsOf: "e", at: i)
        XCTAssertEqual(String(repeating: "foo\n", count: 100_000) + "e" + String(repeating: "foo\n", count: 100_000), String(r))

        XCTAssertEqual(800_001, r.root.count)
        XCTAssertEqual(800_001, r.root.summary.utf16)
        XCTAssertEqual(800_001, r.root.summary.scalars)
        XCTAssertEqual(800_001, r.root.summary.chars)
        XCTAssertEqual(200_000, r.root.summary.newlines)

        let j = r.utf8.index(at: 200_000)
        r.insert(contentsOf: "\n", at: j)
        XCTAssertEqual(800_002, r.root.count)
        XCTAssertEqual(800_002, r.root.summary.utf16)
        XCTAssertEqual(800_002, r.root.summary.scalars)
        XCTAssertEqual(800_002, r.root.summary.chars)
        XCTAssertEqual(200_001, r.root.summary.newlines)
    }

    func testSummarizeCombiningCharacters() {
        var r = Rope("foo\u{0301}\nbar\nbaz") // "foó"
        XCTAssertEqual(11, r.count)
        XCTAssertEqual(12, r.unicodeScalars.count)
        XCTAssertEqual(12, r.utf16.count)
        XCTAssertEqual(13, r.utf8.count)
        XCTAssertEqual(3, r.lines.count)

        // this offset is in Characters, not UTF-8 code units or code points.
        // The "a" should be inserted after the "ó".

        let i = r.index(at: 3)
        r.insert(contentsOf: "a", at: i)
        XCTAssertEqual("foo\u{0301}a\nbar\nbaz", String(r)) // "foóa"

        XCTAssertEqual(12, r.count)
        XCTAssertEqual(13, r.unicodeScalars.count)
        XCTAssertEqual(13, r.utf16.count)
        XCTAssertEqual(14, r.utf8.count)
        XCTAssertEqual(3, r.lines.count)
    }

    func testRoundDownCombiningCharacters() {
        let r = Rope("foo\u{0301}") // "foó"
        XCTAssertEqual(3, r.count)
        XCTAssertEqual(4, r.unicodeScalars.count)
        XCTAssertEqual(4, r.utf16.count)
        XCTAssertEqual(5, r.utf8.count)

        var r0 = r
        var i = r0.utf8.index(at: 0)
        i = r0.utf8.index(at: 0)
        r0.insert(contentsOf: "a", at: i)
        XCTAssertEqual("afoo\u{0301}", String(r0)) // "afoó"
        XCTAssertEqual(4, r0.count)
        XCTAssertEqual(5, r0.unicodeScalars.count)
        XCTAssertEqual(5, r0.utf16.count)
        XCTAssertEqual(6, r0.utf8.count)

        var r1 = r
        i = r1.utf8.index(at: 1)
        r1.insert(contentsOf: "a", at: i)
        XCTAssertEqual("faoo\u{0301}", String(r1)) // "faóo"
        XCTAssertEqual(4, r1.count)
        XCTAssertEqual(5, r1.unicodeScalars.count)
        XCTAssertEqual(5, r1.utf16.count)
        XCTAssertEqual(6, r1.utf8.count)

        var r2 = r
        i = r2.utf8.index(at: 2)
        r2.insert(contentsOf: "a", at: i)
        XCTAssertEqual("foao\u{0301}", String(r2)) // "foaó"
        XCTAssertEqual(4, r2.count)
        XCTAssertEqual(5, r2.unicodeScalars.count)
        XCTAssertEqual(5, r2.utf16.count)
        XCTAssertEqual(6, r2.utf8.count)

        var r3 = r
        i = r3.utf8.index(at: 3)
        r3.insert(contentsOf: "a", at: i)
        XCTAssertEqual("foao\u{0301}", String(r2)) // "foaó"
        XCTAssertEqual(4, r3.count)
        XCTAssertEqual(5, r3.unicodeScalars.count)
        XCTAssertEqual(5, r3.utf16.count)
        XCTAssertEqual(6, r3.utf8.count)

        var r4 = r
        i = r4.utf8.index(at: 4)
        r4.insert(contentsOf: "a", at: i)
        XCTAssertEqual("foao\u{0301}", String(r2)) // "foaó"
        XCTAssertEqual(4, r4.count)
        XCTAssertEqual(5, r4.unicodeScalars.count)
        XCTAssertEqual(5, r4.utf16.count)
        XCTAssertEqual(6, r4.utf8.count)

        var r5 = r
        i = r5.utf8.index(at: 5)
        r5.insert(contentsOf: "a", at: i)
        XCTAssertEqual("foo\u{0301}a", String(r5)) // "foóa"
        XCTAssertEqual(4, r5.count)
        XCTAssertEqual(5, r5.unicodeScalars.count)
        XCTAssertEqual(5, r5.utf16.count)
        XCTAssertEqual(6, r5.utf8.count)
    }

    func testSummarizeCombiningCharactersAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))

        XCTAssertEqual(1000, r.count)
        XCTAssertEqual(1000, r.unicodeScalars.count)
        XCTAssertEqual(1000, r.utf16.count)
        XCTAssertEqual(1000, r.utf8.count)

        XCTAssertEqual(0, r.root.height)

        XCTAssertEqual(0, r.root.leaf.prefixCount)

        // 'combining accute accent' + "b"*999
        r.append("\u{0301}" + String(repeating: "b", count: 999))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16.count)
        XCTAssertEqual(2001, r.utf8.count)

        XCTAssertEqual("a\u{0301}", r[999])
    }

    // Appending a Rope directly uses an optimized code path.
    func testSummarizeCombiningCharactersAppendRopeAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))

        XCTAssertEqual(1000, r.count)
        XCTAssertEqual(1000, r.unicodeScalars.count)
        XCTAssertEqual(1000, r.utf16.count)
        XCTAssertEqual(1000, r.utf8.count)

        XCTAssertEqual(0, r.root.height)

        XCTAssertEqual(0, r.root.leaf.prefixCount)

        // 'combining accute accent' + "b"*999
        r.append(Rope("\u{0301}" + String(repeating: "b", count: 999)))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16.count)
        XCTAssertEqual(2001, r.utf8.count)

        XCTAssertEqual("a\u{0301}", r[999])
    }

    func testSummarizeCombiningCharactersReplaceSubrangeAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))

        XCTAssertEqual(1000, r.count)
        XCTAssertEqual(1000, r.unicodeScalars.count)
        XCTAssertEqual(1000, r.utf16.count)
        XCTAssertEqual(1000, r.utf8.count)

        XCTAssertEqual(0, r.root.height)

        XCTAssertEqual(0, r.root.leaf.prefixCount)

        // 'combining accute accent' + "b"*999
        r.replaceSubrange(r.endIndex..<r.endIndex, with: Rope("\u{0301}" + String(repeating: "b", count: 999)))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16.count)
        XCTAssertEqual(2001, r.utf8.count)

        XCTAssertEqual("a\u{0301}", r[999])
    }


    func testSummarizeCombiningCharactersSplit() {
        let s = "e\u{0301}\n"
        // 1024 == Chunk.maxSize + 1
        assert(1024 % s.utf8.count == 0)

        var r = Rope(String(repeating: s, count: 256))
        XCTAssertEqual(1024, r.root.count)          // utf8len("e") == utf8len("\n") == 1; utf8len("´") == 2, so 256 * 4
        XCTAssertEqual(768, r.root.summary.utf16)   // All codepoints are in the BMP, so no surrogate pairs. 3 codepoints/line.
        XCTAssertEqual(768, r.root.summary.scalars) // 3 scalars/line
        XCTAssertEqual(512, r.root.summary.chars)   // 2 chars/line
        XCTAssertEqual(256, r.root.summary.newlines) 

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        // Again, this is brittle. The split may not happen at 511/513 bytes.
        // This split puts a newline at the beginning of the second child.

        XCTAssertEqual(511, r.root.children[0].count)
        XCTAssertEqual(383, r.root.children[0].summary.utf16)   // "é\n"*127 + "é" => 3*127 + 2
        XCTAssertEqual(383, r.root.children[0].summary.scalars) // Same as above because all codepoints are in the BMP
        XCTAssertEqual(255, r.root.children[0].summary.chars)   // "é\n"*127 + "é" => 2*127 + 1
        XCTAssertEqual(127, r.root.children[0].summary.newlines)

        XCTAssertEqual(513, r.root.children[1].count)
        XCTAssertEqual(385, r.root.children[1].summary.utf16)   // "\n" + "é\n"*128 => 1 + 3*128
        XCTAssertEqual(385, r.root.children[1].summary.scalars) // Same as above because all codepoints are in the BMP
        XCTAssertEqual(257, r.root.children[1].summary.chars)   // "\n" + "é\n"*128 => 1 + 2*128
        XCTAssertEqual(129, r.root.children[1].summary.newlines)

        let i = r.utf8.index(at: 511)
        r.insert(contentsOf: "a\u{0301}", at: i)

        XCTAssertEqual(1027, r.root.count)           // added 3 bytes
        XCTAssertEqual(770, r.root.summary.utf16)    // 2 UTF-16 code units, with no surrogates
        XCTAssertEqual(770, r.root.summary.scalars)  // 2 scalars
        XCTAssertEqual(513, r.root.summary.chars)    // 1 char
        XCTAssertEqual(256, r.root.summary.newlines) // no newlines

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(514, r.root.children[0].count)            // added 3 bytes
        XCTAssertEqual(385, r.root.children[0].summary.utf16)    // 2 UTF-16 code units, with no surrogates
        XCTAssertEqual(385, r.root.children[0].summary.scalars)  // 2 scalars
        XCTAssertEqual(256, r.root.children[0].summary.chars)    // 1 char
        XCTAssertEqual(127, r.root.children[0].summary.newlines) // no newlines

        // children[1] remains the same
        XCTAssertEqual(513, r.root.children[1].count)
        XCTAssertEqual(385, r.root.children[1].summary.utf16)
        XCTAssertEqual(385, r.root.children[1].summary.scalars)
        XCTAssertEqual(257, r.root.children[1].summary.chars)
        XCTAssertEqual(129, r.root.children[1].summary.newlines)
    }

    func testSummarizeCombiningCharactersHuge() {
        var r = Rope(String(repeating: "e\u{0301}\n", count: 200_000))
        XCTAssertEqual(800_000, r.root.count)            // 4 bytes/line
        XCTAssertEqual(600_000, r.root.summary.utf16)    // 3 UTF-16 code units/line
        XCTAssertEqual(600_000, r.root.summary.scalars)  // 3 scalars/line
        XCTAssertEqual(400_000, r.root.summary.chars)    // 2 chars/line
        XCTAssertEqual(200_000, r.root.summary.newlines)

        let i = r.utf8.index(at: 400_000)
        r.insert(contentsOf: "a\u{0301}", at: i)
        XCTAssertEqual(String(repeating: "e\u{0301}\n", count: 100_000) + "a\u{0301}" + String(repeating: "e\u{0301}\n", count: 100_000), String(r))

        XCTAssertEqual(800_003, r.root.count)            // added 3 bytes
        XCTAssertEqual(600_002, r.root.summary.utf16)    // 2 UTF-16 code units, with no surrogates
        XCTAssertEqual(600_002, r.root.summary.scalars)  // 2 scalars
        XCTAssertEqual(400_001, r.root.summary.chars)    // 1 char
        XCTAssertEqual(200_000, r.root.summary.newlines) // no newlines

        let j = r.utf8.index(at: 200_000)
        r.insert(contentsOf: "\n", at: j)
        XCTAssertEqual(800_004, r.root.count)            // added 1 byte
        XCTAssertEqual(600_003, r.root.summary.utf16)    // 1 UTF-16 code unit, with no surrogates
        XCTAssertEqual(600_003, r.root.summary.scalars)  // 1 scalar
        XCTAssertEqual(400_002, r.root.summary.chars)    // 1 char
        XCTAssertEqual(200_001, r.root.summary.newlines) // 1 newline
    }

    func testSummarizeOutsideBMP() {
        var r = Rope("🙂🙂")

        XCTAssertEqual(8, r.root.count)
        XCTAssertEqual(4, r.root.summary.utf16)
        XCTAssertEqual(2, r.root.summary.scalars)
        XCTAssertEqual(2, r.root.summary.chars)
        XCTAssertEqual(0, r.root.summary.newlines)

        var i = r.utf8.index(at: 4)
        r.insert(contentsOf: "🙁", at: i)
        XCTAssertEqual("🙂🙁🙂", String(r))

        XCTAssertEqual(12, r.root.count)
        XCTAssertEqual(6, r.root.summary.utf16)
        XCTAssertEqual(3, r.root.summary.scalars)
        XCTAssertEqual(3, r.root.summary.chars)
        XCTAssertEqual(0, r.root.summary.newlines)

        // Inserting a character in the middle of a code point rounds down
        i = r.utf8.index(at: 6)
        r.insert(contentsOf: "👍", at: i)
        XCTAssertEqual("🙂👍🙁🙂", String(r))

        XCTAssertEqual(16, r.root.count)
        XCTAssertEqual(8, r.root.summary.utf16)
        XCTAssertEqual(4, r.root.summary.scalars)
        XCTAssertEqual(4, r.root.summary.chars)
        XCTAssertEqual(0, r.root.summary.newlines)
    }

    func testSummarizeOutsideBMPSplit() {
        let s = "🙋" // U+1F64B HAPPY PERSON RAISING ONE HAND
        // 1024 == Chunk.maxSize + 1
        assert(1024 % s.utf8.count == 0)

        var r = Rope(String(repeating: s, count: 256))
        XCTAssertEqual(1024, r.root.count)
        XCTAssertEqual(512, r.root.summary.utf16)
        XCTAssertEqual(256, r.root.summary.scalars)
        XCTAssertEqual(256, r.root.summary.chars)
        XCTAssertEqual(0, r.root.summary.newlines)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        // This time, the split happens at 512/512 because there are
        // no newlines.

        XCTAssertEqual(512, r.root.children[0].count)
        XCTAssertEqual(256, r.root.children[0].summary.utf16)
        XCTAssertEqual(128, r.root.children[0].summary.scalars)
        XCTAssertEqual(128, r.root.children[0].summary.chars)
        XCTAssertEqual(0, r.root.children[0].summary.newlines)

        XCTAssertEqual(512, r.root.children[1].count)
        XCTAssertEqual(256, r.root.children[1].summary.utf16)
        XCTAssertEqual(128, r.root.children[1].summary.scalars)
        XCTAssertEqual(128, r.root.children[1].summary.chars)
        XCTAssertEqual(0, r.root.children[1].summary.newlines)

        let i = r.utf8.index(at: 512)
        r.insert(contentsOf: "🏻", at: i) // U+1F3FB EMOJI MODIFIER FITZPATRICK TYPE-1

        XCTAssertEqual(1028, r.root.count)          // added 4 bytes
        XCTAssertEqual(514, r.root.summary.utf16)   // 2 UTF-16 code units (one surrogate pair)
        XCTAssertEqual(257, r.root.summary.scalars) // 1 scalar
        XCTAssertEqual(256, r.root.summary.chars)   // 0 chars (combined with previous)
        XCTAssertEqual(0, r.root.summary.newlines)  // 0 newlines

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(516, r.root.children[0].count)           // added 4 bytes
        XCTAssertEqual(258, r.root.children[0].summary.utf16)   // 2 UTF-16 code units (one surrogate pair)
        XCTAssertEqual(129, r.root.children[0].summary.scalars) // 1 scalar
        XCTAssertEqual(128, r.root.children[0].summary.chars)   // 0 chars (combined with previous)
        XCTAssertEqual(0, r.root.children[0].summary.newlines)  // 0 newlines

        // children[1] remains the same
        XCTAssertEqual(512, r.root.children[1].count)
        XCTAssertEqual(256, r.root.children[1].summary.utf16)
        XCTAssertEqual(128, r.root.children[1].summary.scalars)
        XCTAssertEqual(128, r.root.children[1].summary.chars)
        XCTAssertEqual(0, r.root.children[1].summary.newlines)
    }

    func testSummarizeOutsideBMPHuge() {
        var r = Rope(String(repeating: "🙋", count: 200_000))
        XCTAssertEqual(800_000, r.root.count)
        XCTAssertEqual(400_000, r.root.summary.utf16)
        XCTAssertEqual(200_000, r.root.summary.scalars)
        XCTAssertEqual(200_000, r.root.summary.chars)
        XCTAssertEqual(0, r.root.summary.newlines)

        let i = r.utf8.index(at: 400_000)
        r.insert(contentsOf: "🏻", at: i) // U+1F3FB EMOJI MODIFIER FITZPATRICK TYPE-1
        XCTAssertEqual(String(repeating: "🙋", count: 99_999) + "🙋🏻" + String(repeating: "🙋", count: 100_000), String(r))

        XCTAssertEqual(800_004, r.root.count)           // added 4 bytes
        XCTAssertEqual(400_002, r.root.summary.utf16)   // 2 UTF-16 code units (one surrogate pair)
        XCTAssertEqual(200_001, r.root.summary.scalars) // 1 scalar
        XCTAssertEqual(200_000, r.root.summary.chars)   // 0 chars (combined with previous)
        XCTAssertEqual(0, r.root.summary.newlines)      // 0 newlines
    }

    func testSummaryizeRegionalIndicators() {
        var r = Rope("🇺🇸🇺🇸🇺🇸🇺🇸🇺🇸") // 5 * [U+1F1FA REGIONAL INDICATOR SYMBOL LETTER U, U+1F1F8 REGIONAL INDICATOR SYMBOL LETTER S]
        XCTAssertEqual(5, r.count)
        XCTAssertEqual(10, r.unicodeScalars.count)
        XCTAssertEqual(20, r.utf16.count)
        XCTAssertEqual(40, r.utf8.count)
        XCTAssertEqual(1, r.lines.count)

        var i = r.utf8.index(at: 8)
        r.insert(contentsOf: "🇨🇦", at: i) // [U+1F1E8 REGIONAL INDICATOR SYMBOL LETTER C, U+1F1E6 REGIONAL INDICATOR SYMBOL LETTER A]
        XCTAssertEqual("🇺🇸🇨🇦🇺🇸🇺🇸🇺🇸🇺🇸", String(r))

        XCTAssertEqual(6, r.count)
        XCTAssertEqual(12, r.unicodeScalars.count)
        XCTAssertEqual(24, r.utf16.count)
        XCTAssertEqual(48, r.utf8.count)
        XCTAssertEqual(1, r.lines.count)

        i = r.utf8.index(at: 0)
        r.insert(contentsOf: "🇻", at: i) // U+1F1FB REGIONAL INDICATOR SYMBOL LETTER V
        XCTAssertEqual("🇻🇺🇸🇨🇦🇺🇸🇺🇸🇺🇸🇺🇸", String(r))

        XCTAssertEqual(7, r.count)
        XCTAssertEqual(13, r.unicodeScalars.count)
        XCTAssertEqual(26, r.utf16.count)
        XCTAssertEqual(52, r.utf8.count)
        XCTAssertEqual(1, r.lines.count)
    }

    func testConcatinateUpdatesGraphemeBreakState() {
        let r1 = Rope(String(repeating: "a", count: 1000))
        let r2 = Rope("\u{0301}" + String(repeating: "b", count: 999))

        XCTAssertEqual(0, r1.root.height)
        XCTAssertEqual(1000, r1.root.count)
        XCTAssertEqual(0, r1.root.leaf.prefixCount)

        XCTAssertEqual(0, r2.root.height)
        XCTAssertEqual(1001, r2.root.count) // "´" takes up two bytes
        XCTAssertEqual(0, r2.root.leaf.prefixCount)

        let r = r1 + r2

        XCTAssertEqual("a\u{0301}", r[999]) // U+0301 COMBINING ACUTE ACCENT
        
        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // Make sure r1 and r2 haven't changed
        XCTAssertEqual(0, r1.root.height)
        XCTAssertEqual(1000, r1.root.count)
        XCTAssertEqual(0, r1.root.leaf.prefixCount)

        XCTAssertEqual(0, r2.root.height)
        XCTAssertEqual(1001, r2.root.count) // "´" takes up two bytes
        XCTAssertEqual(0, r2.root.leaf.prefixCount)
    }

    // If you push a smaller tree followed by a bigger tree, builder concats them together
    // until we're pushing the smaller tree onto the stack. Make sure fixup happens here too.
    func testSmallFollowedByLargeRopeFixup() {
        var r1 = Rope(String(repeating: "a", count: 1000))
        var r2 = Rope("\u{0301}" + String(repeating: "b", count: 1999))

        XCTAssertEqual(0, r1.root.height)
        XCTAssertEqual(1000, r1.root.count)
        XCTAssertEqual(0, r1.root.leaf.prefixCount)

        XCTAssertEqual(1, r2.root.height)
        XCTAssertEqual(2, r2.root.children.count)
        XCTAssertEqual(0, r2.root.children[0].leaf.prefixCount)
        XCTAssertEqual(0, r2.root.children[1].leaf.prefixCount)

        XCTAssertEqual(2001, r2.utf8.count) // "´" takes up two bytes

        var b = BTreeBuilder<Rope>()
        b.push(&r1.root)
        b.push(&r2.root)
        let r = b.build()

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(3, r.root.children.count)
        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)
        XCTAssertEqual(0, r.root.children[2].leaf.prefixCount)

        XCTAssertEqual(3001, r.utf8.count) // "´" takes up two bytes
    }

    // MARK: - Index tests

    func testIndexBeforeAfterASCII() {
        let r = Rope("Hello, world!")

        XCTAssertEqual(0, r.startIndex.position)
        XCTAssertEqual(13, r.endIndex.position)

        let i = r.index(after: r.startIndex)

        XCTAssertEqual(1, i.position)
        XCTAssertEqual(0, r.index(before: i).position)

        let j = r.index(before: r.endIndex)

        XCTAssertEqual(12, j.position)
        XCTAssertEqual(13, r.index(after: j).position)
    }

    func testIndexOffsetByASCII() {
        let r = Rope("Hello, world!")

        let i = r.index(r.startIndex, offsetBy: 3)
        XCTAssertEqual(3, i.position)

        let j = r.index(i, offsetBy: -2)
        XCTAssertEqual(1, j.position)
    }

    func testIndexOffsetByLimitedByASCII() {
        let r = Rope("Hello, world!")

        let i = r.index(r.startIndex, offsetBy: 3, limitedBy: r.endIndex)
        XCTAssertEqual(3, i?.position)

        let j = r.index(r.startIndex, offsetBy: 30, limitedBy: r.endIndex)
        XCTAssertNil(j)
    }

    func testIndexAfterJoinedEmoji() {
        // [Man, ZWJ, Laptop, Man, ZWJ, Laptop]
        // UTF-16 count: 2*(2+1+2)
        // UTF-8 count: 2*(4+3+4)
        let r = Rope("👨‍💻🧑‍💻")

        XCTAssertEqual(2, r.count)
        XCTAssertEqual(6, r.unicodeScalars.count)
        XCTAssertEqual(10, r.utf16.count)
        XCTAssertEqual(22, r.utf8.count)

        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 0)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 1)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 2)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 3)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 4)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 5)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 6)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 7)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 8)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 9)).position)
        XCTAssertEqual(11, r.index(after: r.utf8.index(at: 10)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 11)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 12)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 13)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 14)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 15)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 16)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 17)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 18)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 19)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 20)).position)
        XCTAssertEqual(22, r.index(after: r.utf8.index(at: 21)).position)

        XCTAssertEqual(4, r.unicodeScalars.index(after: r.utf8.index(at: 0)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(after: r.utf8.index(at: 1)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(after: r.utf8.index(at: 2)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(after: r.utf8.index(at: 3)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(after: r.utf8.index(at: 4)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(after: r.utf8.index(at: 5)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(after: r.utf8.index(at: 6)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(after: r.utf8.index(at: 7)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(after: r.utf8.index(at: 8)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(after: r.utf8.index(at: 9)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(after: r.utf8.index(at: 10)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(after: r.utf8.index(at: 11)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(after: r.utf8.index(at: 12)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(after: r.utf8.index(at: 13)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(after: r.utf8.index(at: 14)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(after: r.utf8.index(at: 15)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(after: r.utf8.index(at: 16)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(after: r.utf8.index(at: 17)).position)
        XCTAssertEqual(22, r.unicodeScalars.index(after: r.utf8.index(at: 18)).position)
        XCTAssertEqual(22, r.unicodeScalars.index(after: r.utf8.index(at: 19)).position)
        XCTAssertEqual(22, r.unicodeScalars.index(after: r.utf8.index(at: 20)).position)
        XCTAssertEqual(22, r.unicodeScalars.index(after: r.utf8.index(at: 21)).position)

        XCTAssertEqual(1, r.utf8.index(after: r.utf8.index(at: 0)).position)
        XCTAssertEqual(2, r.utf8.index(after: r.utf8.index(at: 1)).position)
        XCTAssertEqual(3, r.utf8.index(after: r.utf8.index(at: 2)).position)
        XCTAssertEqual(4, r.utf8.index(after: r.utf8.index(at: 3)).position)
        XCTAssertEqual(5, r.utf8.index(after: r.utf8.index(at: 4)).position)
        XCTAssertEqual(6, r.utf8.index(after: r.utf8.index(at: 5)).position)
        XCTAssertEqual(7, r.utf8.index(after: r.utf8.index(at: 6)).position)
        XCTAssertEqual(8, r.utf8.index(after: r.utf8.index(at: 7)).position)
        XCTAssertEqual(9, r.utf8.index(after: r.utf8.index(at: 8)).position)
        XCTAssertEqual(10, r.utf8.index(after: r.utf8.index(at: 9)).position)
        XCTAssertEqual(11, r.utf8.index(after: r.utf8.index(at: 10)).position)
        XCTAssertEqual(12, r.utf8.index(after: r.utf8.index(at: 11)).position)
        XCTAssertEqual(13, r.utf8.index(after: r.utf8.index(at: 12)).position)
        XCTAssertEqual(14, r.utf8.index(after: r.utf8.index(at: 13)).position)
        XCTAssertEqual(15, r.utf8.index(after: r.utf8.index(at: 14)).position)
        XCTAssertEqual(16, r.utf8.index(after: r.utf8.index(at: 15)).position)
        XCTAssertEqual(17, r.utf8.index(after: r.utf8.index(at: 16)).position)
        XCTAssertEqual(18, r.utf8.index(after: r.utf8.index(at: 17)).position)
        XCTAssertEqual(19, r.utf8.index(after: r.utf8.index(at: 18)).position)
        XCTAssertEqual(20, r.utf8.index(after: r.utf8.index(at: 19)).position)
        XCTAssertEqual(21, r.utf8.index(after: r.utf8.index(at: 20)).position)
        XCTAssertEqual(22, r.utf8.index(after: r.utf8.index(at: 21)).position)
    }

    func testIndexBeforeJoinedEmoji() {
        // [Man, ZWJ, Laptop, Man, ZWJ, Laptop]
        // UTF-16 count: 2*(2+1+2)
        // UTF-8 count: 2*(4+3+4)
        let r = Rope("👨‍💻🧑‍💻")

        XCTAssertEqual(2, r.count)
        XCTAssertEqual(6, r.unicodeScalars.count)
        XCTAssertEqual(10, r.utf16.count)
        XCTAssertEqual(22, r.utf8.count)

        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 1)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 2)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 3)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 4)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 5)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 6)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 7)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 8)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 9)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 10)).position)
        XCTAssertEqual(0, r.index(before: r.utf8.index(at: 11)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 12)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 13)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 14)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 15)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 16)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 17)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 18)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 19)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 20)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 21)).position)
        XCTAssertEqual(11, r.index(before: r.utf8.index(at: 22)).position)

        XCTAssertEqual(0, r.unicodeScalars.index(before: r.utf8.index(at: 1)).position)
        XCTAssertEqual(0, r.unicodeScalars.index(before: r.utf8.index(at: 2)).position)
        XCTAssertEqual(0, r.unicodeScalars.index(before: r.utf8.index(at: 3)).position)
        XCTAssertEqual(0, r.unicodeScalars.index(before: r.utf8.index(at: 4)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(before: r.utf8.index(at: 5)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(before: r.utf8.index(at: 6)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(before: r.utf8.index(at: 7)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(before: r.utf8.index(at: 8)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(before: r.utf8.index(at: 9)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(before: r.utf8.index(at: 10)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(before: r.utf8.index(at: 11)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(before: r.utf8.index(at: 12)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(before: r.utf8.index(at: 13)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(before: r.utf8.index(at: 14)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(before: r.utf8.index(at: 15)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(before: r.utf8.index(at: 16)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(before: r.utf8.index(at: 17)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(before: r.utf8.index(at: 18)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(before: r.utf8.index(at: 19)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(before: r.utf8.index(at: 20)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(before: r.utf8.index(at: 21)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(before: r.utf8.index(at: 22)).position)

        XCTAssertEqual(0, r.utf8.index(before: r.utf8.index(at: 1)).position)
        XCTAssertEqual(1, r.utf8.index(before: r.utf8.index(at: 2)).position)
        XCTAssertEqual(2, r.utf8.index(before: r.utf8.index(at: 3)).position)
        XCTAssertEqual(3, r.utf8.index(before: r.utf8.index(at: 4)).position)
        XCTAssertEqual(4, r.utf8.index(before: r.utf8.index(at: 5)).position)
        XCTAssertEqual(5, r.utf8.index(before: r.utf8.index(at: 6)).position)
        XCTAssertEqual(6, r.utf8.index(before: r.utf8.index(at: 7)).position)
        XCTAssertEqual(7, r.utf8.index(before: r.utf8.index(at: 8)).position)
        XCTAssertEqual(8, r.utf8.index(before: r.utf8.index(at: 9)).position)
        XCTAssertEqual(9, r.utf8.index(before: r.utf8.index(at: 10)).position)
        XCTAssertEqual(10, r.utf8.index(before: r.utf8.index(at: 11)).position)
        XCTAssertEqual(11, r.utf8.index(before: r.utf8.index(at: 12)).position)
        XCTAssertEqual(12, r.utf8.index(before: r.utf8.index(at: 13)).position)
        XCTAssertEqual(13, r.utf8.index(before: r.utf8.index(at: 14)).position)
        XCTAssertEqual(14, r.utf8.index(before: r.utf8.index(at: 15)).position)
        XCTAssertEqual(15, r.utf8.index(before: r.utf8.index(at: 16)).position)
        XCTAssertEqual(16, r.utf8.index(before: r.utf8.index(at: 17)).position)
        XCTAssertEqual(17, r.utf8.index(before: r.utf8.index(at: 18)).position)
        XCTAssertEqual(18, r.utf8.index(before: r.utf8.index(at: 19)).position)
        XCTAssertEqual(19, r.utf8.index(before: r.utf8.index(at: 20)).position)
        XCTAssertEqual(20, r.utf8.index(before: r.utf8.index(at: 21)).position)
        XCTAssertEqual(21, r.utf8.index(before: r.utf8.index(at: 22)).position)
    }

    func testIndexRoundingDownJoinedEmoji() {
        // [Man, ZWJ, Laptop, Man, ZWJ, Laptop]
        // UTF-16 count: 2*(2+1+2)
        // UTF-8 count: 2*(4+3+4)
        let r = Rope("👨‍💻🧑‍💻")

        XCTAssertEqual(2, r.count)
        XCTAssertEqual(6, r.unicodeScalars.count)
        XCTAssertEqual(10, r.utf16.count)
        XCTAssertEqual(22, r.utf8.count)

        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 0)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 1)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 2)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 3)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 4)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 5)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 6)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 7)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 8)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 9)).position)
        XCTAssertEqual(0, r.index(roundingDown: r.utf8.index(at: 10)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 11)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 12)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 13)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 14)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 15)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 16)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 17)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 18)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 19)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 20)).position)
        XCTAssertEqual(11, r.index(roundingDown: r.utf8.index(at: 21)).position)
        XCTAssertEqual(22, r.index(roundingDown: r.utf8.index(at: 22)).position)

        XCTAssertEqual(0, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 0)).position)
        XCTAssertEqual(0, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 1)).position)
        XCTAssertEqual(0, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 2)).position)
        XCTAssertEqual(0, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 3)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 4)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 5)).position)
        XCTAssertEqual(4, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 6)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 7)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 8)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 9)).position)
        XCTAssertEqual(7, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 10)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 11)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 12)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 13)).position)
        XCTAssertEqual(11, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 14)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 15)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 16)).position)
        XCTAssertEqual(15, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 17)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 18)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 19)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 20)).position)
        XCTAssertEqual(18, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 21)).position)
        XCTAssertEqual(22, r.unicodeScalars.index(roundingDown: r.utf8.index(at: 22)).position)

        XCTAssertEqual(0, r.utf8.index(roundingDown: r.utf8.index(at: 0)).position)
        XCTAssertEqual(1, r.utf8.index(roundingDown: r.utf8.index(at: 1)).position)
        XCTAssertEqual(2, r.utf8.index(roundingDown: r.utf8.index(at: 2)).position)
        XCTAssertEqual(3, r.utf8.index(roundingDown: r.utf8.index(at: 3)).position)
        XCTAssertEqual(4, r.utf8.index(roundingDown: r.utf8.index(at: 4)).position)
        XCTAssertEqual(5, r.utf8.index(roundingDown: r.utf8.index(at: 5)).position)
        XCTAssertEqual(6, r.utf8.index(roundingDown: r.utf8.index(at: 6)).position)
        XCTAssertEqual(7, r.utf8.index(roundingDown: r.utf8.index(at: 7)).position)
        XCTAssertEqual(8, r.utf8.index(roundingDown: r.utf8.index(at: 8)).position)
        XCTAssertEqual(9, r.utf8.index(roundingDown: r.utf8.index(at: 9)).position)
        XCTAssertEqual(10, r.utf8.index(roundingDown: r.utf8.index(at: 10)).position)
        XCTAssertEqual(11, r.utf8.index(roundingDown: r.utf8.index(at: 11)).position)
        XCTAssertEqual(12, r.utf8.index(roundingDown: r.utf8.index(at: 12)).position)
        XCTAssertEqual(13, r.utf8.index(roundingDown: r.utf8.index(at: 13)).position)
        XCTAssertEqual(14, r.utf8.index(roundingDown: r.utf8.index(at: 14)).position)
        XCTAssertEqual(15, r.utf8.index(roundingDown: r.utf8.index(at: 15)).position)
        XCTAssertEqual(16, r.utf8.index(roundingDown: r.utf8.index(at: 16)).position)
        XCTAssertEqual(17, r.utf8.index(roundingDown: r.utf8.index(at: 17)).position)
        XCTAssertEqual(18, r.utf8.index(roundingDown: r.utf8.index(at: 18)).position)
        XCTAssertEqual(19, r.utf8.index(roundingDown: r.utf8.index(at: 19)).position)
        XCTAssertEqual(20, r.utf8.index(roundingDown: r.utf8.index(at: 20)).position)
        XCTAssertEqual(21, r.utf8.index(roundingDown: r.utf8.index(at: 21)).position)
        XCTAssertEqual(22, r.utf8.index(roundingDown: r.utf8.index(at: 22)).position)
    }

    func testNextCharacterAtBoundaryWithoutCombining() {
        let s = String(repeating: "a", count: 1023) + String(repeating: "b", count: 1023)
        let r = Rope(s)

        let i = r.utf8.index(at: 1022)
        XCTAssertEqual(1023, r.index(after: i).position)
    }

    func testNextCharacterAtBoundaryWithCombining() {
        let s = String(repeating: "a", count: 1023) + "\u{0301}" + String(repeating: "b", count: 1022) // U+0301 COMBINING ACUTE ACCENT
        let r = Rope(s)

        let i = r.utf8.index(at: 1022)
        XCTAssertEqual(1025, r.index(after: i).position)
    }

    func testPrevCharacterAtBoundaryWithoutCombining() {
        let s = String(repeating: "a", count: 1023) + String(repeating: "b", count: 1023)
        let r = Rope(s)

        var i = r.utf8.index(at: 1024)

        i = r.index(before: i)
        XCTAssertEqual(1023, i.position)

        i = r.index(before: i)
        XCTAssertEqual(1022, i.position)
    }

    func testPrevCharacterAtBoundaryWithCombining() {
        let s = String(repeating: "a", count: 1023) + "\u{0301}" + String(repeating: "b", count: 1022) // U+0301 COMBINING ACUTE ACCENT
        let r = Rope(s)

        let i = r.utf8.index(at: 1025)
        XCTAssertEqual(1022, r.index(before: i).position)
    }

    func testIndexOffsetByUTF16Surrogates() {
        var r = Rope("🙂")
        XCTAssertEqual(1, r.unicodeScalars.count)
        XCTAssertEqual(2, r.utf16.count)

        var i = r.utf16.index(r.startIndex, offsetBy: 1)
        XCTAssertEqual(r.startIndex, i)

        i = r.utf16.index(r.startIndex, offsetBy: 2)
        XCTAssertEqual(r.unicodeScalars.index(at: 1), i)

        r = Rope("🇺🇸")
        XCTAssertEqual(2, r.unicodeScalars.count)
        XCTAssertEqual(4, r.utf16.count)

        i = r.utf16.index(r.startIndex, offsetBy: 1)
        XCTAssertEqual(r.startIndex, i)

        i = r.utf16.index(r.startIndex, offsetBy: 2)
        XCTAssertEqual(r.unicodeScalars.index(at: 1), i)

        i = r.utf16.index(r.startIndex, offsetBy: 3)
        XCTAssertEqual(r.unicodeScalars.index(at: 1), i)

        i = r.utf16.index(r.startIndex, offsetBy: 4)
        XCTAssertEqual(r.unicodeScalars.index(at: 2), i)
    }

    // MARK: - Lines

    func testShortLines() {
        var r = Rope("foo\nbar\nbaz")

        XCTAssertEqual(3, r.lines.count)
        XCTAssertEqual("foo\n", r.lines[0])
        XCTAssertEqual("bar\n", r.lines[1])
        XCTAssertEqual("baz", r.lines[2])

        XCTAssertEqual(["foo\n", "bar\n", "baz"], Array(r.lines))

        r = Rope("foo\nbar\nbaz\n")

        XCTAssertEqual(4, r.lines.count)
        XCTAssertEqual("foo\n", r.lines[0])
        XCTAssertEqual("bar\n", r.lines[1])
        XCTAssertEqual("baz\n", r.lines[2])
        XCTAssertEqual("", r.lines[3])

        XCTAssertEqual(["foo\n", "bar\n", "baz\n", ""], Array(r.lines))
    }

    func testLongLines() {
        let a = String(repeating: "a", count: 2000) + "\n"
        let b = String(repeating: "b", count: 2000) + "\n"
        let c = String(repeating: "c", count: 2000)

        let r = Rope(a + b + c)

        XCTAssert(r.root.height > 0)

        XCTAssertEqual(3, r.lines.count)
        XCTAssertEqual(a, String(r.lines[0]))
        XCTAssertEqual(b, String(r.lines[1]))
        XCTAssertEqual(c, String(r.lines[2]))

        XCTAssertEqual([a, b, c], Array(r.lines.map { String($0) }))
    }

    // LinesView has to have some extra logic in its indexing
    // methods to handle endIndex correctly. This is because
    // the .newlines metric counts "\n" characters and there's
    // always one more line than newlines.
    func testLinesViewIndexAtEnd() {
        let r = Rope("foo")

        XCTAssertEqual(1, r.lines.count)

        let i = r.lines.index(at: 1)
        XCTAssertEqual(r.endIndex, i)
        XCTAssertEqual(3, i.position)
    }

    func testLinesViewIndexAfterEnd() {
        let r = Rope("foo")

        XCTAssertEqual(1, r.lines.count)

        let i = r.lines.index(after: r.startIndex)
        XCTAssertEqual(r.endIndex, i)
        XCTAssertEqual(3, i.position)
    }

    func testLinesViewIndexBeforeEnd() {
        let r = Rope("foo")

        XCTAssertEqual(1, r.lines.count)

        let i = r.lines.index(before: r.endIndex)
        XCTAssertEqual(r.index(at: 0), i)
        XCTAssertEqual(0, i.position)
    }

    func testLinesViewIndexOffsetByEnd() {
        let r = Rope("foo")

        XCTAssertEqual(1, r.lines.count)

        let i = r.lines.index(r.index(at: 2), offsetBy: 1)
        XCTAssertEqual(r.endIndex, i)
        XCTAssertEqual(3, i.position)
    }

    func testLinesViewIndexOffsetByLimitedByEnd() {
        let r = Rope("foo")

        XCTAssertEqual(1, r.lines.count)

        var i = r.lines.index(r.index(at: 2), offsetBy: 1, limitedBy: r.endIndex)
        XCTAssertEqual(r.endIndex, i)
        XCTAssertEqual(3, i?.position)

        i = r.lines.index(r.index(at: 2), offsetBy: 2, limitedBy: r.endIndex)
        XCTAssertNil(i)

        // limit in opposite direction is a no-op.
        i = r.lines.index(r.index(at: 2), offsetBy: 1, limitedBy: r.startIndex)
        XCTAssertEqual(r.endIndex, i)
        XCTAssertEqual(3, i?.position)

        let r1 = Rope("foo\nbar\nbaz")
        i = r1.lines.index(r1.index(at: 2), offsetBy: 3, limitedBy: r1.startIndex)
        XCTAssertEqual(r1.endIndex, i)
        XCTAssertEqual(11, i?.position)
    }

    // MARK: - Deltas

    func testDeltaSummarizeCombiningCharactersAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))

        XCTAssertEqual(1000, r.count)
        XCTAssertEqual(1000, r.unicodeScalars.count)
        XCTAssertEqual(1000, r.utf16.count)
        XCTAssertEqual(1000, r.utf8.count)

        XCTAssertEqual(0, r.root.height)

        XCTAssertEqual(0, r.root.leaf.prefixCount)

        // 'combining accute accent' + "b"*999
        let r2 = Rope("\u{0301}" + String(repeating: "b", count: 999))

        var b = BTreeDeltaBuilder<Rope>(r.root.count)
        b.replaceSubrange(r.root.count..<r.root.count, with: r2)
        let delta = b.build()

        r = r.applying(delta: delta)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16.count)
        XCTAssertEqual(2001, r.utf8.count)

        XCTAssertEqual("a\u{0301}", r[999])
    }

    func testDeltaSliceCombiningCharactersAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))
        r.append("\u{0301}" + String(repeating: "b", count: 999))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16.count)
        XCTAssertEqual(2001, r.utf8.count)

        var b = BTreeDeltaBuilder<Rope>(r.root.count)
        b.replaceSubrange(0..<999, with: "")
        b.replaceSubrange(1002..<r.root.count, with: "")
        let delta = b.build()

        let r2 = r.applying(delta: delta)

        XCTAssertEqual(0, r2.root.height)

        XCTAssertEqual(1, r2.count)
        XCTAssertEqual(2, r2.unicodeScalars.count)
        XCTAssertEqual(2, r2.utf16.count)
        XCTAssertEqual(3, r2.utf8.count)

        XCTAssertEqual("a\u{0301}", String(r2))
    }

    // MARK: - Regression tests

    func testConvertMultiChunkRopeToStringAsSequence() {
        let s = String(repeating: "a", count: 1023) + String(repeating: "b", count: 1023)
        let r = Rope(s)

        let seq: any Sequence<Character> = r
        // This shouldn't crash
        XCTAssertEqual(s, String(seq))
    }

    func testReadCharacterAtLeafBoundary() {
        let s = String(repeating: "a", count: 1023) + String(repeating: "b", count: 1023)
        let r = Rope(s)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)
        XCTAssertEqual(1023, r.root.children[0].count)
        XCTAssertEqual(1023, r.root.children[1].count)
        // This shouldn't crash
        XCTAssertEqual("a", r[1022])
    }

    func testReadCharacterAtEnd() {
        let s = String(repeating: "a", count: 1023) + String(repeating: "b", count: 1023)
        let r = Rope(s)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)
        XCTAssertEqual(1023, r.root.children[0].count)
        XCTAssertEqual(1023, r.root.children[1].count)
        // This shouldn't crash
        XCTAssertEqual("b", r[2045])
    }

    func testReadLastLineInChunkWhereChunkEndsInNewlineAndIsNotTheLastChunk() {
        // Very contrived. I don't know how to create this situation naturally
        // because of how boundaryForBulkInsert tries to put the "\n" on the right
        // side of the rope boundary, but it has appeared in the wild.
        var b = BTreeBuilder<Rope>()
        var breaker = Rope.GraphemeBreaker()

        let firstString = String(repeating: "a", count: 511) + "\n" + String(repeating: "b", count: 510) + "\n"
        b.push(leaf: Chunk(firstString[...], breaker: &breaker))

        b.push(leaf: Chunk(String(repeating: "c", count: 1023)[...], breaker: &breaker))
        let r = b.build()

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)
        XCTAssertEqual(1023, r.root.children[0].count)
        XCTAssertEqual(1023, r.root.children[1].count)

        // This shouldn't crash
        XCTAssertEqual(String(repeating: "b", count: 510) + "\n", r.lines[1])
    }

    func testMoveToPreviousLineInAFourChunkStretchOfNoNewlines() {
        var r = Rope()
        r += String(repeating: "a", count: 1020)
        r += String(repeating: "b", count: 1021)
        r += String(repeating: "c", count: 1022)

        let i = r.endIndex
        // This shouldn't crash
        let j = r.lines.index(roundingDown: i)

        XCTAssertEqual(0, j.position)
    }

    // TODO: this is broken. Rope.LinesView really needs its own Index type.
    // In the case where the rope is empty, or the rope ends in a newline,
    // LinesView needs to have an index after rope.endIndex. If we fix this
    // issue, we can get rid of Lines.Iterator and switch to IndexingIterator
    // which is the default.
    func testMoveToLastLineIndexInEmptyRope() {
//        let r = Rope()
//        XCTAssertEqual(r.lines.count, 1)
//
//        let i = r.startIndex
//        XCTAssertEqual(r.lines[i], "")
//
//        let j = r.lines.index(after: i)
//        XCTAssertEqual(j, r.endIndex)
    }
}

