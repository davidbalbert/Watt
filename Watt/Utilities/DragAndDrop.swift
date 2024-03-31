//
//  DragAndDrop.swift
//  Watt
//
//  Created by David Albert on 2/19/24.
//

import Cocoa
import OrderedCollections

enum DragSourceType {
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
}

extension DragOperation {
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

fileprivate protocol Handler {
    var type: NSPasteboardReading.Type { get }
    var searchOptions: [NSPasteboard.ReadingOptionKey: Any] { get }
}

fileprivate typealias Invocation<H> = (handler: H, items: [NSDraggingItem]) where H: Handler

extension Handler {
    func matchesType(of draggingItem: NSDraggingItem) -> Bool {
        Swift.type(of: draggingItem.item) == type
    }

    static func invocations(
        options enumOpts: NSDraggingItemEnumerationOptions = [],
        for view: NSView, draggingItemProvider: DraggingItemProvider,
        matching handlers: some Collection<Self>,
        _ doesMatch: @escaping (Self, NSDraggingItem) -> Bool = { _, _ in true }
    ) -> [Invocation<Self>] {
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        var matches: [ObjectIdentifier: Invocation<Self>] = [:]
        draggingItemProvider.enumerateDraggingItems(options: enumOpts, for: view, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matchesType(of: draggingItem) && doesMatch($0, draggingItem) }
            guard let handler else {
                return
            }

            matches[ObjectIdentifier(handler.type), default: (handler, [])].items.append(draggingItem)
        }

        return matches.values.sorted { a, b in
            let i = handlers.firstIndex { $0.type == a.handler.type }!
            let j = handlers.firstIndex { $0.type == b.handler.type }!
            return i < j
        }
    }
}

fileprivate protocol DraggingItemProvider {
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void)
}

extension NSDraggingSession: DraggingItemProvider {}

fileprivate struct DraggingInfoItemProvider: DraggingItemProvider {
    let draggingInfo: NSDraggingInfo

    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        draggingInfo.enumerateDraggingItems(options: enumOpts, for: view, classes: classArray, searchOptions: searchOptions, using: block)
    }
}

fileprivate struct DragStartHandler: Handler {
    let type: NSPasteboardReading.Type
    let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
    private let action: ([NSDraggingItem]) -> Void

    init<T>(type: T.Type, searchOptions: [NSPasteboard.ReadingOptionKey: Any], action: @escaping ([T]) -> Void) where T: NSPasteboardReading {
        self.type = type
        self.searchOptions = searchOptions
        self.action = { action($0.map { $0.item as! T }) }
    }

    func run(draggingItems: [NSDraggingItem]) {
        action(draggingItems)
    }
}

fileprivate struct DragEndHandler: Handler {
    let type: NSPasteboardReading.Type
    let operations: [DragOperation]
    let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
    private let action: ([NSDraggingItem], DragOperation) -> Void

    init<T>(type: T.Type, operations: [DragOperation], searchOptions: [NSPasteboard.ReadingOptionKey: Any], action: @escaping ([T], DragOperation) -> Void) where T: NSPasteboardReading {
        self.type = type
        self.operations = operations
        self.searchOptions = searchOptions
        self.action = { draggingItems, operation in
            action(draggingItems.map { $0.item as! T }, operation)
        }
    }

    func run(draggingItems: [NSDraggingItem], operation: DragOperation) {
        action(draggingItems, operation)
    }
}

@MainActor
protocol DragSource: AnyObject {
    var dragManager: DragManager { get set }
}

extension DragSource {
    func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: NSPasteboardReading {
        let handler = DragStartHandler(type: T.self, searchOptions: searchOptions, action: action)
        dragManager.addDragStartHandler(handler)
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

    func onDragEnd<T>(
        for type: T.Type,
        operations: [DragOperation],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: NSPasteboardReading {
        let handler = DragEndHandler(type: T.self, operations: operations, searchOptions: searchOptions, action: action)
        dragManager.addDragEndHandler(handler)
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
}

struct DragManager {
    weak var view: NSView?

    // keys are ObjectIdentifier of the types of the NSPasteboardReading classes
    private var dragStartHandlers: OrderedDictionary<ObjectIdentifier, [DragStartHandler]> = [:]
    private var dragEndHandlers: OrderedDictionary<ObjectIdentifier, [DragEndHandler]> = [:]

    fileprivate mutating func addDragStartHandler(_ handler: DragStartHandler) {
        dragStartHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
    }

    // MARK: Drag end handlers

    fileprivate mutating func addDragEndHandler(_ handler: DragEndHandler) {
        dragEndHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        guard let view else {
            return
        }

        let handlers = dragStartHandlers.values.joined()
        let invocations = DragStartHandler.invocations(for: view, draggingItemProvider: session, matching: handlers)

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems)
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        precondition(operation.rawValue % 2 == 0, "\(operation) should be a single value")

        guard let view else {
            return
        }

        // At this point, NSDragOperation should always be a single flag (power of two), so force unwrap is safe
        let dragOperation = DragOperation(operation)!

        let handlers = dragEndHandlers.values.joined()
        let invocations = DragEndHandler.invocations(for: view, draggingItemProvider: session, matching: handlers) { handler, draggingItem in
            handler.operations.contains(dragOperation)
        }

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems, operation: dragOperation)
        }
    }
}


