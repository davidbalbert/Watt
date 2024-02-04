//
//  Document.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa
import UniformTypeIdentifiers

enum DocumentStorage {
    case text(Buffer)
    case generic(URL)
}

class Document: NSDocument {
    var storage: DocumentStorage?
    var documentViewControllers: [DocumentViewController] = []

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }

    override class var autosavesInPlace: Bool {
        true
    }

    convenience init(type typeName: String) throws {
        // The docs say to call super.init(typeName:), but that's a convenience initializer,
        // so we can't do it. The docs also say this just calls super.init() and sets fileType
        // so hopefully this is good enough.
        self.init()
        fileType = typeName

        let type = UTType(typeName)
        assert(type == .plainText || type!.isSubtype(of: .plainText))
        storage = .text(Buffer())
    }

    override func read(from url: URL, ofType typeName: String) throws {
        let type = UTType(typeName) ?? .data

        if type.conforms(to: .plainText) {
            let string = try String(contentsOf: url)
            storage = .text(Buffer(string, language: type.language ?? .plainText))
        } else {
            storage = .generic(url)
        }
    }

    override func write(to url: URL, ofType typeName: String) throws {
        switch storage! {
        case let .text(buffer):
            try buffer.data.write(to: url, options: .atomic)
        case .generic:
            break
        }
    }

    override func makeWindowControllers() {
        switch storage! {
        case let .text(buffer):
            let windowController = TextDocumentWindowController(buffer: buffer)
            addWindowController(windowController)
        case .generic:
            // no-op, only text can be opened outside of a workspace
            break
        }
    }

    func makeDocumentViewController() -> DocumentViewController {
        switch storage! {
        case let .text(buffer):
            TextDocumentViewController(buffer: buffer)
        case let .generic(url):
            GenericDocumentViewController(url: url)
        }
    }

    func addDocumentViewController(_ viewController: DocumentViewController) {
        if documentViewControllers.contains(viewController) {
            return
        }
        
        viewController.document?.removeDocumentViewController(viewController)
        documentViewControllers.append(viewController)
        viewController.document = self
    }

    func removeDocumentViewController(_ viewController: DocumentViewController) {
        if let index = documentViewControllers.firstIndex(of: viewController) {
            documentViewControllers.remove(at: index)
            viewController.document = nil
        }
    }
}
