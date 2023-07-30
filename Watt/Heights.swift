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
        self.height = leaf.yOffsets.last!
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

    // Positions contains the index following each "\n" in the
    // associated rope, measured in UTF-8 code units from the
    // start of the string. YOffsets contains the y-offset of
    // each line.
    //
    // Invariant: positions.count == yOffsets.count - 1.
    //
    // This is because yOffsets contains the the y-offset after
    // the final line, which is the same as the height of the
    // entire leaf.
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
    // Otherwise, all lines, even empty ones, have length 1, because
    // the length of an empty line that's not at the end of the
    // document includes the "\n".
    var positions: [Int]
    var yOffsets: [CGFloat]

    static var zero: HeightsLeaf {
        HeightsLeaf()
    }

    var isUndersized: Bool {
        positions.count < HeightsLeaf.minSize
    }

    init() {
        self.positions = []
        self.yOffsets = [0]
    }

    init(positions: [Int], yOffsets: [CGFloat]) {
        assert(positions.count == yOffsets.count - 1)
        self.positions = positions
        self.yOffsets = yOffsets
    }

    mutating func pushMaybeSplitting(other: HeightsLeaf) -> HeightsLeaf? {
        assert(positions.count == yOffsets.count - 1)

        let end = count
        for p in other.positions {
            positions.append(end + p)
        }

        // yOffsets is never empty
        let height = yOffsets.last!

        // The current height of self will be the first
        // y-offset of the combined leaf.
        for y in other.yOffsets.dropFirst() {
            yOffsets.append(height + y)
        }

        assert(positions.count == yOffsets.count - 1)

        if positions.count < HeightsLeaf.maxSize {
            return nil
        } else {
            let splitIndex = positions.count / 2
            let leftCount = positions[splitIndex-1]
            let leftHeight = yOffsets[splitIndex]

            var rightPositions = Array(positions[splitIndex...])
            for i in 0..<rightPositions.count {
                rightPositions[i] -= leftCount
            }

            var rightYOffsets = Array(yOffsets[splitIndex...])
            for i in 0..<rightYOffsets.count {
                rightYOffsets[i] -= leftHeight
            }

            assert(rightPositions.count == rightYOffsets.count - 1)

            positions.removeLast(rightPositions.count)
            yOffsets.removeLast(rightYOffsets.count - 1) // make sure to leave the height on the end

            assert(positions.count == yOffsets.count - 1)
            return HeightsLeaf(positions: rightPositions, yOffsets: rightYOffsets)
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
        let prefixHeight = yOffsets[start]

        if (start..<end).isEmpty {
            let i = min(start, positions.count - 1)
            return HeightsLeaf(positions: [0], yOffsets: [0, yOffsets[i+1] - yOffsets[i]])
        }

        var newPositions = Array(positions[start..<end])
        for i in 0..<newPositions.count {
            newPositions[i] -= prefixCount
        }

        var newYOffsets = Array(yOffsets[start..<(end+1)])
        for i in 0..<newYOffsets.count {
            newYOffsets[i] -= prefixHeight
        }

        return HeightsLeaf(positions: newPositions, yOffsets: newYOffsets)
    }
}

extension Heights.Index {
    func readLeafIndex() -> (HeightsLeaf, Int)? {
        guard let (leaf, offset) = read() else {
            return nil
        }

        if offsetOfLeaf + offset == root!.count {
            return (leaf, leaf.positions.count - 1)
        }

        let (i, found) = leaf.positions.binarySearch(for: offset)
        if found {
            return (leaf, i+1)
        } else {
            return (leaf, i)
        }
    }

    func readHeight() -> CGFloat? {
        guard let (leaf, i) = readLeafIndex() else {
            return nil
        }
        return leaf.yOffsets[i+1] - leaf.yOffsets[i]
    }
}

extension Heights {
    init(rope: Rope) {
        var b = HeightsBuilder()

        for l in rope.lines {
            b.addLine(withBaseCount: l.utf8.count, height: 14)
        }

        self.init(b.build())
    }

    var contentHeight: CGFloat {
        measure(using: .height)
    }

    // Returns the height of the line containing position.
    subscript(i: Index) -> CGFloat {
        get {
            i.validate(for: root)
            precondition(i.position <= measure(using: .heightsBaseMetric), "index out of bounds")

            return i.readHeight()!
        }
        set {
            i.validate(for: root)
            precondition(i.position <= measure(using: .heightsBaseMetric), "index out of bounds")
            precondition(i.isBoundary(in: .heightsBaseMetric), "not a boundary")

            let (leaf, li) = i.readLeafIndex()!
            let count = li == 0 ? leaf.positions[0] : leaf.positions[li] - leaf.positions[li - 1]

            let newLeaf = HeightsLeaf(positions: [count], yOffsets: [0, newValue])

            var b = Builder()

            let prefixEnd = li == 0 ? i.offsetOfLeaf : i.offsetOfLeaf + leaf.positions[li - 1]
            let suffixStart = li == leaf.positions.count ? root.count : i.offsetOfLeaf + leaf.positions[li]

            b.push(&root, slicedBy: 0..<(prefixEnd))
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
    struct YOffsetMetric: BTreeMetric {
        func measure(summary: HeightsSummary, count: Int) -> CGFloat {
            summary.height
        }
        
        func convertToBaseUnits(_ measuredUnits: CGFloat, in leaf: HeightsLeaf) -> Int {
            if measuredUnits <= 0 {
                return 0
            }

            if measuredUnits >= leaf.yOffsets.dropLast().last! {
                return leaf.count
            }

            var (i, found) = leaf.yOffsets.dropLast().binarySearch(for: measuredUnits)
            if !found {
                i -= 1
            }

            return i == 0 ? 0 : leaf.positions[i-1]
        }

        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            if baseUnits >= leaf.count {
                // Asking for anything >= rope.endIndex should give us
                // the y-offset of the final line.
                return leaf.yOffsets.dropLast().last!
            }

            switch leaf.positions.binarySearch(for: baseUnits) {
            case let (i, found: true):
                return leaf.yOffsets[i+1]
            case let (i, found: false):
                return leaf.yOffsets[i]
            }
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
            if measuredUnits <= 0 {
                return 0
            }

            if measuredUnits > leaf.yOffsets.last! {
                return leaf.count
            }

            // TODO: I think this special case for 0 can be removed once we
            // switch to positions.count == heights.count
            var (i, _) = leaf.yOffsets.binarySearch(for: measuredUnits)
            return i == 1 ? 0 : leaf.positions[i-2]
        }

        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            if baseUnits >= leaf.positions.dropLast().last ?? 0 {
                return leaf.yOffsets.last!
            }

            switch leaf.positions.dropLast().binarySearch(for: baseUnits) {
            case let (i, found: true):
                return leaf.yOffsets[i+2]
            case let (i, found: false):
                return leaf.yOffsets[i+1]
            }
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            YOffsetMetric().isBoundary(offset, in: leaf)
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

extension BTreeMetric<HeightsSummary> where Self == Heights.YOffsetMetric {
    static var height: Heights.HeightMetric { Heights.HeightMetric() }
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
            YOffsetMetric().isBoundary(offset, in: leaf)
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

    mutating func addLine(withBaseCount count: Int, height: CGFloat) {
        if leaf.positions.count == HeightsLeaf.maxSize {
            b.push(leaf: leaf)
            leaf = HeightsLeaf()
        }

        leaf.positions.append(leaf.count + count)
        leaf.yOffsets.append(leaf.yOffsets.last! + height)
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
