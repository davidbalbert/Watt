//
//  LineFragment.swift
//  Watt
//
//  Created by David Albert on 5/1/23.
//

import Foundation
import CoreText
import Cocoa

extension LayoutManager {
    struct LineFragment {
        var line: CTLine
        let glyphOrigin: CGPoint
        let position: CGPoint
        let typographicBounds: CGRect
        let characterOffset: Int
        let endsWithNewline: Bool

        var frame: CGRect {
            CGRect(origin: position, size: typographicBounds.size)
        }

        func draw(at point: CGPoint, in ctx: CGContext) {
            ctx.saveGState()

            ctx.textMatrix = .identity

            ctx.translateBy(x: glyphOrigin.x, y: glyphOrigin.y)
            ctx.translateBy(x: point.x, y: point.y)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = .zero

            CTLineDraw(line, ctx)
            ctx.restoreGState()

            ctx.saveGState()
            ctx.translateBy(x: point.x, y: point.y)

//            let bounds = CGRect(x: 0, y: 0, width: floor(typographicBounds.width), height: typographicBounds.height)
//            ctx.setStrokeColor(NSColor.purple.cgColor)
//            ctx.stroke(bounds.insetBy(dx: 0.5, dy: 0.5), width: 1)

            ctx.setStrokeColor(NSColor.blue.cgColor)

            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            for run in runs {
                let count = CTRunGetGlyphCount(run)
                let range = CFRange(location: 0, length: count)
                var positions: [CGPoint] = Array(repeating: .zero, count: count)
                var advances: [CGSize] = Array(repeating: .zero, count: count)
                CTRunGetPositions(run, range, &positions)
                CTRunGetAdvances(run, range, &advances)

                for i in 0..<count {
                    let p = positions[i]
                    let a = advances[i]
                    let rect = CGRect(x: p.x + glyphOrigin.x, y: p.y, width: a.width, height: typographicBounds.height)
                    ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
                }
            }


            ctx.restoreGState()
        }

        // The range of the string in the line. Always starts at 0
        var characterRange: NSRange {
            let range = CTLineGetStringRange(line)
            return NSRange(location: 0, length: range.length)
        }

        // The character index in the line closest to point. Range from 0..<count+1, unless
        // line ends in a newline, in which case it ranges from 0..<count. Works the same as
        // CTLineGetStringIndexForPosition, except for the newline behavior described previously.
        func characterIndex(for point: CGPoint) -> Int {
            // adjust for TextContainer line padding
            let adjusted = CGPoint(x: point.x - glyphOrigin.x, y: point.y)

            // we're at the start of the line
            if adjusted.x < 0 {
                return 0
            }

            let runs = CTLineGetGlyphRuns(line) as! [CTRun]

            for (i, run) in runs.enumerated() {
                let glyphCount = CTRunGetGlyphCount(run)
                let range = CFRange(location: 0, length: glyphCount)

                var indices: [CFIndex] = Array(repeating: 0, count: glyphCount)
                var positions: [CGPoint] = Array(repeating: .zero, count: glyphCount)
                var advances: [CGSize] = Array(repeating: .zero, count: glyphCount)
                CTRunGetStringIndices(run, range, &indices)
                CTRunGetPositions(run, range, &positions)
                CTRunGetAdvances(run, range, &advances)

                let isLastRun = i == runs.count-1

                let limit: Int
                if isLastRun {
                    // we handle the final glyph outside the loop
                    // to make the special casing for "\n" easier.
                    limit = glyphCount-1
                } else {
                    limit = glyphCount
                }

                for j in 0..<limit {
                    let minX = positions[j].x
                    let maxX = minX + advances[j].width

                    if (minX..<maxX).contains(adjusted.x) {
                        let width = maxX - minX
                        let glyphOffset = adjusted.x - minX

                        if glyphOffset < width/2 {
                            return indices[j]
                        } else {
                            return indices[j] + 1
                        }
                    }
                }
            }

            if endsWithNewline {
                return characterRange.upperBound-1
            } else {
                return characterRange.upperBound
            }
        }

        func locationForCharacter(at index: Int) -> CGPoint {
            CGPoint(x: CTLineGetOffsetForStringIndex(line, index - characterOffset, nil), y: 0)
        }
    }
}
