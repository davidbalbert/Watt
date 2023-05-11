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
    var ranges: [TextRange]

    init(storage: TextStorage?) {
        heights = []
        ys = []
        ranges = []

        guard let storage else {
            return
        }

        var y: CGFloat = 0
        storage.enumerateTextElements(from: storage.documentRange.start) { el in
            let h: CGFloat = 10 // TODO: better estimate

            heights.append(h)
            ys.append(y)
            ranges.append(el.textRange)

            y += h

            return true
        }
    }

    var documentHeight: CGFloat {
        if ys.count == 0 {
            return 0
        }

        let i = ys.count-1

        return ys[i] + heights[i]
    }

    func textRange(for position: CGPoint) -> TextRange? {
        var low = 0
        var high = ys.count

        // binary search to find the first y that's less than or equal to position.minY
        while low < high {
            let mid = low + (high - low)/2
            let y = ys[mid]

            if y > position.y {
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
        if position.y <= maxY {
            return ranges[i]
        } else {
            return nil
        }
    }
}
