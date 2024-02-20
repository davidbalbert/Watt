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
final class OutlineViewDiffableDataSource<Data>: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate where Data: RandomAccessCollection, Data.Element: Identifiable {
    let outlineView: NSOutlineView
    let delegate: Delegate
    let cellProvider: (NSOutlineView, NSTableColumn, Data.Element) -> NSView
    var rowViewProvider: ((NSOutlineView, Data.Element) -> NSTableRowView)?
    var loadChildren: ((Data.Element) -> OutlineViewSnapshot<Data>?)?
    var validDropTargets: OutlineViewDropTargets = .any
    var onDrag: ((Data.Element) -> NSPasteboardWriting?)?

    var insertRowAnimation: NSTableView.AnimationOptions = .slideDown
    var removeRowAnimation: NSTableView.AnimationOptions = .slideUp

    private(set) var snapshot: OutlineViewSnapshot<Data>

    // keys are ObjectIdentifier of the types of the NSPasteboardReading classes
    private var selfDropHandlers: OrderedDictionary<ObjectIdentifier, [DropHandler<OutlineViewDropDestination>]> = [:]
    private var localDropHandlers: OrderedDictionary<ObjectIdentifier, [DropHandler<OutlineViewDropDestination>]> = [:]
    private var remoteDropHandlers: OrderedDictionary<ObjectIdentifier, [DropHandler<OutlineViewDropDestination>]> = [:]

    private var dragSource: DragSource = DragSource()

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

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        onDrag?(self[item]!)
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let handlers = dropHandlers(for: info)
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        let id = id(from: item)
        var destination = OutlineViewDropDestination(parent: self[id], index: index, location: outlineView.convert(info.draggingLocation, from: nil))

        var matches: [ObjectIdentifier: (handler: DropHandler<OutlineViewDropDestination>, items: [NSDraggingItem])] = [:]
        info.enumerateDraggingItems(for: outlineView, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matches(draggingItem, operation: info.draggingSourceOperationMask) }
            guard let handler else {
                return
            }

            matches[ObjectIdentifier(handler.type), default: (handler, [])].items.append(draggingItem)
        }

        let invocations = matches.values.sorted { a, b in
            let i = handlers.firstIndex { $0.type == a.handler.type }!
            let j = handlers.firstIndex { $0.type == b.handler.type }!
            return i < j
        }

        // The first matching handler determines the operation.
        var operation: NSDragOperation = []
        for (handler, items) in invocations {
            if handler.isValid(items, destination: &destination) {
                if info.draggingSourceOperationMask.rawValue % 2 == 0 {
                    operation = info.draggingSourceOperationMask
                } else {
                    operation = NSDragOperation(handler.operations.first!)
                }
                break
            }
        }

        if destination.parent?.id != id || destination.index != index {
            // Any retargeting done by the validator takes precedence over our normal retargeting rules.
            outlineView.setDropItem(destination.parent?.id, dropChildIndex: destination.index)
        } else {
            // If the validator didn't retarget, retarget based on validDropTargets
            retargetIfNecessary(destination: destination)
        }

        return operation
    }

    func retargetIfNecessary(destination: OutlineViewDropDestination) {
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

    func outlineView(_ outlineView: NSOutlineView, updateDraggingItemsForDrag draggingInfo: NSDraggingInfo) {
        if source(for: draggingInfo) == .self {
            return
        }

        let handlers = dropHandlers(for: draggingInfo)
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        var count = 0
        draggingInfo.enumerateDraggingItems(options: .clearNonenumeratedImages, for: outlineView, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matches(draggingItem, operation: draggingInfo.draggingSourceOperationMask) }!

            if let preview = handler.preview(draggingItem) {
                draggingItem.draggingFrame = preview.frame
                draggingItem.imageComponentsProvider = preview.imageComponentsProvider
            }
            count += 1
        }
        draggingInfo.numberOfValidItemsForDrop = count
        draggingInfo.draggingFormation = .list
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        let handlers = dropHandlers(for: info)
        // I had this as handlers.map(\.type) but I got this error at runtime:
        //     Thread 1: Fatal error: could not demangle keypath type from 'Xe6ReaderQam'
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }
        var destination = OutlineViewDropDestination(parent: self[item], index: index, location: outlineView.convert(info.draggingLocation, from: nil))

        var matches: [ObjectIdentifier: (handler: DropHandler<OutlineViewDropDestination>, items: [NSDraggingItem])] = [:]
        info.enumerateDraggingItems(for: outlineView, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matches(draggingItem, operation: info.draggingSourceOperationMask) }
            guard let handler else {
                return
            }

            matches[ObjectIdentifier(handler.type), default: (handler, [])].items.append(draggingItem)
        }

        var invocations = matches.values.sorted { a, b in
            let i = handlers.firstIndex { $0.type == a.handler.type }!
            let j = handlers.firstIndex { $0.type == b.handler.type }!
            return i < j
        }

        var operation: NSDragOperation = []
        for (handler, items) in invocations {
            if handler.isValid(items, destination: &destination) {
                if info.draggingSourceOperationMask.rawValue % 2 == 0 {
                    operation = info.draggingSourceOperationMask
                } else {
                    operation = NSDragOperation(handler.operations.first!)
                }
                break
            }
        }

        assert(operation != [])
        let dragOperation = DragOperation(operation)!

        invocations.removeAll { handler, items in
            !handler.operations.contains(dragOperation)
        }

        for (handler, items) in invocations {
            handler.run(draggingItems: items, destination: destination, operation: dragOperation)
        }

        // TODO: make handlers return a bool indicating whether they succeeded
        return invocations.count > 0
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        dragSource.draggingSession(session, for: outlineView, willBeginAt: screenPoint)
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt: NSPoint, operation: NSDragOperation) {
        // TODO: perhaps add session and endedAt to the handler's action.
        dragSource.draggingSession(session, for: outlineView, endedAt: endedAt, operation: operation)
    }
}