struct DragPreview {
    let frame: NSRect
    let imageComponentsProvider: () -> [NSDraggingImageComponent]
}

fileprivate struct DropHandler<DropInfo>: Handler {
    let type: NSPasteboardReading.Type
    let operations: [DragOperation]
    let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
    private let action: ([NSDraggingItem], DropInfo, DragOperation) -> Void
    private let validator: (([NSDraggingItem], inout DropInfo) -> Bool)
    private let previewer: ((NSDraggingItem) -> DragPreview?)?

    init<T>(
        type: T.Type, 
        operations: [DragOperation], 
        searchOptions: [NSPasteboard.ReadingOptionKey: Any], 
        action: @escaping ([T], DropInfo, DragOperation) -> Void,
        validator: (([T], inout DropInfo) -> Bool)?,
        preview: ((T) -> DragPreview?)?
    ) where T: NSPasteboardReading {
        self.type = type
        self.operations = operations
        self.searchOptions = searchOptions
        self.action = { draggingItems, dropInfo, operation in
            action(draggingItems.map { $0.item as! T }, dropInfo, operation)
        }

        self.validator = { draggingItems, dropInfo in
            validator?(draggingItems.map { $0.item as! T }, &dropInfo) ?? true
        }

        if let preview {
            self.previewer = { draggingItem in
                guard let value = draggingItem.item as? T else {
                    return nil
                }

                return preview(value)
            }
        } else {
            self.previewer = nil
        }
    }

    func matches(operationMask: NSDragOperation) -> Bool {
        !operationMask.intersection(NSDragOperation(operations)).isEmpty
    }

    // Calling run(draggingItems:) on a DragEndHandler where matches(_:) returns false for any
    // items will result in a runtime panic.
    func run(draggingItems: [NSDraggingItem], dropInfo: DropInfo, operation: DragOperation) {
        action(draggingItems, dropInfo, operation)
    }

    // Ditto
    func isValid(_ draggingItems: [NSDraggingItem], dropInfo: inout DropInfo) -> Bool {
        validator(draggingItems, &dropInfo)
    }

    func preview(_ draggingItem: NSDraggingItem) -> DragPreview? {
        previewer?(draggingItem)
    }
}

@MainActor
protocol DragDestination: AnyObject {
    associatedtype DropInfo

    var dropManager: DropManager<DropInfo> { get set }
}

extension DragDestination {
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
    // If you specify multiple operations and you drag over the view without holding any keys
    // down, the first DragOperation you specify for the handler is the one reported to the
    // view. I.e. if operations is [.move, .generic], and you're not holding down any keys,
    // .move will be reported to the view so that it can show the correct cursor.
    //
    // If we're receiving a drop from .self (source and destination are our NSView), both
    // .self and .local handlers will be considered with all .self handlers considered before any
    // .local handlers. If we're receiving the drop from some other view in our app (.local), only
    // .local handlers will be considered.
    func onDrop<T>(
        of type: T.Type,
        operations: [DragOperation],
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DropInfo, DragOperation) -> Void,
        validator: (([T], inout DropInfo) -> Bool)? = nil,
        preview: ((T) -> DragPreview?)? = nil
    ) where T: NSPasteboardReading {
        precondition(!operations.isEmpty, "Must specify at least one operation")

        if type == NSURL.self, let fileURLsOnly = searchOptions[.urlReadingFileURLsOnly] as? Bool, fileURLsOnly == true {
            dropManager.registerForDraggedTypes([.fileURL])
        } else {
            dropManager.registerForDraggedTypes(type.readableTypes(for: NSPasteboard(name: .drag)))
        }

        let handler = DropHandler(type: T.self, operations: operations, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
        dropManager.addDropHandler(handler, source: source)
    }

    // Conveience method for registering a handler with a single DragOperation.
    func onDrop<T>(
        of type: T.Type,
        operation: DragOperation,
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DropInfo, DragOperation) -> Void,
        validator: (([T], inout DropInfo) -> Bool)? = nil,
        preview: ((T) -> DragPreview?)? = nil
    ) where T: NSPasteboardReading {
        onDrop(of: type, operations: [operation], source: source, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
    }

    func onDrop<T>(
        of type: T.Type,
        operations: [DragOperation],
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DropInfo, DragOperation) -> Void,
        validator: (([T], inout DropInfo) -> Bool)? = nil,
        preview: ((T) -> DragPreview?)? = nil
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        var wrappedPreview: ((T.ReferenceType) -> DragPreview?)?
        if let preview {
            wrappedPreview = { reference in
                preview(reference as! T)
            }
        }

        onDrop(of: T.ReferenceType.self, operations: operations, source: source, searchOptions: searchOptions, action: { references, dropInfo, operation in
            action(references.map { $0 as! T }, dropInfo, operation)
        }, validator: { references, dropInfo in
            validator?(references.map { $0 as! T }, &dropInfo) ?? true
        }, preview: wrappedPreview)
    }

    func onDrop<T>(
        of type: T.Type,
        operation: DragOperation,
        source: DragSourceType,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DropInfo, DragOperation) -> Void,
        validator: (([T], inout DropInfo) -> Bool)? = nil,
        preview: ((T) -> DragPreview?)? = nil
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDrop(of: type, operations: [operation], source: source, searchOptions: searchOptions, action: action, validator: validator, preview: preview)
    }
}

