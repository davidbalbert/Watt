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
        let contentManager = ContentManager("Hello, world!")
        let heightEstimates = HeightEstimates(contentManager: contentManager)
        XCTAssertEqual(1, heightEstimates.heights.count)
        XCTAssertEqual(14, heightEstimates.heights[0])
        XCTAssertEqual(0, heightEstimates.ys[0])
        XCTAssertEqual(contentManager.documentRange, heightEstimates.ranges[0])
    }

    func testMultipleLines() {
        let contentManager = ContentManager("Foo\nBar\nBaz")
        let heightEstimates = HeightEstimates(contentManager: contentManager)
        XCTAssertEqual(3, heightEstimates.heights.count)
        XCTAssertEqual(14, heightEstimates.heights[0])
        XCTAssertEqual(14, heightEstimates.heights[1])
        XCTAssertEqual(14, heightEstimates.heights[2])
        XCTAssertEqual(0, heightEstimates.ys[0])
        XCTAssertEqual(14, heightEstimates.ys[1])
        XCTAssertEqual(28, heightEstimates.ys[2])

        var start = contentManager.documentRange.lowerBound
        var end = contentManager.location(start, offsetBy: "Foo\n".count)
        XCTAssertEqual(start..<end, heightEstimates.ranges[0])

        start = end
        end = contentManager.location(start, offsetBy: "Bar\n".count)
        XCTAssertEqual(start..<end, heightEstimates.ranges[1])

        start = end
        end = contentManager.location(start, offsetBy: "Baz".count)
    }

    func testEmpty() {
        let contentManager = ContentManager("")
        let heightEstimates = HeightEstimates(contentManager: contentManager)
        XCTAssertEqual(1, heightEstimates.heights.count)
        XCTAssertEqual(1, heightEstimates.ys.count)
        XCTAssertEqual(1, heightEstimates.ranges.count)
        XCTAssertEqual(14, heightEstimates.heights[0])
        XCTAssertEqual(0, heightEstimates.ys[0])
        XCTAssertEqual(contentManager.documentRange, heightEstimates.ranges[0])
    }

    func testTrailingNewline() {
        let contentManager = ContentManager("Foo\nBar\nBaz\n")
        let heightEstimates = HeightEstimates(contentManager: contentManager)
        XCTAssertEqual(4, heightEstimates.heights.count)
        XCTAssertEqual(14, heightEstimates.heights[0])
        XCTAssertEqual(14, heightEstimates.heights[1])
        XCTAssertEqual(14, heightEstimates.heights[2])
        XCTAssertEqual(14, heightEstimates.heights[3])
        XCTAssertEqual(0, heightEstimates.ys[0])
        XCTAssertEqual(14, heightEstimates.ys[1])
        XCTAssertEqual(28, heightEstimates.ys[2])
        XCTAssertEqual(42, heightEstimates.ys[3])

        var start = contentManager.documentRange.lowerBound
        var end = contentManager.location(start, offsetBy: "Foo\n".count)
        XCTAssertEqual(start..<end, heightEstimates.ranges[0])

        start = end
        end = contentManager.location(start, offsetBy: "Bar\n".count)
        XCTAssertEqual(start..<end, heightEstimates.ranges[1])

        start = end
        end = contentManager.location(start, offsetBy: "Baz\n".count)
        XCTAssertEqual(start..<end, heightEstimates.ranges[2])

        start = contentManager.documentRange.upperBound
        end = contentManager.documentRange.upperBound
        XCTAssertEqual(start..<end, heightEstimates.ranges[3])
    }

    func testTextRange() {
        let contentManager = ContentManager("Foo\nBar\nBaz")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        var location = contentManager.documentRange.lowerBound
        var start = contentManager.documentRange.lowerBound
        var end = contentManager.location(start, offsetBy: "Foo\n".count)

        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)

        location = contentManager.location(location, offsetBy: "F".count)
        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)

        location = contentManager.location(location, offsetBy: "oo".count)
        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)

        location = contentManager.location(location, offsetBy: "\n".count)
        start = end
        end = contentManager.location(start, offsetBy: "Bar\n".count)

        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)

        location = contentManager.location(location, offsetBy: "Bar".count)
        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)

        location = contentManager.location(location, offsetBy: "\n".count)
        start = end
        end = contentManager.documentRange.upperBound

        XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)

        // TODO: I think we need to hard code the the final line to contain documentRange.upperBound
        // location = contentManager.location(location, offsetBy: "Baz".count)
        // XCTAssertEqual(heightEstimates.textRange(containing: location), start..<end)
    }

    // MARK: - Points to ranges
    func testTextRangeForPointEmpty() {
        let contentManager = ContentManager("")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        var point = CGPoint(x: 0, y: 0)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 7)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 13.999)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 14)
        XCTAssertNil(heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: -1)
        XCTAssertNil(heightEstimates.textRange(for: point))

        point = CGPoint(x: 500, y: 7)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))
    }

    func testTextRangeForPointOneLine() {
        let contentManager = ContentManager("Foo")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        var point = CGPoint(x: 0, y: -1)
        XCTAssertNil(heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 0)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 7)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 500, y: 7)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 13.999)
        XCTAssertEqual(contentManager.documentRange, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 14)
        XCTAssertNil(heightEstimates.textRange(for: point))
    }

    func testTextRangeForPointTwoLines() {
        let contentManager = ContentManager("Foo\nBar")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        var start = contentManager.documentRange.lowerBound
        var end = contentManager.location(start, offsetBy: "Foo\n".count)

        var point = CGPoint(x: 0, y: -1)
        XCTAssertNil(heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 0)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 7)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 500, y: 7)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 13.999)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        start = end
        end = contentManager.documentRange.upperBound

        point = CGPoint(x: 0, y: 14)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 21)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 27.999)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 28)
        XCTAssertNil(heightEstimates.textRange(for: point))
    }

    func testTextRangeForPointTrailingNewline() {
        let contentManager = ContentManager("Foo\n")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        var start = contentManager.documentRange.lowerBound
        var end = contentManager.location(start, offsetBy: "Foo\n".count)

        var point = CGPoint(x: 0, y: -1)
        XCTAssertNil(heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 0)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 7)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 500, y: 7)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 13.999)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        start = contentManager.documentRange.upperBound
        end = contentManager.documentRange.upperBound

        point = CGPoint(x: 0, y: 14)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 21)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 27.999)
        XCTAssertEqual(start..<end, heightEstimates.textRange(for: point))

        point = CGPoint(x: 0, y: 28)
        XCTAssertNil(heightEstimates.textRange(for: point))
    }

    // MARK: - Document height

    func testDocumentHeight() {
        let contentManager = ContentManager("Foo")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        XCTAssertEqual(14, heightEstimates.documentHeight)
    }

    func testDocumentHeightEmpty() {
        let contentManager = ContentManager("")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        XCTAssertEqual(14, heightEstimates.documentHeight)
    }

    func testDocumentHeightTrailingNewline() {
        let contentManager = ContentManager("Foo\n")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        XCTAssertEqual(28, heightEstimates.documentHeight)
    }

    // MARK: - Line number and offset

    func testLineNumberAndOffset() {
        let contentManager = ContentManager("Foo\nBar")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        var location = contentManager.documentRange.lowerBound
        var (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
        XCTAssertEqual(1, lineno)
        XCTAssertEqual(0, offset)

        location = contentManager.location(location, offsetBy: "Foo".count)
        (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
        XCTAssertEqual(1, lineno)
        XCTAssertEqual(0, offset)

        location = contentManager.location(location, offsetBy: "\n".count)
        (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
        XCTAssertEqual(2, lineno)
        XCTAssertEqual(14, offset)

        location = contentManager.location(location, offsetBy: "Bar".count)
        (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
        XCTAssertEqual(2, lineno)
        XCTAssertEqual(14, offset)
    }

    func testLineNumberAndOffsetEmpty() {
        let contentManager = ContentManager("")
        let heightEstimates = HeightEstimates(contentManager: contentManager)

        let location = contentManager.documentRange.lowerBound
        let (lineno, offset) = heightEstimates.lineNumberAndOffset(containing: location)!
        XCTAssertEqual(1, lineno)
        XCTAssertEqual(0, offset)
    }
}
