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


enum BTreeMetricType {
    case leading
    case trailing
    case atomic // both leading and trailing
}

protocol BTreeMetric<Summary> {
    associatedtype Summary: BTreeSummary
    associatedtype Unit: Numeric & Comparable

    func measure(summary: Summary, count: Int) -> Unit
    func convertToBaseUnits(_ measuredUnits: Unit, in leaf: Summary.Leaf) -> Int
    func convertFromBaseUnits(_ baseUnits: Int, in leaf: Summary.Leaf) -> Unit
    func isBoundary(_ offset: Int, in leaf: Summary.Leaf) -> Bool

    // Prev is never called with offset == 0
    func prev(_ offset: Int, in leaf: Summary.Leaf) -> Int?
    func next(_ offset: Int, in leaf: Summary.Leaf) -> Int?

    var canFragment: Bool { get }
    var type: BTreeMetricType { get }
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
            self.children = []
            self.leaf = leaf
            self.summary = Summary(summarizing: leaf)
        }

        init<S>(children: S) where S: Sequence<BTreeNode<Summary>> {
            let children = Array(children)

            assert(1 <= children.count && children.count <= BTreeNode<Summary>.maxChild)
            let height = children[0].height + 1
            var count = 0
            var summary = Summary.zero

            for child in children {
                assert(child.height + 1 == height)
                assert(!child.isUndersized)
                count += child.count
                summary += child.summary
            }

            self.height = height
            self.count = count
            self.children = children
            self.leaf = .zero
            self.summary = summary
        }

        init(copying storage: Storage) {
            self.height = storage.height
            self.mutationCount = storage.mutationCount
            self.count = storage.count
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

    func convert<M1, M2>(_ m1: M1.Unit, from: M1, to: M2) -> M2.Unit where M1: BTreeMetric<Summary>, M2: BTreeMetric<Summary> {
        if m1 == 0 {
            return 0
        }

        if type(of: from) == type(of: to) {
            // If both metrics are the same, don't do any conversion.
            // This makes distance(from:to:using:) O(1) for the
            // base metric.
            //
            // This assumes metrics don't have any state, so any instance
            // of the same metric will return the same values.
            return m1 as! M2.Unit
        }

        // TODO: figure out m1_fudge in xi-editor. I believe it's just an optimization, so this code is probably fine.
        // If you implement it, remember that the <= comparison becomes <.
        var m1 = m1
        var m2: M2.Unit = 0
        var node = self
        while !node.isLeaf {
            let parent = node
            for child in node.children {
                let childM1 = child.measure(using: from)
                if m1 <= childM1 {
                    node = child
                    break
                }
                m1 -= childM1
                m2 += child.measure(using: to)
            }
            assert(node != parent)
        }

        let base = from.convertToBaseUnits(m1, in: node.leaf)
        return m2 + to.convertFromBaseUnits(base, in: node.leaf)
    }
}

extension BTreeNode where Summary: BTreeDefaultMetric {
    func count<M>(_ metric: M, upThrough offset: Int) -> M.Unit where M: BTreeMetric<Summary> {
        convert(offset, from: Summary.defaultMetric, to: metric)
    }

