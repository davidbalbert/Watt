//
//  DocumentController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa
import UniformTypeIdentifiers
import System

class DocumentController: NSDocumentController {
    enum RestorationKeys {
        static let substituteDocumentURL = "substituteDocumentURL"
    }
    static var substituteDocumentURL: URL?
    var skipNoteNextRecentDocument: Bool = false

    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?, completionHandler: @escaping (Int) -> Void) {
        openPanel.canChooseDirectories = true
        super.beginOpenPanel(openPanel, forTypes: inTypes, completionHandler: completionHandler)
    }

    override func noteNewRecentDocument(_ document: NSDocument) {
        if skipNoteNextRecentDocument {
            skipNoteNextRecentDocument = false
            return
        }
        super.noteNewRecentDocument(document)
    }

    override static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        substituteDocumentURL = state.decodeObject(of: NSURL.self, forKey: RestorationKeys.substituteDocumentURL) as? URL
        super.restoreWindow(withIdentifier: identifier, state: state, completionHandler: completionHandler)
    }

    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        super.openDocument(withContentsOf: url, display: displayDocument) { document, displayDocument, error in
            if error != nil {
                // If the open fails, noteNewRecentDocument doesn't get called, so reset it here
                self.skipNoteNextRecentDocument = false
            }

            completionHandler(document, displayDocument, error)
        }
    }

    override func reopenDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        if let substituteDocumentURL = Self.substituteDocumentURL {
            assert(urlOrNil != nil)
            assertURL(urlOrNil!, isDescendentOf: substituteDocumentURL)

            Self.substituteDocumentURL = nil
            super.reopenDocument(for: substituteDocumentURL, withContentsOf: substituteDocumentURL, display: displayDocument, completionHandler: completionHandler)
        } else {
            super.reopenDocument(for: urlOrNil, withContentsOf: contentsURL, display: displayDocument, completionHandler: completionHandler)
        }
    }

    func assertURL(_ url: URL, isDescendentOf ancestor: URL) {
        let w = FilePath(ancestor.path(percentEncoded: false))
        let u = FilePath(url.path(percentEncoded: false))
        assert(w == u || u.starts(with: w))
    }
}
