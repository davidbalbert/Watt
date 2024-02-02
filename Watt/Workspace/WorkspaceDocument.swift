//
//  WorkspaceDocument.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class WorkspaceDocument: NSDocument {
    var workspace: Workspace!

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    override class var autosavesInPlace: Bool {
        false
    }

    override func makeWindowControllers() {
        addWindowController(WorkspaceWindowController(workspace: workspace))
    }

    override func read(from url: URL, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            workspace = try Workspace(url: url)
        }
    }

    override func write(to url: URL, ofType typeName: String) throws {
        // no-op
    }
}
