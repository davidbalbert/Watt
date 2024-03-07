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

    let charsPerFrag = 10
    let charWidth = 7.41796875
    let fragHeight = 14.1328125

    var w: Double {
        charWidth
    }

    func makeLayoutManager(_ s: String) -> LayoutManager {
        var r = AttributedRope(s)
        r.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let buffer = Buffer(r, language: .plainText)

        let layoutManager = LayoutManager()
        layoutManager.buffer = buffer
        layoutManager.textContainer.size = CGSize(width: charWidth * Double(charsPerFrag), height: 0)
        layoutManager.textContainer.lineFragmentPadding = 0

        return layoutManager
    }

    // Make sure the metrics of the font we're using don't change.
    func testFontMetrics() {
        let layoutManager = makeLayoutManager("abc")
        let buffer = layoutManager.buffer

        let font = buffer.runs[buffer.index(at: 0)].font!
        XCTAssertEqual(charWidth, font.maximumAdvancement.width)

        let line = layoutManager.line(containing: buffer.index(at: 0))
        XCTAssertEqual(line.lineFragments.count, 1)
        XCTAssertEqual(fragHeight, line.lineFragments[0].typographicBounds.height)
    }

    // MARK: Editing + invalidating

    func testYOffsetAfterSplittingLine() {
        class Delegate: NSObject, LayoutManagerDelegate {
            func viewportBounds(for layoutManager: LayoutManager) -> CGRect {
                CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            func visibleRect(for layoutManager: LayoutManager) -> CGRect {
                viewportBounds(for: layoutManager)
            }
            func didInvalidateLayout(for layoutManager: LayoutManager) {}
            func defaultAttributes(for layoutManager: LayoutManager) -> AttributedRope.Attributes {
                AttributedRope.Attributes()
            }
            func selections(for layoutManager: LayoutManager) -> [Selection] {
                []
            }
            func layoutManager(_ layoutManager: LayoutManager, bufferDidReload buffer: Buffer) {}
            func layoutManager(_ layoutManager: LayoutManager, buffer: Buffer, contentsDidChangeFrom old: Rope, to new: Rope, withDelta delta: BTreeDelta<Rope>) {}
            func layoutManager(_ layoutManager: LayoutManager, createLayerForLine line: Line) -> LineLayer {
                LineLayer(line: line)
            }
            func layoutManager(_ layoutManager: LayoutManager, positionLineLayer layer: LineLayer) {}
        }

        let string = "0123456789wrap"
        let l = makeLayoutManager(string)
        let b = l.buffer

        // This test is only relevant if layout info is cached, so we need
        // a delegate to provide layers for the lines.
        let delegate = Delegate()
        l.delegate = delegate
        // ensures layout info is cached
        l.layoutText { _, _ in }

        XCTAssertEqual(l.lineLayers.count, 1)

        // insert "\n" after "w"
        b.replaceSubrange(b.index(at: 11)..<b.index(at: 11), with: "\n")

        // ensures layout info is cached
        l.layoutText { _, _ in }

        XCTAssertEqual(l.lineLayers.count, 2)
        XCTAssertEqual(b.text, "0123456789w\nrap")

        let line2 = l.line(containing: b.index(at: 12))
        XCTAssertEqual(b.text[line2.range], "rap")

        // Each line's alignment frame has point aligned minY and maxY. Line2's minY
        // is equal to the first line's maxY. Alignment frame heights are calculated
        // as follows:
        //
        // let heights = lineFragments.map(\.typographicBounds.height)
        // let boundsHeight = sum(heights.dropLast().map { round($0) }) + heights.last
        // let alignmentHeight = round(boundsHeight)
        //
        // The first line has two line fragments, so it's typographicBounds is
        // round(fragHeight) + fragHeight. It's alignment height is that value rounded.
        let line1MaxY = round(round(fragHeight) + fragHeight)

        // After an edit, the layout manager has to ensure that the y-offsets of any newly
        // inserted lines are correct by recalculating the height of the line containing
        // the index immediately preceding the replacement range.
        XCTAssertEqual(line2.alignmentFrame.minY, line1MaxY)
    }

    // MARK: lineFragmentRange(containing:)

    func testLineFragmentRangesEmptyBuffer() {
        let string = ""
        let l = makeLayoutManager(string)
        let b = l.buffer

        let r = l.lineFragmentRange(containing: b.startIndex)

        XCTAssertEqual(0..<0, Range(r, in: b))
    }

    func testLineFragmentRangesStartOfFrags() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)
        let l = makeLayoutManager(string)
        let b = l.buffer

        let start0 = b.index(b.startIndex, offsetBy: 0*charsPerFrag)
        let start1 = b.index(b.startIndex, offsetBy: 1*charsPerFrag)
        let start2 = b.index(b.startIndex, offsetBy: 2*charsPerFrag)
        let start3 = b.index(b.startIndex, offsetBy: 3*charsPerFrag)
        let start4 = b.index(b.startIndex, offsetBy: 4*charsPerFrag)

        let r0 = l.lineFragmentRange(containing: start0)
        let r1 = l.lineFragmentRange(containing: start1)
        let r2 = l.lineFragmentRange(containing: start2)
        let r3 = l.lineFragmentRange(containing: start3)
        let r4 = l.lineFragmentRange(containing: start4)
        let r5 = l.lineFragmentRange(containing: b.endIndex)

        XCTAssertEqual(0..<10,  Range(r0, in: b))
        XCTAssertEqual(10..<20, Range(r1, in: b))
        XCTAssertEqual(20..<30, Range(r2, in: b))
        XCTAssertEqual(30..<40, Range(r3, in: b))
        XCTAssertEqual(40..<42, Range(r4, in: b))
        XCTAssertEqual(40..<42, Range(r5, in: b))
    }


    func testLineFragmentRangesMiddleOfFrags() {
        // 1 line, 5 line fragments, with the fifth fragment only holding 2 characters
        let string = String(repeating: "a", count: charsPerFrag*4 + 2)
        let l = makeLayoutManager(string)
        let b = l.buffer

        let i0 = b.index(b.startIndex, offsetBy: 0*charsPerFrag + 1)
        let i1 = b.index(b.startIndex, offsetBy: 1*charsPerFrag + 1)
        let i2 = b.index(b.startIndex, offsetBy: 2*charsPerFrag + 1)
        let i3 = b.index(b.startIndex, offsetBy: 3*charsPerFrag + 1)
        let i4 = b.index(b.startIndex, offsetBy: 4*charsPerFrag + 1)

        let r0 = l.lineFragmentRange(containing: i0)
        let r1 = l.lineFragmentRange(containing: i1)
        let r2 = l.lineFragmentRange(containing: i2)
        let r3 = l.lineFragmentRange(containing: i3)
        let r4 = l.lineFragmentRange(containing: i4)

        XCTAssertEqual(0..<10,  Range(r0, in: b))
        XCTAssertEqual(10..<20, Range(r1, in: b))
        XCTAssertEqual(20..<30, Range(r2, in: b))
        XCTAssertEqual(30..<40, Range(r3, in: b))
        XCTAssertEqual(40..<42, Range(r4, in: b))
    }


    func testLineFragmentRangesMultipleLines() {
        // 4 lines, 5 line fragments, no trailing newline

        let string = """
        hello
        0123456789
        0123456789wrap
        world
        """

        let l = makeLayoutManager(string)
        let b = l.buffer

        // First line: a single fragment that takes up less than the entire width.
        let start0 = b.index(b.startIndex, offsetBy: 0)
        var r = l.lineFragmentRange(containing: start0)
        XCTAssertEqual(0..<6, Range(r, in: b))

        // between "o" and "\n"
        let last0 = b.index(b.startIndex, offsetBy: 5)
        r = l.lineFragmentRange(containing: last0)
        XCTAssertEqual(0..<6, Range(r, in: b))


        // Second line: a fragment that takes up the entire width and ends in a newline.
        let start1 = b.index(b.startIndex, offsetBy: 6)
        r = l.lineFragmentRange(containing: start1)
        XCTAssertEqual(6..<17, Range(r, in: b))

        // between "9" and "\n"
        let last1 = b.index(b.startIndex, offsetBy: 16)
        r = l.lineFragmentRange(containing: last1)
        XCTAssertEqual(6..<17, Range(r, in: b))


        // Third line wraps, with two fragments
        //
        // First fragment
        let start2 = b.index(b.startIndex, offsetBy: 17)
        r = l.lineFragmentRange(containing: start2)
        XCTAssertEqual(17..<27, Range(r, in: b))

        // between "9" and "w"
        let boundary2 = b.index(b.startIndex, offsetBy: 27)
        r = l.lineFragmentRange(containing: boundary2)
        XCTAssertEqual(27..<32, Range(r, in: b))

        // between "p" and "\n"
        let last2 = b.index(b.startIndex, offsetBy: 31)
        r = l.lineFragmentRange(containing: last2)
        XCTAssertEqual(27..<32, Range(r, in: b))

        // Fourth line
        let start3 = b.index(b.startIndex, offsetBy: 32)
        r = l.lineFragmentRange(containing: start3)
        XCTAssertEqual(32..<37, Range(r, in: b))

        // At the end of the buffer
        let last3 = b.index(b.startIndex, offsetBy: 37)
        XCTAssertEqual(last3, b.endIndex)

        r = l.lineFragmentRange(containing: last3)
        XCTAssertEqual(32..<37, Range(r, in: b))
    }

    func testLineFragmentRangesEndingInNewline() {
        // 2 lines, 3 line fragments
        let string = """
        0123456789wrap

        """
        let l = makeLayoutManager(string)
        let b = l.buffer


        // First line: two fragments
        let start0 = b.index(b.startIndex, offsetBy: 0)
        var r = l.lineFragmentRange(containing: start0)
        XCTAssertEqual(0..<10, Range(r, in: b))


        // between "9" and "w"
        let boundary0 = b.index(b.startIndex, offsetBy: 10)
        r = l.lineFragmentRange(containing: boundary0)
        XCTAssertEqual(10..<15, Range(r, in: b))

        // between "p" and "\n"
        let last0 = b.index(b.startIndex, offsetBy: 14)
        r = l.lineFragmentRange(containing: last0)
        XCTAssertEqual(10..<15, Range(r, in: b))

        // Second line, a single empty fragment
        let start1 = b.index(b.startIndex, offsetBy: 15)
        r = l.lineFragmentRange(containing: start1)
        XCTAssertEqual(15..<15, Range(r, in: b))
    }

    func testLineFragmentRangeFullFragAndNewline() {
        let string = "0123456789\n"
        let l = makeLayoutManager(string)
        let b = l.buffer

        var r = l.lineFragmentRange(containing: b.index(at: 0))
        XCTAssertEqual(0..<11, Range(r, in: b))

        r = l.lineFragmentRange(containing: b.index(at: 5))
        XCTAssertEqual(0..<11, Range(r, in: b))

        r = l.lineFragmentRange(containing: b.index(at: 10))
        XCTAssertEqual(0..<11, Range(r, in: b))

        r = l.lineFragmentRange(containing: b.index(at: 11))
        XCTAssertEqual(11..<11, Range(r, in: b))
    }

    func testLineFragmentRangeEndIndex() {
        let string = "abc"
        let l = makeLayoutManager(string)
        let b = l.buffer

        // End index returns the last line
        let r = l.lineFragmentRange(containing: b.index(at: 3))
        XCTAssertEqual(0..<3, Range(r, in: b))
    }


    // MARK: enumerateCaretOffsetsInLineFragment(containing:using:)

    func testEnumerateCaretOffsetsEmptyLine() {
        let string = ""
        let l = makeLayoutManager(string)
        let b = l.buffer

        let offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(2, offsets.count)
        XCTAssertEqual(O(0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(0, b.index(at: 0), .trailing), offsets[1])
    }

    func testEnumerateCaretOffsetsOnlyNewline() {
        let string = "\n"
        let l = makeLayoutManager(string)
        let b = l.buffer

        var offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 0))

        XCTAssertEqual(2, offsets.count)
        XCTAssertEqual(O(0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(0, b.index(at: 0), .trailing), offsets[1])

        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 1))

        XCTAssertEqual(2, offsets.count)
        XCTAssertEqual(O(0, b.index(at: 1), .leading), offsets[0])
        XCTAssertEqual(O(0, b.index(at: 1), .trailing), offsets[1])
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

        XCTAssertEqual(8, offsets.count)

        XCTAssertEqual(O(w*0, b.index(at: 0), .leading), offsets[0])
        XCTAssertEqual(O(w*1, b.index(at: 0), .trailing), offsets[1])
        XCTAssertEqual(O(w*1, b.index(at: 1), .leading), offsets[2])
        XCTAssertEqual(O(w*2, b.index(at: 1), .trailing), offsets[3])
        XCTAssertEqual(O(w*2, b.index(at: 2), .leading), offsets[4])
        XCTAssertEqual(O(w*3, b.index(at: 2), .trailing), offsets[5])
        XCTAssertEqual(O(w*3, b.index(at: 3), .leading), offsets[6])
        XCTAssertEqual(O(w*3, b.index(at: 3), .trailing), offsets[7])


        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 4))

        XCTAssertEqual(2, offsets.count)

        XCTAssertEqual(O(0, b.index(at: 4), .leading), offsets[0])
        XCTAssertEqual(O(0, b.index(at: 4), .trailing), offsets[1])
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

        XCTAssertEqual(22, offsets.count)

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
        XCTAssertEqual(O(w*10, b.index(at: 10), .leading), offsets[20])
        XCTAssertEqual(O(w*10, b.index(at: 10), .trailing), offsets[21])

        offsets = l.carretOffsetsInLineFragment(containing: b.index(at: 11))

        XCTAssertEqual(2, offsets.count)

        XCTAssertEqual(O(0, b.index(at: 11), .leading), offsets[0])
        XCTAssertEqual(O(0, b.index(at: 11), .trailing), offsets[1])
    }
}
