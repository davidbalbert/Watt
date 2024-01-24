//
//  OutlineViewDiffableDataSource.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa
import SwiftUI

import Tree
import OrderedCollections

@MainActor
final class OutlineViewDiffableDataSource<Data>: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate where Data: RandomAccessCollection, Data.Element: Identifiable {
    let outlineView: NSOutlineView
    let delegate: Delegate
    let cellProvider: (NSOutlineView, NSTableColumn, Data.Element) -> NSView
    var rowViewProvider: ((NSOutlineView, Data.Element) -> NSTableRowView)?
    var loadChildren: ((Data.Element) -> OutlineViewSnapshot<Data>?)?
    var onDrag: ((Data.Element) -> NSPasteboardWriting?)?

    var insertRowAnimation: NSTableView.AnimationOptions = .slideDown
    var removeRowAnimation: NSTableView.AnimationOptions = .slideUp

    private var selfDropHandlers: [any OutlineViewDropHandler<Data.Element>] = []
    private var localDropHandlers: [any OutlineViewDropHandler<Data.Element>] = []
    private var remoteDropHandlers: [any OutlineViewDropHandler<Data.Element>] = []


    private(set) var snapshot: OutlineViewSnapshot<Data>

    init(_ outlineView: NSOutlineView, delegate: NSOutlineViewDelegate? = nil, cellProvider: @escaping (NSOutlineView, NSTableColumn, Data.Element) -> NSView) {
        self.outlineView = outlineView
        self.delegate = Delegate(target: delegate ?? NullOutlineViewDelegate())
        self.cellProvider = cellProvider
        self.snapshot = OutlineViewSnapshot()
        super.init()

        self.delegate.dataSource = self
        self.outlineView.dataSource = self
        self.outlineView.delegate = self.delegate
    }

    convenience init<Body>(_ outlineView: NSOutlineView, delegate: NSOutlineViewDelegate? = nil, @ViewBuilder cellProvider: @escaping (NSOutlineView, NSTableColumn, Data.Element) -> Body) where Body: View {
        self.init(outlineView, delegate: delegate) { outlineView, column, element in
            let rootView = cellProvider(outlineView, column, element)

            let hostingView: NSHostingView<Body>
            if let v = outlineView.makeView(withIdentifier: column.identifier, owner: nil) as? NSHostingView<Body> {
                hostingView = v
            } else {
                hostingView = NSHostingView(rootView: rootView)
                hostingView.identifier = column.identifier
            }

            hostingView.rootView = rootView
            hostingView.autoresizingMask = [.width, .height]

            let view = NSTableCellView()
            view.addSubview(hostingView)

            return view
        }
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
        return snapshot.childIds(ofElementWithID: id)?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let id = id(from: item)
        loadChildren(ofElementWithID: id)
        // we should only be asked for children of an item if it has children
        return snapshot.childIds(ofElementWithID: id)![index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        snapshot.childIds(ofElementWithID: id(from: item)) != nil
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        id(from: item)
    }

    // MARK: Drag and Drop

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        onDrag?(self[item]!)
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let operations = validOperations(for: source(for: info))

        var operation: NSDragOperation = []
        info.enumerateDraggingItems(for: outlineView, classes: operations.values.map(\.type)) { item, index, stop in
            let ops = operations[ObjectIdentifier(type(of: item.item))]?.operations ?? []
            for op in ops {
                let nsop = NSDragOperation(op)
                if info.draggingSourceOperationMask.contains(nsop) {
                    operation = nsop
                    stop.pointee = true
                    break
                }
            }

        }
        return operation
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        let handlers = handlers(for: source(for: info))
        let classes = handlers.map { $0.type }

        var success = false // can only transition from false to true
        info.enumerateDraggingItems(for: outlineView, classes: classes) { draggingItem, index, stop in
            let handler = handlers.first { $0.isValid(for: draggingItem, operation: info.draggingSourceOperationMask ) }!
            let destination = OutlineViewDropDestination(parent: self[item], index: index)
            handler.performOnDrop(destination: destination, draggingItem: draggingItem)
            success = true
        }
        return success
    }
}

// MARK: - Drag and Drop

protocol CustomReferenceConvertible {
    associatedtype ReferenceType: AnyObject
    init(_ reference: ReferenceType)
    var reference: ReferenceType { get }
}

extension NSDragOperation {
    init(_ operation: DragOperation) {
        switch operation {
        case .copy: self = .copy
        case .link: self = .link
        case .generic: self = .generic
        case .private: self = .private
        case .move: self = .move
        case .delete: self = .delete
        }
    }
}

protocol OutlineViewDropHandler<Element> {
    associatedtype Element: Identifiable
    associatedtype Reader: NSPasteboardReading

