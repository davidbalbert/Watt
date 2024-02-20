//
//  OutlineViewDiffableDataSource.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa

import Tree
import OrderedCollections

enum OutlineViewDropTargets {
    case onRows
    case betweenRows
    case any
}

@MainActor
final class OutlineViewDiffableDataSource<Data>: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, DragSource, DragDestination where Data: RandomAccessCollection, Data.Element: Identifiable {
    let outlineView: NSOutlineView
    let delegate: Delegate
    let cellProvider: (NSOutlineView, NSTableColumn, Data.Element) -> NSView
    var rowViewProvider: ((NSOutlineView, Data.Element) -> NSTableRowView)?
    var loadChildren: ((Data.Element) -> OutlineViewSnapshot<Data>?)?
    var validDropTargets: OutlineViewDropTargets = .any

    var insertRowAnimation: NSTableView.AnimationOptions = .slideDown
    var removeRowAnimation: NSTableView.AnimationOptions = .slideUp

    private(set) var snapshot: OutlineViewSnapshot<Data>

    internal var dragManager: DragManager
    internal var dropManager: DropManager<OutlineViewDropInfo>

    // TODO: is there a way to extract this into DragSource/DragManager? It depends on Data.Element, which means dragManager's
    // onDrag would have to have a different signature.
    var onDrag: ((Data.Element) -> NSPasteboardWriting?)?

    init(_ outlineView: NSOutlineView, delegate: NSOutlineViewDelegate? = nil, cellProvider: @escaping (NSOutlineView, NSTableColumn, Data.Element) -> NSView) {
        self.outlineView = outlineView
        self.delegate = Delegate(target: delegate ?? NullOutlineViewDelegate())
        self.cellProvider = cellProvider
        self.snapshot = OutlineViewSnapshot()

        self.dragManager = DragManager()
        self.dropManager = DropManager()

        super.init()

        self.delegate.dataSource = self
        self.outlineView.dataSource = self
        self.outlineView.delegate = self.delegate

        self.dragManager.view = outlineView
        self.dropManager.view = outlineView
    }

    var isEmpty: Bool {
        snapshot.isEmpty
    }

    subscript(id: Data.Element.ID) -> Data.Element? {
        snapshot[id]
    }

    private subscript(item: Any?) -> Data.Element? {
        snapshot[id(from: item)]
    }

    private func id(from item: Any?) -> Data.Element.ID? {
        if let item {
            return (item as! Data.Element.ID?)
        } else {
            return nil
        }
    }

    private func loadChildren(ofElementWithID id: Data.Element.ID?) {
        guard let loadChildren, let element = snapshot[id] else {
            return
        }

        if let newSnapshot = loadChildren(element) {
            // Snapshot should be the same except for the new data, so no need to diff.
            self.snapshot = newSnapshot
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let id = id(from: item)
        loadChildren(ofElementWithID: id)
        return snapshot.childIDs(ofElementWithID: id)?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let id = id(from: item)
        loadChildren(ofElementWithID: id)
        // we should only be asked for children of an item if it has children
        return snapshot.childIDs(ofElementWithID: id)![index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        snapshot.childIDs(ofElementWithID: id(from: item)) != nil
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        id(from: item)
    }

    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        guard let element = self[item] else {
            return nil
        }

        guard let codable = element as? Codable else {
            return nil
        }

        return try? PropertyListEncoder().encode(codable)
    }

    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        guard let data = object as? Foundation.Data else {
            return nil
        }

        guard let type = Data.Element.self as? Codable.Type else {
            return nil
        }

        guard let element = try? PropertyListDecoder().decode(type, from: data) else {
            return nil
        }

        return (element as! Data.Element).id
    }

    // MARK: Drag and Drop

    struct OutlineViewDropInfo {
        var parent: Data.Element?
        var index: Int
        let location: NSPoint
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        onDrag?(self[item]!)
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let id = id(from: item)
        var destination = OutlineViewDropInfo(parent: self[id], index: index, location: outlineView.convert(info.draggingLocation, from: nil))
        let operation = dropManager.validateDrop(info, dropInfo: &destination)

        if destination.parent?.id != id || destination.index != index {
            // Any retargeting done by the validator takes precedence over our normal retargeting rules.
            outlineView.setDropItem(destination.parent?.id, dropChildIndex: destination.index)
        } else {
            // If the validator didn't retarget, retarget based on validDropTargets
            retargetIfNecessary(destination: destination)
        }

        return operation
    }

