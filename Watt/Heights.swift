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
        self.height = leaf.heights.last!
    }
}

extension HeightsSummary: BTreeDefaultMetric {
    static var defaultMetric: Heights.HeightsBaseMetric { Heights.HeightsBaseMetric() }
}

struct HeightsLeaf: BTreeLeaf, Equatable {
    static let minSize = 32
    static let maxSize = 64

    var count: Int {
        positions.last ?? 0
    }

    // Positions contains the length of each line in the
    // associated rope, measured in UTF-8 code units from the
    // start of the string. Heights contains the height of
    // each line.
    //
    // Invariant: positions.count == heights.count.
    //
    // An HeightsLeaf where positions.count == 0 is invalid.
    // An empty string has a single line of length 0, with an
    // associated height.
    //
    // There are two situations in which you can have a line of
    // length 0:
    //
    // - The empty string
    // - When the string ends with a "\n".
    //
    // Otherwise, all lines, even empty ones, have length >= 1,
    // because the length of an empty line that's not at the end
    // of the document includes the "\n".
    var positions: [Int]
    var heights: [CGFloat]

    static var zero: HeightsLeaf {
        HeightsLeaf()
    }

    var isUndersized: Bool {
        positions.count < HeightsLeaf.minSize
    }

    init() {
        self.positions = []
        self.heights = []
    }

    init(positions: [Int], heights: [CGFloat]) {
        assert(positions.count == heights.count)
        assert(heights.allSatisfy { $0 > 0 })
        self.positions = positions
        self.heights = heights
    }

    mutating func pushMaybeSplitting(other: HeightsLeaf) -> HeightsLeaf? {
        assert(positions.count == heights.count)

        let end = count
        for p in other.positions {
            positions.append(end + p)
        }

        // heights is never empty
        let height = heights.last!

        // The current height of self will be the first
        // y-offset of the combined leaf.
        for y in other.heights {
            heights.append(height + y)
        }

        assert(positions.count == heights.count)

        if positions.count < HeightsLeaf.maxSize {
            return nil
        } else {
            let splitIndex = positions.count / 2
            let leftCount = positions[splitIndex-1]
            let leftHeight = heights[splitIndex-1]

            var rightPositions = Array(positions[splitIndex...])
            for i in 0..<rightPositions.count {
                rightPositions[i] -= leftCount
            }

            var rightHeights = Array(heights[splitIndex...])
            for i in 0..<rightHeights.count {
                rightHeights[i] -= leftHeight
            }

            assert(rightPositions.count == rightHeights.count)

            positions.removeLast(rightPositions.count)
            heights.removeLast(rightHeights.count) // make sure to leave the height on the end

            assert(positions.count == heights.count)
            return HeightsLeaf(positions: rightPositions, heights: rightHeights)
        }
    }

    // When slicing to low..<high, we slice from (low+1)..<(high+1). This is because
    // the values stored in positions are line lengths, i.e. one more than the last
    // position in the line. Therefore, if the first line length is 5, and we slice from
    // 5..<10, we want to drop the first 5 characters, aka positions[0]. But if we were
    // to include low (5), we'd include position[0] because its value is 5. The same
    // logic applies to the upper bounds.
    subscript(bounds: Range<Int>) -> HeightsLeaf {
        assert(bounds.lowerBound <= count && bounds.upperBound <= count)

        if positions == [0] {
            assert(bounds == 0..<0)
            return self
        }

        let (start, _) = positions.binarySearch(for: bounds.lowerBound + 1)
        var (end, _) = positions.binarySearch(for: bounds.upperBound + 1)

        let emptyLastLine = positions.last! == positions.dropLast().last!
        if emptyLastLine && end == positions.count - 1 {
            end += 1
        }

        let prefixCount = start == 0 ? 0 : positions[start-1]
        let prefixHeight = start == 0 ? 0 : heights[start-1]

        if (start..<end).isEmpty {
            // if we're slicing an empty range at the end
            // of the rope, e.g. self.count..<self.count,
            // we want the line height to be the height of
            // the last line.
            let i = min(start, heights.count - 1)
            let lineHeight = i == 0 ? heights[0] : heights[i] - heights[i-1]
            return HeightsLeaf(positions: [0], heights: [lineHeight])
        }

        var newPositions = Array(positions[start..<end])
        for i in 0..<newPositions.count {
            newPositions[i] -= prefixCount
        }

        var newYOffsets = Array(heights[start..<end])
        for i in 0..<newYOffsets.count {
            newYOffsets[i] -= prefixHeight
        }

        return HeightsLeaf(positions: newPositions, heights: newYOffsets)
    }
}

