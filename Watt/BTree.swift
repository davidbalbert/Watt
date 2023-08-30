//
//  BTree.swift
//
//
//  Created by David Albert on 6/2/23.
//

import Foundation

// MARK: - Protocols

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

    // Measured in base units
    var count: Int { get }
    var isUndersized: Bool { get }
    mutating func pushMaybeSplitting(other: Self) -> Self?

    // Specified in base units from the start of self. Should be O(1).
    subscript(bounds: Range<Int>) -> Self { get }
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

    func needsLookback(_ offset: Int, in leaf: Summary.Leaf) -> Bool
    func needsLookahead(_ offset: Int, in leaf: Summary.Leaf) -> Bool

    // Prev is never called with offset == 0
    func prev(_ offset: Int, in leaf: Summary.Leaf, prevLeaf: Summary.Leaf?) -> Int?
    func next(_ offset: Int, in leaf: Summary.Leaf, nextLeaf: Summary.Leaf?) -> Int?

    var canFragment: Bool { get }
    var type: BTreeMetricType { get }
}

extension BTreeMetric {
    func needsLookback(_ offset: Int, in leaf: Summary.Leaf) -> Bool {
        false
    }

    func needsLookahead(_ offset: Int, in leaf: Summary.Leaf) -> Bool {
        false
    }
}

protocol BTree {
    associatedtype Summary: BTreeSummary

    var root: BTreeNode<Summary> { get set }

    init(_ root: BTreeNode<Summary>)
}

extension BTree {
    init(_ root: BTreeNode<Summary>, slicedBy range: Range<Int>) {
        assert(range.lowerBound >= 0 && range.upperBound <= root.count)

        var r = root

        var b = BTreeBuilder<Self>()
        b.push(&r, slicedBy: range)
        self = b.build()
    }
}

// MARK: - Node

final class BTreeNode<Summary> where Summary: BTreeSummary {
    static var minChild: Int { 4 }
    static var maxChild: Int { 8 }

    typealias Leaf = Summary.Leaf

    var height: Int
    var count: Int // in base units

    // children and leaf are mutually exclusive
    var _children: [BTreeNode]
    var _leaf: Leaf
    var summary: Summary

    var mutationCount: Int = 0

    #if DEBUG
    var cloneCount: Int = 0
    #endif

    var children: [BTreeNode] {
        _read {
            guard !isLeaf else { fatalError("children called on a leaf node") }
            yield _children
        }
        _modify {
            guard !isLeaf else { fatalError("children called on a leaf node") }
            yield &_children
        }
    }

    var leaf: Leaf {
        _read {
            guard isLeaf else { fatalError("leaf called on a non-leaf node") }
            yield _leaf
        }
        _modify {
            guard isLeaf else { fatalError("leaf called on a non-leaf node") }
            yield &_leaf
        }
    }

    init(_ leaf: Leaf) {
        self.height = 0
        self.count = leaf.count
        self._children = []
        self._leaf = leaf
        self.summary = Summary(summarizing: leaf)
    }

    init(_ children: [BTreeNode]) {
        assert(1 <= children.count && children.count <= BTreeNode.maxChild)
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
        self._children = children
        self._leaf = Leaf.zero
        self.summary = summary
    }

    init(cloning node: BTreeNode) {
        self.height = node.height
        self.mutationCount = node.mutationCount
        self.count = node.count
        self._children = node._children
        self._leaf = node._leaf
        self.summary = node.summary

        #if DEBUG
        self.cloneCount = node.cloneCount + 1
        #endif
    }

    convenience init() {
        self.init(Leaf.zero)
    }

    convenience init<C>(_ children: C) where C: Sequence, C.Element == BTreeNode {
        self.init(Array(children))
    }

    convenience init<C1, C2>(children leftChildren: C1, mergedWith rightChildren: C2) where C1: Collection, C2: Collection, C1.Element == BTreeNode, C1.Element == C2.Element {
        let count = leftChildren.count + rightChildren.count
        assert(count <= BTreeNode.maxChild*2)

        let children = [AnySequence(leftChildren), AnySequence(rightChildren)].joined()

        if count <= BTreeNode.maxChild {
            self.init(children)
        } else {
            let split = count / 2
            let left = BTreeNode(children.prefix(split))
            let right = BTreeNode(children.dropFirst(split))
            self.init([left, right])
        }
    }