    func outlineView(_ outlineView: NSOutlineView, updateDraggingItemsForDrag draggingInfo: NSDraggingInfo) {
        dropManager.updateDragPreviews(draggingInfo)
        draggingInfo.draggingFormation = .list
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        var destination = OutlineViewDropInfo(parent: self[item], index: index, location: outlineView.convert(info.draggingLocation, from: nil))
        return dropManager.acceptDrop(info, dropInfo: &destination)
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        dragManager.draggingSession(session, willBeginAt: screenPoint)
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt: NSPoint, operation: NSDragOperation) {
        // TODO: perhaps add session and endedAt to the handler's action.
        dragManager.draggingSession(session, endedAt: endedAt, operation: operation)
    }

    func retargetIfNecessary(destination: OutlineViewDropInfo) {
        let id = destination.parent?.id
        let index = destination.index
        let locationInView = destination.location

        if validDropTargets == .betweenRows && destination.index == NSOutlineViewDropOnItemIndex {
            let childIDs = snapshot.childIDs(ofElementWithID: id)
            if let childIDs, id == nil {
                // Dropping on the root. Retarget to the first or last child depending on
                // the location in the view.

                let firstRow = outlineView.rowView(atRow: 0, makeIfNecessary: false)
                if firstRow == nil || locationInView.y <= firstRow!.frame.minY {
                    outlineView.setDropItem(nil, dropChildIndex: 0)
                } else {
                    outlineView.setDropItem(nil, dropChildIndex: childIDs.count)
                }
            } else if childIDs != nil {
                // Dropping on an expandable node. Retarget to the first child.
                outlineView.setDropItem(id, dropChildIndex: 0)
            } else {
                assert(id != nil)
                // Dropping on a leaf node. Retarget to the next sibling.
                let parentID = snapshot.parentID(ofElementWithID: id!)
                let siblingIDs = snapshot.childIDs(ofElementWithID: parentID)!
                let idx = (siblingIDs.firstIndex(of: id!) ?? 0) + 1
                outlineView.setDropItem(parentID, dropChildIndex: idx)
            }
        } else if validDropTargets == .onRows && index == NSOutlineViewDropOnItemIndex {
            // if we're dropping on a leaf, retarget to it's parent – we can only drop on
            // expandable nodes.
            //
            // ID must be non-nil because the root (a nil id) is always expandable.
            if let id, snapshot.childIDs(ofElementWithID: id) == nil {
                let parentID = snapshot.parentID(ofElementWithID: id)
                outlineView.setDropItem(parentID, dropChildIndex: NSOutlineViewDropOnItemIndex)
            }
        } else if validDropTargets == .onRows {
            // we're dropping between nodes, so we need to retarget
            let childIDs = snapshot.childIDs(ofElementWithID: id)!
            if index == childIDs.count {
                // we're pointing after the last child, so retarget to self
                outlineView.setDropItem(id, dropChildIndex: NSOutlineViewDropOnItemIndex)
            } else {
                let childID = childIDs[index]
                let isExpandable = snapshot.childIDs(ofElementWithID: childID) != nil

                if isExpandable {
                    // pointing before an expandable node, so drop on that node
                    outlineView.setDropItem(childID, dropChildIndex: NSOutlineViewDropOnItemIndex)
                } else {
                    // pointing before a leaf node, so drop on self
                    outlineView.setDropItem(id, dropChildIndex: NSOutlineViewDropOnItemIndex)
                }
            }
        }

    }
}

// MARK: - NSOutlineViewDelegate

extension OutlineViewDiffableDataSource {
    class NullOutlineViewDelegate: NSObject, NSOutlineViewDelegate {}

    class Delegate: SimpleProxy, NSOutlineViewDelegate {
        weak var dataSource: OutlineViewDiffableDataSource?

        init(target: NSOutlineViewDelegate) {
            super.init(target: target)
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let dataSource, let tableColumn else {
                return nil
            }
            return dataSource.cellProvider(outlineView, tableColumn, dataSource[item]!)
        }

        func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            guard let dataSource else {
                return nil
            }
            return dataSource.rowViewProvider?(outlineView, dataSource[item]!)
        }
    }
}

// MARK: - Snapshots

extension TreeNode {
    init<Data>(_ element: Data.Element, children: KeyPath<Data.Element, Data?>) where Data: RandomAccessCollection, Data.Element: Identifiable, Value == Data.Element.ID {
        self.init(element.id, children: element[keyPath: children]?.map { TreeNode($0, children: children) } ?? [])
    }
}