extension Heights.Index {
    func readLeafIndex() -> (HeightsLeaf, Int)? {
        guard let (leaf, offset) = read() else {
            return nil
        }

        // End of rope, return the height of the
        // last line.
//        if offsetOfLeaf + offset == root!.count {
//            return (leaf, leaf.positions.count - 1)
//        }

        let (i, found) = leaf.positions.binarySearch(for: offset)
        if found {
            return (leaf, i+1)
        } else {
            return (leaf, i)
        }
    }
}

extension Heights {
    init(rope: Rope) {
        var b = HeightsBuilder()

        for l in rope.lines {
            // TODO: better estimate
            b.addLine(withBaseCount: l.utf8.count, height: 14)
        }

        self.init(b.build())
    }

    var contentHeight: CGFloat {
        measure(using: .yOffset)
    }

    subscript(position: Int) -> CGFloat {
        get {
            self[index(at: position)]
        }
        set {
            self[index(at: position)] = newValue
        }
    }

    // Returns the height of the line containing position.
    subscript(i: Index) -> CGFloat {
        get {
            i.validate(for: root)
            precondition(i.position <= measure(using: .heightsBaseMetric), "index out of bounds")
            precondition(i.isBoundary(in: .heightsBaseMetric), "not a boundary")

            let (leaf, li) = i.readLeafIndex()!
            // The end of the string is a valid boundary, but it's only
            // a valid position if the string ends with a blank line (i.e.
            // the end of the string is also the beginning of a line).
            precondition(li < leaf.heights.count, "not a boundary")

            return li == 0 ? leaf.heights[0] : leaf.heights[li] - leaf.heights[li-1]
        }
        set {
            i.validate(for: root)
            precondition(i.position <= measure(using: .heightsBaseMetric), "index out of bounds")
            precondition(i.isBoundary(in: .heightsBaseMetric), "not a boundary")

            let (leaf, li) = i.readLeafIndex()!
            // See comment in get.
            precondition(li < leaf.heights.count, "not a boundary")

            let count = li == 0 ? leaf.positions[0] : leaf.positions[li] - leaf.positions[li - 1]

            let newLeaf = HeightsLeaf(positions: [count], heights: [newValue])

            var b = Builder()

            let prefixEnd = li == 0 ? i.offsetOfLeaf : i.offsetOfLeaf + leaf.positions[li - 1]
            let suffixStart = li == leaf.positions.count ? root.count : i.offsetOfLeaf + leaf.positions[li]

            b.push(&root, slicedBy: 0..<prefixEnd)
            b.push(leaf: newLeaf)
            b.push(&root, slicedBy: suffixStart..<root.count)

            self.root = b.build()
        }
    }

    // Returns an index at a base offset
    func index(at offset: Int) -> Index {
        index(at: offset, using: .heightsBaseMetric)
    }
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
            let (_, found) = leaf.positions.binarySearch(for: offset)
            return found
        }

        func prev(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            assert(offset > 0 && offset <= leaf.count)

            let (i, _) = leaf.positions.binarySearch(for: offset)
            return i == 0 ? 0 : leaf.positions[i-1]
        }

        func next(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            assert(offset < leaf.count)

            switch leaf.positions.binarySearch(for: offset) {
            case let (i, found: true):
                return leaf.positions[i+1]
            case let (i, found: false):
                return leaf.positions[i]
            }
        }

        var canFragment: Bool {
            false
        }

        // Even though this looks a lot like the Rope's base metric, and
        // in fact the units are the same (bytes), there exist (many) strings
        // when put into Heights where you can find a non-empty string for
        // which HeightsLeaf has a measure of 0, so the measure is non-atomic.
        // E.g. if the first line is "abc", positions 0, 1, and 2 will all
        // have a measure of zero.
        //
        // This is not the clearest explanation :/.
        var type: BTreeMetricType {
            .trailing
        }
    }
}

