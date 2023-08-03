//
//  HeightsTest.swift
//  WattTests
//
//  Created by David Albert on 7/27/23.
//

import XCTest
@testable import Watt

final class HeightsTest: XCTestCase {
    // MARK: - Measuring y-offsts

    func testYOffsetEmpty() {
        let r = Rope()
        let h = Heights(rope: r)

        XCTAssertEqual(14, h.contentHeight)

        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))

        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .yOffset))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(0, h.countBaseUnits(of: 14, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 14.0001, measuredIn: .yOffset))
    }

    func testYOffsetOneLine() {
        let r = Rope("a")
        let h = Heights(rope: r)

        XCTAssertEqual(14, h.contentHeight)

        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))

        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .yOffset))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(0, h.countBaseUnits(of: 14, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 14.0001, measuredIn: .yOffset))
    }

    func testYOffsetNonEmptyLastLine() {
        // 32 lines total. The final line is "a".
        // Useful y-offset reference points (line - y-offset):
        // 0 - 0
        // 1 - 14
        // 2 - 28
        // ...
        // 31 - 434 (32nd line, final, non-empty)
        //
        // Total characters = 63; endIndex == 63.
        // Total height = 448 (434 + 14).
        let r = Rope(Array(repeating: "a", count: 32).joined(separator: "\n"))
        let h = Heights(rope: r)

        XCTAssertEqual(448, h.contentHeight)

        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))
        XCTAssertEqual(0, h.count(.yOffset, upThrough: 1))
        XCTAssertEqual(14, h.count(.yOffset, upThrough: 2))
        XCTAssertEqual(14, h.count(.yOffset, upThrough: 3))

        XCTAssertEqual(434, h.count(.yOffset, upThrough: 62))
        XCTAssertEqual(434, h.count(.yOffset, upThrough: 63)) // endIndex

        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 14, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 14.0001, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 27, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 27.9999, measuredIn: .yOffset))
        XCTAssertEqual(4, h.countBaseUnits(of: 28, measuredIn: .yOffset))

        XCTAssertEqual(62, h.countBaseUnits(of: 434, measuredIn: .yOffset))
        XCTAssertEqual(62, h.countBaseUnits(of: 447.9999, measuredIn: .yOffset))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(62, h.countBaseUnits(of: 448, measuredIn: .yOffset))
        XCTAssertEqual(62, h.countBaseUnits(of: 448.0001, measuredIn: .yOffset))
    }

    func testYOffsetEmptyLastLine() {
        // 33 lines total, with an empty last line.
        // Useful y-offset reference points (line - y-offset):
        // 0 - 0
        // 1 - 14
        // 2 - 28
        // ...
        // 31 - 434 (32nd line, non-empty)
        // 32 - 448 (empty line)
        //
        // Total characters = 64; endIndex == 64.
        // Total height = 462 (448 + 14).
        let r = Rope(String(repeating: "a\n", count: 32))
        let h = Heights(rope: r)

        XCTAssertEqual(462, h.contentHeight)

        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))
        XCTAssertEqual(0, h.count(.yOffset, upThrough: 1))
        XCTAssertEqual(14, h.count(.yOffset, upThrough: 2))
        XCTAssertEqual(14, h.count(.yOffset, upThrough: 3))

        XCTAssertEqual(434, h.count(.yOffset, upThrough: 62))
        XCTAssertEqual(434, h.count(.yOffset, upThrough: 63))
        XCTAssertEqual(448, h.count(.yOffset, upThrough: 64)) // endIndex, new line.

        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .yOffset))
        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 14, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 14.0001, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 27, measuredIn: .yOffset))
        XCTAssertEqual(2, h.countBaseUnits(of: 27.9999, measuredIn: .yOffset))
        XCTAssertEqual(4, h.countBaseUnits(of: 28, measuredIn: .yOffset))

        XCTAssertEqual(62, h.countBaseUnits(of: 434, measuredIn: .yOffset))
        XCTAssertEqual(62, h.countBaseUnits(of: 447.9999, measuredIn: .yOffset))
        XCTAssertEqual(64, h.countBaseUnits(of: 448, measuredIn: .yOffset))
        XCTAssertEqual(64, h.countBaseUnits(of: 461.9999, measuredIn: .yOffset))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(64, h.countBaseUnits(of: 462, measuredIn: .yOffset))
        XCTAssertEqual(64, h.countBaseUnits(of: 462.0001, measuredIn: .yOffset))
    }

    // TODO: make it span two leaves, make sure the boundaries work

    // MARK: - Getting and setting heights

    func testHeightEmpty() {
        let r = Rope()
        var h = Heights(rope: r)

        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h.contentHeight)

        h[0] = 15

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(15, h.contentHeight)
    }

    func testHeightOneLine() {
        let r = Rope("a")
        var h = Heights(rope: r)

        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h.contentHeight)

        h[0] = 15

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(15, h.contentHeight)
    }

    func testHeightNonEmptyLastLine() {
        // 32 lines total. The final line is "a".
        // Total characters == 63; endIndex == 63.

        let r = Rope(Array(repeating: "a", count: 32).joined(separator: "\n"))
        var h = Heights(rope: r)

        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[60])
        XCTAssertEqual(14, h[62])

        XCTAssertEqual(448, h.contentHeight)

        h[0] = 15

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[60])
        XCTAssertEqual(14, h[62])

        XCTAssertEqual(449, h.contentHeight)

        h[2] = 16

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(16, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[60])
        XCTAssertEqual(14, h[62])

        XCTAssertEqual(451, h.contentHeight)

        h[4] = 17

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(16, h[2])
        XCTAssertEqual(17, h[4])
        // ...
        XCTAssertEqual(14, h[60])
        XCTAssertEqual(14, h[62])

        XCTAssertEqual(454, h.contentHeight)

        h[60] = 18

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(16, h[2])
        XCTAssertEqual(17, h[4])
        // ...
        XCTAssertEqual(18, h[60])
        XCTAssertEqual(14, h[62])

        XCTAssertEqual(458, h.contentHeight)

        h[62] = 19

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(16, h[2])
        XCTAssertEqual(17, h[4])
        // ...
        XCTAssertEqual(18, h[60])
        XCTAssertEqual(19, h[62])

        XCTAssertEqual(463, h.contentHeight)
    }

    func testHmm() {
        // 33 lines total, with an empty last line.
        // Total characters = 64; endIndex == 64.
        let r = Rope(String(repeating: "a\n", count: 32))
        var h = Heights(rope: r)
        
        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[62])
        // endIndex, but allowed because endIndex is the beginning of a line.
        XCTAssertEqual(14, h[64])

        XCTAssertEqual(462, h.contentHeight)

        h[64] = 15

        XCTAssertEqual(33, h.root.leaf.positions.count)

        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[62])
        XCTAssertEqual(15, h[64])

        XCTAssertEqual(463, h.contentHeight)
    }

    func testHeightEmptyLastLine() {
        // 33 lines total, with an empty last line.
        // Total characters = 64; endIndex == 64.
        let r = Rope(String(repeating: "a\n", count: 32))
        var h = Heights(rope: r)

        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[62])
        // endIndex, but allowed because endIndex is the beginning of a line.
        XCTAssertEqual(14, h[64])

        XCTAssertEqual(462, h.contentHeight)

        h[0] = 15

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(14, h[4])
        // ...
        XCTAssertEqual(14, h[62])
        XCTAssertEqual(14, h[64])

        XCTAssertEqual(463, h.contentHeight)

        h[4] = 16

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(16, h[4])
        // ...
        XCTAssertEqual(14, h[62])
        XCTAssertEqual(14, h[64])

        XCTAssertEqual(465, h.contentHeight)

        h[64] = 17

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        XCTAssertEqual(16, h[4])
        // ...
        XCTAssertEqual(14, h[62])
        XCTAssertEqual(17, h[64])

        XCTAssertEqual(468, h.contentHeight)
    }

    // TODO: test edge cases split across two leaves.

    // MARK: - Internal structure
