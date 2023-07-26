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
    static let minSize = 32
    static let maxSize = 64

    var count: Int

    // Offsets contains the start of each line, measured in
    // UTF-8 code units from the start of the leaf. Heights
    // contains the height of the line starting at each offset.
    //
    // Invariants:
    // - offsets.count == heights.count
    // - if the leaf isn't empty, offsets[0] == 0
    var offsets: [Int]
    var heights: [CGFloat]

    static var zero: HeightsLeaf {
        HeightsLeaf()
    }

    var isUndersized: Bool {
        heights.count < HeightsLeaf.minSize
    }

    init() {
        self.count = 0
        self.offsets = []
        self.heights = []
    }

    init(count: Int, offsets: [Int], heights: [CGFloat]) {
        assert(offsets.count == heights.count)
        self.count = count
        self.offsets = offsets
        self.heights = heights
    }

    mutating func pushMaybeSplitting(other: HeightsLeaf) -> HeightsLeaf? {
        for o in other.offsets {
            offsets.append(count + o)
        }
        heights.append(contentsOf: other.heights)
        count += other.count

        assert(offsets.count == heights.count)

        if offsets.count < HeightsLeaf.maxSize {
            return nil
        } else {
            let splitIndex = offsets.count / 2
            let splitOffset = offsets[splitIndex]

            var rightOffsets = Array(offsets[splitIndex...])
            for i in 0..<rightOffsets.count {
                rightOffsets[i] -= splitOffset
            }
            let rightHeights = Array(heights[splitIndex...])

            assert(rightOffsets.count == rightHeights.count)

            let rightCount = count - splitOffset
            count = splitOffset
            offsets.removeLast(rightOffsets.count)
            heights.removeLast(rightOffsets.count)

            return HeightsLeaf(count: rightCount, offsets: rightOffsets, heights: rightHeights)
        }
    }
    
    subscript(bounds: Range<Int>) -> HeightsLeaf {
        let (start, _) = offsets.binarySearch(for: bounds.lowerBound)
        let (end, _) = offsets.binarySearch(for: bounds.upperBound)

        let range = start..<end

        let startOffset = start == offsets.count ? count : offsets[start]
        let endOffset = end == offsets.count ? count : offsets[end]

        var newOffsets = Array(offsets[range])
        for i in 0..<newOffsets.count {
            newOffsets[i] -= startOffset
        }

        return HeightsLeaf(count: endOffset - startOffset, offsets: newOffsets, heights: Array(heights[range]))
    }
}

extension Heights {
    init(rope: Rope) {
        var b = HeightsBuilder()

        if rope.startIndex == rope.endIndex {
            b.push(height: 14, count: 0)
        } else {
            var i = rope.startIndex

            repeat {
                let next = rope.lines.index(after: i)
                // TODO: maybe a method on BTree that gives you the base distance?
                b.push(height: 14, count: next.position - i.position)
                i = next
            } while i < rope.endIndex
        }

        self.init(b.build())
    }

    var contentHeight: CGFloat {
        measure(using: .yOffset)
    }

    func offset(for point: CGPoint) -> Int? {
        if point.y < 0 || point.y > measure(using: .yOffset) {
            return nil
        }

        return countBaseUnits(of: point.y, measuredIn: .yOffset)
    }

    // Returns the height of the line containing position.
    subscript(position: Int) -> CGFloat {
        get {
            // fail on endIndex.
            precondition(position < measure(using: .heightsBaseMetric), "index out of bounds")
            let i = Index(offsetBy: position, in: self)
            let (leaf, _) = i.read()!
            let (j, _) = leaf.offsets.binarySearch(for: position - i.offsetOfLeaf)
            return leaf.heights[j]
        }
        set {
            // fail on endIndex.
            precondition(position < measure(using: .heightsBaseMetric), "index out of bounds")

            let i = Index(offsetBy: position, in: self)
            let (leaf, _) = i.read()!

            let offset = position - i.offsetOfLeaf

            let (j, ok) = leaf.offsets.binarySearch(for: offset)

            if !ok {
                fatalError("you can only replace, not insert right now")
            }

            let count: Int
            if j == leaf.offsets.count - 1 {
                count = leaf.count - offset
            } else {
                count = leaf.offsets[j+1] - offset
            }

            let newLeaf = HeightsLeaf(count: count, offsets: [0], heights: [newValue])

            var b = Builder()
            b.push(&root, slicedBy: 0..<position)
            b.push(leaf: newLeaf)
            b.push(&root, slicedBy: (position+1)..<root.count)

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

            if i == leaf.heights.count {
                return leaf.count
            } else {
                return leaf.offsets[i]
            }
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            let (i, _) = leaf.offsets.binarySearch(for: baseUnits)
            return leaf.heights[..<i].reduce(0, +)
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            let (_, found) = leaf.offsets.binarySearch(for: offset)
            return found
        }
        
        func prev(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            assert(offset > 0)
            let (i, _) = leaf.offsets.binarySearch(for: offset)

            if i == 0 {
                return nil
            } else {
                return leaf.offsets[i-1]
            }
        }
        
        func next(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            assert(offset < leaf.heights.count)
            var (i, found) = leaf.offsets.binarySearch(for: offset)
            if found {
                i += 1
            }

            if i == leaf.offsets.count {
                return nil
            } else {
                return leaf.offsets[i]
            }
        }

        var canFragment: Bool {
            true
        }

        var type: BTreeMetricType {
            .trailing
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
            true
        }

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<HeightsSummary> where Self == Heights.HeightsBaseMetric {
    static var heightsBaseMetric: Heights.HeightsBaseMetric { Heights.HeightsBaseMetric() }
}

struct HeightsBuilder {
    var b: BTree<HeightsSummary>.Builder
    var leaf: HeightsLeaf

    init() {
        b = BTree<HeightsSummary>.Builder()
        leaf = HeightsLeaf()
    }

    mutating func push(height: CGFloat, count: Int) {
        if leaf.offsets.count == HeightsLeaf.maxSize {
            b.push(leaf: leaf)
            leaf = HeightsLeaf()
        }
        leaf.offsets.append(leaf.count)
        leaf.heights.append(height)
        leaf.count += count
    }

    consuming func build() -> BTree<HeightsSummary>.Node {
        b.push(leaf: leaf)
        return b.build()
    }
}