extension BTreeMetric<HeightsSummary> where Self == Heights.HeightsBaseMetric {
    static var heightsBaseMetric: Heights.HeightsBaseMetric { Heights.HeightsBaseMetric() }
}

extension BTree {
    struct YOffsetMetric: BTreeMetric {
        func measure(summary: HeightsSummary, count: Int) -> CGFloat {
            summary.height
        }
        
        func convertToBaseUnits(_ measuredUnits: CGFloat, in leaf: HeightsLeaf) -> Int {
            if measuredUnits >= leaf.heights.last! {
                return leaf.positions.dropLast().last ?? 0
            }

            var (i, found) = leaf.heights.binarySearch(for: measuredUnits)
            if found {
                i += 1
            }
            return i == 0 ? 0 : leaf.positions[i-1]
        }

        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            if baseUnits >= leaf.count {
                return leaf.heights.dropLast().last ?? 0
            }

            var (i, found) = leaf.positions.binarySearch(for: baseUnits)
            if found {
                i += 1
            }
            return i == 0 ? 0 : leaf.heights[i - 1]
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            HeightsBaseMetric().isBoundary(offset, in: leaf)
        }
        
        func prev(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            HeightsBaseMetric().prev(offset, in: leaf)
        }
        
        func next(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            HeightsBaseMetric().next(offset, in: leaf)
        }

        var canFragment: Bool {
            false
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
    struct HeightMetric: BTreeMetric {
        func measure(summary: HeightsSummary, count: Int) -> CGFloat {
            summary.height
        }
        
        func convertToBaseUnits(_ measuredUnits: CGFloat, in leaf: HeightsLeaf) -> Int {
            if measuredUnits < 0 {
                return 0
            }

            if measuredUnits > leaf.heights.last! {
                return leaf.count
            }

            let (i, _) = leaf.heights.binarySearch(for: measuredUnits)
            return leaf.positions[i]
        }

        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            // TODO: I think this is wrong, though I think the real issue is that the whole Heights metric is wrong.
            if baseUnits >= leaf.count {
                return leaf.heights.last!
            }

            var (i, found) = leaf.positions.binarySearch(for: baseUnits)
            if found {
                i += 1
            }
            return leaf.heights[i]
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            HeightsBaseMetric().isBoundary(offset, in: leaf)
        }

        func prev(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            HeightsBaseMetric().prev(offset, in: leaf)
        }

        func next(_ offset: Int, in leaf: HeightsLeaf) -> Int? {
            HeightsBaseMetric().next(offset, in: leaf)
        }

        var canFragment: Bool {
            false
        }

        var type: BTreeMetricType {
            .trailing
        }
    }
}

extension BTreeMetric<HeightsSummary> where Self == Heights.YOffsetMetric {
    static var height: Heights.HeightMetric { Heights.HeightMetric() }
}

struct HeightsBuilder {
    var b: BTree<HeightsSummary>.Builder
    var leaf: HeightsLeaf

    init() {
        b = BTree<HeightsSummary>.Builder()
        leaf = HeightsLeaf()
    }

    mutating func addLine(withBaseCount count: Int, height: CGFloat) {
        if leaf.positions.count == HeightsLeaf.maxSize {
            b.push(leaf: leaf)
            leaf = HeightsLeaf()
        }

        leaf.positions.append(leaf.count + count)
        leaf.heights.append((leaf.heights.last ?? 0) + height)
    }

    consuming func build() -> BTree<HeightsSummary>.Node {
        if leaf.positions.count > 0 {
            b.push(leaf: leaf)
        }

        let node = b.build()
        assert(node.height > 0 || node.leaf.positions.count > 0)
        return node
    }
}
