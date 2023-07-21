//
//  Heights.swift
//  Watt
//
//  Created by David Albert on 7/20/23.
//

import Foundation

typealias Heights = BTree<HeightsSummary>

struct HeightsSummary: BTreeSummary {
    var height: CGFloat

    static func += (left: inout HeightsSummary, right: HeightsSummary) {
        left.height += right.height
    }

    static var zero: HeightsSummary {
        HeightsSummary()
    }

    init() {
        self.height = 0
    }

    init(summarizing leaf: HeightsLeaf) {
        self.height = leaf.heights.reduce(0, +)
    }
}

extension HeightsSummary: BTreeDefaultMetric {
    static var defaultMetric: Heights.HeightsBaseMetric { Heights.HeightsBaseMetric() }
}

struct HeightsLeaf: BTreeLeaf {
    var count: Int {
        heights.count
    }

    static let minSize = 32
    static let maxSize = 64

    // indices are zero-indexed line numbers from the start of the leaf, values are heights of each line.
    var heights: [CGFloat]

    static var zero: HeightsLeaf {
        HeightsLeaf()
    }

    var isUndersized: Bool {
        heights.count < HeightsLeaf.minSize
    }

    init() {
        self.heights = []
    }

    init(heights: [CGFloat]) {
        self.heights = heights
    }

    mutating func pushMaybeSplitting(other: HeightsLeaf) -> HeightsLeaf? {
        heights.append(contentsOf: other.heights)
        
        if heights.count < HeightsLeaf.maxSize {
            return nil
        } else {
            let splitIndex = heights.count / 2
            let rightHeights = Array(heights[splitIndex...])
            
            heights.removeLast(rightHeights.count)
            
            return HeightsLeaf(heights: rightHeights)
        }
    }
    
    subscript(bounds: Range<Int>) -> HeightsLeaf {
        return HeightsLeaf(heights: Array(heights[bounds]))
    }
}

extension Heights {
    init(rope: Rope) {
        var b = Builder()

        // TODO: better estimate
        b.push(heights: Array(repeating: 14, count: rope.lines.count))

        self.init(b.build())
    }

    var contentHeight: CGFloat {
        measure(using: .yOffset)
    }

    func lineRange(for bounds: CGRect) -> Range<Int> {
        // Because we want to render all lines that overlap with the
        // viewport, the range that we return should include end.
        // I.e. start..<(end+1).
        //
        // We subtract a small amount from bounds.maxY when calculating
        // end because a rectangle's y coordinates range from [minY, maxY).
        // If we didn't do this, we'd panic when scrolling all the way to
        // the end of the document: in a 100 line file, we'd return 0..<101
        // instead of 0..<100, and then crash when we tried buffer.lines[100].
        //
        // I haven't seen any fractional coordinates for viewportBounds, so
        // we could probably get a away with just subtracting 1.0, but this
        // feels a bit safer.
        let start = countBaseUnits(of: bounds.minY, measuredIn: .yOffset)
        let end = countBaseUnits(of: bounds.maxY - 0.00001, measuredIn: .yOffset)

        return start..<(end+1)
    }

    // line is zero-indexed
    func yOffset(forLine lineno: Int) -> CGFloat {
        count(.yOffset, upThrough: lineno)
    }

    // Returns the height of lineno
    subscript(lineno: Int) -> CGFloat {
        get {
            let i = Index(offsetBy: lineno, in: self)
            let (leaf, offset) = i.read()!
            precondition(offset < leaf.count, "lineno out of bounds")

            return leaf.heights[offset]
        }
        set {
            var b = Builder()
            b.push(&root, slicedBy: 0..<lineno)
            b.push(heights: [newValue])
            b.push(&root, slicedBy: (lineno+1)..<root.count)

            self.root = b.build()
        }
    }
}

extension BTree {
    struct YOffsetMetric: BTreeMetric {
        func measure(summary: HeightsSummary, count: Int) -> CGFloat {
            summary.height
        }
        
        func convertToBaseUnits(_ measuredUnits: CGFloat, in leaf: HeightsLeaf) -> Int {
            var i = 0
            var remaining = measuredUnits

            while i < leaf.heights.count {
                let height = leaf.heights[i]
                if remaining < height {
                    break
                } 

                remaining -= height
                i += 1
            }

            return i
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            return leaf.heights[..<baseUnits].reduce(0, +)
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            return true
        }
        
        func prev(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            assert(offset > 0)
            return offset - 1
        }
        
        func next(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            assert(offset < leaf.heights.count)
            return offset + 1
        }

        var canFragment: Bool {
            false
        }

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<HeightsSummary> where Self == Heights.YOffsetMetric {
    static var yOffset: Heights.YOffsetMetric { Heights.YOffsetMetric() }
}


extension BTree {
    struct HeightsBaseMetric: BTreeMetric {
        func measure(summary: HeightsSummary, count: Int) -> Int {
            count
        }
        
        func convertToBaseUnits(_ measuredUnits: Int, in leaf: HeightsLeaf) -> Int {
            measuredUnits
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> Int {
            baseUnits
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            true
        }
        
        func prev(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            YOffsetMetric().prev(offset, in: leaf)
        }
        
        func next(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            YOffsetMetric().next(offset, in: leaf)
        }
        
        var canFragment: Bool {
            false
        }

        var type: BTreeMetricType {
            .trailing
        }
    }
}

extension BTreeMetric<HeightsSummary> where Self == Heights.HeightsBaseMetric {
    static var heightsBaseMetric: Heights.HeightsBaseMetric { Heights.HeightsBaseMetric() }
}

extension Heights.Builder {
    mutating func push(heights: [CGFloat]) {
        var i = 0

        while i < heights.endIndex {
            let n = min(heights[i...].count, HeightsLeaf.maxSize)
            push(leaf: HeightsLeaf(heights: Array(heights[i..<(i+n)])))
            i += n
        }
    }
}
