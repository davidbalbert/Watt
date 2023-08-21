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
    var endsWithBlankLine: Bool

    static func += (left: inout HeightsSummary, right: HeightsSummary) {
        left.height += right.height
        left.endsWithBlankLine = left.endsWithBlankLine || right.endsWithBlankLine
    }

    static var zero: HeightsSummary {
        HeightsSummary()
    }

    init() {
        self.height = 0
        self.endsWithBlankLine = false
    }

    init(summarizing leaf: HeightsLeaf) {
        self.height = leaf.heights.last!
        self.endsWithBlankLine = leaf.endsWithBlankLine
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

    var endsWithBlankLine: Bool {
        lineLength(atIndex: positions.count - 1) == 0
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

        // May temporarily create an invalid empty leaf if positions == [0].
        if endsWithBlankLine {
            positions.removeLast()
            heights.removeLast()
        }

        // If we created an invalid leaf above, just use other.
        if positions.isEmpty {
            self = other
            return nil
        }

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

        if endsWithBlankLine && end == positions.count - 1 {
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
            return HeightsLeaf(positions: [0], heights: [lineHeight(atIndex: i)])
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

    func lineHeight(atIndex i: Int) -> CGFloat {
        i == 0 ? heights[0] : heights[i] - heights[i-1]
    }

    func lineLength(atIndex i: Int) -> Int {
        i == 0 ? positions[0] : positions[i] - positions[i-1]
    }

    func offset(ofLine i: Int) -> Int {
        i == 0 ? 0 : positions[i-1]
    }

    func height(ofLine i: Int) -> CGFloat {
        i == 0 ? 0 : heights[i-1]
    }
}

extension Heights.Index {
    func readLeafIndex() -> (HeightsLeaf, Int)? {
        guard let (leaf, offset) = read() else {
            return nil
        }

        // We're addressing an empty line at the end of the
        // rope. In that case, just return the index of
        // the last element.
        if leaf.endsWithBlankLine && offset == leaf.positions.last! {
            return (leaf, leaf.positions.count - 1)
        }

        let (i, found) = leaf.positions.binarySearch(for: offset)
        // Because leaf stores line lengths, the index of a line
        // starting at positions[n] will be n+1.
        if found {
            return (leaf, i+1)
        } else {
            // offset == 0 is a boundary even though positions
            // usually doesn't contain 0, so we have to handle
            // this case.
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

    init() {
        var b = HeightsBuilder()
        b.addLine(withBaseCount: 0, height: 14)
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

            // readLeafIndex can return li == leaf.heights.count if
            // i.offsetInLeaf == leaf.positions.last. The only time
            // this is valid is if we're addressing an empty line
            // at the end of the string, but we handle that in
            // readLeafIndex by returning leaf.heights.count - 1.
            precondition(li < leaf.heights.count, "not a boundary")

            return li == 0 ? leaf.heights[0] : leaf.heights[li] - leaf.heights[li-1]
        }
        // TODO: this would be much simpler if we had a technique for replacing a known number
        // of values that already exist in the underlying tree.
        //
        // N.b. if we do something like that, we have to update all the trailing heights in
        // the leaf as well.
        set {
            i.validate(for: root)
            precondition(i.position <= measure(using: .heightsBaseMetric), "index out of bounds")
            precondition(i.isBoundary(in: .heightsBaseMetric), "not a boundary")

            let (leaf, li) = i.readLeafIndex()!

            // See comment in get
            precondition(li < leaf.heights.count, "not a boundary")

            let count = leaf.lineLength(atIndex: li)

            let prefixEnd: Int
            let suffixStart: Int
            let newLeaf: HeightsLeaf

            if count == 0 && li == 0 {
                // Updating a zero length line that's the only line in the leaf.
                assert(i.offsetOfLeaf + leaf.count == root.count)

                prefixEnd = i.offsetOfLeaf
                suffixStart = leaf.positions.last!
                newLeaf = HeightsLeaf(positions: [0], heights: [newValue])
            } else if count == 0 && li == 1 {
                // Updating a zero length line that's the second line in the leaf
                assert(i.offsetOfLeaf + leaf.count == root.count)

                prefixEnd = i.offsetOfLeaf
                suffixStart = leaf.positions.last!

                assert(leaf.positions[0] == leaf.positions[1])
                let pos = leaf.positions[0]

                newLeaf = HeightsLeaf(positions: [pos, pos], heights: [leaf.heights[0], leaf.heights[0] + newValue])
            } else if count == 0 {
                // Updating a zero length line later in the leaf – it's by definition the last line.
                assert(i.offsetOfLeaf + leaf.count == root.count)

                prefixEnd = i.offsetOfLeaf + leaf.positions[leaf.positions.count - 3]
                suffixStart = leaf.positions.last!

                assert(leaf.positions[leaf.positions.count - 2] == leaf.positions[leaf.positions.count - 1])

                let pos = leaf.lineLength(atIndex: leaf.positions.count - 2)
                let penultimateHeight = leaf.lineHeight(atIndex: leaf.heights.count - 2)

                newLeaf = HeightsLeaf(positions: [pos, pos], heights: [penultimateHeight, penultimateHeight + newValue])
            } else {
                // Updating a line with length > 0
                prefixEnd = li == 0 ? i.offsetOfLeaf : i.offsetOfLeaf + leaf.positions[li - 1]
                suffixStart = li == leaf.positions.count ? root.count : i.offsetOfLeaf + leaf.positions[li]
                newLeaf = HeightsLeaf(positions: [count], heights: [newValue])
            }

            var b = Builder()

            b.push(&root, slicedBy: 0..<prefixEnd)
            b.push(leaf: newLeaf)
            b.push(&root, slicedBy: suffixStart..<root.count)

            self.root = b.build()
        }
    }

    mutating func replaceSubrange(_ oldRange: Range<Int>, with rope: Rope) {
        let start: Int
        if oldRange.lowerBound == root.count && !root.summary.endsWithBlankLine {
            start = index(before: index(at: oldRange.lowerBound), using: .heightsBaseMetric).position
        } else {
            start = index(roundingDown: index(at: oldRange.lowerBound), using: .heightsBaseMetric).position
        }

        let end: Int
        if oldRange.upperBound == root.count {
            end = oldRange.upperBound
        } else {
            end = index(after: index(at: oldRange.upperBound), using: .heightsBaseMetric).position
        }

        let prefixCount = oldRange.lowerBound - start
        let suffixCount = end - oldRange.upperBound

        var hb = HeightsBuilder()

        // - make a new height builder
        // - iterate over the lengths of each line in the string, calling addLine on the height builder
        // - if we're on the first line, add prefixCount to the length of the first line
        // - if we're on the last line, add suffixCount to the length of the last line
        // - remember that the first line can also be the last line

        var i = rope.startIndex
        var lineLength = 0
        var lineCount = 0

        let endIndex = rope.endIndex
        let last = rope.isEmpty ? rope.startIndex : rope.utf8.index(before: endIndex)

        while i < endIndex {
            let c = rope.utf8[i]
            if c == UInt8(ascii: "\n") || i == last {
                lineLength += 1

                if lineCount == 0 {
                    lineLength += prefixCount
                }

                if lineCount == rope.lines.count - 1 {
                    assert(!(c == UInt8(ascii: "\n") && i == last))
                    lineLength += suffixCount
                }

                hb.addLine(withBaseCount: lineLength, height: 14)

                if c == UInt8(ascii: "\n") && i == last {
                    // String ends with a newline. We need to add one more line to cover
                    // the suffix. If suffixCount == 0, this will be an empty line.
                    hb.addLine(withBaseCount: suffixCount, height: 14)
                } else if lineCount == rope.lines.count - 1 && suffixCount > 0 && end == root.count && root.summary.endsWithBlankLine {
                    // If we're on the last line of string, and we're replacing a portion, but
                    // not all of the last line of the rope, and the rope ends in an empty line,
                    // make sure to include the empty line.
                    hb.addLine(withBaseCount: 0, height: 14)
                }

                lineLength = 0
                lineCount += 1
            } else {
                lineLength += 1
            }

            i = rope.utf8.index(after: i)
        }

        var b = Heights.Builder()
        var r = root
        b.push(&r, slicedBy: 0..<start)
        var new = hb.build()
        b.push(&new)
        b.push(&r, slicedBy: end..<r.count)

        root = b.build()
    }

    func yOffset(upThroughPosition offset: Int) -> CGFloat {
        if offset >= root.count {
            let i = endIndex
            let (leaf, _) = i.read()!
            let height = leaf.lineHeight(atIndex: leaf.heights.count - 1)

            return root.measure(using: .yOffset) - height
        }

        return count(.yOffset, upThrough: offset)
    }

    func position(upThroughYOffset yOffset: CGFloat) -> Int {
        if yOffset >= root.measure(using: .yOffset) {
            let i = endIndex
            let (leaf, _) = i.read()!
            let lineLength = leaf.lineLength(atIndex: leaf.positions.count - 1)

            return root.count - lineLength
        }

        return countBaseUnits(of: yOffset, measuredIn: .yOffset)
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
            // binarySearch(for:) will return (i, true) for all boundaries other than
            // 0. Specifically for [3, 6], search(3) will return (0, true),
            // search(6) will return (1, true), but search(0) will return
            // (0, false). This means we can't use found alone as a measure
            // of whether we're at a boundary.
            if offset == 0 {
                return true
            }

            // The end of the leaf is only a valid boundary if the leaf ends with
            // an empty line. E.g. in [3, 6], 0 and 3 are valid boundaries, but in
            // [3, 6, 6], 0, 3, and 6 are all valid boundaries.
            if offset == leaf.count {
                return leaf.endsWithBlankLine
            }

            let (_, found) = leaf.positions.binarySearch(for: offset)
            return found
        }

        func prev(_ offset: Int, in leaf: HeightsLeaf, prevLeaf: HeightsLeaf?) -> Int? {
            assert(offset > 0 && offset <= leaf.count)

            // Handle special cases where leaf ends in a blank line.
            //
            // Note: we don't handle offset == leaf.count where positions.count == 1,
            // because that would imply positions == [0], implying leaf.count 0,
            // and thus, offset == 0, and offset is not allowed to be 0.
            if offset == leaf.count && leaf.endsWithBlankLine && leaf.positions.count == 2 {
                return 0
            } else if offset == leaf.count && leaf.endsWithBlankLine {
                return leaf.positions[leaf.positions.count - 3]
            }

            for i in 0..<leaf.positions.count {
                if offset <= leaf.positions[i] {
                    if i == 0 {
                        return nil
                    } else {
                        return leaf.positions[i-1]
                    }
                }
            }

            fatalError("this is unreachable, offset must be <= leaf.count")
        }

        func next(_ offset: Int, in leaf: HeightsLeaf, nextLeaf: HeightsLeaf?) -> Int? {
            assert(offset >= 0 && offset < leaf.count)

            // situations:
            //   endsWithBlankLine
            //     offset == 0, positions == [0] – Impossible. Leaf.count would be 0.
            //     positions == [n, n], offset < n – returns n
            //     positions == [..., x, n, n], offset in x..<n – returns n.
            //   else
            //     let (i, found) = binarySearch(offset)
            //     found ? positions[i+1] : positions[i]

            if leaf.endsWithBlankLine {
                if leaf.positions.count == 2 {
                    return leaf.positions[0]
                } else if leaf.positions[leaf.positions.count - 3] <= offset && offset < leaf.positions[leaf.positions.count - 2] {
                    return leaf.positions[leaf.positions.count - 2]
                }
            }

            // binarySearch(for:) doesn't work if we're searching for repeated elements,
            // but we know offset < leaf.count, and the only repeated elements will be
            // leaf.count, so we're ok.
            let n: Int
            switch leaf.positions.binarySearch(for: offset) {
            case let (i, true):
                n = i + 1
            case let (i, false):
                n = i
            }

            // At this we know offset < leaf.count, so we're not looking at
            // a trailing blank line, which means the length of the leaf
            // is never a boundary.
            if n == leaf.positions.count - 1 {
                return nil
            }

            return leaf.positions[n]
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
                return leaf.positions.last!
            }

            var (i, found) = leaf.heights.binarySearch(for: measuredUnits)
            if found {
                i += 1
            }
            return leaf.offset(ofLine: i)
        }

        func convertFromBaseUnits(_ baseUnits: Int, in leaf: HeightsLeaf) -> CGFloat {
            if baseUnits >= leaf.count {
                return leaf.heights.last!
            }

            var (i, found) = leaf.positions.binarySearch(for: baseUnits)
            if found {
                i += 1
            }
            return leaf.height(ofLine: i)
        }
        
        func isBoundary(_ offset: Int, in leaf: HeightsLeaf) -> Bool {
            HeightsBaseMetric().isBoundary(offset, in: leaf)
        }
        
        func prev(_ offset: Int, in leaf: HeightsLeaf, prevLeaf: HeightsLeaf?) -> Int? {
            HeightsBaseMetric().prev(offset, in: leaf, prevLeaf: prevLeaf)
        }
        
        func next(_ offset: Int, in leaf: HeightsLeaf, nextLeaf: HeightsLeaf?) -> Int? {
            HeightsBaseMetric().next(offset, in: leaf, nextLeaf: nextLeaf)
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

fileprivate func countNewlines(in buf: UnsafeBufferPointer<UInt8>) -> Int {
    let nl = UInt8(ascii: "\n")
    var count = 0

    for b in buf {
        if b == nl {
            count += 1
        }
    }

    return count
}