    var isEmpty: Bool {
        count == 0
    }

    var isLeaf: Bool {
        return height == 0
    }

    var isUndersized: Bool {
        if isLeaf {
            return leaf.isUndersized
        } else {
            return count < BTreeNode.minChild
        }
    }

    // Mutating. Self must be unique at this point.
    func concatenate(_ other: BTreeNode) -> BTreeNode {
        let h1 = height
        let h2 = other.height

        if h1 < h2 {
            if h1 == h2 - 1 && !isUndersized {
                return BTreeNode(children: [self], mergedWith: other.children)
            }

            // Concatinate mutates self, but self is already guaranteed to be
            // unique at this point.
            let new = concatenate(other.children[0])
            if new.height == h2 - 1 {
                return BTreeNode(children: [new], mergedWith: other.children.dropFirst())
            } else {
                return BTreeNode(children: new.children, mergedWith: other.children.dropFirst())
            }
        } else if h1 == h2 {
            if !isUndersized && !other.isUndersized {
                return BTreeNode([self, other])
            } else if h1 == 0 {
                // Mutates self, but because concatinate requires a unique
                // self, we know self is already unique at this point.
                return merge(withLeaf: other)
            } else {
                return BTreeNode(children: children, mergedWith: other.children)
            }
        } else {
            if h2 == h1 - 1 && !other.isUndersized {
                return BTreeNode(children: children, mergedWith: [other])
            }

            // Because concatinate is mutating, we need to make sure that
            // children.last is unique before calling.
            if !isKnownUniquelyReferenced(&children[children.count-1]) {
                mutationCount &+= 1
                children[children.count-1] = children[children.count-1].clone()
            }

            let new = children[children.count - 1].concatenate(other)
            if new.height == h1 - 1 {
                return BTreeNode(children: children.dropLast(), mergedWith: [new])
            } else {
                return BTreeNode(children: children.dropLast(), mergedWith: new.children)
            }
        }
    }

    // Mutating. Self must be unique at this point.
    func merge(withLeaf other: BTreeNode) -> BTreeNode {
        assert(isLeaf && other.isLeaf)
        mutationCount &+= 1

        let newLeaf = leaf.pushMaybeSplitting(other: other.leaf)
        count = leaf.count
        summary = Summary(summarizing: leaf)

        if let newLeaf {
            return BTreeNode([self, BTreeNode(newLeaf)])
        } else {
            return self
        }
    }

    func clone() -> BTreeNode {
        // All properties are value types, so it's sufficient
        // to just create a new Node instance.
        return BTreeNode(cloning: self)
    }

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
            assert(node !== parent)
        }

        let base = from.convertToBaseUnits(m1, in: node.leaf)
        return m2 + to.convertFromBaseUnits(base, in: node.leaf)
    }
}


// MARK: - Basic operations

// These methods must be called on already validated indices.
extension BTreeNode where Summary: BTreeDefaultMetric {
    func index<M>(before i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: self)

        var i = i
        let offset = i.prev(using: metric)
        if offset == nil {
            fatalError("Index out of bounds")
        }
        return i
    }

    func index<M>(after i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: self)

        var i = i
        let offset = i.next(using: metric)
        if offset == nil {
            fatalError("Index out of bounds")
        }
        return i
    }

    func index<M>(_ i: Index, offsetBy distance: M.Unit, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: self)

        var i = i
        let m = count(metric, upThrough: i.position)
        precondition(m+distance >= 0 && m+distance <= measure(using: metric), "Index out of bounds")
        let pos = countBaseUnits(upThrough: m + distance, measuredIn: metric)
        i.set(pos)

        return i
    }

    func index<M>(_ i: Index, offsetBy distance: M.Unit, limitedBy limit: Index, using metric: M) -> Index? where M: BTreeMetric<Summary> {
        i.assertValid(for: self)
        limit.assertValid(for: self)

        let l = self.distance(from: i, to: limit, using: metric)
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }

        return index(i, offsetBy: distance, using: metric)
    }

    func distance<M>(from start: Index, to end: Index, using metric: M) -> M.Unit where M: BTreeMetric<Summary> {
        start.assertValid(for: self)
        end.assertValid(for: self)

        return count(metric, upThrough: end.position) - count(metric, upThrough: start.position)
    }

    func index<M>(roundingDown i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: self)

        if i.isBoundary(in: metric) {
            return i
        }

        return index(before: i, using: metric)
    }

    func index<M>(at offset: M.Unit, using metric: M) -> Index where M: BTreeMetric<Summary> {
        let count = countBaseUnits(upThrough: offset, measuredIn: metric)
        return Index(offsetBy: count, in: self)
    }
}

