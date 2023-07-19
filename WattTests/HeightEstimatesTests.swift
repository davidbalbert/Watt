//
//  HeightEstimatesTests.swift
//  WattTests
//
//  Created by David Albert on 5/26/23.
//

import XCTest
@testable import Watt

final class HeightEstimatesTests: XCTestCase {
    func testSingleLine() {
//        let buffer = Buffer("Hello, world!")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//        XCTAssertEqual(1, heightEstimates.heights.count)
//        XCTAssertEqual(14, heightEstimates.heights[0])
//        XCTAssertEqual(0, heightEstimates.ys[0])
//        XCTAssertEqual(buffer.documentRange, heightEstimates.ranges[0])
    }

    func testMultipleLines() {
//        let buffer = Buffer("Foo\nBar\nBaz")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//        XCTAssertEqual(3, heightEstimates.heights.count)
//        XCTAssertEqual(14, heightEstimates.heights[0])
//        XCTAssertEqual(14, heightEstimates.heights[1])
//        XCTAssertEqual(14, heightEstimates.heights[2])
//        XCTAssertEqual(0, heightEstimates.ys[0])
//        XCTAssertEqual(14, heightEstimates.ys[1])
//        XCTAssertEqual(28, heightEstimates.ys[2])
//
//        var start = buffer.documentRange.lowerBound
//        var end = buffer.location(start, offsetBy: "Foo\n".count)
//        XCTAssertEqual(start..<end, heightEstimates.ranges[0])
//
//        start = end
//        end = buffer.location(start, offsetBy: "Bar\n".count)
//        XCTAssertEqual(start..<end, heightEstimates.ranges[1])
//
//        start = end
//        end = buffer.location(start, offsetBy: "Baz".count)
    }

    func testEmpty() {
//        let buffer = Buffer()
//        let heightEstimates = HeightEstimates(buffer: buffer)
//        XCTAssertEqual(1, heightEstimates.heights.count)
//        XCTAssertEqual(1, heightEstimates.ys.count)
//        XCTAssertEqual(1, heightEstimates.ranges.count)
//        XCTAssertEqual(14, heightEstimates.heights[0])
//        XCTAssertEqual(0, heightEstimates.ys[0])
//        XCTAssertEqual(buffer.documentRange, heightEstimates.ranges[0])
    }

    func testTrailingNewline() {
//        let buffer = Buffer("Foo\nBar\nBaz\n")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//        XCTAssertEqual(4, heightEstimates.heights.count)
//        XCTAssertEqual(14, heightEstimates.heights[0])
//        XCTAssertEqual(14, heightEstimates.heights[1])
//        XCTAssertEqual(14, heightEstimates.heights[2])
//        XCTAssertEqual(14, heightEstimates.heights[3])
//        XCTAssertEqual(0, heightEstimates.ys[0])
//        XCTAssertEqual(14, heightEstimates.ys[1])
//        XCTAssertEqual(28, heightEstimates.ys[2])
//        XCTAssertEqual(42, heightEstimates.ys[3])
//
//        var start = buffer.documentRange.lowerBound
//        var end = buffer.location(start, offsetBy: "Foo\n".count)
//        XCTAssertEqual(start..<end, heightEstimates.ranges[0])
//
//        start = end
//        end = buffer.location(start, offsetBy: "Bar\n".count)
//        XCTAssertEqual(start..<end, heightEstimates.ranges[1])
//
//        start = end
//        end = buffer.location(start, offsetBy: "Baz\n".count)
//        XCTAssertEqual(start..<end, heightEstimates.ranges[2])
//
//        start = buffer.documentRange.upperBound
//        end = buffer.documentRange.upperBound
//        XCTAssertEqual(start..<end, heightEstimates.ranges[3])
    }

