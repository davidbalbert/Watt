//
//  Document.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa
import UniformTypeIdentifiers

class Document: NSDocument {
    // TODO: from "Developing a Document Based App:
    //
    //     The Cocoa document architecture uses the Objective-C runtime, and document-based
    //     apps often use Objective-C technologies such as key-value coding (KVC), key-value
    //     observing (KVO), Cocoa bindings, and Cocoa archiving (NSCoding). Therefore, the
    //     model classes in your app should be Objective-C classes (subclasses of NSObject),
    //     and the properties and methods in those classes should be Objective-C compatible
    //     (declared @objc). In addition, their properties should be declared dynamic in Swift,
    //     which tells the compiler to use dynamic dispatch to access that attribute.
    //
    // Buffer isn't an NSObject subclass. Will that cause any issues?
    var buffer: Buffer = {
        let url = Bundle.main.url(forResource: "Moby Dick", withExtension: "txt")!
        let text = try! String(contentsOf: url)
        return Buffer(text, language: .plainText)
    }()

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }

    // TODO: canAsynchronouslyWrite(to:ofType:for:)

    enum DocumentError: Error {
        case load
        case save
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        let w = NSWindow(contentViewController: TextViewController(buffer))
        w.setContentSize(CGSize(width: 800, height: 600))
        let c = WindowController(window: w)
        addWindowController(c)
    }

    override func data(ofType typeName: String) throws -> Data {
        buffer.data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        buffer = Buffer(String(decoding: data, as: UTF8.self), language: UTType(typeName)?.language ?? .plainText)
    }
}

