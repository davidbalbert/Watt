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

    // MARK: Regression tests

    func testCountingLeadingEdgeAtSplitPoint() {
        let r = Rope(repeating: "a", count: 511) + Rope(repeating: "b", count: 513)
        XCTAssertEqual(1024, r.root.count)
        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)
        XCTAssertEqual(r.root.children[0].leaf.string, String(repeating: "a", count: 511))
        XCTAssertEqual(r.root.children[1].leaf.string, String(repeating: "b", count: 513))

        XCTAssertEqual(512, r.root.count(.utf8, upThrough: 511, edge: .leading))
        XCTAssertEqual(511, r.root.count(.utf8, upThrough: 511, edge: .trailing))
    }

    func testCountingNonAtomicBaseUnitsAtLeafSplitWithMoreThanTwoLeaves() {
        // "\n" at the end of the left leaf
        let r1 = Rope(repeating: "a", count: 1000) + "\n" + Rope(repeating: "b", count: 1000) + Rope(repeating: "c", count: 1000)
        XCTAssertEqual(3001, r1.root.count)
        XCTAssertEqual(1, r1.root.height)
        XCTAssertEqual(3, r1.root.children.count)
        XCTAssertEqual(r1.root.children[0].leaf.string, String(repeating: "a", count: 1000) + "\n")
        XCTAssertEqual(r1.root.children[1].leaf.string, String(repeating: "b", count: 1000))
        XCTAssertEqual(r1.root.children[2].leaf.string, String(repeating: "c", count: 1000))

        XCTAssertEqual(1000, r1.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .leading))
        XCTAssertEqual(1001, r1.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .trailing))

        XCTAssertEqual(1001, r1.root.convert(1, from: .newlines, edge: .trailing, to: .utf8, edge: .trailing))
        XCTAssertEqual(1002, r1.root.convert(1, from: .newlines, edge: .trailing, to: .utf8, edge: .leading))


        // "\n" at the start of the right leaf
        let r2 = Rope(repeating: "a", count: 1000) + Rope("\n" + String(repeating: "b", count: 1000)) + Rope(repeating: "c", count: 1000)
        XCTAssertEqual(3001, r2.root.count)
        XCTAssertEqual(1, r2.root.height)
        XCTAssertEqual(3, r2.root.children.count)
        XCTAssertEqual(r2.root.children[0].leaf.string, String(repeating: "a", count: 1000))
        XCTAssertEqual(r2.root.children[1].leaf.string, "\n" + String(repeating: "b", count: 1000))
        XCTAssertEqual(r2.root.children[2].leaf.string, String(repeating: "c", count: 1000))

        XCTAssertEqual(1000, r2.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .leading))
        XCTAssertEqual(1001, r2.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .trailing))

        // "\n" in both locations
        let r3 = Rope(repeating: "a", count: 1000) + "\n" + Rope("\n" + String(repeating: "b", count: 1000)) + Rope(repeating: "c", count: 1000)
        XCTAssertEqual(3002, r3.root.count)
        XCTAssertEqual(1, r3.root.height)
        XCTAssertEqual(3, r3.root.children.count)
        XCTAssertEqual(r3.root.children[0].leaf.string, String(repeating: "a", count: 1000) + "\n")
        XCTAssertEqual(r3.root.children[1].leaf.string, "\n" + String(repeating: "b", count: 1000))
        XCTAssertEqual(r3.root.children[2].leaf.string, String(repeating: "c", count: 1000))

        XCTAssertEqual(1000, r3.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .leading))
        XCTAssertEqual(1001, r3.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .trailing))
        XCTAssertEqual(1001, r3.root.countBaseUnits(upThrough: 2, measuredIn: .newlines, edge: .leading))
        XCTAssertEqual(1002, r3.root.countBaseUnits(upThrough: 2, measuredIn: .newlines, edge: .trailing))
    }

    func testCountingAtomicBaseUnitsSplitWithMoreThanTwoLeaves() {
        // A single character splitting multiple leaves
        let r = Rope("e" + String(repeating: "\u{0301}", count: 1500))
        XCTAssertEqual(3001, r.root.count)
        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(3, r.root.children.count)

        XCTAssertEqual(1023, r.root.children[0].leaf.count)
        // 1022, not 1023 because boundary(for:startingAt:) rounds down to the nearest unicode scalar
        // and because \u{0301} is 2 bytes, the 1023rd byte would split the scalar.
        XCTAssertEqual(1022, r.root.children[1].leaf.count)
        XCTAssertEqual(956, r.root.children[2].leaf.count)

        XCTAssertEqual(r.root.children[0].leaf.string, "e" + String(repeating: "\u{0301}", count: 511))
        XCTAssertEqual(r.root.children[1].leaf.string, String(repeating: "\u{0301}", count: 511))
        XCTAssertEqual(r.root.children[2].leaf.string, String(repeating: "\u{0301}", count: 478))

        XCTAssertEqual(1, r.count) // a single character

        XCTAssertEqual(0, r.root.countBaseUnits(upThrough: 0, measuredIn: .characters, edge: .trailing))
        XCTAssertEqual(0, r.root.countBaseUnits(upThrough: 1, measuredIn: .characters, edge: .leading))
        XCTAssertEqual(3001, r.root.countBaseUnits(upThrough: 1, measuredIn: .characters, edge: .trailing))
    }

    func testConvertingWhenCharacterSplitsLeaf() {
        let r = Rope(repeating: "e", count: 1000) + Rope("\u{0301}" + String(repeating: "f", count: 1000))

        XCTAssertEqual(2002, r.root.count)
        XCTAssertEqual(2000, r.count)

        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].measure(using: .characters, edge: .leading))
        XCTAssertEqual(1000, r.root.children[1].measure(using: .characters, edge: .leading))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)
        XCTAssertEqual(r.root.children[0].leaf.string, String(repeating: "e", count: 1000))
        XCTAssertEqual(r.root.children[1].leaf.string, "\u{0301}" + String(repeating: "f", count: 1000))

        XCTAssertEqual(1000, r.root.convert(1000, from: .utf8, edge: .trailing, to: .characters, edge: .leading))
        XCTAssertEqual(999, r.root.convert(1000, from: .utf8, edge: .trailing, to: .characters, edge: .trailing))
    }

    func testConvertingWithNewlinesOnEitherSideOfLeafBoundary() {
        let r = Rope(String(repeating: "a", count: 999) + "\n") + Rope("\n" + String(repeating: "b", count: 999))
        XCTAssertEqual(2000, r.root.count)
        XCTAssertEqual(2000, r.count)

        XCTAssertEqual(1, r.root.count(.newlines, upThrough: 999, edge: .leading))
        XCTAssertEqual(1, r.root.count(.newlines, upThrough: 1000, edge: .trailing))
        XCTAssertEqual(2, r.root.count(.newlines, upThrough: 1000, edge: .leading))
        XCTAssertEqual(2, r.root.count(.newlines, upThrough: 1001, edge: .trailing))

        XCTAssertEqual(999, r.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .leading))
        XCTAssertEqual(1000, r.root.countBaseUnits(upThrough: 1, measuredIn: .newlines, edge: .trailing))
        XCTAssertEqual(1000, r.root.countBaseUnits(upThrough: 2, measuredIn: .newlines, edge: .leading))
        XCTAssertEqual(1001, r.root.countBaseUnits(upThrough: 2, measuredIn: .newlines, edge: .trailing))

        XCTAssertEqual(1000, r.root.convert(1000, from: .utf8, edge: .leading, to: .utf8, edge: .leading))
        XCTAssertEqual(999, r.root.convert(1000, from: .utf8, edge: .leading, to: .utf8, edge: .trailing))
        XCTAssertEqual(1000, r.root.convert(999, from: .utf8, edge: .trailing, to: .utf8, edge: .leading))
        XCTAssertEqual(1000, r.root.convert(1000, from: .utf8, edge: .trailing, to: .utf8, edge: .trailing))

        XCTAssertEqual(1000, r.root.convert(1001, from: .utf8, edge: .leading, to: .utf8, edge: .trailing))
        XCTAssertEqual(1001, r.root.convert(1000, from: .utf8, edge: .trailing, to: .utf8, edge: .leading))

        XCTAssertEqual(1, r.root.convert(1000, from: .utf8, edge: .trailing, to: .newlines, edge: .trailing))
        XCTAssertEqual(2, r.root.convert(1000, from: .utf8, edge: .trailing, to: .newlines, edge: .leading))

        XCTAssertEqual(0, r.root.convert(1000, from: .utf8, edge: .leading, to: .newlines, edge: .trailing))
        XCTAssertEqual(1, r.root.convert(1000, from: .utf8, edge: .leading, to: .newlines, edge: .leading))
    }

    func testConvertingFromTrailingToLeading() {
        let r = Rope(repeating: "a", count: 1000) + Rope(repeating: "b", count: 1000)
        XCTAssertEqual(2000, r.root.count)
        XCTAssertEqual(2000, r.count)
        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)
        XCTAssertEqual(r.root.children[0].leaf.string, String(repeating: "a", count: 1000))
        XCTAssertEqual(r.root.children[1].leaf.string, String(repeating: "b", count: 1000))

        XCTAssertEqual(1001, r.root.convert(1000, from: .utf8, edge: .trailing, to: .utf8, edge: .leading))
    }
}