    func countBaseUnits<M>(upThrough measured: M.Unit, measuredIn metric: M) -> Int where M: BTreeMetric<Summary> {
        convert(measured, from: metric, to: Summary.defaultMetric)
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

        func isBoundary<M>(in metric: M) -> Bool where M: BTreeMetric<Summary> {
            assert(rootStorage != nil)

            guard let leaf else {
                return false
            }

            if offsetInLeaf == 0 && !metric.canFragment {
                return true
            }

            switch metric.type {
            case .leading:
                if position == rootStorage!.count {
                    return true
                } else {
                    // Unlike the trailing case below, we don't have to peek at the
                    // next leaf if offsetInLeaf == leaf.count, because offsetInLeaf
                    // is guaranteed to be less than leaf.count unless we're at
                    // endIndex (position == root!.count), which we've already taken
                    // care of above.
                    return metric.isBoundary(offsetInLeaf, in: leaf)
                }
            case .trailing:
                if position == 0 {
                    return true
                } else if offsetInLeaf == 0 {
                    // We have to look to the previous leaf to
                    // see if we have a boundary.
                    let (prev, _) = peekPrevLeaf()!
                    return metric.isBoundary(prev.count, in: prev)
                } else {
                    return metric.isBoundary(offsetInLeaf, in: leaf)
                }
            case .atomic:
                if position == 0 || position == rootStorage!.count {
                    return true
                } else {
                    // Atomic metrics don't make the distinction between leading and
                    // trailing boundaries. When offsetInLeaf == 0, we could either
                    // choose to look at the start of the current leaf, or do what
                    // we do in with trailing metrics and look at the end of the previous
                    // leaf. Here, we do the former.
                    //
                    // I'm not sure if there's a more principled way of deciding which
                    // of these to do, but CharacterMetric works best if we look at the
                    // current leaf – looking at the current leaf's prefixCount is the
                    // only way to tell whether a character starts at the beginning of
                    // the leaf – and there are no other atomic metrics that care one
                    // way or another.
                    return metric.isBoundary(offsetInLeaf, in: leaf)
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
        mutating func prev<M>(using metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil)
            if leaf == nil || position == 0 {
                invalidate()
                return nil
            }

            // try to find a boundary within this leaf
            let origPos = position
            if offsetInLeaf > 0 {
                if let newOffsetInLeaf = metric.prev(offsetInLeaf, in: leaf!) {
                    position = offsetOfLeaf + newOffsetInLeaf
                    return position
                }
            }
    
            // We didn't find a boundary, go to the previous leaf and try again.
            if prevLeaf() == nil {
                // We were in the first leaf. We're done.
                return nil
            }
            if let position = last(withinLeafUsing: metric, originalPosition: origPos) {
                return position
            }

            // We've searched at least one full leaf backwards and
            // found nothing. Just start at the top and descend instead.
            //
            // TODO: it's possible this only works with trailing boundaries, but
            // I'm not sure.
            let measure = measure(upToLeafContaining: position, using: metric)
            descend(toLeafContaining: measure, asMeasuredBy: metric)
            if let pos = last(withinLeafUsing: metric, originalPosition: origPos) {
                return pos
            }
            invalidate()
            return nil
        }

        // Searches for the last boundary in the current leaf.
        //
        // If the last boundary is at the end of the leaf, it's only valid if
        // it's less than originalPosition.
        mutating func last<M>(withinLeafUsing metric: M, originalPosition: Int) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil && leaf != nil)
            if offsetOfLeaf + leaf!.count < originalPosition && metric.isBoundary(leaf!.count, in: leaf!) {
                nextLeaf()
                return position
            }
            if let newOffsetInLeaf = metric.prev(leaf!.count, in: leaf!) {
                position = offsetOfLeaf + newOffsetInLeaf
                return position
            }
            if offsetOfLeaf == 0 && (metric.type == .leading || metric.type == .atomic) {
                // Didn't find a boundary, but leading and atomic metrics have a boundary at startIndex.
                position = 0
                return position
            }

            return nil
        }

        @discardableResult
        mutating func next<M>(using metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil)
            if leaf == nil || position == rootStorage!.count {
                invalidate()
                return nil
            }

            if let pos = next(withinLeafUsing: metric) {
                return pos
            }

            // We didn't find a boundary, go to the next leaf and try again.
            if nextLeaf() == nil {
                // We were in the last leaf. We're done.
                return nil
            }

            // one more shot
            if let pos = next(withinLeafUsing: metric) {
                return pos
            }

            // We've searched at least one full leaf forwards and
            // found nothing. Just start at the top and descend instead.
            //
            // TODO: it's possible this only works with trailing boundaries, but
            // I'm not sure.
            let measure = measure(upToLeafContaining: position, using: metric)
            descend(toLeafContaining: measure+1, asMeasuredBy: metric)

            if let pos = next(withinLeafUsing: metric) {
                return pos
            }

            // we didn't find anything
            invalidate()
            return nil
        }