//    func testEmptyRope() {
//        let r = Rope("")
//        let h = Heights(rope: r)
//
//        XCTAssertEqual(0, h.root.count)
//        XCTAssertEqual(0, h.root.height)
//
//        XCTAssertEqual([0], h.root.leaf.positions)
//        XCTAssertEqual([14], h.root.leaf.heights)
//
//        XCTAssertEqual(14, h[h.index(at: 0)])
//        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))
//
//        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 14, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 14.0001, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 5000, measuredIn: .yOffset))
//
//        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))
//        XCTAssertEqual(14, h.count(.height, upThrough: 0))
//    }
//
//    func testInitReadAndWrite() {
//        let r = Rope("foo\nbar\nbaz")
//        let h = Heights(rope: r)
//
//        XCTAssertEqual(11, h.root.count)
//        XCTAssertEqual(0, h.root.height)
//
//        XCTAssertEqual([4, 8, 11], h.root.leaf.positions)
//        XCTAssertEqual([14, 28, 42], h.root.leaf.heights)
//
//        XCTAssertEqual(14, h[h.index(at: 0)])
//        XCTAssertEqual(14, h[h.index(at: 1)])
//        XCTAssertEqual(14, h[h.index(at: 2)])
//
//        XCTAssertEqual(0, h.count(.yOffset, upThrough: 0))
//        XCTAssertEqual(0, h.count(.yOffset, upThrough: 3))
//        XCTAssertEqual(14, h.count(.yOffset, upThrough: 4))
//        XCTAssertEqual(14, h.count(.yOffset, upThrough: 7))
//        XCTAssertEqual(28, h.count(.yOffset, upThrough: 8))
//        XCTAssertEqual(28, h.count(.yOffset, upThrough: 10))
//        XCTAssertEqual(28, h.count(.yOffset, upThrough: 11))
//
//        XCTAssertEqual(14, h.count(.height, upThrough: 0))
//        XCTAssertEqual(14, h.count(.height, upThrough: 3))
//        XCTAssertEqual(28, h.count(.height, upThrough: 4))
//        XCTAssertEqual(28, h.count(.height, upThrough: 7))
//        XCTAssertEqual(42, h.count(.height, upThrough: 8))
//        XCTAssertEqual(42, h.count(.height, upThrough: 10))
//        XCTAssertEqual(42, h.count(.height, upThrough: 11))
//
//        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .yOffset))
//        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .yOffset))
//        XCTAssertEqual(4, h.countBaseUnits(of: 14, measuredIn: .yOffset))
//        XCTAssertEqual(4, h.countBaseUnits(of: 14.0001, measuredIn: .yOffset))
//        XCTAssertEqual(4, h.countBaseUnits(of: 27, measuredIn: .yOffset))
//        XCTAssertEqual(4, h.countBaseUnits(of: 27.9999, measuredIn: .yOffset))
//        XCTAssertEqual(8, h.countBaseUnits(of: 28, measuredIn: .yOffset))
//        XCTAssertEqual(8, h.countBaseUnits(of: 28.0001, measuredIn: .yOffset))
//        XCTAssertEqual(8, h.countBaseUnits(of: 41, measuredIn: .yOffset))
//        XCTAssertEqual(8, h.countBaseUnits(of: 41.9999, measuredIn: .yOffset))
//        XCTAssertEqual(11, h.countBaseUnits(of: 42, measuredIn: .yOffset))
//
//        XCTAssertEqual(4, h.countBaseUnits(of: 0, measuredIn: .height))
//        XCTAssertEqual(4, h.countBaseUnits(of: 1, measuredIn: .height))
//        XCTAssertEqual(4, h.countBaseUnits(of: 13, measuredIn: .height))
//        XCTAssertEqual(4, h.countBaseUnits(of: 13.9999, measuredIn: .height))
//        XCTAssertEqual(4, h.countBaseUnits(of: 14, measuredIn: .height))
//        XCTAssertEqual(8, h.countBaseUnits(of: 14.0001, measuredIn: .height))
//        XCTAssertEqual(8, h.countBaseUnits(of: 27, measuredIn: .height))
//        XCTAssertEqual(8, h.countBaseUnits(of: 27.9999, measuredIn: .height))
//        XCTAssertEqual(8, h.countBaseUnits(of: 28, measuredIn: .height))
//        XCTAssertEqual(11, h.countBaseUnits(of: 28.0001, measuredIn: .height))
//        XCTAssertEqual(11, h.countBaseUnits(of: 41, measuredIn: .height))
//        XCTAssertEqual(11, h.countBaseUnits(of: 41.9999, measuredIn: .height))
//        XCTAssertEqual(11, h.countBaseUnits(of: 42, measuredIn: .height))
//        XCTAssertEqual(11, h.countBaseUnits(of: 42.0001, measuredIn: .height))
//    }
//
//    func testOnBoundary() {
//        let p = (1..<33).map { $0*5 }
//        let y = (1..<33).map { CGFloat($0*14) }
//
//        var b = Heights.Builder()
//        b.push(leaf: HeightsLeaf(positions: p, heights: y))
//        b.push(leaf: HeightsLeaf(positions: p, heights: y))
//        let h = Heights(b.build())
//
//
//        XCTAssertEqual(896, h.measure(using: .yOffset))
//
//        XCTAssertEqual(434, h.count(.yOffset, upThrough: 160))
//
//        let i = h.index(at: 160)
//        XCTAssertEqual(14, h[i])
//    }
//
//    func testLeafSlicing() {
//        let l = HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45])
//        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<12], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<13], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<14], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<15], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<16], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<17], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
//        XCTAssertEqual(l[0..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
//
//        XCTAssertEqual(l[1..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
//        XCTAssertEqual(l[2..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
//        XCTAssertEqual(l[3..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
//        XCTAssertEqual(l[4..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
//        XCTAssertEqual(l[5..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
//        XCTAssertEqual(l[6..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
//        XCTAssertEqual(l[7..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
//        XCTAssertEqual(l[8..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
//        XCTAssertEqual(l[9..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
//        XCTAssertEqual(l[10..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
//        XCTAssertEqual(l[11..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[12..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[13..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[14..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[15..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[16..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[17..<18], HeightsLeaf(positions: [7], heights: [16]))
//        XCTAssertEqual(l[18..<18], HeightsLeaf(positions: [0], heights: [16]))
//    }
//
//    func testLeafSlicingEmpty() {
//        let l = HeightsLeaf(positions: [0], heights: [14])
//        XCTAssertEqual(l, l[0..<0])
//    }
//
//    func testLeafSlicingEmptyLastLine() {
//        let l = HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45])
//        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [0], heights: [14]))
//        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5], heights: [14]))
//        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
//
//        XCTAssertEqual(l[1..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
//        XCTAssertEqual(l[2..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
//        XCTAssertEqual(l[3..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
//        XCTAssertEqual(l[4..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
//        XCTAssertEqual(l[5..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[6..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[7..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[8..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[10..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
//        XCTAssertEqual(l[11..<11], HeightsLeaf(positions: [0], heights: [16]))
//    }
}
