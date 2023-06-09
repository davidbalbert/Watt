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
        var low = 0
        var high = ranges.count

        // binary search to find the first range that contains location
        while low < high {
            let mid = low + (high - low)/2
            let range = ranges[mid]

            if range.contains(location) {
                return (mid+1, ys[mid])
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
        if point.y <= maxY {
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
}