extension TreeList {
    init<Data>(_ data: Data, children: KeyPath<Data.Element, Data?>) where Data: RandomAccessCollection, Data.Element: Identifiable, Value == Data.Element.ID {
        self.init(data.map { TreeNode($0, children: children) })
    }
}

struct OutlineViewSnapshot<Data> where Data: RandomAccessCollection, Data.Element: Identifiable {
    let ids: TreeList<Data.Element.ID>
    let children: KeyPath<Data.Element, Data?>?
    let index: [Data.Element.ID: Data.Element]
    let parents: [Data.Element.ID: Data.Element.ID]

    init() {
        self.ids = TreeList()
        self.children = nil
        self.index = [:]
        self.parents = [:]
    }

    init(_ data: Data, children: KeyPath<Data.Element, Data?>) {
        self.ids = TreeList(data, children: children)
        self.children = children

        var index: [Data.Element.ID: Data.Element] = [:]
        var parents: [Data.Element.ID: Data.Element.ID] = [:]
        var pending: [Data.Element] = Array(data)
        while !pending.isEmpty {
            let element = pending.removeFirst()
            index[element.id] = element
            if let children = element[keyPath: children] {
                pending.append(contentsOf: children)
                for child in children {
                    parents[child.id] = element.id
                }
            }
        }

        self.index = index
        self.parents = parents
    }

    var isEmpty: Bool {
        ids.isEmpty
    }

    subscript(id: Data.Element.ID?) -> Data.Element? {
        guard let id else {
            return nil
        }

        return index[id]
    }

    func parentID(ofElementWithID id: Data.Element.ID) -> Data.Element.ID? {
        parents[id]
    }

    func childIDs(ofElementWithID id: Data.Element.ID?) -> [Data.Element.ID]? {
        guard let id else {
            return ids.nodes.map(\.value)
        }

        guard let children else {
            assert(isEmpty)
            return nil
        }

        return index[id]?[keyPath: children]?.map(\.id)
    }

    func difference(from other: Self) -> Difference {
        let treeDiff = ids.difference(from: other.ids).inferringMoves()

        var reloads: [Data.Element.ID] = []
        for (id, element) in index {
            if let otherElement = other[id], element is any Equatable && !isEqual(element, otherElement) {
                reloads.append(id)
            }
        }
        return Difference(treeDiff: treeDiff, reloads: reloads)
    }
}

extension OutlineViewSnapshot where Data: RangeReplaceableCollection {
    init(_ root: Data.Element, children: KeyPath<Data.Element, Data?>) {
        self.init(Data([root]), children: children)
    }
}

extension OutlineViewSnapshot {
    struct Difference {
        typealias Change = TreeDifference<Data.Element.ID>.Change

        let treeDiff: TreeDifference<Data.Element.ID>
        let reloads: [Data.Element.ID]

        var isSingleMove: Bool {
            guard changes.count == 2 else { return false }
            guard case let .remove(_, _, insertPosition) = changes.first else { return false }
            return insertPosition != nil
        }

        var changes: [Change] {
            treeDiff.changes
        }
    }
}

extension OutlineViewDiffableDataSource {
    func apply(_ snapshot: OutlineViewSnapshot<Data>, animatingDifferences: Bool = true) {
        let old = self.snapshot
        let new = snapshot

        if old.isEmpty {
            self.snapshot = new
            outlineView.reloadData()
            return
        }

        let diff = new.difference(from: old)
        self.snapshot = new

        outlineView.beginUpdates()
        if animatingDifferences && diff.isSingleMove, case let .insert(newIndex, _, .some(oldIndex)) = diff.changes.last {
            outlineView.moveItem(at: oldIndex.offset, inParent: oldIndex.parent, to: newIndex.offset, inParent: newIndex.parent)
        } else {
            for change in diff.changes {
                switch change {
                case let .insert(newIndex, _, _):
                    outlineView.insertItems(at: [newIndex.offset], inParent: newIndex.parent, withAnimation: animatingDifferences ? insertRowAnimation : [])
                case let .remove(newIndex, _, _):
                    outlineView.removeItems(at: [newIndex.offset], inParent: newIndex.parent, withAnimation: animatingDifferences ? removeRowAnimation : [])
                }
            }
        }

        for id in diff.reloads {
            outlineView.reloadItem(id, reloadChildren: false)
        }

        outlineView.endUpdates()
    }
}
