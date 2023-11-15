//
//  BufferTests.swift
//  WattTests
//
//  Created by David Albert on 9/14/23.
//

import XCTest
@testable import Watt

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

        let buffer = Buffer(code, language: .c)

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

        buffer.applyTokens(tokens)

        XCTAssertEqual(buffer.contents.runs[\.token].count, 19)

        var iter = buffer.contents.runs[\.token].makeIterator()
        var r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .keyword, range: 0..<8))
        XCTAssertEqual(Range(r.range), 0..<8)
        XCTAssertEqual(buffer.text[0..<8], "#include")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 9..<10))
        XCTAssertEqual(Range(r.range), 9..<10)
        XCTAssertEqual(buffer.text[9..<10], "<")
        
        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .string, range: 10..<17))
        XCTAssertEqual(Range(r.range), 10..<17)
        XCTAssertEqual(buffer.text[10..<17], "stdio.h")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 17..<18))
        XCTAssertEqual(Range(r.range), 17..<18)
        XCTAssertEqual(buffer.text[17..<18], ">")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .type, range: 20..<23))
        XCTAssertEqual(Range(r.range), 20..<23)
        XCTAssertEqual(buffer.text[20..<23], "int")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .function, range: 24..<28))
        XCTAssertEqual(Range(r.range), 24..<28)
        XCTAssertEqual(buffer.text[24..<28], "main")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 28..<29))
        XCTAssertEqual(Range(r.range), 28..<29)
        XCTAssertEqual(buffer.text[28..<29], "(")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .type, range: 29..<33))
        XCTAssertEqual(Range(r.range), 29..<33)
        XCTAssertEqual(buffer.text[29..<33], "void")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 33..<34))
        XCTAssertEqual(Range(r.range), 33..<34)
        XCTAssertEqual(buffer.text[33..<34], ")")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 35..<36))
        XCTAssertEqual(Range(r.range), 35..<36)
        XCTAssertEqual(buffer.text[35..<36], "{")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .function, range: 41..<47))
        XCTAssertEqual(Range(r.range), 41..<47)
        XCTAssertEqual(buffer.text[41..<47], "printf")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 47..<48))
        XCTAssertEqual(Range(r.range), 47..<48)
        XCTAssertEqual(buffer.text[47..<48], "(")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .string, range: 48..<65))
        XCTAssertEqual(Range(r.range), 48..<65)
        XCTAssertEqual(buffer.text[48..<65], "\"Hello, world!\\n\"")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 65..<66))
        XCTAssertEqual(Range(r.range), 65..<66)
        XCTAssertEqual(buffer.text[65..<66], ")")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 66..<67))
        XCTAssertEqual(Range(r.range), 66..<67)
        XCTAssertEqual(buffer.text[66..<67], ";")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .keyword, range: 72..<78))
        XCTAssertEqual(Range(r.range), 72..<78)
        XCTAssertEqual(buffer.text[72..<78], "return")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .number, range: 79..<80))
        XCTAssertEqual(Range(r.range), 79..<80)
        XCTAssertEqual(buffer.text[79..<80], "0")

        r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 80..<81))
        XCTAssertEqual(Range(r.range), 80..<81)
        XCTAssertEqual(buffer.text[80..<81], ";")

         r = iter.next()!
        XCTAssertEqual(r.token, Token(type: .delimiter, range: 82..<83))
         XCTAssertEqual(Range(r.range), 82..<83)
         XCTAssertEqual(buffer.text[82..<83], "}")

         XCTAssertNil(iter.next())
    }
}
