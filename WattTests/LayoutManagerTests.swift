//
//  LayoutManagerTests.swift
//  WattTests
//
//  Created by David Albert on 11/8/23.
//

import XCTest
import AppKit

import StandardKeyBindingResponder
@testable import Watt

struct CaretOffset: Equatable {
    let offset: CGFloat
    let i: Buffer.Index
    let edge: Edge

    init(_ offset: CGFloat, _ i: Buffer.Index, _ edge: Edge) {
        self.offset = offset
        self.i = i
        self.edge = edge
    }
}

extension LayoutManager {
    func carretOffsetsInLineFragment(containing index: Buffer.Index) -> [CaretOffset] {
        var offsets: [CaretOffset] = []
        enumerateCaretOffsetsInLineFragment(containing: index) { offset, i, edge in
            offsets.append(CaretOffset(offset, i, edge))
            return true
        }
        return offsets
    }

}

final class LayoutManagerTests: XCTestCase {
    typealias O = CaretOffset

    let charWidth = 7.41796875
    var w: Double {
        charWidth
    }

    func makeLayoutManager(_ s: String) -> LayoutManager {
        var r = AttributedRope(s)
        r.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let buffer = Buffer(r, language: .plainText)

        let layoutManager = LayoutManager()
        layoutManager.buffer = buffer
        layoutManager.textContainer.size = CGSize(width: charWidth * 10, height: 0)
        layoutManager.textContainer.lineFragmentPadding = 0

        return layoutManager
    }

    // Make sure the metrics of the font we're using don't change.
    func testFontMetrics() {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        XCTAssertEqual(charWidth, font.maximumAdvancement.width)
    }

    // MARK: enumerateCaretOffsetsInLineFragment(containing:using:)

    func testEnumerateCaretOffsetsEmptyLine() {
        let string = ""
        let l = makeLayoutManager(string)
        let b = l.buffer

        let offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, b.index(at: 0), .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetsOnlyNewline() {
        let string = "\n"
        let l = makeLayoutManager(string)
        let b = l.buffer

        var offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, b.index(at: 0), .trailing), offsets[0])

        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 1))

        XCTAssertEqual(1, offsets.count)
        XCTAssertEqual(O(0, b.index(at: 1), .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetOneLine() {
        let string = "abc"
        let l = makeLayoutManager(string)
        let b = l.buffer

        let offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(6, offsets.count)

        XCTAssertEqual(O(w*0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(w*1, b.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(w*1, b.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(w*2, b.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(w*2, b.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(w*3, b.index(at: 2), .trailing), offsets[5])
    }

    func testEnumerateCaretOffsetWithNewline() {
        let string = "abc\n"
        let l = makeLayoutManager(string)
        let b = l.buffer

        var offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(6, offsets.count)

        XCTAssertEqual(O(w*0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(w*1, b.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(w*1, b.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(w*2, b.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(w*2, b.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(w*3, b.index(at: 2), .trailing), offsets[5])

        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 4))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, b.index(at: 4), .trailing), offsets[0])
    }

    func testEnumerateCaretOffsetsWithWrap() {
        let string = "0123456789wrap"
        let l = makeLayoutManager(string)
        let b = l.buffer

        var offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(20, offsets.count)

        XCTAssertEqual(O(w*0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(w*1, b.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(w*1, b.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(w*2, b.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(w*2, b.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(w*3, b.index(at: 2), .trailing), offsets[5])
        XCTAssertEqual(O(w*3, b.index(at: 3), .leading), offsets[6])
        XCTAssertEqual(O(w*4, b.index(at: 3), .trailing), offsets[7])
        XCTAssertEqual(O(w*4, b.index(at: 4), .leading), offsets[8])
        XCTAssertEqual(O(w*5, b.index(at: 4), .trailing), offsets[9])
        XCTAssertEqual(O(w*5, b.index(at: 5), .leading), offsets[10])
        XCTAssertEqual(O(w*6, b.index(at: 5), .trailing), offsets[11])
        XCTAssertEqual(O(w*6, b.index(at: 6), .leading), offsets[12])
        XCTAssertEqual(O(w*7, b.index(at: 6), .trailing), offsets[13])
        XCTAssertEqual(O(w*7, b.index(at: 7), .leading), offsets[14])
        XCTAssertEqual(O(w*8, b.index(at: 7), .trailing), offsets[15])
        XCTAssertEqual(O(w*8, b.index(at: 8), .leading), offsets[16])
        XCTAssertEqual(O(w*9, b.index(at: 8), .trailing), offsets[17])
        XCTAssertEqual(O(w*9, b.index(at: 9), .leading), offsets[18])
        XCTAssertEqual(O(w*10, b.index(at: 9), .trailing), offsets[19])

        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 10))

        XCTAssertEqual(8, offsets.count)

        XCTAssertEqual(O(w*0, b.index(at: 10), .leading), offsets[0])
        XCTAssertEqual(O(w*1, b.index(at: 10), .trailing), offsets[1])
        XCTAssertEqual(O(w*1, b.index(at: 11), .leading), offsets[2])
        XCTAssertEqual(O(w*2, b.index(at: 11), .trailing), offsets[3])
        XCTAssertEqual(O(w*2, b.index(at: 12), .leading), offsets[4])
        XCTAssertEqual(O(w*3, b.index(at: 12), .trailing), offsets[5])
        XCTAssertEqual(O(w*3, b.index(at: 13), .leading), offsets[6])
        XCTAssertEqual(O(w*4, b.index(at: 13), .trailing), offsets[7])
    }

    func testEnumerateCaretOffsetFullLineFragmentPlusNewline() {
        let string = "0123456789\n"
        let l = makeLayoutManager(string)
        let b = l.buffer

        var offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(20, offsets.count)

        XCTAssertEqual(O(w*0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(w*1, b.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(w*1, b.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(w*2, b.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(w*2, b.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(w*3, b.index(at: 2), .trailing), offsets[5])
        XCTAssertEqual(O(w*3, b.index(at: 3), .leading), offsets[6])
        XCTAssertEqual(O(w*4, b.index(at: 3), .trailing), offsets[7])
        XCTAssertEqual(O(w*4, b.index(at: 4), .leading), offsets[8])
        XCTAssertEqual(O(w*5, b.index(at: 4), .trailing), offsets[9])
        XCTAssertEqual(O(w*5, b.index(at: 5), .leading), offsets[10])
        XCTAssertEqual(O(w*6, b.index(at: 5), .trailing), offsets[11])
        XCTAssertEqual(O(w*6, b.index(at: 6), .leading), offsets[12])
        XCTAssertEqual(O(w*7, b.index(at: 6), .trailing), offsets[13])
        XCTAssertEqual(O(w*7, b.index(at: 7), .leading), offsets[14])
        XCTAssertEqual(O(w*8, b.index(at: 7), .trailing), offsets[15])
        XCTAssertEqual(O(w*8, b.index(at: 8), .leading), offsets[16])
        XCTAssertEqual(O(w*9, b.index(at: 8), .trailing), offsets[17])
        XCTAssertEqual(O(w*9, b.index(at: 9), .leading), offsets[18])
        XCTAssertEqual(O(w*10, b.index(at: 9), .trailing), offsets[19])

        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 11))

        XCTAssertEqual(1, offsets.count)

        XCTAssertEqual(O(0, b.index(at: 11), .trailing), offsets[0])
    }
}
