//
//  Document.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class Document: NSDocument {
    var contents: String = ""

    enum DocumentError: Error {
        case load
        case save
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        let w = NSWindow(contentViewController: TextViewController(self))
        w.setContentSize(CGSize(width: 800, height: 600))
        let c = WindowController(window: w)
        addWindowController(c)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = contents.data(using: .utf8) else {
            throw DocumentError.save
        }

        return data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let contents = String(bytes: data, encoding: .utf8) else {
            throw DocumentError.load
        }

        self.contents = contents
    }
}

