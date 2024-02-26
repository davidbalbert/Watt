//
//  BufferTests.swift
//  WattTests
//
//  Created by David Albert on 9/14/23.
//

import XCTest
@testable import Watt

extension Rope {
    subscript(bounds: Range<Int>) -> Subrope {
        let start = index(at: bounds.lowerBound)
        let end = index(at: bounds.upperBound)
        return self[start..<end]
    }
}

final class BufferTests: XCTestCase {
    func testApplyingMultipleTokens() {
        let code = """
        #include <stdio.h>

        int
        main(void) {
            printf("Hello, world!\\n");
            return 0;
        }
        """

        let b = Buffer(code, language: .c)

        let tokens = [
            Token(type: .keyword, range: 0..<8), // #include
            Token(type: .delimiter, range: 9..<10), // <
            Token(type: .string, range: 10..<17), // stdio.h
            Token(type: .delimiter, range: 17..<18), // >
            Token(type: .type, range: 20..<23), // int
            Token(type: .function, range: 24..<28), // main
            Token(type: .delimiter, range: 28..<29), // (
            Token(type: .type, range: 29..<33), // void
            Token(type: .delimiter, range: 33..<34), // )
            Token(type: .delimiter, range: 35..<36), // {
            Token(type: .function, range: 41..<47), // printf
            Token(type: .delimiter, range: 47..<48), // (
            Token(type: .string, range: 48..<65), // "Hello, world!\n"
            Token(type: .delimiter, range: 65..<66), // )
            Token(type: .delimiter, range: 66..<67), // ;
            Token(type: .keyword, range: 72..<78), // return
            Token(type: .number, range: 79..<80), // 0
            Token(type: .delimiter, range: 80..<81), // ;
            Token(type: .delimiter, range: 82..<83), // }
        ]

        b.applyTokens(tokens)

        XCTAssertEqual(b.contents.runs[\.token].count, 19)

        var iter = b.contents.runs[\.token].makeIterator()
        var r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .keyword, range: 0..<8))
        XCTAssertEqual(Range(r.range, in: b), 0..<8)
        XCTAssertEqual(String(b.text[0..<8]), "#include")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 9..<10))
        XCTAssertEqual(Range(r.range, in: b), 9..<10)
        XCTAssertEqual(String(b.text[9..<10]), "<")
        
        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .string, range: 10..<17))
        XCTAssertEqual(Range(r.range, in: b), 10..<17)
        XCTAssertEqual(String(b.text[10..<17]), "stdio.h")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 17..<18))
        XCTAssertEqual(Range(r.range, in: b), 17..<18)
        XCTAssertEqual(String(b.text[17..<18]), ">")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .type, range: 20..<23))
        XCTAssertEqual(Range(r.range, in: b), 20..<23)
        XCTAssertEqual(String(b.text[20..<23]), "int")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .function, range: 24..<28))
        XCTAssertEqual(Range(r.range, in: b), 24..<28)
        XCTAssertEqual(String(b.text[24..<28]), "main")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 28..<29))
        XCTAssertEqual(Range(r.range, in: b), 28..<29)
        XCTAssertEqual(String(b.text[28..<29]), "(")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .type, range: 29..<33))
        XCTAssertEqual(Range(r.range, in: b), 29..<33)
        XCTAssertEqual(String(b.text[29..<33]), "void")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 33..<34))
        XCTAssertEqual(Range(r.range, in: b), 33..<34)
        XCTAssertEqual(String(b.text[33..<34]), ")")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 35..<36))
        XCTAssertEqual(Range(r.range, in: b), 35..<36)
        XCTAssertEqual(String(b.text[35..<36]), "{")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .function, range: 41..<47))
        XCTAssertEqual(Range(r.range, in: b), 41..<47)
        XCTAssertEqual(String(b.text[41..<47]), "printf")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 47..<48))
        XCTAssertEqual(Range(r.range, in: b), 47..<48)
        XCTAssertEqual(String(b.text[47..<48]), "(")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .string, range: 48..<65))
        XCTAssertEqual(Range(r.range, in: b), 48..<65)
        XCTAssertEqual(String(b.text[48..<65]), "\"Hello, world!\\n\"")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 65..<66))
        XCTAssertEqual(Range(r.range, in: b), 65..<66)
        XCTAssertEqual(String(b.text[65..<66]), ")")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 66..<67))
        XCTAssertEqual(Range(r.range, in: b), 66..<67)
        XCTAssertEqual(String(b.text[66..<67]), ";")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .keyword, range: 72..<78))
        XCTAssertEqual(Range(r.range, in: b), 72..<78)
        XCTAssertEqual(String(b.text[72..<78]), "return")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .number, range: 79..<80))
        XCTAssertEqual(Range(r.range, in: b), 79..<80)
        XCTAssertEqual(String(b.text[79..<80]), "0")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 80..<81))
        XCTAssertEqual(Range(r.range, in: b), 80..<81)
        XCTAssertEqual(String(b.text[80..<81]), ";")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 82..<83))
        XCTAssertEqual(Range(r.range, in: b), 82..<83)
        XCTAssertEqual(String(b.text[82..<83]), "}")

        XCTAssertNil(iter.next())
    }

    func testReplaceSubrangeOnUnicodeScalarBoundary() {
        let b = Buffer("a\u{0301}b", language: .plainText) // áb
        let start = b.text.unicodeScalars.index(b.text.startIndex, offsetBy: 1)
        let end = b.text.unicodeScalars.index(b.text.startIndex, offsetBy: 2)

        b.replaceSubrange(start..<end, with: "")
        XCTAssertEqual(b.text, "ab")
    }

    func testReplaceSubrangeWithAttributedRopeOnUnicodeScalarBoundary() {
        let b = Buffer("a\u{0301}b", language: .plainText) // áb
        let start = b.text.unicodeScalars.index(b.text.startIndex, offsetBy: 1)
        let end = b.text.unicodeScalars.index(b.text.startIndex, offsetBy: 2)

        b.replaceSubrange(start..<end, with: AttributedRope(""))
        XCTAssertEqual(b.text, "ab")
    }

    func testReplaceSubrangeOnUTF8BoundaryShouldRoundDownToUnicodeScalar() {
        let b = Buffer("a\u{0301}b", language: .plainText) // áb
        let start = b.text.utf8.index(b.text.utf8.startIndex, offsetBy: 1)
        let end = b.text.utf8.index(b.text.utf8.startIndex, offsetBy: 2)

        b.replaceSubrange(start..<end, with: "")
        XCTAssertEqual(b.text, "a\u{0301}b")
    }

    func testReplaceSubrangeWithAttributedRopeOnUTF8BoundaryShouldRoundDownToUnicodeScalar() {
        let b = Buffer("a\u{0301}b", language: .plainText) // áb
        let start = b.text.utf8.index(b.text.utf8.startIndex, offsetBy: 1)
        let end = b.text.utf8.index(b.text.utf8.startIndex, offsetBy: 2)

        b.replaceSubrange(start..<end, with: AttributedRope(""))
        XCTAssertEqual(b.text, "a\u{0301}b")
    }
}
