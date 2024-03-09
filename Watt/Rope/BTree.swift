//
//  BTree.swift
//
//
//  Created by David Albert on 6/2/23.
//

import Foundation

// MARK: - Protocols

protocol BTree {
    associatedtype Summary: BTreeSummary

    var root: BTreeNode<Summary> { get set }

    init(_ root: BTreeNode<Summary>)
}

extension BTree {
    init(_ root: BTreeNode<Summary>, slicedBy range: Range<Int>) {
        assert(range.lowerBound >= 0 && range.upperBound <= root.count)

        // don't mutate root
        var r = root

        var b = BTreeBuilder<Self>()
        b.push(&r, slicedBy: range)
        self = b.build()
    }
}


protocol BTreeSummary {
    associatedtype Leaf: BTreeLeaf

    // A subset of AdditiveArithmetic
    static func += (lhs: inout Self, rhs: Self)
    static var zero: Self { get }

    init(summarizing leaf: Leaf)
}


protocol BTreeDefaultMetric: BTreeSummary {
    associatedtype DefaultMetric: BTreeMetric<Self> where DefaultMetric.Unit == Int

    static var defaultMetric: DefaultMetric { get }
}


protocol BTreeLeaf {
    static var zero: Self { get }

    // True if the state of a leaf depends on the state of the previous and/or
    // next leaves.
    static var needsFixupOnAppend: Bool { get }

    // Measured in base units
    var count: Int { get }
    var isUndersized: Bool { get }
    mutating func pushMaybeSplitting(other: Self) -> Self?

    // Returns true if we're in sync. Returns false if we need to continue fixing up.
    mutating func fixup(withNext next: inout Self) -> Bool

    // Specified in base units from the start of self. Should be O(1).
    subscript(bounds: Range<Int>) -> Self { get }
}

extension BTreeLeaf {
    static var needsFixupOnAppend: Bool {
        false
    }

    mutating func fixup(withNext next: inout Self) -> Bool {
        true
    }

    var isEmpty: Bool {
        count == 0
    }
}


enum BTreeMetricEdge {
    case leading
    case trailing
}

protocol BTreeMetric<Summary> {
    associatedtype Summary: BTreeSummary
    associatedtype Unit: Numeric & Comparable

    // To understand leading and trailing boundaries, consider a metric that counts
    // "\n" characters.
    //
    // The string "ab\ncd\nef" has a measure of 8 in the base metric (it contains 8
    // bytes) and a measure of 2 in the newlines metric (it contains 2 newlines).
    //
    // The newlines cover the ranges 2..<3 and 5..<6. This means there are leading
    // boundaries at 2 and 5, and trailing boundaries at 3 and 6.
    //
    // To get some intuition for how metrics work, start by drawing a number line in
    // the base metric of "ab\ncd\nef" and then superimpose the ranges of each "\n":
    //
    // 0 1 2 3 4 5 6 7 8
    //     |-    |-
    //
    // In the above diagram, each "|" represents a leading boundary, and the position
    // immediately after the last "-" in each range representes a trailing boundary.
    //
    // To count leading boundaries in convertToMeasuredUnits, imagine sliding a vertical
    // line across the number line from left to right until you reach baseUnits. Whenever
    // your vertical line intersects with a "|", increment your counter. For leading
    // edges, if there's a leading edge at baseUnits, you should count that too.
    //
    // Concretely, if baseUnits == 5, you'll count both leading edges and return 2.
    //
    // For trailing boundaries, do the same thing, but increment your counter at the
    // first index that's not contained within each range (i.e. the range's upperBound).
    // If baseUnits == 5, you'll count the first trailing boundary (at 3), but not the
    // second one (at 6) and return 1.
    //
    // Conceptually there's always an implicit trailing boundary at 0 and an implicit leading
    // boundary at count (8 in the above example), but these are never counted, so ignore them
    // in convertToBaseUnits and convertToMeasuredUnits. You should also ignore these implicit
    // boundaries in isBoundary, prev, and next. The BTree implementation will handle implict
    // boundaries for you.
    //
    // Intuitionally: even though "foo\nbar" has an implicit trailing newlines boundary at 0,
    // and an implicit leading boundary at 7, there's only 1 "\n", not 2, so the maximum
    // number of leading and trailing boundaries your metric should count is 1.
    //
    // Note that it's possible to have an explicit leading boundary at 0 or an explicit
    // trailing boundary at count – "\nfoo\n" has both of these. In these cases you should treat
    // these boundaries like any other. Note that it's impossible to have an explicit trailing
    // boundary at 0, or an explicit leading boundary at count.
    //
    // In the case of "\nfoo\n" where there's a leading boundary at 0, it's not possible for
    // convertToMeasuredUnits to return 0 when counting leading boundaries.
    //
    // For convertToBaseUnits, slide the vertical line from left to right until you've counted
    // measuredUnits worth of leading or trailing boundaries. Then return the index of that boundary
    // on the number line. E.g. in "ab\ncd\nef", convertToBaseUnits(1, measuredIn: .newlines, ege: .leading)
    // should return 2.
    //
    // The number line represents the count of trailing boundaries in the base metric. It's possible
    // to measure leading boundaries in the base metric as well. It would look like this:
    //
    // 0 1 2 3 4 5 6 7 8    <- base metric trailing boundaries – the canonical "number line"
    // 1 2 3 4 5 6 7 8      <- count of base metric leading boundaries
    // |-|-|-|-|-|-|-|-     <- ranges of each element in the base metric.
    //
    // Trailing boundaries in the base metric are special because they also represent valid indices in
    // the tree. convertToBaseUnits should always return the count of trailing boundaries,
    // and the baseUnits parameter in convertToMeasuredUnits should be treated as a count of trailing
    // base unit boundaries. Don't overthink this. Trailing boundaries in the base metric are just
    // 0-based indices into the tree.


    // Measure always counts trailing boundaries. For leaves, this is equivalent to
    // convertFromBaseUnits(count, in: leaf, .trailing), but measure(summary:count:) can be
    // used for internal nodes as well.
    func measure(summary: Summary, count: Int) -> Unit

    // Converts a count of leading or trailing edges in this metric, to trailing edges in the base metric.
    func convertToBaseUnits(_ measuredUnits: Unit, in leaf: Summary.Leaf, edge: BTreeMetricEdge) -> Int

    // Converts a count of trailing edges in the base metric to leading or trailing edges in this metric.
    func convertToMeasuredUnits(_ baseUnits: Int, in leaf: Summary.Leaf, edge: BTreeMetricEdge) -> Unit

    func isBoundary(_ offset: Int, in leaf: Summary.Leaf, edge: BTreeMetricEdge) -> Bool
    func prev(_ offset: Int, in leaf: Summary.Leaf, edge: BTreeMetricEdge) -> Int?
    func next(_ offset: Int, in leaf: Summary.Leaf, edge: BTreeMetricEdge) -> Int?

    // Can the measured unit in this metric can span multiple leaves.
    var canFragment: Bool { get }

    // A metric is atomic if the empty tree has a count of 0 and every
    // non-empty tree has a count > 0.
    var isAtomic: Bool { get }
}


// MARK: - Nodes

protocol BTreeNodeProtocol<Summary> {
    associatedtype Summary where Summary: BTreeSummary
    typealias Storage = BTreeNode<Summary>.Storage
    typealias Leaf = Summary.Leaf

    var storage: Storage { get set }
    mutating func isUnique() -> Bool
    mutating func ensureUnique()
}

extension BTreeNodeProtocol {
    var height: Int {
        storage.height
    }

    var isLeaf: Bool {
        height == 0
    }

    var count: Int {
        storage.count
    }

    var leafCount: Int {
        storage.leafCount
    }

    var isEmpty: Bool {
        count == 0
    }

    var children: [BTreeNode<Summary>] {
        _read {
            guard !isLeaf else { fatalError("children called on a leaf node") }
            yield storage.children
        }

        _modify {
            guard !isLeaf else { fatalError("children called on a leaf node") }
            yield &storage.children
        }
    }

    var leaf: Leaf {
        _read {
            guard isLeaf else { fatalError("leaf called on a non-leaf node") }
            yield storage.leaf
        }

        _modify {
            guard isLeaf else { fatalError("leaf called on a non-leaf node") }
            yield &storage.leaf
        }
    }

    var summary: Summary {
        storage.summary
    }

    var mutationCount: Int {
        storage.mutationCount
    }

#if DEBUG
    var copyCount: Int {
        storage.copyCount
    }
#endif

