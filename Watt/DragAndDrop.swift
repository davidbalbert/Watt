//
//  DragAndDrop.swift
//  Watt
//
//  Created by David Albert on 2/19/24.
//

import Cocoa

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
    let view: NSView

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint, handlers: some Collection<DragStartHandler>) {
        let invocations = DragStartHandler.invocations(for: view, draggingItemProvider: session, matching: handlers) { handler, draggingItem in
            handler.matches(draggingItem)
        }

        for (handler, draggingItems) in invocations {
            handler.run(draggingItems: draggingItems)
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation, handlers: some Collection<DragEndHandler>) {
        precondition(operation.rawValue % 2 == 0, "\(operation) should be a single value")

        // At this point, NSDragOperation should always be a single flag (power of two), so force unwrap is safe
        let dragOperation = DragOperation(operation)!

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
