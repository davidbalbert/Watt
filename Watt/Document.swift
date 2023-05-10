//
//  Document.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class Document: NSDocument {
    var storage: AttributedStringTextStorage = {
        if let url = Bundle.main.url(forResource: "Moby Dick", withExtension: "txt") {
            let text = try! String(contentsOf: url)

            let maxLines = 10
            var line = 0
            var i = text.startIndex
            while true {
                if let newline = text[i...].firstIndex(of: "\n") {
                    i = text.index(after: newline)
                } else {
                    i = text.endIndex
                }
                line += 1

                if i == text.endIndex || line >= maxLines {
                    break
                }
            }

            let s = text[text.startIndex..<i]

            return AttributedStringTextStorage(String(s))
        }

        return AttributedStringTextStorage("Couldn't load")
    }()

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