    var isUndersized: Bool {
        if isLeaf {
            return leaf.isUndersized
        } else {
            return children.count < BTreeNode<Summary>.minChild
        }
    }

    var startIndex: BTreeNode<Summary>.Index {
        BTreeNode<Summary>.Index(startOf: self)
    }

    var endIndex: BTreeNode<Summary>.Index {
        BTreeNode<Summary>.Index(endOf: self)
    }

    func index(at offset: Int) -> BTreeNode<Summary>.Index {
        BTreeNode<Summary>.Index(offsetBy: offset, in: self)
    }
}

struct BTreeNode<Summary>: BTreeNodeProtocol where Summary: BTreeSummary {
    static var minChild: Int { 4 }
    static var maxChild: Int { 8 }

    var storage: Storage

    mutating func isUnique() -> Bool {
        isKnownUniquelyReferenced(&storage)
    }

    mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
    }
}

extension BTreeNode {
    final class Storage {
        var height: Int
        var count: Int // in base units
        var leafCount: Int

        // TODO: maybe make these optional?
        // children and leaf are mutually exclusive
        var children: [BTreeNode]
        var leaf: Leaf
        var summary: Summary

        var mutationCount: Int = 0

#if DEBUG
        var copyCount: Int = 0
#endif

        convenience init() {
            self.init(leaf: Leaf.zero)
        }

        init(leaf: Leaf) {
            self.height = 0
            self.count = leaf.count
            self.leafCount = 1
            self.children = []
            self.leaf = leaf
            self.summary = Summary(summarizing: leaf)
        }

        init<S>(children: S) where S: Sequence<BTreeNode<Summary>> {
            let children = Array(children)

            assert(1 <= children.count && children.count <= BTreeNode<Summary>.maxChild)
            let height = children[0].height + 1
            var count = 0
            var leafCount = 0
            var summary = Summary.zero

            for child in children {
                assert(child.height + 1 == height)
                assert(!child.isUndersized)
                count += child.count
                leafCount += child.leafCount
                summary += child.summary
            }

            self.height = height
            self.count = count
            self.leafCount = leafCount
            self.children = children
            self.leaf = .zero
            self.summary = summary
        }

        init(copying storage: Storage) {
            self.height = storage.height
            self.mutationCount = storage.mutationCount
            self.count = storage.count
            self.leafCount = storage.leafCount
            self.children = storage.children
            self.leaf = storage.leaf
            self.summary = storage.summary

#if DEBUG
            self.copyCount = storage.copyCount + 1
#endif
        }

        func copy() -> Storage {
            // All properties are value types, so it's sufficient
            // to just create a new Storage instance.
            return Storage(copying: self)
        }
    }
}

extension BTreeNode {
    init() {
        self.init(storage: Storage())
    }

    init(leaf: Leaf) {
        self.init(storage: Storage(leaf: leaf))
    }

    init<S>(children: S) where S: Sequence<BTreeNode<Summary>> {
        self.init(storage: Storage(children: children))
    }

    fileprivate init<N>(_ n: N) where N: BTreeNodeProtocol<Summary> {
        self.init(storage: n.storage)
    }

    fileprivate init<N>(copying n: N) where N: BTreeNodeProtocol<Summary> {
        self.init(storage: n.storage.copy())
    }
}

extension BTreeNode: Equatable {
    static func == (lhs: BTreeNode<Summary>, rhs: BTreeNode<Summary>) -> Bool {
        lhs.storage === rhs.storage
    }
}


// MARK: - Metrics conversion

extension BTreeNode {
    func measure<M>(using metric: M) -> M.Unit where M: BTreeMetric<Summary> {
        metric.measure(summary: summary, count: count)
    }

    func convert<M1, M2>(_ m1: M1.Unit, from: M1, edge edge1: BTreeMetricEdge, to: M2, edge edge2: BTreeMetricEdge) -> M2.Unit where M1: BTreeMetric<Summary>, M2: BTreeMetric<Summary> {

        // startIndex on a leading edge can have a count of 0 or 1. startIndex on a trailing edge can only have a count of 0.
        //
        // In "\nbar", you can never have a count of .leading newlines == 0 because startIndex has a count of 1. But startIndex
        // in .trailing newlines has to be 0, because startIndex doesn't trail anything.
        //
        // In contrast, with "foo\nbar", .leading newlines is 0 for positions 0, 1, and 2, and only becomes 1 at position 3.
        //
        // All this to say, if we have a measure of 0, whether it's .leading or .trailing, if we're converting it to .trailing
        // we know it's going to be 0.
        if m1 == 0 && edge2 == .trailing {
            return 0
        }

        if type(of: from) == type(of: to) && edge1 == edge2 {
            // If both metrics are the same, don't do any conversion.
            // This makes distance(from:to:using:) O(1) for the
            // base metric.
            //
            // This assumes metrics don't have any state, so any instance
            // of the same metric will return the same values.
            return m1 as! M2.Unit
        }

        var m1 = m1
        var m2: M2.Unit = 0
        var node = self
        while !node.isLeaf {
            let parent = node
            for (i, child) in node.children.enumerated() {
                // If m1 is the boundary between two leaves (m1 == childM1) and it's a count of trailing
                // boundaries (edge1 == .trailing), we want to land at the start of the right leaf,
                // so we only descend if m1 < childM1. OTOH, if m1 is a count of leading boundaries,
                // we want to land at the end of the left leaf, so we descend if m1 <= childM1.
                //
                // There's one exception: m1 is the measure of `from` in the whole tree, we need to
                // allow ourselves to descend into the last child of each internal node, so we use
                // m1 <= childM1 in that case too.
                //
                // Xi has similar code – though just for optimizations and I'm not sure that it's
                // correct – but it uses a fudge of 0 or 1, and the condition `m1 < childM1 + fudge`.
                // This is simpler, but it doesn't work for us because HeightsMetric.Unit is CGFloat
                // and can have values in between childM1 and childM1 + 1.
                let childM1 = child.measure(using: from)
                if m1 < childM1 || (m1 <= childM1 && (edge1 == .leading || i == node.children.count-1)) {
                    node = child
                    break
                }
                m1 -= childM1
                m2 += child.measure(using: to)
            }
            assert(node != parent)
        }

        let base = from.convertToBaseUnits(m1, in: node.leaf, edge: edge1)
        return m2 + to.convertToMeasuredUnits(base, in: node.leaf, edge: edge2)
    }
}

extension BTreeNode where Summary: BTreeDefaultMetric {
    func count<M>(_ metric: M, upThrough offset: Int, edge: BTreeMetricEdge) -> M.Unit where M: BTreeMetric<Summary> {
        convert(offset, from: Summary.defaultMetric, edge: .trailing, to: metric, edge: edge)
    }

    func countBaseUnits<M>(upThrough measured: M.Unit, measuredIn metric: M, edge: BTreeMetricEdge) -> Int where M: BTreeMetric<Summary> {
        convert(measured, from: metric, edge: edge, to: Summary.defaultMetric, edge: .trailing)
    }
}


// MARK: - Indexing

extension BTreeNode {
    struct PathElement {
        // An index is valid only if its root present and its mutation
        // count is equal to the root's mutation count. If both of those
        // are true, we're guaranteed that the path is valid, so we can
        // unowned instead of weak references for the nodes.
        unowned var storage: BTreeNode<Summary>.Storage
        var slot: Int // child index

        var child: BTreeNode {
            storage.children[slot]
        }
    }

    struct Index {
        weak var rootStorage: Storage?
        let mutationCount: Int

        var position: Int

        var path: [PathElement]

        unowned var leafStorage: BTreeNode<Summary>.Storage? // Present unless the index is invalid.
        var leaf: Leaf? { leafStorage?.leaf }

        var offsetOfLeaf: Int // Position of the first element of the leaf in base units. -1 if we're invalid.

        // Must be less than leaf.count unless we're at the end of the rope, in which case
        // it's equal to leaf.count.
        var offsetInLeaf: Int {
            position - offsetOfLeaf
        }

        var atEnd: Bool {
            position == rootStorage!.count
        }

        init<N>(offsetBy offset: Int, in root: N) where N: BTreeNodeProtocol<Summary> {
            precondition((0...root.count).contains(offset), "Index out of bounds")

            self.rootStorage = root.storage
            self.mutationCount = root.mutationCount
            self.position = offset
            self.path = []
            self.leafStorage = nil
            self.offsetOfLeaf = -1

            descend()
        }

        init<N>(startOf root: N) where N: BTreeNodeProtocol<Summary>  {
            self.init(offsetBy: 0, in: root)
        }

