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

        XCTAssertEqual(0, h.yOffset(upThroughPosition: 0))

        XCTAssertEqual(0, h.position(upThroughYOffset: 0))
        XCTAssertEqual(0, h.position(upThroughYOffset: 1))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13.9999))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(0, h.position(upThroughYOffset: 14))
        XCTAssertEqual(0, h.position(upThroughYOffset: 14.0001))
    }

    func testYOffsetOneLine() {
        let r = Rope("a")
        let h = Heights(rope: r)

        XCTAssertEqual(14, h.contentHeight)

        XCTAssertEqual(0, h.yOffset(upThroughPosition: 0))

        XCTAssertEqual(0, h.position(upThroughYOffset: 0))
        XCTAssertEqual(0, h.position(upThroughYOffset: 1))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13.9999))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(0, h.position(upThroughYOffset: 14))
        XCTAssertEqual(0, h.position(upThroughYOffset: 14.0001))
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

        XCTAssertEqual(0, h.yOffset(upThroughPosition: 0))
        XCTAssertEqual(0, h.yOffset(upThroughPosition: 1))
        XCTAssertEqual(14, h.yOffset(upThroughPosition: 2))
        XCTAssertEqual(14, h.yOffset(upThroughPosition: 3))

        XCTAssertEqual(434, h.yOffset(upThroughPosition: 62))
        // endIndex rounds down to the y-offset of the last line
        XCTAssertEqual(434, h.yOffset(upThroughPosition: 63))

        XCTAssertEqual(0, h.position(upThroughYOffset: 0))
        XCTAssertEqual(0, h.position(upThroughYOffset: 1))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13.9999))
        XCTAssertEqual(2, h.position(upThroughYOffset: 14))
        XCTAssertEqual(2, h.position(upThroughYOffset: 14.0001))
        XCTAssertEqual(2, h.position(upThroughYOffset: 27))
        XCTAssertEqual(2, h.position(upThroughYOffset: 27.9999))
        XCTAssertEqual(4, h.position(upThroughYOffset: 28))

        XCTAssertEqual(62, h.position(upThroughYOffset: 434))
        XCTAssertEqual(62, h.position(upThroughYOffset: 447.9999))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(62, h.position(upThroughYOffset: 448))
        XCTAssertEqual(62, h.position(upThroughYOffset: 448.0001))
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

        XCTAssertEqual(0, h.yOffset(upThroughPosition: 0))
        XCTAssertEqual(0, h.yOffset(upThroughPosition: 1))
        XCTAssertEqual(14, h.yOffset(upThroughPosition: 2))
        XCTAssertEqual(14, h.yOffset(upThroughPosition: 3))

        XCTAssertEqual(434, h.yOffset(upThroughPosition: 62))
        XCTAssertEqual(434, h.yOffset(upThroughPosition: 63))
        // endIndex is the beginning of the last line
        XCTAssertEqual(448, h.yOffset(upThroughPosition: 64))

        XCTAssertEqual(0, h.position(upThroughYOffset: 0))
        XCTAssertEqual(0, h.position(upThroughYOffset: 1))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13.9999))
        XCTAssertEqual(2, h.position(upThroughYOffset: 14))
        XCTAssertEqual(2, h.position(upThroughYOffset: 14.0001))
        XCTAssertEqual(2, h.position(upThroughYOffset: 27))
        XCTAssertEqual(2, h.position(upThroughYOffset: 27.9999))
        XCTAssertEqual(4, h.position(upThroughYOffset: 28))

        XCTAssertEqual(62, h.position(upThroughYOffset: 434))
        XCTAssertEqual(62, h.position(upThroughYOffset: 447.9999))
        XCTAssertEqual(64, h.position(upThroughYOffset: 448))
        XCTAssertEqual(64, h.position(upThroughYOffset: 461.9999))

        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(64, h.position(upThroughYOffset: 462))
        XCTAssertEqual(64, h.position(upThroughYOffset: 462.0001))
    }

    func testYOffsetAcrossTwoLeaves() {
        // 128 lines total. The final line is "a".
        // Useful y-offset reference points (line - y-offset):
        // 0 - 0
        // 1 - 14
        // 2 - 28
        // ...
        // 127 - 1778 (128th line, final, non-empty)
        //
        // Total characters = 255; endIndex == 255.
        // Total height = 1792 (1778 + 14).

        let r = Rope(Array(repeating: "a", count: 128).joined(separator: "\n"))
        let h = Heights(rope: r)

        XCTAssertEqual(1792, h.contentHeight)

        XCTAssertEqual(0, h.yOffset(upThroughPosition: 0))
        XCTAssertEqual(0, h.yOffset(upThroughPosition: 1))
        XCTAssertEqual(14, h.yOffset(upThroughPosition: 2))
        XCTAssertEqual(14, h.yOffset(upThroughPosition: 3))
        // ...
        XCTAssertEqual(868, h.yOffset(upThroughPosition: 124))
        XCTAssertEqual(868, h.yOffset(upThroughPosition: 125))
        XCTAssertEqual(882, h.yOffset(upThroughPosition: 126))
        XCTAssertEqual(882, h.yOffset(upThroughPosition: 127))

        // leaf boundary

        XCTAssertEqual(896, h.yOffset(upThroughPosition: 128))
        XCTAssertEqual(896, h.yOffset(upThroughPosition: 129))
        XCTAssertEqual(910, h.yOffset(upThroughPosition: 130))
        XCTAssertEqual(910, h.yOffset(upThroughPosition: 131))
        // ...
        XCTAssertEqual(1778, h.yOffset(upThroughPosition: 254))
        // endIndex rounds down to the y-offset of the last line.
        XCTAssertEqual(1778, h.yOffset(upThroughPosition: 255))

        XCTAssertEqual(0, h.position(upThroughYOffset: 0))
        XCTAssertEqual(0, h.position(upThroughYOffset: 1))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13))
        XCTAssertEqual(0, h.position(upThroughYOffset: 13.9999))
        XCTAssertEqual(2, h.position(upThroughYOffset: 14))
        XCTAssertEqual(2, h.position(upThroughYOffset: 14.0001))
        XCTAssertEqual(2, h.position(upThroughYOffset: 27))
        XCTAssertEqual(2, h.position(upThroughYOffset: 27.9999))
        XCTAssertEqual(4, h.position(upThroughYOffset: 28))
        // ...
        XCTAssertEqual(124, h.position(upThroughYOffset: 868))
        XCTAssertEqual(124, h.position(upThroughYOffset: 869))
        XCTAssertEqual(124, h.position(upThroughYOffset: 881))
        XCTAssertEqual(124, h.position(upThroughYOffset: 881.9999))
        XCTAssertEqual(126, h.position(upThroughYOffset: 882))
        XCTAssertEqual(126, h.position(upThroughYOffset: 882.0001))
        XCTAssertEqual(126, h.position(upThroughYOffset: 895))
        XCTAssertEqual(126, h.position(upThroughYOffset: 895.9999))

        // leaf boundary

        XCTAssertEqual(128, h.position(upThroughYOffset: 896))
        XCTAssertEqual(128, h.position(upThroughYOffset: 896.0001))
        XCTAssertEqual(128, h.position(upThroughYOffset: 909))
        XCTAssertEqual(128, h.position(upThroughYOffset: 909.9999))
        XCTAssertEqual(130, h.position(upThroughYOffset: 910))
        XCTAssertEqual(130, h.position(upThroughYOffset: 910.0001))
        XCTAssertEqual(130, h.position(upThroughYOffset: 923))
        XCTAssertEqual(130, h.position(upThroughYOffset: 923.9999))
        XCTAssertEqual(132, h.position(upThroughYOffset: 924))
        // ...
        XCTAssertEqual(254, h.position(upThroughYOffset: 1778))
        XCTAssertEqual(254, h.position(upThroughYOffset: 1778.0001))
        XCTAssertEqual(254, h.position(upThroughYOffset: 1791))
        XCTAssertEqual(254, h.position(upThroughYOffset: 1791.9999))
        // contentHeight and greater rounds down to the beginning of the last line
        XCTAssertEqual(254, h.position(upThroughYOffset: 1792))
        XCTAssertEqual(254, h.position(upThroughYOffset: 1792.0001))
    }

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

    func testHeightAcrossTwoLeaves() {
        // 128 lines total. The final line is "a".
        // Total characters == 255; endIndex == 255.
        
        let r = Rope(Array(repeating: "a", count: 128).joined(separator: "\n"))
        var h = Heights(rope: r)

        XCTAssertEqual(1, h.root.height)
        XCTAssertEqual(2, h.root.children.count)

        XCTAssertEqual(14, h[0])
        XCTAssertEqual(14, h[2])
        // ...
        XCTAssertEqual(14, h[126])
        // leaf boundary
        XCTAssertEqual(14, h[128])
        XCTAssertEqual(14, h[130])
        // ...
        XCTAssertEqual(14, h[254])

        XCTAssertEqual(1792, h.contentHeight)

        h[0] = 15

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        // ...
        XCTAssertEqual(14, h[126])
        // leaf boundary
        XCTAssertEqual(14, h[128])
        XCTAssertEqual(14, h[130])
        // ...
        XCTAssertEqual(14, h[254])

        XCTAssertEqual(1793, h.contentHeight)

        h[126] = 16

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        // ...
        XCTAssertEqual(16, h[126])
        // leaf boundary
        XCTAssertEqual(14, h[128])
        XCTAssertEqual(14, h[130])
        // ...
        XCTAssertEqual(14, h[254])

        XCTAssertEqual(1795, h.contentHeight)

        h[128] = 17

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        // ...
        XCTAssertEqual(16, h[126])
        // leaf boundary
        XCTAssertEqual(17, h[128])
        XCTAssertEqual(14, h[130])
        // ...
        XCTAssertEqual(14, h[254])

        XCTAssertEqual(1798, h.contentHeight)

        h[254] = 18

        XCTAssertEqual(15, h[0])
        XCTAssertEqual(14, h[2])
        // ...
        XCTAssertEqual(16, h[126])
        // leaf boundary
        XCTAssertEqual(17, h[128])
        XCTAssertEqual(14, h[130])
        // ...
        XCTAssertEqual(18, h[254])

        XCTAssertEqual(1802, h.contentHeight)
    }

    // MARK: - Internal structure

    func testLeafSlicing() {
        let l = HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45])
        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<12], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<13], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<14], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<15], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<16], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<17], HeightsLeaf(positions: [5, 11], heights: [14, 29]))
        XCTAssertEqual(l[0..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))

        XCTAssertEqual(l[1..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
        XCTAssertEqual(l[2..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
        XCTAssertEqual(l[3..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
        XCTAssertEqual(l[4..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))
        XCTAssertEqual(l[5..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[6..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[7..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[8..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[9..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[10..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[11..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[12..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[13..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[14..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[15..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[16..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[17..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[18..<18], HeightsLeaf(positions: [0], heights: [16]))
    }

    func testLeafSlicingEmpty() {
        let l = HeightsLeaf(positions: [0], heights: [14])
        XCTAssertEqual(l, l[0..<0])
    }

    func testLeafSlicingEmptyLastLine() {
        let l = HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45])
        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5], heights: [14]))
        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))

        XCTAssertEqual(l[1..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
        XCTAssertEqual(l[2..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
        XCTAssertEqual(l[3..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
        XCTAssertEqual(l[4..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
        XCTAssertEqual(l[5..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[6..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[7..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[8..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[10..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[11..<11], HeightsLeaf(positions: [0], heights: [16]))
    }

    // MARK: - Updating the associated Rope
    func testInsertIntoEmpty() {
        let r = Rope()
        var h = Heights(rope: r)

        XCTAssertEqual(0, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.handleReplaceSubrange(0..<0, with: "abc")

        XCTAssertEqual(3, h.root.count)
        XCTAssertEqual(14, h.contentHeight)
    }

    func testInsertIntoOneLine() {
        let r = Rope("a")
        var h = Heights(rope: r)

        XCTAssertEqual(1, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.handleReplaceSubrange(0..<0, with: "abc")

        XCTAssertEqual(4, h.root.count)
        XCTAssertEqual(14, h.contentHeight)
    }

    func testInsertIntoNonEmptyLastLine() {
        // 32 lines total. The final line is "a".
        // Total characters == 63; endIndex == 63.

        let r = Rope(Array(repeating: "a", count: 32).joined(separator: "\n"))
        var h = Heights(rope: r)

        XCTAssertEqual(63, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(63, ps.last)

        h.handleReplaceSubrange(63..<63, with: "abc")

        XCTAssertEqual(66, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(66, ps.last)
    }

    func testInsertIntoEmptyLastLine() {
        // 33 lines total, with an empty last line.
        // Total characters = 64; endIndex == 64.
        let r = Rope(String(repeating: "a\n", count: 32))
        var h = Heights(rope: r)

        XCTAssertEqual(64, h.root.count)
        XCTAssertEqual(462, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(33, ps.count)
        XCTAssertEqual(64, ps.last)

        h.handleReplaceSubrange(64..<64, with: "abc")

        XCTAssertEqual(67, h.root.count)
        XCTAssertEqual(462, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(33, ps.count)
        XCTAssertEqual(67, ps.last)
    }

    func testInsertIntoPenultimateLineWithNonEmptyLastLine() {
        // 32 lines total. The final line is "a".
        // Total characters == 63; endIndex == 63.

        let r = Rope(Array(repeating: "a", count: 32).joined(separator: "\n"))
        var h = Heights(rope: r)

        XCTAssertEqual(63, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(62, ps.dropLast().last)
        XCTAssertEqual(63, ps.last)

        h.handleReplaceSubrange(61..<61, with: "abc")

        XCTAssertEqual(66, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(65, ps.dropLast().last)
        XCTAssertEqual(66, ps.last)
    }
}
