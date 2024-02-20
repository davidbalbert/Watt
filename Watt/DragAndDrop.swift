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

protocol DragHandler {
    var type: NSPasteboardReading.Type { get }
    var searchOptions: [NSPasteboard.ReadingOptionKey: Any] { get }
}

protocol DraggingItemProvider {
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void)
}

extension DraggingItemProvider {
    func enumerateDraggingItems(for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateDraggingItems(options: [], for: view, classes: classArray, searchOptions: searchOptions, using: block)
    }
}

extension NSDraggingSession: DraggingItemProvider {}

struct DraggingInfoItemProvider: DraggingItemProvider {
    let draggingInfo: NSDraggingInfo

    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        draggingInfo.enumerateDraggingItems(options: enumOpts, for: view, classes: classArray, searchOptions: searchOptions, using: block)
    }
}

extension DragHandler {
    static func invocations(for view: NSView, draggingItemProvider: DraggingItemProvider, matching handlers: some Collection<Self>, _ doesMatch: @escaping (Self, NSDraggingItem) -> Bool) -> [(handler: Self, items: [NSDraggingItem])] {
        let classes = handlers.map { $0.type }
        let searchOptions = handlers.map(\.searchOptions).reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { left, right in left }) }

        var matches: [ObjectIdentifier: (handler: Self, items: [NSDraggingItem])] = [:]
        draggingItemProvider.enumerateDraggingItems(for: view, classes: classes, searchOptions: searchOptions) { draggingItem, index, stop in
            let handler = handlers.first { doesMatch($0, draggingItem) }
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

struct DragStartHandler: DragHandler {
    let type: NSPasteboardReading.Type
    let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
    private let matcher: (NSDraggingItem) -> Bool
    private let action: ([NSDraggingItem]) -> Void

    init<T>(type: T.Type, searchOptions: [NSPasteboard.ReadingOptionKey: Any], action: @escaping ([T]) -> Void) where T: NSPasteboardReading {
        self.type = type
        self.searchOptions = searchOptions
        self.matcher = { $0.item is T }
        self.action = { action($0.map { $0.item as! T }) }
    }

    func matches(_ draggingItem: NSDraggingItem) -> Bool {
        matcher(draggingItem)
    }

    // Calling run(draggingItems:) on a DragStartHandler where matches(_:) returns false for any
    // items will result in a runtime panic.
    func run(draggingItems: [NSDraggingItem]) {
        action(draggingItems)
    }
}

struct DragEndHandler: DragHandler {
    let type: NSPasteboardReading.Type
    let operations: [DragOperation]
    let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
    private let matcher: (NSDraggingItem, DragOperation) -> Bool
    private let action: ([NSDraggingItem], DragOperation) -> Void

    init<T>(type: T.Type, operations: [DragOperation], searchOptions: [NSPasteboard.ReadingOptionKey: Any], action: @escaping ([T], DragOperation) -> Void) where T: NSPasteboardReading {
        self.type = type
        self.operations = operations
        self.searchOptions = searchOptions
        self.matcher = { draggingItem, operation in
            draggingItem.item is T && operations.contains(operation)
        }
        self.action = { draggingItems, operation in
            action(draggingItems.map { $0.item as! T }, operation)
        }
    }

    func matches(_ draggingItem: NSDraggingItem, operation: DragOperation) -> Bool {
        matcher(draggingItem, operation)
    }

    // Calling run(draggingItems:) on a DragEndHandler where matches(_:) returns false for any
    // items will result in a runtime panic.
    func run(draggingItems: [NSDraggingItem], operation: DragOperation) {
        action(draggingItems, operation)
    }
}

struct DragPreview {
    let frame: NSRect
    let imageComponentsProvider: () -> [NSDraggingImageComponent]
}

// TODO: Maybe rename Destination -> DropTarget
struct DropHandler<Destination> {
    let type: NSPasteboardReading.Type
    let operations: [DragOperation]
    let searchOptions: [NSPasteboard.ReadingOptionKey: Any]
    private let matcher: (NSDraggingItem) -> Bool
    private let action: ([NSDraggingItem], Destination, DragOperation) -> Void
    private let validator: ([NSDraggingItem], inout Destination) -> Bool
    private let previewer: ((NSDraggingItem) -> DragPreview?)?

    init<T>(
        type: T.Type, 
        operations: [DragOperation], 
        searchOptions: [NSPasteboard.ReadingOptionKey: Any], 
        action: @escaping ([T], Destination, DragOperation) -> Void,
        validator: @escaping ([T], inout Destination) -> Bool,
        preview: ((T) -> DragPreview?)?
    ) where T: NSPasteboardReading {
        self.type = type
        self.operations = operations
        self.searchOptions = searchOptions
        self.matcher = { draggingItem in
            draggingItem.item is T
        }
        self.action = { draggingItems, destination, operation in
            action(draggingItems.map { $0.item as! T }, destination, operation)
        }
        self.validator = { draggingItems, destination in
            validator(draggingItems.map { $0.item as! T }, &destination)
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

    func matches(_ draggingItem: NSDraggingItem, operation nsOperation: NSDragOperation) -> Bool {
        matcher(draggingItem) && !nsOperation.intersection(NSDragOperation(operations)).isEmpty
    }

    // Calling run(draggingItems:) on a DragEndHandler where matches(_:) returns false for any
    // items will result in a runtime panic.
    func run(draggingItems: [NSDraggingItem], destination: Destination, operation: DragOperation) {
        action(draggingItems, destination, operation)
    }

    // Ditto
    func isValid(_ draggingItems: [NSDraggingItem], destination: inout Destination) -> Bool {
        validator(draggingItems, &destination)
    }

    func preview(_ draggingItem: NSDraggingItem) -> DragPreview? {
        previewer?(draggingItem)
    }
}

struct DragSource {
    private var dragStartHandlers: OrderedDictionary<ObjectIdentifier, [DragStartHandler]> = [:]
    private var dragEndHandlers: OrderedDictionary<ObjectIdentifier, [DragEndHandler]> = [:]

    // MARK: Drag start handlers

    mutating func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: NSPasteboardReading {
        let handler = DragStartHandler(type: T.self, searchOptions: searchOptions, action: action)
        addDragStartHandler(handler)
    }

    mutating func onDragStart<T>(
        for type: T.Type,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T]) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDragStart(for: T.ReferenceType.self, searchOptions: searchOptions) { references in
            action(references.map { $0 as! T })
        }
    }

    private mutating func addDragStartHandler(_ handler: DragStartHandler) {
        dragStartHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
    }

    // MARK: Drag end handlers

    mutating func onDragEnd<T>(
        for type: T.Type,
        operations: [DragOperation],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: NSPasteboardReading {
        let handler = DragEndHandler(type: T.self, operations: operations, searchOptions: searchOptions, action: action)
        addDragEndHandler(handler)
    }

    mutating func onDragEnd<T>(
        for type: T.Type,
        operation: DragOperation,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: NSPasteboardReading {
        onDragEnd(for: type, operations: [operation], searchOptions: searchOptions, action: action)
    }

    mutating func onDragEnd<T>(
        for type: T.Type,
        operations: [DragOperation],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDragEnd(for: T.ReferenceType.self, operations: operations, searchOptions: searchOptions) { references, operation in
            action(references.map { $0 as! T }, operation)
        }
    }

    mutating func onDragEnd<T>(
        for type: T.Type,
        operation: DragOperation,
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        action: @escaping ([T], DragOperation) -> Void
    ) where T: ReferenceConvertible, T.ReferenceType: NSPasteboardReading {
        onDragEnd(for: type, operations: [operation], searchOptions: searchOptions, action: action)
    }

    private mutating func addDragEndHandler(_ handler: DragEndHandler) {
        dragEndHandlers[ObjectIdentifier(handler.type), default: []].append(handler)
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, for view: NSView, willBeginAt screenPoint: NSPoint) {
        let handlers = dragStartHandlers.values.joined()
        let invocations = DragStartHandler.invocations(for: view, draggingItemProvider: session, matching: handlers) { handler, draggingItem in
            handler.matches(draggingItem)
        }

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems)
        }
    }

    func draggingSession(_ session: NSDraggingSession, for view: NSView, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        precondition(operation.rawValue % 2 == 0, "\(operation) should be a single value")

        // At this point, NSDragOperation should always be a single flag (power of two), so force unwrap is safe
        let dragOperation = DragOperation(operation)!

        let handlers = dragEndHandlers.values.joined()
        let invocations = DragEndHandler.invocations(for: view, draggingItemProvider: session, matching: handlers) { handler, draggingItem in
            handler.matches(draggingItem, operation: dragOperation)
        }

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems, operation: dragOperation)
        }
    }
}

struct DragDestination {

}