        init<N>(endOf root: N) where N: BTreeNodeProtocol<Summary> {
            self.init(offsetBy: root.count, in: root)
        }

        mutating func descend() {
            path = []
            var node = BTreeNode<Summary>(storage: rootStorage!) // assume we have a root
            var offset = 0
            while !node.isLeaf {
                var slot = 0
                for child in node.children.dropLast() {
                    if position < offset + child.count {
                        break
                    }
                    offset += child.count
                    slot += 1
                }
                path.append(PathElement(storage: node.storage, slot: slot))
                node = node.children[slot]
            }

            self.leafStorage = node.storage
            self.offsetOfLeaf = offset
        }

        func isBoundary<M>(using metric: M, edge: BTreeMetricEdge) -> Bool where M: BTreeMetric<Summary> {
            assert(rootStorage != nil)

            guard let leaf else {
                return false
            }

            if metric.isAtomic && !metric.canFragment && offsetInLeaf == 0 {
                return true
            }

            switch edge {
            case .leading:
                if position == rootStorage!.count {
                    return true
                } else {
                    // The only index with offsetInLeaf == leaf.count is endIndex, where
                    // position == rootStorage!.count, which we've already handled above.
                    assert(offsetInLeaf < leaf.count)
                    return metric.isBoundary(offsetInLeaf, in: leaf, edge: .leading)
                }
            case .trailing:
                if position == 0 {
                    return true
                } else if offsetInLeaf == 0 {
                    let (prev, _) = peekPrevLeaf()!
                    return metric.isBoundary(prev.count, in: prev, edge: .trailing)
                } else {
                    return metric.isBoundary(offsetInLeaf, in: leaf, edge: .trailing)
                }
            }
        }

        mutating func set(_ position: Int) {
            precondition((0...rootStorage!.count).contains(position), "Index out of bounds")

            self.position = position

            if let leaf {
                let leafEnd = offsetOfLeaf + leaf.count

                if position >= offsetOfLeaf && (position < leafEnd || position == leafEnd && position == rootStorage!.count) {
                    // We're still in the same leaf. No need to descend.
                    return
                }
            }

            descend()
        }

        @discardableResult
        mutating func prev<M>(using metric: M, edge: BTreeMetricEdge) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil)
            if leaf == nil || position == 0 {
                invalidate()
                return nil
            }

            // try to find a boundary within this leaf
            let origPos = position
            if offsetInLeaf > 0 {
                if let newOffsetInLeaf = metric.prev(offsetInLeaf, in: leaf!, edge: edge) {
                    position = offsetOfLeaf + newOffsetInLeaf
                    return position
                }
            }
    
            // We didn't find a boundary, go to the previous leaf and try again.
            if prevLeaf() == nil {
                // We were in the first leaf. We're done.
                return nil
            }
            if let position = last(withinLeafUsing: metric, edge: edge, originalPosition: origPos) {
                return position
            }

            // We've searched at least one full leaf backwards and
            // found nothing. Just start at the top and descend instead.
            //
            // TODO: it's possible this only works with trailing boundaries, but
            // I'm not sure.
            let measure = measure(upToLeafContaining: position, using: metric)
            descend(toLeafContaining: measure, asMeasuredBy: metric)
            if let pos = last(withinLeafUsing: metric, edge: edge, originalPosition: origPos) {
                return pos
            }
            invalidate()
            return nil
        }

        // Searches for the last boundary in the current leaf.
        //
        // If the last boundary is at the end of the leaf, it's only valid if
        // it's less than originalPosition.
        mutating func last<M>(withinLeafUsing metric: M, edge: BTreeMetricEdge, originalPosition: Int) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil && leaf != nil)
            if offsetOfLeaf + leaf!.count < originalPosition && metric.isBoundary(leaf!.count, in: leaf!, edge: edge) {
                nextLeaf()
                return position
            }
            if let newOffsetInLeaf = metric.prev(leaf!.count, in: leaf!, edge: edge) {
                position = offsetOfLeaf + newOffsetInLeaf
                return position
            }
            if offsetOfLeaf == 0 && edge == .trailing {
                // Didn't find a boundary, but startIndex is a trailing boundary.
                position = 0
                return position
            }

            return nil
        }

        @discardableResult
        mutating func next<M>(using metric: M, edge: BTreeMetricEdge) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil)
            if leaf == nil || position == rootStorage!.count {
                invalidate()
                return nil
            }

            if let pos = next(withinLeafUsing: metric, edge: edge) {
                return pos
            }

            // We didn't find a boundary, go to the next leaf and try again.
            if nextLeaf() == nil {
                // We were in the last leaf. We're done.
                return nil
            }

            // The start of this new leaf might be a leading boundary
            if edge == .leading && isBoundary(using: metric, edge: .leading) {
                assert(offsetInLeaf == 0)
                return position
            }

            // one more shot
            if let pos = next(withinLeafUsing: metric, edge: edge) {
                return pos
            }

            // We've searched at least one full leaf forwards and
            // found nothing. Just start at the top and descend instead.
            //
            // TODO: it's possible this only works with trailing boundaries, but
            // I'm not sure.
            let measure = measure(upToLeafContaining: position, using: metric)
            descend(toLeafContaining: measure+1, asMeasuredBy: metric)

            if let pos = next(withinLeafUsing: metric, edge: edge) {
                return pos
            }

            // we didn't find anything
            invalidate()
            return nil
        }

        mutating func next<M>(withinLeafUsing metric: M, edge: BTreeMetricEdge) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil && leaf != nil)

            let isLastLeaf = offsetOfLeaf + leaf!.count == rootStorage!.count

            let newOffsetInLeaf = metric.next(offsetInLeaf, in: leaf!, edge: edge)
            if newOffsetInLeaf == nil && isLastLeaf && edge == .leading {
                // Didn't find a boundary, but endIndex is always a leading boundary
                position = offsetOfLeaf + leaf!.count
                return position
            }

            guard let newOffsetInLeaf else {
                return nil
            }

            if newOffsetInLeaf == leaf!.count && !isLastLeaf {
                // sets position = offsetOfLeaf + leaf!.count, offsetInLeaf will be 0.
                nextLeaf()
            } else {
                position = offsetOfLeaf + newOffsetInLeaf
            }

            return position
        }

        // Moves to the start of the previous leaf, regardless of offsetInLeaf.
        @discardableResult
        mutating func prevLeaf() -> (Leaf, Int)? {
            assert(rootStorage != nil)

            if leaf == nil {
                return nil
            }

            // if we're in the first leaf, there is no previous leaf.
            if offsetOfLeaf == 0 {
                invalidate()
                return nil
            }

            // ascend until we can go left
            while let el = path.last, el.slot == 0 {
                path.removeLast()
            }

            // move left
            path[path.count - 1].slot -= 1

            var node = path[path.count - 1].child

            // descend right
            while !node.isLeaf {
                path.append(PathElement(storage: node.storage, slot: node.children.count - 1))
                node = node.children[node.children.count - 1]
            }

            self.leafStorage = node.storage
            self.offsetOfLeaf -= node.count
            self.position = offsetOfLeaf

            return read()
        }

        @discardableResult
        mutating func nextLeaf() -> (Leaf, Int)? {
            assert(rootStorage != nil)

            guard let leaf else {
                return nil
            }

            self.position = offsetOfLeaf + leaf.count

            if position == rootStorage!.count {
                invalidate()
                return nil
            }

            // ascend until we can go right
            while let el = path.last, el.slot == el.storage.children.count - 1 {
                path.removeLast()
            }

            // move right
            path[path.count - 1].slot += 1

            var node = path[path.count - 1].child

            // descend left
            while !node.isLeaf {
                path.append(PathElement(storage: node.storage, slot: 0))
                node = node.children[0]
            }

            self.leafStorage = node.storage
            self.offsetOfLeaf = position
            return read()
        }

        func peekPrevLeaf() -> (Leaf, Int)? {
            var i = self
            return i.prevLeaf()
        }

        func peekNextLeaf() -> (Leaf, Int)? {
            var i = self
            return i.nextLeaf()
        }

        mutating func floorLeaf() -> Leaf? {
            assert(rootStorage != nil)

            guard let leaf else {
                return nil
            }

            position = offsetOfLeaf
            return leaf
        }

        func measure<M>(upToLeafContaining pos: Int, using metric: M) -> M.Unit where M: BTreeMetric<Summary> {
            if pos == 0 {
                return 0
            }

            var node = BTreeNode(storage: rootStorage!)
            var measure: M.Unit = 0
            var pos = pos

            while !node.isLeaf {
                for child in node.children {
                    if pos < child.count {
                        node = child
                        break
                    }
                    pos -= child.count
                    measure += child.measure(using: metric)
                }
            }

            return measure
        }

        mutating func descend<M>(toLeafContaining measure: M.Unit, asMeasuredBy metric: M) where M: BTreeMetric<Summary> {
            var node = BTreeNode(storage: rootStorage!)
            var offset = 0
            var measure = measure

            path = []

            while !node.isLeaf {
                var slot = 0
                for child in node.children.dropLast() {
                    let childMeasure = child.measure(using: metric)
                    if measure <= childMeasure {
                        break
                    }
                    offset += child.count
                    measure -= childMeasure
                    slot += 1
                }
                path.append(PathElement(storage: node.storage, slot: slot))
                node = node.children[slot]
            }

            self.leafStorage = node.storage
            self.position = offset
            self.offsetOfLeaf = offset
        }

        var isValid: Bool {
            leafStorage != nil
        }

        func validate(for root: BTreeNode) {
            precondition(self.rootStorage === root.storage)
            precondition(self.mutationCount == root.mutationCount)
            precondition(self.leafStorage != nil)
        }

        func validate(_ other: Index) {
            precondition(rootStorage === other.rootStorage && rootStorage != nil)
            precondition(mutationCount == rootStorage!.mutationCount)
            precondition(mutationCount == other.mutationCount)
            precondition(leafStorage != nil && other.leafStorage != nil)
        }

        func assertValid(for root: BTreeNode) {
            assert(self.rootStorage === root.storage)
            assert(self.mutationCount == root.mutationCount)
            assert(self.leafStorage != nil)
        }

        func assertValid(_ other: Index) {
            assert(rootStorage === other.rootStorage && rootStorage != nil)
            assert(mutationCount == rootStorage!.mutationCount)
            assert(mutationCount == other.mutationCount)
            assert(leafStorage != nil && other.leafStorage != nil)
        }

        func read() -> (Leaf, Int)? {
            guard let leaf else {
                return nil
            }

            return (leaf, offsetInLeaf)
        }

        mutating func invalidate() {
            self.leafStorage = nil
            self.offsetOfLeaf = -1
        }
    }
}

