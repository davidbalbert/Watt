//
//  HeightsTests.swift
//  WattTests
//
//  Created by David Albert on 7/27/23.
//

import XCTest
@testable import Watt

final class HeightsTests: XCTestCase {
    // MARK: - Measuring y-offsets

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
        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [1], heights: [14]))
        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [2], heights: [14]))
        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [3], heights: [14]))
        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [4], heights: [14]))
        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5, 5], heights: [14, 29]))
        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5, 6], heights: [14, 29]))
        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5, 7], heights: [14, 29]))
        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5, 8], heights: [14, 29]))
        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5, 9], heights: [14, 29]))
        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5, 10], heights: [14, 29]))
        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<12], HeightsLeaf(positions: [5, 11, 12], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<13], HeightsLeaf(positions: [5, 11, 13], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<14], HeightsLeaf(positions: [5, 11, 14], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<15], HeightsLeaf(positions: [5, 11, 15], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<16], HeightsLeaf(positions: [5, 11, 16], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<17], HeightsLeaf(positions: [5, 11, 17], heights: [14, 29, 45]))
        XCTAssertEqual(l[0..<18], HeightsLeaf(positions: [5, 11, 18], heights: [14, 29, 45]))

        XCTAssertEqual(l[1..<18], HeightsLeaf(positions: [4, 10, 17], heights: [14, 29, 45]))
        XCTAssertEqual(l[2..<18], HeightsLeaf(positions: [3, 9, 16], heights: [14, 29, 45]))
        XCTAssertEqual(l[3..<18], HeightsLeaf(positions: [2, 8, 15], heights: [14, 29, 45]))
        XCTAssertEqual(l[4..<18], HeightsLeaf(positions: [1, 7, 14], heights: [14, 29, 45]))
        XCTAssertEqual(l[5..<18], HeightsLeaf(positions: [6, 13], heights: [15, 31]))
        XCTAssertEqual(l[6..<18], HeightsLeaf(positions: [5, 12], heights: [15, 31]))
        XCTAssertEqual(l[7..<18], HeightsLeaf(positions: [4, 11], heights: [15, 31]))
        XCTAssertEqual(l[8..<18], HeightsLeaf(positions: [3, 10], heights: [15, 31]))
        XCTAssertEqual(l[9..<18], HeightsLeaf(positions: [2, 9], heights: [15, 31]))
        XCTAssertEqual(l[10..<18], HeightsLeaf(positions: [1, 8], heights: [15, 31]))
        XCTAssertEqual(l[11..<18], HeightsLeaf(positions: [7], heights: [16]))
        XCTAssertEqual(l[12..<18], HeightsLeaf(positions: [6], heights: [16]))
        XCTAssertEqual(l[13..<18], HeightsLeaf(positions: [5], heights: [16]))
        XCTAssertEqual(l[14..<18], HeightsLeaf(positions: [4], heights: [16]))
        XCTAssertEqual(l[15..<18], HeightsLeaf(positions: [3], heights: [16]))
        XCTAssertEqual(l[16..<18], HeightsLeaf(positions: [2], heights: [16]))
        XCTAssertEqual(l[17..<18], HeightsLeaf(positions: [1], heights: [16]))
        XCTAssertEqual(l[18..<18], HeightsLeaf(positions: [0], heights: [16]))
    }

    func testLeafSlicingEmpty() {
        let l = HeightsLeaf(positions: [0], heights: [14])
        XCTAssertEqual(l, l[0..<0])
    }

    func testLeafSlicingEmptyLastLine() {
        let l = HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45])
        XCTAssertEqual(l[0..<0], HeightsLeaf(positions: [0], heights: [14]))
        XCTAssertEqual(l[0..<1], HeightsLeaf(positions: [1], heights: [14]))
        XCTAssertEqual(l[0..<2], HeightsLeaf(positions: [2], heights: [14]))
        XCTAssertEqual(l[0..<3], HeightsLeaf(positions: [3], heights: [14]))
        XCTAssertEqual(l[0..<4], HeightsLeaf(positions: [4], heights: [14]))
        XCTAssertEqual(l[0..<5], HeightsLeaf(positions: [5, 5], heights: [14, 29]))
        XCTAssertEqual(l[0..<6], HeightsLeaf(positions: [5, 6], heights: [14, 29]))
        XCTAssertEqual(l[0..<7], HeightsLeaf(positions: [5, 7], heights: [14, 29]))
        XCTAssertEqual(l[0..<8], HeightsLeaf(positions: [5, 8], heights: [14, 29]))
        XCTAssertEqual(l[0..<9], HeightsLeaf(positions: [5, 9], heights: [14, 29]))
        XCTAssertEqual(l[0..<10], HeightsLeaf(positions: [5, 10], heights: [14, 29]))
        XCTAssertEqual(l[0..<11], HeightsLeaf(positions: [5, 11, 11], heights: [14, 29, 45]))

        XCTAssertEqual(l[1..<11], HeightsLeaf(positions: [4, 10, 10], heights: [14, 29, 45]))
        XCTAssertEqual(l[2..<11], HeightsLeaf(positions: [3, 9, 9], heights: [14, 29, 45]))
        XCTAssertEqual(l[3..<11], HeightsLeaf(positions: [2, 8, 8], heights: [14, 29, 45]))
        XCTAssertEqual(l[4..<11], HeightsLeaf(positions: [1, 7, 7], heights: [14, 29, 45]))
        XCTAssertEqual(l[5..<11], HeightsLeaf(positions: [6, 6], heights: [15, 31]))
        XCTAssertEqual(l[6..<11], HeightsLeaf(positions: [5, 5], heights: [15, 31]))
        XCTAssertEqual(l[7..<11], HeightsLeaf(positions: [4, 4], heights: [15, 31]))
        XCTAssertEqual(l[8..<11], HeightsLeaf(positions: [3, 3], heights: [15, 31]))
        XCTAssertEqual(l[9..<11], HeightsLeaf(positions: [2, 2], heights: [15, 31]))
        XCTAssertEqual(l[10..<11], HeightsLeaf(positions: [1, 1], heights: [15, 31]))
        XCTAssertEqual(l[11..<11], HeightsLeaf(positions: [0], heights: [16]))
    }

    // MARK: - Updating the associated Rope
    func testInsertIntoEmpty() {
        let r = Rope()
        var h = Heights(rope: r)

        XCTAssertEqual(0, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(0..<0, with: Subrope("abc"))

        XCTAssertEqual(3, h.root.count)
        XCTAssertEqual(14, h.contentHeight)
    }

    func testInsertIntoOneLine() {
        let r = Rope("a")
        var h = Heights(rope: r)

        XCTAssertEqual(1, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(0..<0, with: Subrope("abc"))

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

        h.replaceSubrange(63..<63, with: Subrope("abc"))

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

        h.replaceSubrange(64..<64, with: Subrope("abc"))

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

        h.replaceSubrange(61..<61, with: Subrope("abc"))

        XCTAssertEqual(66, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(65, ps.dropLast().last)
        XCTAssertEqual(66, ps.last)
    }

    func testInsertIntoPenultimateLineWithEmptyLastLine() {
        // 33 lines total, with an empty last line.
        // Total characters = 64; endIndex == 64.
        let r = Rope(String(repeating: "a\n", count: 32))
        var h = Heights(rope: r)

        XCTAssertEqual(64, h.root.count)
        XCTAssertEqual(462, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(33, ps.count)
        XCTAssertEqual(64, ps.dropLast().last)
        XCTAssertEqual(64, ps.last)

        h.replaceSubrange(61..<61, with: Subrope("abc"))

        XCTAssertEqual(67, h.root.count)
        XCTAssertEqual(462, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(33, ps.count)
        XCTAssertEqual(67, ps.dropLast().last)
        XCTAssertEqual(67, ps.last)
    }

    func testInsertNewlineIntoEmpty() {
        let r = Rope()
        var h = Heights(rope: r)

        XCTAssertEqual(0, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(0..<0, with: Subrope("\n"))

        XCTAssertEqual(1, h.root.count)
        XCTAssertEqual(28, h.contentHeight)
    }

    func testInsertNewlineIntoOneLineBeginning() {
        let r = Rope("ab")
        var h = Heights(rope: r)

        XCTAssertEqual(2, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(0..<0, with: Subrope("\n"))

        XCTAssertEqual(3, h.root.count)
        XCTAssertEqual(28, h.contentHeight)
    }

    func testInsertNewlineIntoOneLineMiddle() {
        let r = Rope("ab")
        var h = Heights(rope: r)

        XCTAssertEqual(2, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(1..<1, with: Subrope("\n"))

        XCTAssertEqual(3, h.root.count)
        XCTAssertEqual(28, h.contentHeight)
    }

    func testInsertNewlineIntoOneLineEnd() {
        let r = Rope("ab")
        var h = Heights(rope: r)

        XCTAssertEqual(2, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(2..<2, with: Subrope("\n"))

        XCTAssertEqual(3, h.root.count)
        XCTAssertEqual(28, h.contentHeight)
    }

    func testInsertNewlineIntoMultipleLinesAtBeginning() {
        let r = Rope("ab\ncd")
        var h = Heights(rope: r)

        XCTAssertEqual(5, h.root.count)
        XCTAssertEqual(28, h.contentHeight)

        h.replaceSubrange(0..<0, with: Subrope("\n"))

        XCTAssertEqual(6, h.root.count)
        XCTAssertEqual(42, h.contentHeight)
    }

    func testInsertMultibyteCharacter() {
        let r = Rope("foo\nbar\nbaz")
        var h = Heights(rope: r)

        XCTAssertEqual(11, h.root.count)
        XCTAssertEqual(42, h.contentHeight)

        h.replaceSubrange(0..<0, with: Subrope("🙂"))

        XCTAssertEqual(15, h.root.count)
        XCTAssertEqual(42, h.contentHeight)
    }

    func testReplaceRangeOneLine() {
        let r = Rope("foo bar baz")
        var h = Heights(rope: r)

        XCTAssertEqual(11, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        h.replaceSubrange(4..<7, with: Subrope("quux"))

        XCTAssertEqual(12, h.root.count)
        XCTAssertEqual(14, h.contentHeight)
    }

    func testReplaceRangeOverNewline() {
        let r = Rope("foo\nbar\nbaz")
        var h = Heights(rope: r)

        XCTAssertEqual(11, h.root.count)
        XCTAssertEqual(42, h.contentHeight)

        // overwrite "oo\nbar\b" with "qux". The result is "fquxaz".
        h.replaceSubrange(1..<9, with: Subrope("qux"))

        XCTAssertEqual(6, h.root.count)
        XCTAssertEqual(14, h.contentHeight)
    }

    func testReplaceRangeOverNewlineEndingWithBlankLine() {
        let r = Rope("foo\nbar\nbaz\n")
        var h = Heights(rope: r)

        XCTAssertEqual(12, h.root.count)
        XCTAssertEqual(56, h.contentHeight)

        // overwrite "oo\nbar\nbaz\n" with "qux". The result is "fqux".
        h.replaceSubrange(1..<12, with: Subrope("qux"))

        XCTAssertEqual(4, h.root.count)
        XCTAssertEqual(14, h.contentHeight)
    }

    func testReplaceRangeInsertingNewlines() {
        let r = Rope("hello")
        var h = Heights(rope: r)

        XCTAssertEqual(5, h.root.count)
        XCTAssertEqual(14, h.contentHeight)

        // overwrite "ll" with "foo\nbar\nbaz". The result is "hefoo\nbar\nbazo".
        h.replaceSubrange(2..<4, with: Subrope("foo\nbar\nbaz"))

        XCTAssertEqual(14, h.root.count)
        XCTAssertEqual(42, h.contentHeight)
    }

    func testReplaceRangeInsertingNewlinesMaintainingTrailingBlankLine() {
        let r = Rope("hello\n")
        var h = Heights(rope: r)

        XCTAssertEqual(6, h.root.count)
        XCTAssertEqual(28, h.contentHeight)

        // overwrite "ll" with "foo\nbar\nbaz". The result is "hefoo\nbar\nbazo\n".
        h.replaceSubrange(2..<4, with: Subrope("foo\nbar\nbaz"))

        XCTAssertEqual(15, h.root.count)
        XCTAssertEqual(56, h.contentHeight)   
    }

    func testReplaceRangeInsertingNewlinesMaintainingTrailingBlankLineAfterReplacementRange() {
        let r = Rope("foo\nbar\n")
        var h = Heights(rope: r)

        XCTAssertEqual(8, h.root.count)
        XCTAssertEqual(42, h.contentHeight)

        // overwrite the first "o" with "qux". The result is "fquxo\nbar\n".
        h.replaceSubrange(1..<2, with: Subrope("qux"))

        XCTAssertEqual(10, h.root.count)
        XCTAssertEqual(42, h.contentHeight)
    }

    func testReplaceInNonEmptyLastLine() {
        // 32 lines total. The final line is "a".
        // Total characters == 63; endIndex == 63.

        let r = Rope(Array(repeating: "a", count: 32).joined(separator: "\n"))
        var h = Heights(rope: r)

        XCTAssertEqual(63, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(63, ps.last)

        h.replaceSubrange(62..<63, with: Subrope("abc"))

        XCTAssertEqual(65, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(65, ps.last)
    }

    func testReplaceInEmptyLastLine() {
        // 33 lines total, with an empty last line.
        // Total characters = 64; endIndex == 64.

        let r = Rope(String(repeating: "a\n", count: 32))
        var h = Heights(rope: r)

        XCTAssertEqual(64, h.root.count)
        XCTAssertEqual(462, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(33, ps.count)
        XCTAssertEqual(64, ps.last)

        // this replaces the newline, so we lose the empty last line.
        h.replaceSubrange(63..<64, with: Subrope("abc"))

        XCTAssertEqual(66, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(66, ps.last)
    }

    func testReplaceInPenultimateLineWithNonEmptyLastLine() {
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

        h.replaceSubrange(60..<61, with: Subrope("abc"))

        XCTAssertEqual(65, h.root.count)
        XCTAssertEqual(448, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(32, ps.count)
        XCTAssertEqual(64, ps.dropLast().last)
        XCTAssertEqual(65, ps.last)
    }

    func testReplaceBeforeEmptyLastLine() {
        let r = Rope("foo\nbar\nbaz\n")
        var h = Heights(rope: r)

        XCTAssertEqual(12, h.root.count)
        XCTAssertEqual(56, h.contentHeight)

        var ps = h.root.leaf.positions
        XCTAssertEqual(4, ps.count)
        XCTAssertEqual(4, ps[0])
        XCTAssertEqual(8, ps[1])
        XCTAssertEqual(12, ps[2])
        XCTAssertEqual(12, ps[3])

        h.replaceSubrange(11..<11, with: Subrope("\n"))

        XCTAssertEqual(13, h.root.count)
        XCTAssertEqual(70, h.contentHeight)

        ps = h.root.leaf.positions
        XCTAssertEqual(5, ps.count)
        XCTAssertEqual(4, ps[0])
        XCTAssertEqual(8, ps[1])
        XCTAssertEqual(12, ps[2])
        XCTAssertEqual(13, ps[3])
        XCTAssertEqual(13, ps[4])
    }

    func testInsertNewlineAfterBlankLine() {
        let r = Rope("foo\n")
        var h = Heights(rope: r)

        h.replaceSubrange(4..<4, with: Subrope("\n"))

        // "foo\n\n"
        XCTAssertEqual(h.root.leaf.positions, [4, 5, 5])
    }

    func testInsertNewlineBeforeBlankLine() {
        let r = Rope("foo\n")
        var h = Heights(rope: r)

        h.replaceSubrange(3..<3, with: Subrope("\n"))

        // "foo\n\n"
        XCTAssertEqual(h.root.leaf.positions, [4, 5, 5])
    }

    func testReplaceBeforeEmptyTwoLastLines() {
        let r = Rope("foo\nbar\nbaz\n\n")
        var h = Heights(rope: r)

        var ps = h.root.leaf.positions
        XCTAssertEqual(5, ps.count)
        XCTAssertEqual(4, ps[0])
        XCTAssertEqual(8, ps[1])
        XCTAssertEqual(12, ps[2])
        XCTAssertEqual(13, ps[3])
        XCTAssertEqual(13, ps[4])

        XCTAssertEqual(13, h.root.count)
        XCTAssertEqual(70, h.contentHeight)

        h.replaceSubrange(12..<12, with: Subrope("\n"))

        XCTAssertEqual(14, h.root.count)
        XCTAssertEqual(84, h.contentHeight)

        XCTAssertEqual(14, h.position(upThroughYOffset: 100))

        ps = h.root.leaf.positions
        XCTAssertEqual(6, ps.count)
        XCTAssertEqual(4, ps[0])
        XCTAssertEqual(8, ps[1])
        XCTAssertEqual(12, ps[2])
        XCTAssertEqual(13, ps[3])
        XCTAssertEqual(14, ps[4])
        XCTAssertEqual(14, ps[5])
    }

    // MARK: Index manipulation

    func testEndOfLineContaining() {
        var h = Heights(rope: Rope("foo"))
        XCTAssertEqual(3, h.endOfLine(containing: 0))

        h = Heights(rope: Rope("foo\n"))
        XCTAssertEqual(4, h.endOfLine(containing: 0))

        h = Heights(rope: Rope("foo\nbar"))
        XCTAssertEqual(4, h.endOfLine(containing: 0))

        h = Heights(rope: Rope("foo\nbar"))
        XCTAssertEqual(7, h.endOfLine(containing: 4))

        h = Heights(rope: Rope("foo\nbar\n"))
        XCTAssertEqual(8, h.endOfLine(containing: 4))
    }

    func testStartOfLineContaining() {
        var h = Heights(rope: Rope("foo"))
        XCTAssertEqual(0, h.startIndexOfLine(containing: h.count))

        h = Heights(rope: Rope("foo\n"))
        XCTAssertEqual(4, h.startIndexOfLine(containing: h.count))

        h = Heights(rope: Rope("foo\nbar"))
        XCTAssertEqual(4, h.startIndexOfLine(containing: h.count))

        h = Heights(rope: Rope("foo\nbar\n"))
        XCTAssertEqual(8, h.startIndexOfLine(containing: h.count))
    }

    // MARK: - Regression tests

    func testUpdatingPenultimateHeightKeepsEndsWithBlankLine() {
        var h = Heights(rope: Rope("foo\nbar\nbaz\n"))

        XCTAssertEqual(14, h[8])
        XCTAssertEqual(12, h.root.count)
        XCTAssertTrue(h.root.summary.endsWithBlankLine)

        h[8] = 15
        XCTAssertEqual(15, h[8])
        XCTAssertEqual(12, h.root.count)
        XCTAssertTrue(h.root.summary.endsWithBlankLine)
    }

    func testSettingHeightsDoesntBreakLeafCount() {
        var b = HeightsBuilder()
        XCTAssertEqual(HeightsLeaf.maxSize, 64)

        for _ in 0..<192 {
            b.addLine(withBaseCount: 10, height: 14)
        }

        var heights = b.build()

        XCTAssertEqual(heights.contentHeight, 2688)

        XCTAssertEqual(heights.root.count, 1920)
        XCTAssertEqual(heights.root.height, 1)
        XCTAssertEqual(heights.root.children.count, 3)

        XCTAssertEqual(heights.root.children[0].count, 640)
        XCTAssertEqual(heights.root.children[1].count, 640)
        XCTAssertEqual(heights.root.children[2].count, 640)

        for i in 0..<192 {
            let hi = heights.index(at: 10*i)
            heights[hi] = 30
        }

        XCTAssertEqual(heights.contentHeight, 5760)

        XCTAssertEqual(heights.root.count, 1920)
        XCTAssertEqual(heights.root.height, 1)
        XCTAssertEqual(heights.root.children.count, 3)

        XCTAssertEqual(heights.root.children[0].count, 640)
        XCTAssertEqual(heights.root.children[1].count, 640)
        XCTAssertEqual(heights.root.children[2].count, 640)
    }
}