        mutating func next<M>(withinLeafUsing metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(rootStorage != nil && leaf != nil)

            let isLastLeaf = offsetOfLeaf + leaf!.count == rootStorage!.count

            let newOffsetInLeaf = metric.next(offsetInLeaf, in: leaf!)
            if newOffsetInLeaf == nil && isLastLeaf && (metric.type == .leading || metric.type == .atomic) {
                // Didn't find a boundary, but leading and atomic metrics have a boundary at endIndex.
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

        // For testing.
        var isValid: Bool {
            leaf != nil
        }

        func validate(for root: BTreeNode) {
            precondition(self.rootStorage === root.storage)
            precondition(self.mutationCount == root.mutationCount)
            precondition(self.leaf != nil)
        }

        func validate(_ other: Index) {
            precondition(rootStorage === other.rootStorage && rootStorage != nil)
            precondition(mutationCount == rootStorage!.mutationCount)
            precondition(mutationCount == other.mutationCount)
            precondition(leaf != nil && other.leaf != nil)
        }

        func assertValid(for root: BTreeNode) {
            assert(self.rootStorage === root.storage)
            assert(self.mutationCount == root.mutationCount)
            assert(self.leaf != nil)
        }

        func assertValid(_ other: Index) {
            assert(rootStorage === other.rootStorage && rootStorage != nil)
            assert(mutationCount == rootStorage!.mutationCount)
            assert(mutationCount == other.mutationCount)
            assert(leaf != nil && other.leaf != nil)
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

extension BTreeNode where Summary: BTreeDefaultMetric {
    func index<M>(before i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)

        var i = index(roundingDown: i, using: metric)
        precondition(i > startIndex, "Index out of bounds")
        let offset = i.prev(using: metric)
        if offset == nil {
            return startIndex
        }
        return i
    }

    func index<M>(after i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)

        precondition(i < endIndex, "Index out of bounds")
        var i = i
        let offset = i.next(using: metric)
        if offset == nil {
            return endIndex
        }
        return i
    }

    func index<M>(_ i: Index, offsetBy distance: M.Unit, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)

        var i = i
        let m = count(metric, upThrough: i.position)
        precondition(m+distance >= 0 && m+distance <= measure(using: metric), "Index out of bounds")
        let pos = countBaseUnits(upThrough: m + distance, measuredIn: metric)
        i.set(pos)

        return i
    }

    func index<M>(_ i: Index, offsetBy distance: M.Unit, limitedBy limit: Index, using metric: M) -> Index? where M: BTreeMetric<Summary> {
        i.validate(for: self)
        limit.validate(for: self)

        if distance < 0 && limit <= i {
            let l = self.distance(from: i, to: index(roundingUp: limit, using: metric), using: metric)
            if distance < l {
                return nil
            }
        } else if distance > 0 && limit >= i {
            let l = self.distance(from: i, to: index(roundingDown: limit, using: metric), using: metric)
            if distance > l {
                return nil
            }
        }

        return index(i, offsetBy: distance, using: metric)
    }

    func distance<M>(from start: Index, to end: Index, using metric: M) -> M.Unit where M: BTreeMetric<Summary> {
        start.validate(for: self)
        end.validate(for: self)

        if start == startIndex && end == endIndex {
            return measure(using: metric)
        }

        return count(metric, upThrough: end.position) - count(metric, upThrough: start.position)
    }

    func index<M>(roundingDown i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)

        if i.isBoundary(in: metric) {
            return i
        }

        var i = i
        let offset = i.prev(using: metric)
        if offset == nil {
            // Leading metrics don't have a boundary at pos == 0, but
            // in Swift, startIndex is always a boundary no matter what.
            return startIndex
        }
        return i
    }

    func index<M>(roundingUp i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: self)

        if i.isBoundary(in: metric) {
            return i
        }

        var i = i
        let offset = i.next(using: metric)
        if offset == nil {
            // Trailing metrics don't have a boundary at pos == count, but
            // in Swift, endIndex is always a boundary no matter what.
            return endIndex
        }
        return i
    }

    func index<M>(at offset: M.Unit, using metric: M) -> Index where M: BTreeMetric<Summary> {
        precondition(offset >= 0 && offset <= measure(using: metric), "index out of bounds")
        let count = countBaseUnits(upThrough: offset, measuredIn: metric)
        return Index(offsetBy: count, in: self)
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
        storage.summary = Summary(summarizing: storage.leaf)
    }

    mutating func updateNonLeafMetadata() {
        let height = storage.children[0].height + 1
        var count = 0
        var summary = Summary.zero

        for child in storage.children {
            assert(child.height + 1 == height)
            assert(!child.isUndersized)
            count += child.count
            summary += child.summary
        }

        storage.height = height
        storage.count = count
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

// TODO: Bubble up leaf counts in Node. Count should be
// O(1) and distance(from:to:) should be O(log(n))
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

// MARK: - Helpers

extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    func offset(by offset: Bound.Stride) -> Self {
        lowerBound.advanced(by: offset)..<upperBound.advanced(by: offset)
    }
}
