//
//  HeightEstimates.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

struct HeightEstimates {
    // assume heights, ys, and ranges are all the same length
    var heights: [CGFloat]
    var ys: [CGFloat]
    var ranges: [Range<String.Index>]

    init(contentManager: ContentManager?) {
        heights = []
        ys = []
        ranges = []

        guard let contentManager else {
            return
        }

        // TODO: enumerating all line ranges can take a long time. Instead, we could
        // enumerate a few ranges from different parts of the document (e.g. 25 from
        // the beginning, 25 from the middle, and 25 from the end) and then take the
        // average.
        //
        // This means not only would our heights and ys be estimates, but so would our
        // ranges. That likely makes things more complicated.
        var y: CGFloat = 0
        contentManager.enumerateLineRanges(from: contentManager.documentRange.lowerBound) { range in
            let h: CGFloat = 14 // TODO: better estimate

            heights.append(h)
            ys.append(y)
            ranges.append(range)

            y += h

            return true
        }
    }

    var lineCount: Int {
        ys.count
    }

    var documentHeight: CGFloat {
        if ys.count == 0 {
            return 0
        }

        let i = ys.count-1

        return ys[i] + heights[i]
    }

    func lineNumberAndOffset(containing location: String.Index) -> (Int, CGFloat)? {
        guard let i = lineIndex(containing: location) else {
            return nil
        }

        return (i+1, ys[i])
    }

    func textRange(containing location: String.Index) -> Range<String.Index>? {
        guard let i = lineIndex(containing: location) else {
            return nil
        }

        return ranges[i]
    }

    private func lineIndex(containing location: String.Index) -> Int? {
        var low = 0
        var high = ranges.count

        // binary search to find the first range that contains location
        while low < high {
            let mid = low + (high - low)/2
            let range = ranges[mid]

            let isLast = mid == ranges.count - 1

            if range.contains(location) || isLast && range.upperBound == location {
                return mid
            } else if range.lowerBound > location {
                high = mid
            } else {
                // range.end <= location
                low = mid + 1
            }
        }

        return nil
    }

    func textRange(for point: CGPoint) -> Range<String.Index>? {
        var low = 0
        var high = ys.count

        // binary search to find the first y that's less than or equal to position.minY
        while low < high {
            let mid = low + (high - low)/2
            let y = ys[mid]

            if y > point.y {
                high = mid
            } else {
                low = mid + 1
            }
        }

        // if we didn't find anything, return nil
        if low == 0 {
            return nil
        }

        // if we found something, check if it's within the range
        let i = low - 1

        let maxY = ys[i] + heights[i]

        // position.y is already >= ys[i]
        if point.y < maxY {
            return ranges[i]
        } else {
            return nil
        }
    }

    mutating func updateFragmentHeight(at lineno: Int, with newHeight: CGFloat) {
        let index = lineno - 1

        if index < 0 || index > heights.count {
            return
        }

        let delta = floor(newHeight - heights[index])

        if delta == 0 {
            return
        }

        for i in (index+1)..<heights.count {
            ys[i] += delta
        }

        heights[index] = newHeight
    }

    mutating func updateEstimatesByReplacingLinesIn(
        oldSubstring: Substring,
        with newSubstring: String,
        startIndex: String.Index,
        originalLastLineLength: Int,
        using contentManager: ContentManager
    ) {
        guard let startLineIndex = lineIndex(containing: startIndex) else {
            return
        }

        // Calculate the number of lines in the old substring
        let oldLines = oldSubstring.split(separator: "\n", omittingEmptySubsequences: false)
        let oldLineCount = oldLines.count

        // Calculate the number of lines in the new string
        let newLines = newSubstring.split(separator: "\n", omittingEmptySubsequences: false)
        let newLineCount = newLines.count

        var currentStart = ranges[startLineIndex].lowerBound
        var currentY = ys[startLineIndex]

        let heightToRemove = heights[startLineIndex..<startLineIndex+oldLineCount].reduce(0, +)

        // Adjust the arrays to remove the old lines
        heights.removeSubrange(startLineIndex..<startLineIndex+oldLineCount)
        ys.removeSubrange(startLineIndex..<startLineIndex+oldLineCount)
        ranges.removeSubrange(startLineIndex..<startLineIndex+oldLineCount)

        // Calculate the height and y-offset for the new lines
        let newHeights = Array(repeating: CGFloat(14), count: newLineCount)
        var newYs: [CGFloat] = []
        var newRanges: [Range<String.Index>] = []

        for (i, line) in newLines.enumerated() {
            let lineLength = line.count
            let endOfRange: String.Index
            if i < newLines.count - 1 {
                // account for newline
                endOfRange = contentManager.location(currentStart, offsetBy: lineLength + 1)
            } else {
                // last line, no newline
                // We need to account for the remaining part of the line in the original string that comes after the old substring.
                // This is the length of the line in the original string that comes after the replaced part.
                let remainingLength = originalLastLineLength - oldLines.last!.count
                endOfRange = contentManager.location(currentStart, offsetBy: lineLength + remainingLength)
            }

            newRanges.append(currentStart..<endOfRange)
            newYs.append(currentY)
            currentStart = endOfRange
            currentY += 14
        }

        // Insert the new lines into the arrays
        heights.insert(contentsOf: newHeights, at: startLineIndex)
        ys.insert(contentsOf: newYs, at: startLineIndex)
        ranges.insert(contentsOf: newRanges, at: startLineIndex)

        // Compute the y offset change and adjust the y offsets for the following lines
        let deltaY = CGFloat(newLineCount)*14 - heightToRemove
        if deltaY != 0 {
            for i in startLineIndex+newLineCount..<ys.count {
                ys[i] += deltaY
            }
        }

        // Compute the range change and adjust the ranges for the following lines
        let lengthDelta = newSubstring.count - oldSubstring.count
        for i in startLineIndex+newLineCount..<ranges.count {
            let newStart = contentManager.location(ranges[i].lowerBound, offsetBy: lengthDelta)
            let newEnd: String.Index
            if i == ranges.count - 1 { // if this is the last line
                newEnd = contentManager.storage.string.endIndex
            } else {
                newEnd = contentManager.location(ranges[i].upperBound, offsetBy: lengthDelta)
            }
            ranges[i] = newStart..<newEnd
        }
    }
}
