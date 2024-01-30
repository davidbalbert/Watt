//
//  OutlineViewDiffableDataSource.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa

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

    private(set) var snapshot: OutlineViewSnapshot<Data>

    // keys are ObjectIdentifier of the types of the NSPasteboardReading classes
    private var selfDropHandlers: OrderedDictionary<ObjectIdentifier, [any DropHandler<DropDestination>]> = [:]
    private var localDropHandlers: OrderedDictionary<ObjectIdentifier, [any DropHandler<DropDestination>]> = [:]
    private var remoteDropHandlers: OrderedDictionary<ObjectIdentifier, [any DropHandler<DropDestination>]> = [:]

    private var dragStartHandlers: OrderedDictionary<ObjectIdentifier, [any DragStartHandler]> = [:]
    private var dragEndHandlers: OrderedDictionary<ObjectIdentifier, [any DragEndHandler]> = [:]

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
        let handlers = dropHandlers(for: info)
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }
        let destination = DropDestination(parent: self[item], index: index)

        var matches: [ObjectIdentifier: (handler: any DropHandler<DropDestination>, items: [NSDraggingItem])] = [:]
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
            if handler.isValid(items, destination: destination) {
                if info.draggingSourceOperationMask.rawValue % 2 == 0 {
                    operation = info.draggingSourceOperationMask
                } else {
                    operation = NSDragOperation(handler.operations.first!)
                }
                break
            }
        }
        return operation
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
        let destination = DropDestination(parent: self[item], index: index)

        var matches: [ObjectIdentifier: (handler: any DropHandler<DropDestination>, items: [NSDraggingItem])] = [:]

        // var success = false // can only transition from false to true
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
            if handler.isValid(items, destination: destination) {
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
        // TODO: perhaps add session and draggedItems (Element.IDs) to the handler's action.

        let handlers = dragStartHandlers.values.joined()
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        var matches: [ObjectIdentifier: (handler: any DragStartHandler, items: [NSDraggingItem])] = [:]
        session.enumerateDraggingItems(for: outlineView, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matches(draggingItem) }
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

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt: NSPoint, operation: NSDragOperation) {
        // TODO: perhaps add session and endedAt to the handler's action.

        let handlers = dragEndHandlers.values.joined()
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        var matches: [ObjectIdentifier: (handler: any DragEndHandler, items: [NSDraggingItem])] = [:]
        session.enumerateDraggingItems(for: outlineView, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matches(draggingItem, operation: operation) }
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

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems, operation: DragOperation(operation)!)
        }
    }
}

// MARK: - Drag and Drop

protocol DragStartHandler {
    associatedtype T: NSPasteboardReading

    var type: T.Type { get }
    var searchOptions: [NSPasteboard.ReadingOptionKey: Any] { get }
    var action: ([T]) -> Void { get }
}

extension DragStartHandler {
    func matches(_ draggingItem: NSDraggingItem) -> Bool {
        draggingItem.item is T
    }

    func run(draggingItems: [NSDraggingItem]) {
        action(draggingItems.map { $0.item as! T })
    }
}


protocol DragEndHandler {
    associatedtype T: NSPasteboardReading

    var type: T.Type { get }
    var operations: [DragOperation] { get }
    var searchOptions: [NSPasteboard.ReadingOptionKey: Any] { get }
    var action: ([T], DragOperation) -> Void { get }
}

extension DragEndHandler {
    func matches(_ draggingItem: NSDraggingItem, operation: NSDragOperation) -> Bool {
        // NSDragOperation should always be a single flag (power of two)
        draggingItem.item is T && operations.contains(DragOperation(operation)!)
    }

    func run(draggingItems: [NSDraggingItem], operation: DragOperation) {
        action(draggingItems.map { $0.item as! T }, operation)
    }
}

struct DragPreview {
    let frame: NSRect
    let imageComponentsProvider: () -> [NSDraggingImageComponent]
}

protocol DropHandler<Destination> {
    associatedtype T: NSPasteboardReading
    associatedtype Destination

    var type: T.Type { get }
    var operations: [DragOperation] { get }
    var searchOptions: [NSPasteboard.ReadingOptionKey: Any] { get }
    var action: ([T], Destination, DragOperation) -> Void { get }
    var validator: ([T], Destination) -> Bool { get }
    var preview: ((T) -> DragPreview?)? { get }
}

extension DropHandler {
    func matches(_ draggingItem: NSDraggingItem, operation nsOperation: NSDragOperation) -> Bool {
        draggingItem.item is T && !nsOperation.intersection(NSDragOperation(operations)).isEmpty
    }

    func isValid(_ draggingItems: [NSDraggingItem], destination: Destination) -> Bool {
        let values = draggingItems.map { $0.item as! T }
        return validator(values, destination)
    }
    
    func preview(_ draggingItem: NSDraggingItem) -> DragPreview? {
        guard let value = draggingItem.item as? T else {
            return nil
        }

        if let preview {
            return preview(value)
        }
        return nil
    }

    func run(draggingItems: [NSDraggingItem], destination: Destination, operation: DragOperation) {
        action(draggingItems.map { $0.item as! T }, destination, operation)
    }
}

enum DragSource {
    case `self`
    case local // includes self
    case remote
}

enum DragOperation: Hashable {
    case none
    case copy
    case link
    case generic
    case `private`
    case move
    case delete