struct DropManager<DropInfo> {
    weak var view: NSView?

    // keys are ObjectIdentifier of the types of the NSPasteboardReading classes
    private var selfDropHandlers: OrderedDictionary<ObjectIdentifier, [DropHandler<DropInfo>]> = [:]
    private var localDropHandlers: OrderedDictionary<ObjectIdentifier, [DropHandler<DropInfo>]> = [:]
    private var remoteDropHandlers: OrderedDictionary<ObjectIdentifier, [DropHandler<DropInfo>]> = [:]

    fileprivate func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {
        view?.registerForDraggedTypes(newTypes)
    }

    fileprivate mutating func addDropHandler(_ handler: DropHandler<DropInfo>, source: DragSourceType) {
        switch source {
        case .self:
            selfDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        case .local:
            localDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        case .remote:
            remoteDropHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
        }
    }

    // MARK: NSDraggingDestination

    func validateDrop(_ draggingInfo: NSDraggingInfo, dropInfo: inout DropInfo) -> NSDragOperation {
        guard let view else {
            return []
        }

        let handlers = dropHandlers(for: draggingInfo)
        let itemProvider = DraggingInfoItemProvider(draggingInfo: draggingInfo)
        let invocations = DropHandler<DropInfo>.invocations(for: view, draggingItemProvider: itemProvider, matching: handlers) { handler, draggingItem in
            handler.matches(operationMask: draggingInfo.draggingSourceOperationMask)
        }

        // The first valid invocation determines the operation.
        var operation: NSDragOperation = []
        for (handler, items) in invocations {
            if handler.isValid(items, dropInfo: &dropInfo) {
                if draggingInfo.draggingSourceOperationMask.rawValue % 2 == 0 {
                    operation = draggingInfo.draggingSourceOperationMask
                } else {
                    operation = NSDragOperation(handler.operations.first!)
                }
                break
            }
        }

        return operation
    }

    func acceptDrop(_ draggingInfo: NSDraggingInfo, dropInfo: inout DropInfo) -> Bool {
        guard let view else {
            return false
        }

        let handlers = dropHandlers(for: draggingInfo)
        let itemProvider = DraggingInfoItemProvider(draggingInfo: draggingInfo)
        var invocations = DropHandler<DropInfo>.invocations(for: view, draggingItemProvider: itemProvider, matching: handlers) { handler, draggingItem in
            handler.matches(operationMask: draggingInfo.draggingSourceOperationMask)
        }

        // The first valid invocation determines the operation.
        var operation: NSDragOperation = []
        for (handler, items) in invocations {
            if handler.isValid(items, dropInfo: &dropInfo) {
                if draggingInfo.draggingSourceOperationMask.rawValue % 2 == 0 {
                    operation = draggingInfo.draggingSourceOperationMask
                } else {
                    operation = NSDragOperation(handler.operations.first!)
                }
                break
            }
        }

        assert(operation != [])
        let dragOperation = DragOperation(operation)!

        invocations.removeAll { handler, _ in
            !handler.operations.contains(dragOperation)
        }

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems, dropInfo: dropInfo, operation: dragOperation)
        }

        // TODO: make handlers return a bool indicating whether they succeeded
        return invocations.count > 0
    }

    func updateDragPreviews(_ draggingInfo: NSDraggingInfo) {
        guard let view else {
            return
        }

        // No need to update previews if we're also the drag source.
        if source(for: draggingInfo, view: view) == .self {
            return
        }

        let handlers = dropHandlers(for: draggingInfo)
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        var count = 0
        draggingInfo.enumerateDraggingItems(options: .clearNonenumeratedImages, for: view, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { $0.matches(operationMask: draggingInfo.draggingSourceOperationMask) }!

            if let preview = handler.preview(draggingItem) {
                draggingItem.draggingFrame = preview.frame
                draggingItem.imageComponentsProvider = preview.imageComponentsProvider
            }
            count += 1
        }
        draggingInfo.numberOfValidItemsForDrop = count
    }

    private func dropHandlers(for info: NSDraggingInfo) -> [DropHandler<DropInfo>] {
        guard let view else {
            return []
        }

        switch source(for: info, view: view) {
        case .self:
            return Array(selfDropHandlers.values.joined()) + Array(localDropHandlers.values.joined())
        case .local:
            return Array(localDropHandlers.values.joined())
        case .remote:
            return Array(remoteDropHandlers.values.joined())
        }
    }

    private func source(for info: NSDraggingInfo, view: NSView) -> DragSourceType {
        if info.draggingSource as? NSView == view {
            return .self
        } else if info.draggingSource != nil {
            return .local
        } else {
            return .remote
        }
    }
}
