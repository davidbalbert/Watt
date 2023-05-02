//
//  Document.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class Document: NSDocument {
    var storage: AttributedStringTextStorage = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

    enum DocumentError: Error {
        case load
        case save
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        let w = NSWindow(contentViewController: TextViewController(storage))
        w.setContentSize(CGSize(width: 800, height: 600))
        let c = WindowController(window: w)
        addWindowController(c)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = storage.string.data(using: .utf8) else {
            throw DocumentError.save
        }

        return data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let contents = String(bytes: data, encoding: .utf8) else {
            throw DocumentError.load
        }

        self.storage = AttributedStringTextStorage(contents)
    }
}