extension BTreeNode.Index: Comparable {
    static func < (lhs: BTreeNode.Index, rhs: BTreeNode.Index) -> Bool {
        lhs.validate(rhs)
        return lhs.position < rhs.position
    }

    static func == (lhs: BTreeNode.Index, rhs: BTreeNode.Index) -> Bool {
        lhs.validate(rhs)
        return lhs.position == rhs.position
    }
}

extension BTreeNode.Index: CustomStringConvertible {
    var description: String {
        "\(position)[pos]"
    }
}

// These indexing functions translate between the internal semmantics of the BTree (leading
// metrics have no boundary at the beginning of the tree, trailing metrics have no boundary
// at the end of the tree) and Swift collection semantics (every collection has a startIndex
// and endIndex regardless of what metric backs it).
//
// All Collection helpers take a range, which allows them to be used for both the base
// Collection as well as slice types.
//
// Rules for index validation:
// 1. All the public index helpers validate their user-provided indices with preconditions.
//    The caller, which should be in a type that implements BTree, does not need to validate.
// 2. The ranges are assumed to be valid because they are not user provided. If a Rope is sliced
//    to a Subrope, the indices should be validated at the point the Subrope is created. After
//    that they are assumed valid.
// 3. All index validation should happen at the top of the first Collection helper called by the
//    type that implements the BTree protocol. If it needs to call another collection helper,
//    it should call the underscored version of that helper that skips validation.
// 4. Every Collection helper, both public and private, should call assertValid(for:) on its
//    indices, which validate with assert instead of precondition.
extension BTreeNode where Summary: BTreeDefaultMetric {
    func index<M>(before i: consuming Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)
        precondition(i.position > range.lowerBound.position && i.position <= range.upperBound.position, "Index out of bounds")

        i = _index(roundingDown: i, in: range, using: metric, edge: edge)
        precondition(i.position > range.lowerBound.position, "Index out of bounds")

