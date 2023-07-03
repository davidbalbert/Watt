//
//  Document.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class Document: NSDocument {
    var contentManager: ContentManager = {
        let url = Bundle.main.url(forResource: "Moby Dick", withExtension: "txt")!
        let text = try! String(contentsOf: url)
        return ContentManager(text)
    }()

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }

    enum DocumentError: Error {
        case load
        case save
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        let w = NSWindow(contentViewController: TextViewController(contentManager))
        w.setContentSize(CGSize(width: 800, height: 600))
        let c = WindowController(window: w)
        addWindowController(c)
    }

    override func data(ofType typeName: String) throws -> Data {
        contentManager.data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        contentManager = ContentManager(String(decoding: data, as: UTF8.self))
    }
}

