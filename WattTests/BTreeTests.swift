//
//  BTreeTests.swift
//  WattTests
//
//  Created by David Albert on 3/5/24.
//

import XCTest
@testable import Watt

final class BTreeTests: XCTestCase {
    // MARK: - Collection helpers

    func testDistance() {
        var rope = Rope("abc")
        var r = rope.root
        var range = r.startIndex..<r.endIndex

        // utf8
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 0), in: range, using: .utf8, edge: .leading))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 1), in: range, using: .utf8, edge: .leading))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 2), in: range, using: .utf8, edge: .leading))
        XCTAssertEqual(3, r.distance(from: r.index(at: 0), to: r.index(at: 3), in: range, using: .utf8, edge: .leading))

        XCTAssertEqual(1, r.distance(from: r.index(at: 1), to: r.index(at: 2), in: range, using: .utf8, edge: .leading))

        XCTAssertEqual(0..<3, Range(rope.startIndex..<rope.endIndex, in: rope))

        rope = Rope("xx\nxx\nxx")
        r = rope.root
        range = r.startIndex..<r.endIndex

        // characters
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 0), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 1), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 2), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(3, r.distance(from: r.index(at: 0), to: r.index(at: 3), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(4, r.distance(from: r.index(at: 0), to: r.index(at: 4), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(5, r.distance(from: r.index(at: 0), to: r.index(at: 5), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(6, r.distance(from: r.index(at: 0), to: r.index(at: 6), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(7, r.distance(from: r.index(at: 0), to: r.index(at: 7), in: range, using: .characters, edge: .leading))
        XCTAssertEqual(8, r.distance(from: r.index(at: 0), to: r.index(at: 8), in: range, using: .characters, edge: .leading))

        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 0), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 1), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 2), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(3, r.distance(from: r.index(at: 0), to: r.index(at: 3), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(4, r.distance(from: r.index(at: 0), to: r.index(at: 4), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(5, r.distance(from: r.index(at: 0), to: r.index(at: 5), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(6, r.distance(from: r.index(at: 0), to: r.index(at: 6), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(7, r.distance(from: r.index(at: 0), to: r.index(at: 7), in: range, using: .characters, edge: .trailing))
        XCTAssertEqual(8, r.distance(from: r.index(at: 0), to: r.index(at: 8), in: range, using: .characters, edge: .trailing))


        // newlines
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 0), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 1), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 2), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 3), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 4), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 5), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 6), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 7), in: range, using: .newlines, edge: .leading))
        XCTAssertEqual(3, r.distance(from: r.index(at: 0), to: r.index(at: 8), in: range, using: .newlines, edge: .leading))

        // newlines
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 0), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 1), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(0, r.distance(from: r.index(at: 0), to: r.index(at: 2), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 3), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 4), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(1, r.distance(from: r.index(at: 0), to: r.index(at: 5), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 6), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(2, r.distance(from: r.index(at: 0), to: r.index(at: 7), in: range, using: .newlines, edge: .trailing))
        XCTAssertEqual(3, r.distance(from: r.index(at: 0), to: r.index(at: 8), in: range, using: .newlines, edge: .trailing))

    }

    func testIndexOffsetBy() {
        let rope = Rope("xx\nxx\nxx")
        let r = rope.root
        let range = r.startIndex..<r.endIndex


        // characters
        XCTAssertEqual(0, r.index(r.index(at: 0), offsetBy: 0, in: range, using: .characters, edge: .leading).position)
        XCTAssertEqual(1, r.index(r.index(at: 0), offsetBy: 1, in: range, using: .characters, edge: .leading).position)
        XCTAssertEqual(2, r.index(r.index(at: 0), offsetBy: 2, in: range, using: .characters, edge: .leading).position)
        XCTAssertEqual(3, r.index(r.index(at: 0), offsetBy: 3, in: range, using: .characters, edge: .leading).position)

        XCTAssertEqual(0, r.index(r.index(at: 0), offsetBy: 0, in: range, using: .characters, edge: .trailing).position)
        XCTAssertEqual(1, r.index(r.index(at: 0), offsetBy: 1, in: range, using: .characters, edge: .trailing).position)
        XCTAssertEqual(2, r.index(r.index(at: 0), offsetBy: 2, in: range, using: .characters, edge: .trailing).position)
        XCTAssertEqual(3, r.index(r.index(at: 0), offsetBy: 3, in: range, using: .characters, edge: .trailing).position)

        // newlines
        XCTAssertEqual(0, r.index(r.index(at: 0), offsetBy: 0, in: range, using: .newlines, edge: .leading).position)
        XCTAssertEqual(2, r.index(r.index(at: 0), offsetBy: 1, in: range, using: .newlines, edge: .leading).position)
        XCTAssertEqual(5, r.index(r.index(at: 0), offsetBy: 2, in: range, using: .newlines, edge: .leading).position)
        XCTAssertEqual(8, r.index(r.index(at: 0), offsetBy: 3, in: range, using: .newlines, edge: .leading).position)

        XCTAssertEqual(5, r.index(r.index(at: 2), offsetBy: 1, in: range, using: .newlines, edge: .leading).position)

        XCTAssertEqual(0, r.index(r.index(at: 0), offsetBy: 0, in: range, using: .newlines, edge: .trailing).position)
        XCTAssertEqual(3, r.index(r.index(at: 0), offsetBy: 1, in: range, using: .newlines, edge: .trailing).position)
        XCTAssertEqual(6, r.index(r.index(at: 0), offsetBy: 2, in: range, using: .newlines, edge: .trailing).position)
        XCTAssertEqual(8, r.index(r.index(at: 0), offsetBy: 3, in: range, using: .newlines, edge: .trailing).position)

        let rope2 = Rope("🙂🙂🙂")
        let r2 = rope2.root
        let range2 = r2.startIndex..<r2.endIndex

        // characters
        XCTAssertEqual(0, r2.index(r2.index(at: 0), offsetBy: 0, in: range2, using: .characters, edge: .leading).position)
        XCTAssertEqual(4, r2.index(r2.index(at: 0), offsetBy: 1, in: range2, using: .characters, edge: .leading).position)
        XCTAssertEqual(8, r2.index(r2.index(at: 0), offsetBy: 2, in: range2, using: .characters, edge: .leading).position)
        XCTAssertEqual(12, r2.index(r2.index(at: 0), offsetBy: 3, in: range2, using: .characters, edge: .leading).position)
    }
}
