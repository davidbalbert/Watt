//
//  HeightsTest.swift
//  WattTests
//
//  Created by David Albert on 7/27/23.
//

import XCTest
@testable import Watt

final class HeightsTest: XCTestCase {
    func testEmptyRope() {
        let r = Rope("")
        let h = Heights(rope: r)

        XCTAssertEqual(0, h.root.count)
        XCTAssertEqual(0, h.root.height)

        XCTAssertEqual([0], h.root.leaf.positions)
        XCTAssertEqual([0, 14], h.root.leaf.yOffsets)

        XCTAssertEqual(14, h[h.index(at: 0)])
        XCTAssertEqual(0, h.count(.minY, upThrough: 0))

        XCTAssertEqual(0, h.countBaseUnits(of: 0, measuredIn: .minY))
        XCTAssertEqual(0, h.countBaseUnits(of: 1, measuredIn: .minY))
        XCTAssertEqual(0, h.countBaseUnits(of: 13, measuredIn: .minY))
        XCTAssertEqual(0, h.countBaseUnits(of: 13.9999, measuredIn: .minY))
        XCTAssertEqual(0, h.countBaseUnits(of: 14, measuredIn: .minY))
        XCTAssertEqual(0, h.countBaseUnits(of: 14.0001, measuredIn: .minY))
        XCTAssertEqual(0, h.countBaseUnits(of: 5000, measuredIn: .minY))

        XCTAssertEqual(0, h.count(.minY, upThrough: 0))
        XCTAssertEqual(14, h.count(.maxY, upThrough: 0))
    }

    func testInitReadAndWrite() {
        let r = Rope("foo\nbar\nbaz")
        let h = Heights(rope: r)

        XCTAssertEqual(11, h.root.count)
        XCTAssertEqual(0, h.root.height)

        XCTAssertEqual([4, 8, 11], h.root.leaf.positions)
        XCTAssertEqual([0, 14, 28, 42], h.root.leaf.yOffsets)

        XCTAssertEqual(14, h[h.index(at: 0)])
        XCTAssertEqual(14, h[h.index(at: 1)])
        XCTAssertEqual(14, h[h.index(at: 2)])

        XCTAssertEqual(0, h.count(.minY, upThrough: 0))
        XCTAssertEqual(0, h.count(.minY, upThrough: 3))
        XCTAssertEqual(14, h.count(.minY, upThrough: 4))
        XCTAssertEqual(14, h.count(.minY, upThrough: 7))
        XCTAssertEqual(28, h.count(.minY, upThrough: 8))
        XCTAssertEqual(28, h.count(.minY, upThrough: 10))

        // Counting the y-offset through the end of the rope
        // should return the y-offset of the last line, not
        // the height of the rope.
        XCTAssertEqual(28, h.count(.minY, upThrough: 11))
    }

    func testOnBoundary() {
        let p = (1..<33).map { $0*5 }
        let y = (0..<33).map { CGFloat($0*14) }

        var b = Heights.Builder()
        b.push(leaf: HeightsLeaf(positions: p, yOffsets: y))
        b.push(leaf: HeightsLeaf(positions: p, yOffsets: y))
        let h = Heights(b.build())


        XCTAssertEqual(896, h.measure(using: .minY))

        XCTAssertEqual(434, h.count(.minY, upThrough: 160))

        let i = h.index(at: 160)
        XCTAssertEqual(14, h[i])
    }

    func testLeafSlicing() {
        let l = HeightsLeaf(positions: [5, 11, 18], yOffsets: [0, 14, 29, 45])
        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<12], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<13], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<14], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<15], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<16], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<17], HeightsLeaf(positions: [5, 11], yOffsets: [0, 14, 29]))
        XCTAssertEqual(l[0..<18], HeightsLeaf(positions: [5, 11, 18], yOffsets: [0, 14, 29, 45]))

        XCTAssertEqual(l[1..<18], HeightsLeaf(positions: [5, 11, 18], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[2..<18], HeightsLeaf(positions: [5, 11, 18], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[3..<18], HeightsLeaf(positions: [5, 11, 18], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[4..<18], HeightsLeaf(positions: [5, 11, 18], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[5..<18], HeightsLeaf(positions: [6, 13], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[6..<18], HeightsLeaf(positions: [6, 13], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[7..<18], HeightsLeaf(positions: [6, 13], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[8..<18], HeightsLeaf(positions: [6, 13], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[9..<18], HeightsLeaf(positions: [6, 13], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[10..<18], HeightsLeaf(positions: [6, 13], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[11..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[12..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[13..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[14..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[15..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[16..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[17..<18], HeightsLeaf(positions: [7], yOffsets: [0, 16]))
        XCTAssertEqual(l[18..<18], HeightsLeaf(positions: [0], yOffsets: [0, 16]))
    }

    func testLeafSlicingEmpty() {
        let l = HeightsLeaf(positions: [0], yOffsets: [0, 14])
        XCTAssertEqual(l, l[0..<0])
    }

    func testLeafSlicingEmptyLastLine() {
        let l = HeightsLeaf(positions: [5, 11, 11], yOffsets: [0, 14, 29, 45])
        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [0], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5], yOffsets: [0, 14]))
        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11, 11], yOffsets: [0, 14, 29, 45]))

        XCTAssertEqual(l[1..<11], HeightsLeaf(positions: [5, 11, 11], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[2..<11], HeightsLeaf(positions: [5, 11, 11], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[3..<11], HeightsLeaf(positions: [5, 11, 11], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[4..<11], HeightsLeaf(positions: [5, 11, 11], yOffsets: [0, 14, 29, 45]))
        XCTAssertEqual(l[5..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[6..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[7..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[8..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[10..<11], HeightsLeaf(positions: [6, 6], yOffsets: [0, 15, 31]))
        XCTAssertEqual(l[11..<11], HeightsLeaf(positions: [0], yOffsets: [0, 16]))
    }
}