    init?(_ operation: NSDragOperation) {
        switch operation {
        case []: self = .none
        case .copy: self = .copy
        case .link: self = .link
        case .generic: self = .generic
        case .private: self = .private
        case .move: self = .move
        case .delete: self = .delete
        default: return nil
        }
    }
}

extension NSDragOperation {
    init(_ operation: DragOperation) {
        switch operation {
        case .none: self = []
        case .copy: self = .copy
        case .link: self = .link
        case .generic: self = .generic
        case .private: self = .private
        case .move: self = .move
        case .delete: self = .delete
        }
    }

    init(_ operations: [DragOperation]) {
        self = operations.reduce(into: []) { $0.insert(NSDragOperation($1)) }
    }
}

extension OutlineViewDiffableDataSource {
    struct DropDestination {
        let parent: Data.Element?
        let index: Int
    }

    struct OutlineViewDropHandler<T>: DropHandler where T: NSPasteboardReading {
        let type: T.Type
        let operations: [DragOperation]
        let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
        let action: ([T], DropDestination, DragOperation) -> Void
        let validator: ([T], DropDestination) -> Bool
        let preview: ((T) -> DragPreview?)?
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
        source: DragSource,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DropDestination, DragOperation) -> Void,
        validator: @escaping ([T], DropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: NSPasteboardReading {
        precondition(!operations.isEmpty, "Must specify at least one operation")

        if type == NSURL.self, let fileURLsOnly = searchOptions[.urlReadingFileURLsOnly] as? Bool, fileURLsOnly == true {
            outlineView.registerForDraggedTypes([.fileURL])
        } else {
            outlineView.registerForDraggedTypes(type.readableTypes(for: NSPasteboard(name: .drag)))
        }

        let handler = OutlineViewDropHandler(type: T.self, operations: operations, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
        addDropHandler(handler, source: source)
    }

    // Conveience method for registering a handler with a single DragOperation.
    func onDrop<T>(
        of type: T.Type,
        operation: DragOperation,
        source: DragSource,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DropDestination, DragOperation) -> Void,
        validator: @escaping ([T], DropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: NSPasteboardReading {
        onDrop(of: type, operations: [operation], source: source, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
    }

    func onDrop<T>(
        of type: T.Type,
        operations: [DragOperation],
        source: DragSource,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:], 
        action: @escaping ([T], DropDestination, DragOperation) -> Void,
        validator: @escaping ([T], DropDestination) -> Bool = { _, _ in true },
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
            validator(references.map { $0  as! T }, destination)
        }, preview: wrappedPreview)
    }

    func onDrop<T>(
        of type: T.Type,
        operation: DragOperation,
        source: DragSource,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:], 
        action: @escaping ([T], DropDestination, DragOperation) -> Void,
        validator: @escaping ([T], DropDestination) -> Bool = { _, _ in true },
        preview: ((T) -> DragPreview?)? = nil
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDrop(of: type, operations: [operation], source: source, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
    }

    private func addDropHandler(_ handler: any DropHandler<DropDestination>, source: DragSource) {
        switch source {
        case .self:
            selfDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        case .local:
            localDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        case .remote:
            remoteDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        }
    }

    private func dropHandlers(for info: NSDraggingInfo) -> [any DropHandler<DropDestination>] {
        switch source(for: info) {
        case .self:
            Array(selfDropHandlers.values.joined()) + Array(localDropHandlers.values.joined())
        case .local:
            Array(localDropHandlers.values.joined())
        case .remote:
            Array(remoteDropHandlers.values.joined())
        }
    }

    private func source(for info: NSDraggingInfo) -> DragSource {
        if info.draggingSource as? NSOutlineView == outlineView {
            return .self
        } else if info.draggingSource != nil {
            return .local
        } else {
            return .remote
        }
    }

    // MARK: Drag start handlers

    struct OutlineViewDragStartHandler<T>: DragStartHandler where T: NSPasteboardReading {
        let type: T.Type
        let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
        let action: ([T]) -> Void
    }

    func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: NSPasteboardReading {
        let handler = OutlineViewDragStartHandler(type: T.self, searchOptions: searchOptions, action: action)
        addDragStartHandler(handler)
    }

    func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDragStart(for: T.ReferenceType.self, searchOptions: searchOptions) { references in
            action(references.map { $0 as! T })
        }
    }

    private func addDragStartHandler(_ handler: any DragStartHandler) {
        dragStartHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
    }

    
    // MARK: Drag end handlers

    struct OutlineViewDragEndHandler<T>: DragEndHandler where T: NSPasteboardReading {
        let type: T.Type
        let operations: [DragOperation]
        let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
        let action: ([T], DragOperation) -> Void
    }

    func onDragEnd<T>(
        for type: T.Type,
        operations: [DragOperation],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: NSPasteboardReading {
        let handler = OutlineViewDragEndHandler(type: T.self, operations: operations, searchOptions: searchOptions, action: action)
        addDragEndHandler(handler)
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
        onDragEnd(for: T.ReferenceType.self, operations: operations, searchOptions: searchOptions) { references, operation in
            action(references.map { $0 as! T }, operation)
        }
    }

    func onDragEnd<T>(
        for type: T.Type,
        operation: DragOperation,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDragEnd(for: type, operations: [operation], searchOptions: searchOptions, action: action)
    }

    private func addDragEndHandler(_ handler: any DragEndHandler) {
        dragEndHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
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
