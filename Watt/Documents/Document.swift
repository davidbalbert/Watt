//
//  Document.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa
import UniformTypeIdentifiers
import os

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

    // TODO: support asyncronous saving
    // When we do this, make sure to look at performActivity(withSynchronousWaiting:using:).
    // See https://download.developer.apple.com/videos/wwdc_2011__hd/session_107__autosave_and_versions_in_mac_os_x_10.7_lion.m4v
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        false
    }

    convenience init(type typeName: String) throws {
        // The docs say to call super.init(typeName:), but that's a convenience initializer,
        // so we can't do it. The docs also say that super.init(typeName:) just calls the designated
        // initializer – self.init() – and then sets fileType, so we'll do that here. Hopefully this
        // is good enough.
        self.init()
        fileType = typeName

        let type = UTType(typeName)
        assert(type == .plainText || type!.isSubtype(of: .plainText))
        storage = .text(Buffer())
    }

    // When canConcurrentlyReadDocuments(ofType:) returns true, the document is initialized and read
    // on a background thread, and then transfered to the main thread to present UI.
    //
    // Specifically, these are called on a background thread:
    //     NSDocumentController.makeDocument(withContentsOf:ofType:)
    //     NSDocument.init(contentsOf:ofType:)
    //     NSDocument.read(from:ofType:)
    //
    // After which these are called on the main thread:
    //     NSDocument.makeWindowControllers()
    //     NSDocument.showWindows()
    //
    // Source: https://download.developer.apple.com/wwdc_2008/adc_on_itunes__wwdc08_sessions__mac_track__videos_2/425.m4v
    //
    // There's an impedance mismatch – NSDocument is @MainActor, but it's not always run on the main thread.
    // Because read(from:ofType:) is non-isolated, Swift wants us to asyncronously read and write storage.
    // But that's not necessary – NSDocument is always isolated to a single thread, even if it's not the
    // main thread.
    //
    // To get around this, we tell Swift to ignore actor isolation (see MainActor+Extensions.swift).
    //
    // For more, see: https://forums.swift.org/t/unsafe-synchronous-access-to-mainactor-isolated-data-in-nsdocument/70049
    //
    // N.b. read(from:ofType:) can also be called directly on the main thread by revert(toContentsOf:ofType:),
    // which is @MainActor.
    override nonisolated func read(from url: URL, ofType typeName: String) throws {
        try MainActor.unsafeIgnoreActorIsolation {
            let type = UTType(typeName) ?? .data

            switch (storage, isTextFile(url, typeName)) {
            case let (.text(buffer), true):
                let string = try String(contentsOf: url)
                buffer.replaceContents(with: string, language: type.language ?? .plainText)
            case (.text, false):
                assertionFailure("Switching from text to generic isn't supported yet")
            case (.generic, true):
                assertionFailure("Switching from generic to text isn't supported yet")
            case (.generic, false):
                // TODO: update document view controlllers so the new file is shown
                storage = .generic(url)
            case (nil, true):
                let string = try String(contentsOf: url)
                storage = .text(Buffer(string, language: type.language ?? .plainText))
            case (nil, false):
                storage = .generic(url)
            }
        }
    }

    nonisolated func isTextFile(_ url: URL, _ typeName: String) -> Bool {
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
            return false
        } else {
            return true
        }
    }

    // Once we enable asyncronous writing, this will probably have to change from assumeIsolated
    // to unsafeIgnoreActorIsolation.
    override nonisolated func write(to url: URL, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            switch storage! {
            case let .text(buffer):
                try buffer.data.write(to: url, options: .atomic)
            case .generic:
                break
            }
        }
    }

    override func makeWindowControllers() {
        switch storage! {
        case let .text(buffer):
            let windowController = TextDocumentWindowController(buffer: buffer)
            addWindowController(windowController)
        case let .generic(url):
            let windowController = GenericDocumentWindowController(url: url)
            addWindowController(windowController)
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
        Logger.documentLog.debug("Document.addDocumentViewController")
        if documentViewControllers.contains(viewController) {
            return
        }
        
        viewController.document?.removeDocumentViewController(viewController)
        documentViewControllers.append(viewController)
        viewController.document = self
    }

    func removeDocumentViewController(_ viewController: DocumentViewController) {
        Logger.documentLog.debug("Document.removeDocumentViewController")
        if let index = documentViewControllers.firstIndex(of: viewController) {
            documentViewControllers.remove(at: index)
            viewController.document = nil
        }
    }

    override func shouldCloseWindowController(_ windowController: NSWindowController, delegate: Any?, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Logger.documentLog.debug("Document.shouldCloseWindowController")
        super.shouldCloseWindowController(windowController, delegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    func shouldCloseDocumentViewController(_ viewController: DocumentViewController) async -> Bool {
        Logger.documentLog.debug("Document.shouldCloseDocumentViewController")
        assert(documentViewControllers.contains(viewController))

        if documentViewControllers.count > 1 {
            return true
        }

        return await canClose()
    }

    func canClose() async -> Bool {
        await withCheckedContinuation { continuation in
            canClose(
                withDelegate: self,
                shouldClose: #selector(document(_:shouldClose:contextInfo:)),
                contextInfo: Unmanaged.passRetained(CheckedContinuationReference(continuation)).toOpaque())
        }
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Logger.documentLog.debug("Document.canClose")
        super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    @objc func document(_ document: Document, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer) {
        let continuation = Unmanaged<CheckedContinuationReference<Bool, Error>>.fromOpaque(contextInfo).takeRetainedValue()
        continuation.resume(returning: shouldClose)
    }

    override nonisolated func presentedItemDidChange() {
        Task { @MainActor in
            // Very much not sure that my logic here is right. performActivity(withSyncronousWaiting:using:) is only
            // relavant and when we start supporting asyncronous writing, and given that we're making sure that all file
            // accesses happen on the main thread (by hopping back at the top of presentedItemDidChange()), I'm pretty
            // sure performAsyncronousFileAccess(_:) isn't needed either.
            //
            // That said, this is hopefully a decent blueprint for getting started with asyncronous file writing.
            performActivity(withSynchronousWaiting: false) { [self] activityDone in
                performAsynchronousFileAccess { [self] fileDone in
                    defer { fileDone() }
                    defer { activityDone() }

                    guard let fileURL, let fileType else {
                        return
                    }

                    do {
                        // TODO: it would be nice if coordinate(readingItemAt:options:) didn't block the main thread. There's
                        // an example of how you might do that in this video at 35:07:
                        //    https://download.developer.apple.com/videos/wwdc_2011__hd/session_107__autosave_and_versions_in_mac_os_x_10.7_lion.m4v
                        //
                        // I attempted to do it, but there were too many concurrency warnings and it wans't worth it.
                        try NSFileCoordinator(filePresenter: self).coordinate(readingItemAt: fileURL, options: .withoutChanges) { actualURL in
                            let date = try actualURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!

                            if fileModificationDate == nil || date == fileModificationDate {
                                return
                            }

                            try revert(toContentsOf: actualURL, ofType: fileType)
                        }
                    } catch {
                        presentErrorAsSheet(error)
                    }
                }
            }
        }
    }

    override nonisolated func accommodatePresentedItemDeletion() async throws {
        try await super.accommodatePresentedItemDeletion()
        await close()
    }

    override nonisolated func presentedItemDidMove(to newURL: URL) {
        super.presentedItemDidMove(to: newURL)

        Task { @MainActor in
            var relationship: FileManager.URLRelationship = .other
            do {
                try FileManager.default.getRelationship(&relationship, of: .trashDirectory, in: .allDomainsMask, toItemAt: newURL)
            } catch {
                presentErrorAsSheet(error)
                return
            }
            
            if relationship == .contains {
                close()
            }
        }
    }

    override func close() {
        var didCloseTab = false
        for vc in documentViewControllers {
            removeDocumentViewController(vc)
            if let wc = vc.view.window?.windowController as? WorkspaceWindowController {
                wc.closeDocumentViewController(vc)
                didCloseTab = true
            }
        }

        if didCloseTab {
            (DocumentController.shared as! DocumentController).skipNoteNextRecentDocument = true
        }

        // Closes all of the document's windows and removes the document from its document controller.
        super.close()
    }

    func presentErrorAsSheet(_ error: Error) {
        if let windowForSheet {
            presentError(error, modalFor: windowForSheet, delegate: nil, didPresent: nil, contextInfo: nil)
        } else {
            presentError(error)
        }
    }
}