        let position = i.prev(using: metric, edge: edge)
        if position == nil || position! < range.lowerBound.position {
            return range.lowerBound
        }
        return i
    }

    func index<M>(after i: consuming Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)
        precondition(i.position >= range.lowerBound.position && i.position < range.upperBound.position, "Index out of bounds")

        let position = i.next(using: metric, edge: edge)
        if position == nil || position! > range.upperBound.position {
            return range.upperBound
        }
        return i
    }

    func index<M>(_ i: consuming Index, offsetBy distance: M.Unit, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        precondition(i.position >= range.lowerBound.position && i.position <= range.upperBound.position, "Index out of bounds")

        return _index(i, offsetBy: distance, in: range, using: metric, edge: edge)
    }

    private func _index<M>(_ i: consuming Index, offsetBy distance: M.Unit, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {

        // Handling empty slices here makes some logic down below a bit easier.
        if range.lowerBound.position == range.upperBound.position {
            precondition(distance == 0, "Index out of bounds")
            return i
        }

        let start = startIndex

        var min = _distance(from: start, to: range.lowerBound, in: start..<range.upperBound, using: metric, edge: edge)
        var max = _distance(from: start, to: range.upperBound, in: start..<range.upperBound, using: metric, edge: edge)
        var m =   _distance(from: start, to: i, in: start..<range.upperBound, using: metric, edge: edge)

        // Consider "\nfoo" without slicing (range = 0..<4). In this situation, 0 is not a valid measured unit in newlines,
        // but e.g. if i.position == 1, distance(0, 1, 0..<4, .newlines, .leading) = 1 - 1 = 0. But m, which is the measure
        // of where we're starting should be 1, not 0, because even the count of leading newline boundaries from startIndex..<startIndex
        // is 0. This is true for any value of i that's less than upperBound.
        //
        // We have to bump min and max for the same reason. distance(0, 0) will always be 0, but because startIndex is a boundary, we
        // want it to be 1.
        if edge == .leading && start.isBoundary(using: metric, edge: .leading) {
            min += 1
            max += 1
            m += 1
        }
        precondition(m+distance >= min && m+distance <= max, "Index out of bounds")

        if m + distance == max {
            i.set(range.upperBound.position)
            return i
        } else if m + distance == min {
            i.set(range.lowerBound.position)
            return i
        }

        let pos = countBaseUnits(upThrough: m + distance, measuredIn: metric, edge: edge)
        i.set(pos)
        return i
    }

    func index<M>(_ i: consuming Index, offsetBy distance: M.Unit, limitedBy limit: Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index? where M: BTreeMetric<Summary> {
        i.validate(for: self)
        limit.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        precondition(i.position >= range.lowerBound.position && i.position <= range.upperBound.position, "Index out of bounds")
        precondition(limit.position >= range.lowerBound.position && limit.position <= range.upperBound.position, "Index out of bounds")

        if distance < 0 && limit.position <= i.position {
            let l = self._distance(from: i, to: _index(roundingUp: limit, in: range, using: metric, edge: edge), in: range, using: metric, edge: edge)
            if distance < l {
                return nil
            }
        } else if distance > 0 && limit.position >= i.position {
            let l = self._distance(from: i, to: _index(roundingDown: limit, in: range, using: metric, edge: edge), in: range, using: metric, edge: edge)
            if distance > l {
                return nil
            }
        }

        return _index(i, offsetBy: distance, in: range, using: metric, edge: edge)
    }

    // distance(from:to:in:using:) always counts trailing boundaries.
    func distance<M>(from start: Index, to end: Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> M.Unit where M: BTreeMetric<Summary> {
        start.validate(for: self)
        end.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        precondition(start.position >= range.lowerBound.position && start.position <= range.upperBound.position, "Index out of bounds")
        precondition(end.position >= range.lowerBound.position && end.position <= range.upperBound.position, "Index out of bounds")
        return _distance(from: start, to: end, in: range, using: metric, edge: edge)
    }

    private func _distance<M>(from start: Index, to end: Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> M.Unit where M: BTreeMetric<Summary> {
        if start.position == end.position {
            return 0
        }

        // TODO: we should be able to remove the edge == .trailing check so that we can use measure(using:)
        // with leading metrics. The issue is that if we have a metric where 0[pos] is a .leading boundary,
        // measure(using: metric) will return one boundary past count(end) - count(start), and we'd need to
        // correct for that.
        let m: M.Unit
        if edge == .trailing && start.position == 0 && end.position == count {
            m = measure(using: metric)
        } else if edge == .trailing && start.position == count && end.position == 0 {
            m = -1 * measure(using: metric)
        } else {
            m = count(metric, upThrough: end.position, edge: edge) - count(metric, upThrough: start.position, edge: edge)
        }

        // In Collection, startIndex is always less than endIndex as long as count > 0. But in the BTree, endIndex
        // might not be a boundary. Some examples:
        //
        // either = {.leading, .trailing}
        //
        // "abc".distance(0, 3, .newlines, either) = 1
        // "abc".distance(3, 0, .newlines, either) = -1
        //
        // Because "abc".count(.newlines, upThrough: 3, edge: either) will always return 0, we need to adjust
        // `m` whenever either start or end == range.upperBound. In the first example, fudge=1 and the second,
        // fudge = -1.
        //
        // Adding a newline at the end adds a bit more complexity.
        //
        // "ab\n".distance(0, 3, .newlines, either) = 1
        // "ab\n".distance(3, 0, .newlines, either) = -1
        //
        // In this case, "ab\n".count(.newlines, upThrough: 3, edge: either) always returns 1, so we don't adjust
        // (fudge = 0), even though end=range.upperBound and start=range.upperBound respectively.
        //
        // Slicing off the end (i.e. range.upperBound < count) doesn't change anything for .trailing boundaries,
        // but it complicates leading boundaries some more.
        //
        // Consider slicing "ab\n" by 0..<2, yielding a substring of "ab" where start or end == range.upperBound.
        //
        // count(.newlines, upThrough: 2, edge: .trailing) = 0, so we need to adjust (i.e. abs(fudge) == 1). This is
        // the same behavior as the non-sliced version.
        //
        // But for leading edges, we have a problem:
        //
        // count(.newlines, upThrough: 2, edge: .leading) = 1, so even if start or end == range.upperBound, we don't
        // want to adjust (fudge = 0).
        //
        // TODO: I have a hunch this won't work with Heights, which is continuous. Look into it.
        let fudge: M.Unit
        if start.position == range.upperBound.position || end.position == range.upperBound.position {
            if edge == .trailing {
                if range.upperBound.isBoundary(using: metric, edge: .trailing) {
                    fudge = 0
                } else if end.position == range.upperBound.position {
                    fudge = 1
                } else {
                    fudge = -1
                }
            } else {
                // If we're slicing the end (i.e. upperBound.position < count) and upperBound
                // is a leading boundary, we need to skip fudging. E.g. slicing "ab\n"
                // by 0..<2 to yield "ab". In this situation, count(.newlines, 2, .leading)
                // will return 1, and there's no need to fudge.
                //
                // If we're not slicing the end, we always need to add an extra leading
                // index to `m`. In "ab".count(.newlines, 2, .leading) = 0, and
                // "a\n".count(.newlines, 2, .leading) = 1, but the distance over the entire
                // ranges should be 1 and 2 respenctively.

                if range.upperBound.position < count && range.upperBound.isBoundary(using: metric, edge: .leading) {
                    fudge = 0
                } else if end.position == range.upperBound.position {
                    fudge = 1
                } else {
                    fudge = -1
                }
            }
        } else {
            fudge = 0
        }

        return m + fudge
    }

    func index<M>(roundingDown i: consuming Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        precondition(i.position >= range.lowerBound.position && i.position <= range.upperBound.position, "Index out of bounds")
        return _index(roundingDown: i, in: range, using: metric, edge: edge)
    }

    private func _index<M>(roundingDown i: consuming Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        if i.position == range.lowerBound.position || i.position == range.upperBound.position || i.isBoundary(using: metric, edge: edge) {
            return i
        }

        let position = i.prev(using: metric, edge: edge)
        if position == nil || position! < range.lowerBound.position {
            // Leading metrics don't have a boundary at pos == 0, but in Swift, startIndex is
            // always a valid index when rounding no matter what.
            return range.lowerBound
        }
        return i
    }

    func index<M>(roundingUp i: consuming Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        precondition(i.position >= range.lowerBound.position && i.position <= range.upperBound.position, "Index out of bounds")
        return _index(roundingUp: i, in: range, using: metric, edge: edge)
    }

    private func _index<M>(roundingUp i: consuming Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        if i.position == range.lowerBound.position || i.position == range.upperBound.position || i.isBoundary(using: metric, edge: edge) {
            return i
        }

        let position = i.next(using: metric, edge: edge)
        if position == nil || position! > range.upperBound.position {
            // Trailing metrics don't have a boundary at pos == count, but
            // in Swift, endIndex is always a boundary no matter what.
            return range.upperBound
        }
        return i
    }

    func index<M>(at offset: M.Unit, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Index where M: BTreeMetric<Summary> {
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)
        return _index(range.lowerBound, offsetBy: offset, in: range, using: metric, edge: edge)
    }

    func isBoundary<M>(_ i: Index, in range: Range<Index>, using metric: M, edge: BTreeMetricEdge) -> Bool where M: BTreeMetric<Summary> {
        i.validate(for: self)
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        precondition(i.position >= range.lowerBound.position && i.position <= range.upperBound.position, "Index out of bounds")
        if i.position == range.lowerBound.position && edge == .trailing {
            return true
        } else if i.position == range.upperBound.position && edge == .leading {
            return true
        }

        return i.isBoundary(using: metric, edge: edge)
    }

    func count<M>(in range: Range<Index>, using metric: M) -> M.Unit where M: BTreeMetric<Summary> {
        range.lowerBound.assertValid(for: self)
        range.upperBound.assertValid(for: self)

        if range.lowerBound.position == range.upperBound.position {
            return 0
        }

        if range.lowerBound.position == 0 && range.upperBound.position == count {
            return measure(using: metric)
        } else {
            return count(metric, upThrough: range.upperBound.position - 1, edge: .leading) - count(metric, upThrough: range.lowerBound.position, edge: .trailing)
        }
    }
}

protocol BTreeIndex: Comparable {
    associatedtype Summary: BTreeSummary

    var baseIndex: BTreeNode<Summary>.Index { get }
}

extension BTreeNode.Index: BTreeIndex {
    var baseIndex: BTreeNode<Summary>.Index {
        self
    }
}

protocol BTreeSlice {
    associatedtype Summary: BTreeSummary
    associatedtype Element
    associatedtype Index: BTreeIndex where Index.Summary == Summary

    var root: BTreeNode<Summary> { get }
    var startIndex: Index { get }
    var endIndex: Index { get }
    subscript(unvalidatedIndex index: BTreeNode<Summary>.Index) -> Element { get }
}

// A more efficient Iterator than IndexingIterator that doesn't need to
// validate its indices.
extension BTreeNode where Summary: BTreeDefaultMetric {
    struct Iterator<Slice, Metric>: IteratorProtocol where Slice: BTreeSlice, Metric: BTreeMetric<Summary>, Slice.Summary == Summary {
        typealias Element = Slice.Element

        let slice: Slice
        let metric: Metric
        let edge: BTreeMetricEdge
        let bounds: Range<Index>
        var index: Index

        init(slice: Slice, metric: Metric, edge: BTreeMetricEdge) {
            assert(slice.startIndex.baseIndex.position <= slice.endIndex.baseIndex.position)
            let bounds = Range(uncheckedBounds: (slice.startIndex.baseIndex, slice.endIndex.baseIndex))

            bounds.lowerBound.assertValid(for: slice.root)
            bounds.upperBound.assertValid(for: slice.root)

            self.slice = slice
            self.metric = metric
            self.edge = edge
            self.bounds = bounds
            self.index = bounds.lowerBound
        }

        mutating func next() -> Element? {
            index.assertValid(for: slice.root)
            if !index.isValid || index >= bounds.upperBound {
                return nil
            }
            let element = slice[unvalidatedIndex: index]
            index.next(using: metric, edge: edge)
            return element
        }
    }
}


// MARK: - Mutation

extension BTreeNodeProtocol {
    mutating func mutatingForEachPair(startingAt position: Int, using block: (inout Leaf, inout Leaf) -> Bool) {
        precondition(position >= 0 && position <= count)

        // If root has height=0, there's only one leaf, so don't mutate.
        if isLeaf {
            return
        }

        func mutatePair(_ pos: Int, _ left: inout BTreeNode<Summary>, _ right: inout BTreeNode<Summary>) -> Bool {
            assert(left.height == right.height)

            if left.isLeaf {
                assert(right.isLeaf)

                return left.updateLeaf { a in
                    right.updateLeaf { b in
                        block(&a, &b)
                    }
                }
            }

            // A root with height=1 can have 2...maxChild children.
            // All other non-leaf nodes can have minChild...maxChild children.
            // assert(left.children.count > 1 && right.children.count > 1)
            assert(left.children.count > 1)
            assert(right.children.count > 1)

            left.ensureUnique()
            left.storage.mutationCount &+= 1
            defer { left.mergeUndersizedChildren() }
            defer { left.updateNonLeafMetadata() }

            var (offset, more) = mutateChildren(pos, &left)

            if !more {
                return false
            }

            right.ensureUnique()
            right.storage.mutationCount &+= 1
            defer { right.mergeUndersizedChildren() }
            defer { right.updateNonLeafMetadata() }

            // handle the middle pair
            if !mutatePair(max(0, pos - offset - left.children.last!.count), &left.children[left.children.count - 1], &right.children[0]) {
                return false
            }

            // handle the rest of the pairs
            (_, more) = mutateChildren(max(0, pos - offset), &right)
            return more
        }

        func mutateChildren<N>(_ pos: Int, _ n: inout N) -> (Int, Bool) where N: BTreeNodeProtocol<Summary> {
            var mutated: [BTreeNode<Summary>] = [n.children.removeFirst()]
            var offset = 0
            var more = true
            while !n.children.isEmpty {
                let end = offset + mutated[mutated.count - 1].count
                defer { offset = end }

                var next = n.children.removeFirst()

                if pos > end || (pos == end && pos < n.count) {
                    mutated.append(next)
                    continue
                }

                if !mutatePair(max(0, pos - offset), &mutated[mutated.count - 1], &next) {
                    mutated.append(contentsOf: n.children)
                    more = false
                    break
                }

                mutated.append(next)
            }

            n.children = mutated
            return (offset, more)
        }

        ensureUnique()
        storage.mutationCount &+= 1
        _ = mutateChildren(position, &self)
        mergeUndersizedChildren()
        updateNonLeafMetadata()

        #if CHECK_INVARIANTS
        checkInvariants()
        #endif
    }

    mutating func mutatingForEach(startingAt position: Int, using block: (_ offsetOfLeaf: Int, _ leaf: inout Leaf) -> Bool) {
        func helper<N>(_ pos: Int, _ offsetOfNode: Int, _ n: inout N) -> Bool where N: BTreeNodeProtocol<Summary> {
            if n.isLeaf {
                return n.updateLeaf { l in block(offsetOfNode, &l) }
            }

            n.ensureUnique()
            n.storage.mutationCount &+= 1
            defer { n.mergeUndersizedChildren() }
            defer { n.updateNonLeafMetadata() }

            var offset = 0
            for i in 0..<n.children.count {
                let end = offset + n.children[i].count

                // skip children that don't contain pos, making an exception for pos == count
                if pos > end || (pos == end && pos < n.count) {
                    offset += n.children[i].count
                    continue
                }

                if !helper(max(0, pos - offset), offsetOfNode+offset, &n.children[i]) {
                    return false
                }

                offset += n.children[i].count
            }

            return true
        }

        _ = helper(position, 0, &self)

        #if CHECK_INVARIANTS
        checkInvariants()
        #endif
    }

    // N.b. doesn't update metadata, requires self to be unique.
    mutating func mergeUndersizedChildren() {
        assert(!isLeaf)
        assert(isUnique())

        guard children.contains(where: \.isUndersized) else {
            return
        }

        var i = 0
        while i < children.count - 1 {
            assert(children[i].height == children[i+1].height)

            if children[i].isUndersized || children[i+1].isUndersized {
                let bothUndersized = children[i].isUndersized && children[i+1].isUndersized

                if children[i].isLeaf {
                    let other = children[i+1]
                    let newLeaf = children[i].updateLeaf { $0.pushMaybeSplitting(other: other.leaf) }
                    if let newLeaf {
                        assert(bothUndersized)
                        children[i+1] = BTreeNode(leaf: newLeaf)
                    }
                } else {
                    let (left, right) = children(merging: children[i].children, with: children[i+1].children)
                    children[i].updateChildren { $0 = left }
                    if let right {
                        assert(bothUndersized)
                        children[i+1].updateChildren { $0 = right }
                    }
                }

                if !bothUndersized {
                    children.remove(at: i+1)
                }

                continue
            }

            i += 1
        }
    }

    #if CHECK_INVARIANTS
    func checkInvariants() {
        func helper<N>(_ n: N, isRoot: Bool) where N: BTreeNodeProtocol<Summary> {
            if isRoot {
                // we don't have a good way to check a tree of height=0. In that case, the root
                // (which is a leaf) is allowed to be undersized, but not too big (oversized?).
                // Unfortunately, we don't have "isOversized," and I don't feel like adding it
                // right now.
                if n.height > 0 {
                    assert(n.children.count > 1 && n.children.count <= BTreeNode<Summary>.maxChild)
                }
            } else {
                assert(!isUndersized)
            }

            guard height > 0 else {
                return
            }

            for c in n.children {
                c.checkInvariants()
            }
        }

        helper(self, isRoot: true)
    }
    #endif

    @discardableResult
    mutating func updateLeaf<T>(_ body: (inout Leaf) -> T) -> T {
        precondition(isLeaf, "updateLeaf called on a non-leaf node")
        ensureUnique()
        storage.mutationCount &+= 1
        let r = body(&storage.leaf)
        updateLeafMetadata()
        return r
    }

    mutating func updateChildren<T>(_ body: (inout [BTreeNode<Summary>]) -> T) -> T {
        precondition(!isLeaf, "updateChildren called on a leaf node")
        ensureUnique()
        storage.mutationCount &+= 1
        let r = body(&storage.children)
        updateNonLeafMetadata()
        return r
    }

    mutating func updateLeafMetadata() {
        assert(isLeaf)
        storage.count = storage.leaf.count
        storage.leafCount = 1
        storage.summary = Summary(summarizing: storage.leaf)
    }

    mutating func updateNonLeafMetadata() {
        let height = storage.children[0].height + 1
        var count = 0
        var leafCount = 0
        var summary = Summary.zero

        for child in storage.children {
            assert(child.height + 1 == height)
            assert(!child.isUndersized)
            count += child.count
            leafCount += child.leafCount
            summary += child.summary
        }

        storage.height = height
        storage.count = count
        storage.leafCount = leafCount
        storage.summary = summary

        // in case we're changing from a leaf to an internal node in replaceChildren(with:merging:)
        storage.leaf = .zero
    }
}

// MARK: - Builder

struct BTreeBuilder<Tree> where Tree: BTree {
    typealias Summary = Tree.Summary
    typealias Leaf = Summary.Leaf
    typealias Storage = BTreeNode<Summary>.Storage

    // PartialTree is an optimization to reduce unnecessary copying.
    // Unless a tree has been pushed on to the builder more than once,
    // it will have exactly one reference inside the builder: either
    // on the stack or in a local variable.
    //
    // For nodes created inside the builder, this is fine. But for
    // uniquely referenced trees created outside the builder, this is
    // a problem. As soon as the tree is in the builder, it has
    // refcount=2 even though it's actually safe to mutate.
    //
    // To get around this, we record the result of isKnownUniquelyReferenced
    // into isUnique before pushing the tree onto the stack.
    struct PartialTree: BTreeNodeProtocol {
        var storage: Storage
        var _isUnique: Bool

        init() {
            self.storage = Storage()
            self._isUnique = true
        }

        init<N>(_ node: N, isUnique: Bool) where N: BTreeNodeProtocol<Summary> {
            self.storage = node.storage
            self._isUnique = isUnique
        }

        init(leaf: Leaf) {
            self.storage = Storage(leaf: leaf)
            self._isUnique = true
        }

        init<S>(children: S) where S: Sequence<BTreeNode<Summary>> {
            self.storage = Storage(children: Array(children))
            self._isUnique = true
        }

        func isUnique() -> Bool {
            _isUnique
        }

        mutating func ensureUnique() {
            if !_isUnique {
                _isUnique = true
                storage = storage.copy()
            }
        }
    }

    // A stack of PartialTrees, strictly descending in height.
    // Each inner array contains trees of the same height and has a
    // count less than maxChild. For each inner array with count > 1,
    // no elements are undersized.
    var stack: [[PartialTree]]
    var skipFixup: Bool

    init() {
        stack = []
        skipFixup = false
    }

    var isEmpty: Bool {
        stack.isEmpty
    }

    // Always call this method on a local variable, never directly on the child
    // of an existing node. I.e. this is bad: push(&node.children[n]).
    mutating func push(_ node: inout BTreeNode<Summary>) {
        // must call isUnique() on a separate line, otherwise
        // we end up with two references.
        let isUnique = node.isUnique()
        push(PartialTree(node, isUnique: isUnique))
    }

    // Precondition: leaves must already be fixed up with each other.
    mutating func push<S>(leaves: S) where S: Sequence<Leaf> {
        for l in leaves {
            push(leaf: l)
            skipFixup = true
        }
        skipFixup = false
    }

    // For descendants of root, isKnownUniquelyReferenced isn't enough to know whether
    // a node is safe to mutate or not. A node can have refcount=1 but a parent with
    // refcount=2. To get around this, we pass down isUnique, a flag that starts out
    // as isKnownUniquelyReferenced(&root.storage), and can only transition from true
    // to false.
    //
    // N.b. always call this method on a local variable, never directly on the child
    // of an existing node. I.e. this is bad: push(&node.children[n], slicedBy:...).
    // If you don't do this, the builder will think that root is safe to mutate even
    // though it's also a subtree of a larger tree.
    mutating func push(_ root: inout BTreeNode<Summary>, slicedBy range: Range<Int>) {
        defer { skipFixup = false }

        func helper(_ n: inout BTreeNode<Summary>, slicedBy r: Range<Int>, isUnique: Bool) {
            let isUnique = isUnique && n.isUnique()

            if r.isEmpty {
                return
            }

            if r == 0..<n.count {
                push(PartialTree(n, isUnique: isUnique))
                skipFixup = true
                return
            }

            if n.isLeaf {
                push(leaf: n.leaf, slicedBy: r)
                skipFixup = true
            } else {
                var offset = 0
                for i in 0..<n.children.count {
                    if r.upperBound <= offset {
                        break
                    }

                    let childRange = 0..<n.children[i].count
                    let intersection = childRange.clamped(to: r.offset(by: -offset))
                    helper(&n.children[i], slicedBy: intersection, isUnique: isUnique)
                    offset += n.children[i].count
                }
            }
        }

        let isUnique = root.isUnique()
        helper(&root, slicedBy: range, isUnique: isUnique)
    }

    mutating func push(leaf: Leaf, slicedBy range: Range<Int>) {
        push(leaf: leaf[range])
    }

    mutating func push(leaf: Leaf) {
        push(PartialTree(leaf: leaf))
    }

    private mutating func push(_ node: PartialTree) {
        #if CHECK_INVARIANTS
        defer { checkInvariants() }
        #endif
        var n = node

        // Ensure that n is no larger than the node at the top of the stack.
        while let lastNode = stack.last?.last, lastNode.height < n.height {
            var popped = pop()

            if Leaf.needsFixupOnAppend && !skipFixup {
                fixup(&popped, &n)
            }

            popped.append(n)
            n = popped
        }

        while true {
            assert(stack.last?.last == nil || stack.last!.last!.height >= n.height)

            if !isEmpty && stack.last!.last!.height == n.height {
                var lastNode = popLast()!

                if !lastNode.isUndersized && !n.isUndersized {
                    if Leaf.needsFixupOnAppend && !skipFixup {
                        let h1 = lastNode.height, h2 = n.height
                        fixup(&lastNode, &n)
                        if h1 != lastNode.height || h2 != n.height || lastNode.isUndersized || n.isUndersized {
                            repushNoFixup(lastNode)
                            repushNoFixup(n)
                            return
                        }
                    }

                    stack[stack.count - 1].append(lastNode)
                    stack[stack.count - 1].append(n)
                } else if n.isLeaf {
                    assert(lastNode.isLeaf)

                    let newLeaf = lastNode.updateLeaf { $0.pushMaybeSplitting(other: n.leaf) }
                    stack[stack.count - 1].append(lastNode)

                    if let newLeaf {
                        assert(!newLeaf.isUndersized)
                        stack[stack.count - 1].append((PartialTree(leaf: newLeaf)))
                    }
                } else {
                    // The only time lastNode (which was already on the stack) would be
                    // undersized is if it was the only element of height N on the stack.
                    assert(stack.last!.isEmpty || (!lastNode.isUndersized && n.isUndersized))

                    if Leaf.needsFixupOnAppend && !skipFixup {
                        let h1 = lastNode.height, h2 = n.height
                        fixup(&lastNode, &n)
                        if h1 != lastNode.height || h2 != n.height {
                            repushNoFixup(lastNode)
                            repushNoFixup(n)
                            return
                        }
                    }

                    let c1 = lastNode.children
                    let c2 = n.children
                    let count = c1.count + c2.count
                    if count <= BTreeNode<Summary>.maxChild {
                        stack[stack.count - 1].append(PartialTree(children: c1 + c2))
                    } else {
                        let split = count / 2
                        let children = [c1, c2].joined()
                        stack[stack.count - 1].append(PartialTree(children: children.prefix(split)))
                        stack[stack.count - 1].append(PartialTree(children: children.dropFirst(split)))
                    }
                }

                if stack[stack.count - 1].count < BTreeNode<Summary>.maxChild {
                    break
                }

                n = pop()
            } else if !isEmpty {
                if Leaf.needsFixupOnAppend && !skipFixup {
                    var lastNode = popLast()!, h = lastNode.height
                    fixup(&lastNode, &n)
                    if h != lastNode.height || lastNode.height <= n.height {
                        repushNoFixup(lastNode)
                        repushNoFixup(n)
                        return
                    }

                    stack[stack.count - 1].append(lastNode)
                }
                stack.append([n])
                break
            } else {
                if Leaf.needsFixupOnAppend && !skipFixup {
                    let h = n.height
                    var blank = PartialTree()
                    fixup(&blank, &n)

                    // fixup shouldn't change heights if either argument
                    // is empty.
                    assert(blank.isEmpty && n.height == h)
                }
                stack.append([n])
                break
            }
        }
    }

    private mutating func popLast() -> PartialTree? {
        if stack.isEmpty {
            return nil
        }
        return stack[stack.count - 1].removeLast()
    }

    private mutating func pop() -> PartialTree {
        let partialTrees = stack.removeLast()
        assert(!partialTrees.isEmpty)

        if partialTrees.count == 1 {
            return partialTrees[0]
        } else {
            return PartialTree(children: partialTrees.map { BTreeNode<Summary>($0) })
        }
    }

    consuming func build() -> Tree {
        var n: PartialTree = PartialTree()
        while !stack.isEmpty {
            var popped = pop()
            if Leaf.needsFixupOnAppend && !skipFixup {
                fixup(&popped, &n)
            }

            popped.append(n)
            n = popped
        }

        return Tree(BTreeNode(n))
    }

    private func fixup(_ left: inout PartialTree, _ right: inout PartialTree) {
        var done = false
        left.mutatingForEach(startingAt: left.count) { _, prev in
            right.mutatingForEach(startingAt: 0) { _, next in
                done = prev.fixup(withNext: &next)
                return false
            }
            return false
        }

        if done {
            return
        }

        right.mutatingForEachPair(startingAt: 0) { prev, next in
            return !prev.fixup(withNext: &next)
        }
    }

    // fixup() guarantees that it won't break either tree's invariants, but it might
    // break the builder's invariants between the two trees. E.g. the trees could
    // change height or a tree of height=0 could become undersized.
    //
    // If that happens, we recurisvely re-push each tree without fixing up (they're now
    // guaranteed to be fixed up relative to each other), and then bail out of the
    // original push.
    mutating func repushNoFixup(_ n: PartialTree) {
        assert(!skipFixup)

        // because we're in the middle of a push, it's possible the last stack is
        // empty because we've popped the only element off. Make sure our invariants
        // are correct
        if stack[stack.count - 1].isEmpty {
            stack.removeLast()
        }
        skipFixup = true
        push(n)
        skipFixup = false
    }

    #if CHECK_INVARIANTS
    func checkInvariants() {
        for nodes in stack {
            assert(!nodes.isEmpty)
            for n in nodes {
                assert(n.height == nodes[0].height)
                assert(nodes.count == 1 || !n.isUndersized)
                n.checkInvariants()
            }
        }
    }
    #endif
}

extension BTreeNodeProtocol {
    mutating func append<N>(_ other: N) where N: BTreeNodeProtocol<Summary> {
        if other.isEmpty {
            return
        }

        let h1 = height
        let h2 = other.height

        if h1 < h2 {
            if h1 == h2 - 1 && !isUndersized {
                replaceChildren(with: [BTreeNode(copying: self)], merging: other.children)
                return
            }

            append(other.children[0])
            // height rather than h1 becuase self.append() can increment height
            if height == h2 - 1 {
                replaceChildren(with: [BTreeNode(copying: self)], merging: other.children.dropFirst())
            } else {
                replaceChildren(with: children, merging: other.children.dropFirst())
            }
        } else if h1 == h2 {
            if !isUndersized && !other.isUndersized {
                replaceChildren(with: [BTreeNode(copying: self)], merging: [BTreeNode(other)])
            } else if h1 == 0 {
                append(leafNode: other)
            } else {
                replaceChildren(with: children, merging: other.children)
            }
        } else {
            if h2 == h1 - 1 && !other.isUndersized {
                replaceChildren(with: children, merging: [BTreeNode(other)])
                return
            }

            children[children.count - 1].append(other)
            if children.last!.height == h1 - 1 {
                replaceChildren(with: children.dropLast(), merging: [children.last!])
            } else {
                replaceChildren(with: children.dropLast(), merging: children.last!.children)
            }
        }
    }

    mutating func replaceChildren<C1, C2>(with leftChildren: C1, merging rightChildren: C2) where C1: Collection<BTreeNode<Summary>>, C2: Collection<BTreeNode<Summary>> {
        ensureUnique()
        storage.mutationCount &+= 1

        let (left, right) = children(merging: leftChildren, with: rightChildren)
        if let right {
            let n1 = BTreeNode<Summary>(children: left)
            let n2 = BTreeNode<Summary>(children: right)
            storage.children = [n1, n2]
        } else {
            storage.children = left
        }

        updateNonLeafMetadata()
    }

    func children<C1, C2>(merging leftChildren: C1, with rightChildren: C2) -> ([BTreeNode<Summary>], [BTreeNode<Summary>]?) where C1: Collection<BTreeNode<Summary>>, C2: Collection<BTreeNode<Summary>> {
        let count = leftChildren.count + rightChildren.count
        assert(count <= BTreeNode<Summary>.maxChild*2)

        let cs = [AnySequence(leftChildren), AnySequence(rightChildren)].joined()

        if count <= BTreeNode<Summary>.maxChild {
            return (Array(cs), nil)
        } else {
            let split = count / 2
            return (Array(cs.prefix(split)), Array(cs.dropFirst(split)))
        }
    }

    mutating func append<N>(leafNode other: N) where N: BTreeNodeProtocol<Summary> {
        assert(isLeaf && other.isLeaf)

        let newLeaf = updateLeaf { $0.pushMaybeSplitting(other: other.leaf) }

        if let newLeaf {
            // No need to explicitly copy self because we're creating a new storage.
            storage = Storage(children: [BTreeNode(self), BTreeNode(leaf: newLeaf)])
        }
    }
}


// MARK: - LeavesView

extension BTreeNode {
    var leaves: LeavesView {
        LeavesView(root: self)
    }

    struct LeavesView {
        var root: BTreeNode
    }
}

// TODO: maybe make a metric and add distance(from:to), index(_:offsetBy:), index(_:offsetBy:limitedBy:)
extension BTreeNode.LeavesView: BidirectionalCollection {
    struct Index: Comparable {
        var ni: BTreeNode.Index

        static func < (lhs: Index, rhs: Index) -> Bool {
            lhs.ni.validate(rhs.ni)
            return lhs.ni.offsetOfLeaf < rhs.ni.offsetOfLeaf
        }

        static func == (lhs: Index, rhs: Index) -> Bool {
            lhs.ni.validate(rhs.ni)
            return lhs.ni.offsetOfLeaf == rhs.ni.offsetOfLeaf && lhs.ni.atEnd == rhs.ni.atEnd
        }

        // the index before endIndex
        var lastLeaf: Bool {
            ni.rootStorage!.count == ni.offsetOfLeaf + ni.leaf!.count && ni.position < ni.rootStorage!.count
        }
    }

    var startIndex: Index {
        Index(ni: root.startIndex)
    }

    var endIndex: Index {
        Index(ni: root.endIndex)
    }

    var count: Int {
        root.leafCount
    }

    subscript(position: Index) -> Summary.Leaf {
        position.ni.validate(for: root)
        let (leaf, _) = position.ni.read()!
        return leaf
    }

    func index(before i: Index) -> Index {
        i.ni.validate(for: root)
        var i = i

        // if we're at endIndex, move back to the last valid
        // leaf index.
        if i.ni.position == root.count && root.count > 0 {
            i.ni.position = i.ni.offsetOfLeaf
            return i
        }

        guard let _ = i.ni.prevLeaf() else {
            fatalError("Index out of bounds")
        }

        return i
    }

    func index(after i: Index) -> Index {
        i.ni.validate(for: root)
        if i.lastLeaf {
            return endIndex
        }

        var i = i
        guard let _ = i.ni.nextLeaf() else {
            fatalError("Index out of bounds")
        }

        return i
    }
}


// MARK: - Deltas

// An ordered list of changes to to a tree. Deletes of a given range
// are represented by the absence of a copy over that range.
struct BTreeDelta<Tree> where Tree: BTree {
    enum DeltaElement: Equatable {
        case copy(Int, Int)
        case insert(BTreeNode<Tree.Summary>)

        static func == (lhs: DeltaElement, rhs: DeltaElement) -> Bool {
            switch (lhs, rhs) {
            case let (.copy(a, b), .copy(c, d)):
                return a == c && b == d
            case let (.insert(a), .insert(b)):
                // Reference equality. Kind of a hack, but the
                // Equatable conformance is just for testing.
                return a.storage === b.storage
            default:
                return false
            }
        }

        var isInsert: Bool {
            switch self {
            case .copy(_, _): return false
            case .insert(_):  return true
            }
        }
    }

    var elements: [DeltaElement]
    var baseCount: Int // the count of the associated BTree before applying the delta.

    // An empty delta contains no changes. It doesn't mean elements will be empty.
    //
    // Specifically, an empty delta contains one or more adjacent copies that
    // span 0..<baseCount.
    var isEmpty: Bool {
        let (replacementRange, newCount) = summary()
        return replacementRange.isEmpty && newCount == 0
    }

    // Returns a range covering the entire changed portion of the
    // original tree and the length of the newly inserted tree.
    func summary() -> (replacementRange: Range<Int>, newCount: Int) {
        var els = elements

        // The only way the replaced range can have a lowerBound
        // greater than 0, is if the first element is a copy that
        // starts at 0.
        var start = 0
        if case let .copy(0, upperBound) = els.first {
            start = upperBound
            els.removeFirst()
        }

        // Ditto for upperBound and the end of the string. For
        // the replaced range's upperBound to be less than the
        // length of the string, the final element has to be a
        // copy that ends at the end of the string.
        var end = baseCount
        if case let .copy(lowerBound, upperBound) = els.last {
            if upperBound == baseCount {
                end = lowerBound
                els.removeLast()
            }
        }

        let count = els.reduce(0) { sum, el in
            switch el {
            case let .copy(start, end):
                return sum + (start - end)
            case let .insert(root):
                return sum + root.count
            }
        }

        return (start..<end, count)
    }
}

struct BTreeDeltaBuilder<Tree> where Tree: BTree {
    var delta: BTreeDelta<Tree>
    var lastOffset: Int

    init(_ baseCount: Int) {
        self.delta = BTreeDelta<Tree>(elements: [], baseCount: baseCount)
        self.lastOffset = 0
    }

    mutating func removeSubrange(_ bounds: Range<Int>) {
        precondition(bounds.lowerBound >= lastOffset, "ranges must be sorted")
        if lastOffset < bounds.lowerBound {
            delta.elements.append(.copy(lastOffset, bounds.lowerBound))
        }
        lastOffset = bounds.upperBound
    }

    mutating func replaceSubrange(_ subrange: Range<Int>, with tree: Tree) {
        removeSubrange(subrange)
        if !tree.root.isEmpty {
            delta.elements.append(.insert(tree.root))
        }
    }

    consuming func build() -> BTreeDelta<Tree> {
        if lastOffset < delta.baseCount {
            delta.elements.append(.copy(lastOffset, delta.baseCount))
        }

        return delta
    }
}

extension BTree {
    func applying(delta: BTreeDelta<Self>) -> Self {
        var r = root
        var b = BTreeBuilder<Self>()
        for el in delta.elements {
            switch el {
            case let .copy(start, end):
                b.push(&r, slicedBy: start..<end)
            case let .insert(node):
                var n = node
                b.push(&n)
            }
        }
        return b.build()
    }
}