extension BTree {
    func measure<M>(using metric: M) -> M.Unit where M: BTreeMetric<Summary> {
        root.measure(using: metric)
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

extension BTree where Summary: BTreeDefaultMetric {
    func count<M>(_ metric: M, upThrough offset: Int) -> M.Unit where M: BTreeMetric<Summary> {
        root.count(metric, upThrough: offset)
    }

    func countBaseUnits<M>(upThrough measured: M.Unit, measuredIn metric: M) -> Int where M: BTreeMetric<Summary> {
        root.countBaseUnits(upThrough: measured, measuredIn: metric)
    }
}


// MARK: - Builder

struct BTreeBuilder<Tree> where Tree: BTree {
    typealias Node = BTreeNode<Tree.Summary>
    typealias Summary = Tree.Summary
    typealias Leaf = Summary.Leaf

    typealias PartialTree = (node: Node, isUnique: Bool)

    // the inner array always has at least one element
    var stack: [[PartialTree]] = []

    mutating func push(_ node: inout Node) {
        var isUnique = isKnownUniquelyReferenced(&node)
        var n = node

        while true {
            if let (lastNode, _) = stack.last?.last, lastNode.height < n.height {
                var popped: Node
                (popped, isUnique) = pop()

                if !isUnique {
                    popped = popped.clone()
                }

                n = popped.concatenate(n)
                isUnique = true
            } else if var (lastNode, _) = stack.last?.last, lastNode.height == n.height {
                if !lastNode.isUndersized && !n.isUndersized {
                    stack[stack.count - 1].append((n, isUnique))
                } else if n.isLeaf { // lastNode and n are both leafs
                    // This is here (rather than in the pattern match in the else if) because
                    // we can't do `if (var lastNode, let lastNodeIsUnique)`, and if they're both
                    // var, then we get a warning.
                    let lastNodeIsUnique = stack.last!.last!.isUnique

                    if !lastNodeIsUnique {
                        lastNode = lastNode.clone()
                        stack[stack.count - 1][stack[stack.count - 1].count - 1] = (lastNode, true)
                    }

                    let newLeaf = lastNode.leaf.pushMaybeSplitting(other: n.leaf)

                    lastNode.mutationCount &+= 1
                    lastNode.count = lastNode.leaf.count
                    lastNode.summary = Summary(summarizing: lastNode.leaf)

                    if let newLeaf {
                        assert(!newLeaf.isUndersized)
                        stack[stack.count - 1].append((Node(newLeaf), true))
                    }
                } else {
                    let c1 = lastNode.children
                    let c2 = n.children
                    let count = c1.count + c2.count
                    if count <= Node.maxChild {
                        stack[stack.count - 1].append((Node(c1 + c2), true))
                    } else {
                        let split = count / 2
                        let children = [c1, c2].joined()
                        stack[stack.count - 1].append((Node(children.prefix(split)), true))
                        stack[stack.count - 1].append((Node(children.dropFirst(split)), true))
                    }
                }

                if stack[stack.count - 1].count < Node.maxChild {
                    break
                }

                (n, isUnique) = pop()
            } else {
                stack.append([(n, isUnique)])
                break
            }
        }
    }

    mutating func push(_ node: inout Node, slicedBy range: Range<Int>) {
        if range.isEmpty {
            return
        }

        if range == 0..<node.count {
            // TODO: figure out and explain why we need to unconditionally clone here
            var n = node.clone()
            push(&n)
            return
        }

        if node.isLeaf {
            push(leaf: node.leaf, slicedBy: range)
        } else {
            var offset = 0
            for i in 0..<node.children.count {
                if range.upperBound <= offset {
                    break
                }

                let childRange = 0..<node.children[i].count
                let intersection = childRange.clamped(to: range.offset(by: -offset))
                push(&node.children[i], slicedBy: intersection)
                offset += node.children[i].count
            }
        }
    }

    mutating func push(leaf: Leaf) {
        var n = Node(leaf)
        push(&n)
    }

    mutating func push(leaf: Leaf, slicedBy range: Range<Int>) {
        push(leaf: leaf[range])
    }

    mutating func pop() -> PartialTree {
        let partialTrees = stack.removeLast()
        if partialTrees.count == 1 {
            return partialTrees[0]
        } else {
            // We are able to throw away isUnique for all our children, because
            // inside Builder, we only care about the uniqueness of the nodes
            // directly on the stack.
            //
            // In general, we do still care if some nodes are unique – specifically
            // when concatinating two nodes, the rightmost branch of the left tree
            // in the concatination is being mutated during the graft, so it needs to
            // be unique, but we take care of that in Node.concatinate.
            return (Node(partialTrees.map(\.node)), true)
        }
    }

    consuming func build() -> Tree {
        if stack.isEmpty {
            return Tree(Node())
        } else {
            var (n, _) = pop()
            while !stack.isEmpty {
                var (popped, isUnique) = pop()
                if !isUnique {
                    popped = popped.clone()
                }

                n = popped.concatenate(n)
            }

            return Tree(n)
        }
    }
}


// MARK: - Index

extension BTreeNode {
    struct PathElement {
        // An index is valid only if it's root present and it's mutation
        // count is equal to the root's mutation count. If both of those
        // are true, we're guaranteed that the path is valid, so we can
        // unowned instead of weak references for the nodes.
        unowned var node: BTreeNode
        var slot: Int // child index

        var child: BTreeNode {
            node.children[slot]
        }
    }

    struct Index {
        weak var root: BTreeNode?
        let mutationCount: Int

        var position: Int

        var path: [PathElement]

        var leaf: Leaf? // Present unless the index is invalid.
        var offsetOfLeaf: Int // Position of the first element of the leaf in base units. -1 if we're invalid.

        // Must be less than leaf.count unless we're at the end of the rope, in which case
        // it's equal to leaf.count.
        var offsetInLeaf: Int {
            position - offsetOfLeaf
        }

        init(offsetBy offset: Int, in root: BTreeNode) {
            precondition((0...root.count).contains(offset), "Index out of bounds")

            self.root = root
            self.mutationCount = root.mutationCount
            self.position = offset
            self.path = []
            self.leaf = nil
            self.offsetOfLeaf = -1

            descend()
        }

        init(startOf root: BTreeNode) {
            self.init(offsetBy: 0, in: root)
        }

        init(endOf root: BTreeNode) {
            self.init(offsetBy: root.count, in: root)
        }

        mutating func descend() {
            path = []
            var node = root! // assume we have a root
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
                path.append(PathElement(node: node, slot: slot))
                node = node.children[slot]
            }

            self.leaf = node.leaf
            self.offsetOfLeaf = offset
        }

        func isBoundary<M>(in metric: M) -> Bool where M: BTreeMetric<Summary> {
            assert(root != nil)

            guard let leaf else {
                return false
            }

            if offsetInLeaf == 0 && !metric.canFragment {
                return true
            }

            switch metric.type {
            case .leading:
                if position == root!.count {
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
                if position == 0 || position == root!.count {
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
            precondition((0...root!.count).contains(position), "Index out of bounds")

            self.position = position

            if let leaf {
                let leafEnd = offsetOfLeaf + leaf.count

                if position >= offsetOfLeaf && (position < leafEnd || position == leafEnd && position == root!.count) {
                    // We're still in the same leaf. No need to descend.
                    return
                }
            }

            descend()
        }

        @discardableResult
        mutating func prev<M>(using metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(root != nil)

            if leaf == nil {
                return nil
            }

            if position == 0 {
                invalidate()
                return nil
            }

            // try to find a boundary within this leaf
            if let offset = prev(withinLeafUsing: metric) {
                return offset
            }

            // If we didn't find a boundary, go to the previous leaf and
            // try again.
            if prevLeaf() == nil {
                // We were on the first leaf, so we're done.
                // prevLeaf invalidates if necessary
                return nil
            }

            // one more shot
            position = offsetOfLeaf + leaf!.count
            if let offset = prev(withinLeafUsing: metric) {
                return offset
            }

            // We've searched at least one full leaf backwards and
            // found nothing. Just start at the top and descend instead.
            //
            // TODO: it's possible this only works with trailing boundaries, but
            // I'm not sure.
            let measure = measure(upToLeafContaining: offsetOfLeaf, using: metric)
            descend(toLeafContaining: measure, asMeasuredBy: metric)

            // We're always valid after the above two lines
            position = offsetOfLeaf + leaf!.count
            if let offset = prev(withinLeafUsing: metric) {
                return offset
            }

            // we didn't find anything
            invalidate()
            return nil
        }

        @discardableResult
        mutating func next<M>(using metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(root != nil)

            if leaf == nil {
                return nil
            }

            if position == root!.count {
                invalidate()
                return nil
            }

            if let offset = next(withinLeafUsing: metric) {
                return offset
            }

            // There was no boundary in the leaf we started on. Move to the next one.
            if nextLeaf() == nil {
                // the leaf we started on was the last leaf, and we didn't
                // find a boundary, so now we're at the end. nextLeaf() will
                // call invalidate() in this case.
                return nil
            }

            // one more shot
            if let offset = next(withinLeafUsing: metric) {
                return offset
            }

            // We've searched at least one full leaf forwards and
            // found nothing. Just start at the top and descend instead.
            //
            // TODO: it's possible this only works with trailing boundaries, but
            // I'm not sure.
            let measure = measure(upToLeafContaining: offsetOfLeaf, using: metric)
            descend(toLeafContaining: measure+1, asMeasuredBy: metric)

            if let offset = next(withinLeafUsing: metric) {
                return offset
            }

            // we didn't find anything
            invalidate()
            return nil
        }

        mutating func prev<M>(withinLeafUsing metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(root != nil && leaf != nil)

            if offsetInLeaf == 0 {
                return nil
            }

            var prev: Leaf?
            if metric.needsLookback(offsetInLeaf, in: leaf!) {
                var i = self
                prev = i.prevLeaf()?.0
            }

            let newOffsetInLeaf = metric.prev(offsetInLeaf, in: leaf!, prevLeaf: prev)

            if let newOffsetInLeaf {
                position = offsetOfLeaf + newOffsetInLeaf
                return position
            }

            if offsetOfLeaf == 0 && (metric.type == .trailing || metric.type == .atomic) {
                // Didn't find a boundary, but trailing and atomic metrics have
                // a boundary at startIndex.
                position = 0
                return position
            }

            // We didn't find a boundary.
            return nil
        }

        mutating func next<M>(withinLeafUsing metric: M) -> Int? where M: BTreeMetric<Summary> {
            assert(root != nil && leaf != nil)

            let isLastLeaf = offsetOfLeaf + leaf!.count == root!.count

            var next: Leaf?
            if metric.needsLookahead(offsetInLeaf, in: leaf!) {
                var i = self
                next = i.nextLeaf()?.0
            }

            let newOffsetInLeaf = metric.next(offsetInLeaf, in: leaf!, nextLeaf: next)

            if newOffsetInLeaf == nil && isLastLeaf && (metric.type == .leading || metric.type == .atomic) {
                // Didn't find a boundary, but leading and atomic metrics have a
                // boundary at endIndex.
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
            assert(root != nil)

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
                path.append(PathElement(node: node, slot: node.children.count - 1))
                node = node.children[node.children.count - 1]
            }

            let leaf = node.leaf
            self.leaf = leaf
            self.offsetOfLeaf -= leaf.count
            self.position = offsetOfLeaf

            return read()
        }

        @discardableResult
        mutating func nextLeaf() -> (Leaf, Int)? {
            assert(root != nil)

            guard let leaf else {
                return nil
            }

            self.position = offsetOfLeaf + leaf.count

            if position == root!.count {
                invalidate()
                return nil
            }

            // ascend until we can go right
            while let el = path.last, el.slot == el.node.children.count - 1 {
                path.removeLast()
            }

            // move right
            path[path.count - 1].slot += 1

            var node = path[path.count - 1].child

            // descend left
            while !node.isLeaf {
                path.append(PathElement(node: node, slot: 0))
                node = node.children[0]
            }

            self.leaf = node.leaf
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
            assert(root != nil)

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

            var node = root!
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
            var node = root!
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
                path.append(PathElement(node: node, slot: slot))
                node = node.children[slot]
            }

            self.leaf = node.leaf
            self.position = offset
            self.offsetOfLeaf = offset
        }

        // For testing.
        var isValid: Bool {
            leaf != nil
        }

        func validate(for root: BTreeNode) {
            precondition(self.root === root)
            precondition(self.mutationCount == root.mutationCount)
            precondition(self.leaf != nil)
        }

        func assertValid(for root: BTreeNode) {
            assert(self.root === root)
            assert(self.mutationCount == root.mutationCount)
            assert(self.leaf != nil)
        }

        func validate(_ other: Index) {
            precondition(root === other.root && root != nil)
            precondition(mutationCount == root!.mutationCount)
            precondition(mutationCount == other.mutationCount)
            precondition(leaf != nil && other.leaf != nil)
        }

        func read() -> (Leaf, Int)? {
            guard let leaf else {
                return nil
            }

            return (leaf, offsetInLeaf)
        }

        mutating func invalidate() {
            self.leaf = nil
            self.offsetOfLeaf = -1
        }
    }

    var startIndex: Index {
        Index(startOf: self)
    }

    var endIndex: Index {
        Index(endOf: self)
    }
}

extension BTreeNode.Index: Comparable {
    static func < (left: BTreeNode.Index, right: BTreeNode.Index) -> Bool {
        left.validate(right)
        return left.position < right.position
    }

    static func == (left: BTreeNode.Index, right: BTreeNode.Index) -> Bool {
        left.validate(right)
        return left.position == right.position
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

extension BTreeNode.LeavesView: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: BTreeNode.Index

        mutating func next() -> Summary.Leaf? {
            guard let (leaf, _) = index.read() else {
                return nil
            }

            index.nextLeaf()
            return leaf
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: root.startIndex)
    }

    var startIndex: BTreeNode.Index {
        root.startIndex
    }

    var endIndex: BTreeNode.Index {
        root.endIndex
    }

    subscript(position: BTreeNode.Index) -> Summary.Leaf {
        position.validate(for: root)
        let (leaf, _) = position.read()!
        return leaf
    }

    func index(before i: BTreeNode.Index) -> BTreeNode.Index {
        i.validate(for: root)
        var i = i
        _ = i.prevLeaf()!
        return i
    }

    func index(after i: BTreeNode.Index) -> BTreeNode.Index {
        i.validate(for: root)
        var i = i
        _ = i.nextLeaf()!
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
                return a === b
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

    // Returns a range covering the entire changed portion of the
    // original tree and the length of the newly inserted tree.
    func summary() -> (Range<Int>, Int) {
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
            case let .insert(tree):
                return sum + tree.count
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

    mutating func delete(_ range: Range<Int>) {
        precondition(range.lowerBound >= lastOffset, "ranges must be sorted")
        if lastOffset < range.lowerBound {
            delta.elements.append(.copy(lastOffset, range.lowerBound))
        }
        lastOffset = range.upperBound
    }

    mutating func replace(_ range: Range<Int>, with tree: Tree) {
        delete(range)
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
                var n = node.clone()
                b.push(&n)
            }
        }
        return b.build()
    }
}

// MARK: - Helpers


extension Range<Int> {
    init<Summary>(fromBTreeRange range: Range<BTreeNode<Summary>.Index>) {
        self.init(uncheckedBounds: (range.lowerBound.position, range.upperBound.position))
    }
}

extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    func offset(by offset: Bound.Stride) -> Self {
        lowerBound.advanced(by: offset)..<upperBound.advanced(by: offset)
    }
}