extension OutlineViewDiffableDataSource {
    struct OutlineViewDropDestination {
        var parent: Data.Element?
        var index: Int
        let location: NSPoint
    }

    // Register a handler for dropping an object of a given type onto the outline view.
    // Registration order is significant. An NSDraggingItem is matched first by type,
    // and then by DragOperation in the order you registered them.
    //
    // Specifically, if an NSDraggingItem can be deserialized into multiple registered types
    // for a given DragOperation, the type you register first will be picked.
    //
    // Once a type is registered, all subsequent DragOperations registered for that type will
    // inherit that types priority order. I.e. if you register [(A, .move), (B, .copy),
    // (A, .copy), (B, .move)], all operations on A will match before operations on B – the
    // final match order will be [(A, .move), (A, .copy), (B, .copy), (B, .move)].
    //
    // For simplicity, register all your types together so it's easy to see what's going on.
    //
    // You can register a single handler for multiple operations – i.e. to make a normal drag and
    // Command + drag (.generic) use the same handler.
    //
    // If you specify multiple operations and you drag over the outline view without holding any
    // keys down, the first DragOperation you specify for the handler is the one reported to the
    // outline view. I.e. if operations is [.move, .generic], and you're not holding down any
    // keys, .move will be reported to the outline view so that it can show the correct cursor.
    //
    // If we're receiving a drop from .self (source and destination are our NSOutlineView), both
    // .self and .local handlers will be considered with all .self handlers considered before any
    // .local handlers. If we're receiving the drop from some other view in our app (.local), only
    // .local handlers will be considered.
    func onDrop<T>(
        of type: T.Type,
        operations: [DragOperation],
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], OutlineViewDropDestination, DragOperation) -> Void,
        validator: @escaping ([T], inout OutlineViewDropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: NSPasteboardReading {
        precondition(!operations.isEmpty, "Must specify at least one operation")

        if type == NSURL.self, let fileURLsOnly = searchOptions[.urlReadingFileURLsOnly] as? Bool, fileURLsOnly == true {
            outlineView.registerForDraggedTypes([.fileURL])
        } else {
            outlineView.registerForDraggedTypes(type.readableTypes(for: NSPasteboard(name: .drag)))
        }

        let handler = DropHandler(type: T.self, operations: operations, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
        addDropHandler(handler, source: source)
    }

    // Conveience method for registering a handler with a single DragOperation.
    func onDrop<T>(
        of type: T.Type,
        operation: DragOperation,
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], OutlineViewDropDestination, DragOperation) -> Void,
        validator: @escaping ([T], inout OutlineViewDropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: NSPasteboardReading {
        onDrop(of: type, operations: [operation], source: source, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
    }

    func onDrop<T>(
        of type: T.Type,
        operations: [DragOperation],
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], OutlineViewDropDestination, DragOperation) -> Void,
        validator: @escaping ([T], inout OutlineViewDropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        var wrappedPreview: ((T.ReferenceType) -> DragPreview?)?
        if let preview {
            wrappedPreview = { reference in
                preview(reference as! T)
            }
        }

        onDrop(of: T.ReferenceType.self, operations: operations, source: source, searchOptions: searchOptions, action: { references, destination, operation in
            action(references.map { $0  as! T }, destination, operation)
        }, validator: { references, destination in
            validator(references.map { $0  as! T }, &destination)
        }, preview: wrappedPreview)
    }

    func onDrop<T>(
        of type: T.Type,
        operation: DragOperation,
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], OutlineViewDropDestination, DragOperation) -> Void,
        validator: @escaping ([T], inout OutlineViewDropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDrop(of: type, operations: [operation], source: source, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
    }

    private func addDropHandler(_ handler: DropHandler<OutlineViewDropDestination>, source: DragSourceType) {
        switch source {
        case .self:
            selfDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        case .local:
            localDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        case .remote:
            remoteDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        }
    }

    private func dropHandlers(for info: NSDraggingInfo) -> [DropHandler<OutlineViewDropDestination>] {
        switch source(for: info) {
        case .self:
            Array(selfDropHandlers.values.joined()) + Array(localDropHandlers.values.joined())
        case .local:
            Array(localDropHandlers.values.joined())
        case .remote:
            Array(remoteDropHandlers.values.joined())
        }
    }

    private func source(for info: NSDraggingInfo) -> DragSourceType {
        if info.draggingSource as? NSOutlineView == outlineView {
            return .self
        } else if info.draggingSource != nil {
            return .local
        } else {
            return .remote
        }
    }

    // MARK: Drag start handlers

    func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: NSPasteboardReading {
        dragSource.onDragStart(for: type, searchOptions: searchOptions, action: action)
    }

    func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        dragSource.onDragStart(for: type, searchOptions: searchOptions, action: action)
    }

    // MARK: Drag end handlers

    func onDragEnd<T>(
        for type: T.Type,
        operations: [DragOperation],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: NSPasteboardReading {
        dragSource.onDragEnd(for: type, operations: operations, searchOptions: searchOptions, action: action)
    }

    func onDragEnd<T>(
        for type: T.Type,
        operation: DragOperation,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: NSPasteboardReading {
        onDragEnd(for: type, operations: [operation], searchOptions: searchOptions, action: action)
    }

    func onDragEnd<T>(
        for type: T.Type,
        operations: [DragOperation],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        dragSource.onDragEnd(for: type, operations: operations, searchOptions: searchOptions, action: action)
    }

    func onDragEnd<T>(
        for type: T.Type,
        operation: DragOperation,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDragEnd(for: type, operations: [operation], searchOptions: searchOptions, action: action)
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
