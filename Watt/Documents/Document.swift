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

class Document: BaseDocument {
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

        let knownBinary: [UTType] = [
            .compositeContent,
            .image,
            .threeDContent,
            .audiovisualContent,
            .archive,
            .executable,
            .directory,
            .font,
            .aliasFile,
            .bookmark,
            .webArchive,
            .binaryPropertyList,
            .realityFile,
            .arReferenceObject
        ]

        // Adapted from CotEditor
        if knownBinary.contains(where: { type.conforms(to: $0) }) && !type.conforms(to: .svg) && url.pathExtension != ".ts" { // conflict between MPEG-2 streamclip file and TypeScript
            storage = .generic(url)
        } else {
            let string = try String(contentsOf: url)
            storage = .text(Buffer(string, language: type.language ?? .plainText))
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
        Swift.print("Document.addDocumentViewController", fileURL)
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

    override func shouldCloseWindowController(_ windowController: NSWindowController, delegate: Any?, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Swift.print("Document.shouldCloseWindowController")
        super.shouldCloseWindowController(windowController, delegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Swift.print("Document.canClose")
        super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    func canClose() async -> Bool {
        await withCheckedContinuation { continuation in
            canClose(
                withDelegate: self,
                shouldClose: #selector(document(_:shouldClose:contextInfo:)),
                contextInfo: Unmanaged.passRetained(CheckedContinuationReference(continuation)).toOpaque())
        }
    }

    func shouldCloseDocumentViewController(_ viewController: DocumentViewController) async -> Bool {
        Swift.print("Document.shouldCloseDocumentViewController")
        assert(documentViewControllers.contains(viewController))

        if documentViewControllers.count > 1 {
            return true
        }

        return await canClose()
    }

    @objc func document(_ document: Document, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer) {
        let continuation = Unmanaged<CheckedContinuationReference<Bool, Error>>.fromOpaque(contextInfo).takeRetainedValue()
        continuation.resume(returning: shouldClose)
    }
}