    func testTextRange() {
//        let buffer = Buffer("Foo\nBar\nBaz")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        var location = buffer.documentRange.lowerBound
//        var start = buffer.documentRange.lowerBound
//        var end = buffer.location(start, offsetBy: "Foo\n".count)
//
//        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
//
//        location = buffer.location(location, offsetBy: "F".count)
//        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
//
//        location = buffer.location(location, offsetBy: "oo".count)
//        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
//
//        location = buffer.location(location, offsetBy: "\n".count)
//        start = end
//        end = buffer.location(start, offsetBy: "Bar\n".count)
//
//        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
//
//        location = buffer.location(location, offsetBy: "Bar".count)
//        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
//
//        location = buffer.location(location, offsetBy: "\n".count)
//        start = end
//        end = buffer.documentRange.upperBound
//
//        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
//
//        // TODO: I think we need to hard code the the final line to contain documentRange.upperBound
//        // location = buffer.location(location, offsetBy: "Baz".count)
//        // XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
    }

    // MARK: - Points to ranges
    func testTextRangeForPointEmpty() {
//        let buffer = Buffer()
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        var point = CGPoint(x: 0, y: 0)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 7)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 13.999)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 14)
//        XCTAssertNil(heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: -1)
//        XCTAssertNil(heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 500, y: 7)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
    }

    func testTextRangeForPointOneLine() {
//        let buffer = Buffer("Foo")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        var point = CGPoint(x: 0, y: -1)
//        XCTAssertNil(heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 0)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 7)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 500, y: 7)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 13.999)
//        XCTAssertEqual(buffer.documentRange, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 14)
//        XCTAssertNil(heightEstimates.textRange(for: point))
    }

    func testTextRangeForPointTwoLines() {
//        let buffer = Buffer("Foo\nBar")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        var start = buffer.documentRange.lowerBound
//        var end = buffer.location(start, offsetBy: "Foo\n".count)
//
//        var point = CGPoint(x: 0, y: -1)
//        XCTAssertNil(heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 0)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 7)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 500, y: 7)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 13.999)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        start = end
//        end = buffer.documentRange.upperBound
//
//        point = CGPoint(x: 0, y: 14)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 21)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 27.999)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 28)
//        XCTAssertNil(heightEstimates.textRange(for: point))
    }

    func testTextRangeForPointTrailingNewline() {
//        let buffer = Buffer("Foo\n")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        var start = buffer.documentRange.lowerBound
//        var end = buffer.location(start, offsetBy: "Foo\n".count)
//
//        var point = CGPoint(x: 0, y: -1)
//        XCTAssertNil(heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 0)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 7)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 500, y: 7)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 13.999)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        start = buffer.documentRange.upperBound
//        end = buffer.documentRange.upperBound
//
//        point = CGPoint(x: 0, y: 14)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 21)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 27.999)
//        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))
//
//        point = CGPoint(x: 0, y: 28)
//        XCTAssertNil(heightEstimates.textRange(for: point))
    }

    // MARK: - Document height

    func testDocumentHeight() {
//        let buffer = Buffer("Foo")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        XCTAssertEqual(14, heightEstimates.documentHeight)
    }

    func testDocumentHeightEmpty() {
//        let buffer = Buffer()
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        XCTAssertEqual(14, heightEstimates.documentHeight)
    }

    func testDocumentHeightTrailingNewline() {
//        let buffer = Buffer("Foo\n")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        XCTAssertEqual(28, heightEstimates.documentHeight)
    }

    // MARK: - Line number and offset

    func testLineNumberAndOffset() {
//        let buffer = Buffer("Foo\nBar")
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        var location = buffer.documentRange.lowerBound
//        var (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
//        XCTAssertEqual(1, lineno)
//        XCTAssertEqual(0, offset)
//
//        location = buffer.location(location, offsetBy: "Foo".count)
//        (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
//        XCTAssertEqual(1, lineno)
//        XCTAssertEqual(0, offset)
//
//        location = buffer.location(location, offsetBy: "\n".count)
//        (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
//        XCTAssertEqual(2, lineno)
//        XCTAssertEqual(14, offset)
//
//        location = buffer.location(location, offsetBy: "Bar".count)
//        (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
//        XCTAssertEqual(2, lineno)
//        XCTAssertEqual(14, offset)
    }

    func testLineNumberAndOffsetEmpty() {
//        let buffer = Buffer()
//        let heightEstimates = HeightEstimates(buffer: buffer)
//
//        let location = buffer.documentRange.lowerBound
//        let (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
//        XCTAssertEqual(1, lineno)
//        XCTAssertEqual(0, offset)
    }
}