    var type: Reader.Type { get }
    var operation: DragOperation { get }

    func performOnDrop(destination: OutlineViewDropDestination<Element>, reader: Reader)
}

extension OutlineViewDropHandler {
    func isValid(for item: NSDraggingItem, operation: NSDragOperation) -> Bool {
        item.item is Reader && operation.contains(NSDragOperation(self.operation))
    }

    func performOnDrop(destination: OutlineViewDropDestination<Element>, draggingItem: NSDraggingItem) {
        performOnDrop(destination: destination, reader: draggingItem.item as! Reader)
    }
}

enum DragSource {
    case `self`
    case local // includes self
    case remote
}

enum DragOperation: Hashable {
    case copy
    case link
    case generic
    case `private`
    case move
    case delete
}

struct OutlineViewDropDestination<Element> where Element: Identifiable {
    let parent: Element?
    let index: Int
}

extension OutlineViewDiffableDataSource {
    struct DropHandler<Reader>: OutlineViewDropHandler where Reader: NSPasteboardReading {
        let type: Reader.Type
        let operation: DragOperation
        let onDrop: (OutlineViewDropDestination<Data.Element>, Reader) -> Void

        func performOnDrop(destination: OutlineViewDropDestination<Data.Element>, reader: Reader) {
            onDrop(destination, reader)
        }
    }

    struct ReferenceConvertibleDropHandler<T>: OutlineViewDropHandler where T: CustomReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        typealias Reader = T.ReferenceType
        let type: Reader.Type
        let operation: DragOperation
        let onDrop: (OutlineViewDropDestination<Data.Element>, T) -> Void

        func performOnDrop(destination: OutlineViewDropDestination<Data.Element>, reader: Reader) {
            onDrop(destination, T(reader))
        }
    }

    // var selfDropHandlers: [any OutlineViewDropHandler<Data>] = []
    // var localDropHandlers: [any OutlineViewDropHandler<Data>] = []
    // var remoteDropHandlers: [any OutlineViewDropHandler<Data>] = []

    func onDrop<T>(of type: T.Type, operation: DragOperation, source: DragSource, perform block: @escaping (OutlineViewDropDestination<Data.Element>, T) -> Void) where T: NSPasteboardReading {
        let handler = DropHandler(type: T.self, operation: operation, onDrop: block)
        addHandler(handler, source: source)
    }

    func onDrop<T>(of type: T.Type, operation: DragOperation, source: DragSource, perform block: @escaping (OutlineViewDropDestination<Data.Element>, T) -> Void) where T: CustomReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        let handler = ReferenceConvertibleDropHandler(type: T.ReferenceType.self, operation: operation, onDrop: block)
        addHandler(handler, source: source)
    }

    func addHandler(_ handler: any OutlineViewDropHandler<Data.Element>, source: DragSource) {
        switch source {
        case .self:
            selfDropHandlers.append(handler)
        case .local:
            localDropHandlers.append(handler)
        case .remote:
            remoteDropHandlers.append(handler)
        }
    }

    func validOperations(for source: DragSource) -> OrderedDictionary<ObjectIdentifier, (type: NSPasteboardReading.Type, operations: [DragOperation])> {
        var operations: OrderedDictionary<ObjectIdentifier, (type: NSPasteboardReading.Type, operations: [DragOperation])> = [:]

        for handler in handlers(for: source) {
            operations[ObjectIdentifier(handler.type), default: (handler.type, [])].operations.append(handler.operation)
        }

        return operations
    }

    func handlers(for source: DragSource) -> [any OutlineViewDropHandler<Data.Element>] {
        switch source {
        case .self:
            return selfDropHandlers
        case .local:
            return selfDropHandlers + localDropHandlers
        case .remote:
            return remoteDropHandlers
        }
    }

    func source(for info: NSDraggingInfo) -> DragSource {
        if info.draggingSource as? NSOutlineView == outlineView {
            return .self
        } else if info.draggingSource != nil {
            return .local
        } else {
            return .remote
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

    init() {
        self.ids = TreeList()
        self.children = nil
        self.index = [:]
    }

    init(_ data: Data, children: KeyPath<Data.Element, Data?>) {
        self.ids = TreeList(data, children: children)
        self.children = children

        var index: [Data.Element.ID: Data.Element] = [:]
        var pending: [Data.Element] = Array(data)
        while !pending.isEmpty {
            let element = pending.removeFirst()
            index[element.id] = element
            if let children = element[keyPath: children] {
                pending.append(contentsOf: children)
            }
        }

        self.index = index
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

    func childIds(ofElementWithID id: Data.Element.ID?) -> [Data.Element.ID]? {
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
