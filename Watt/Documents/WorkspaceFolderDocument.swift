//
//  WorkspaceFolderDocument.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa
import os

class WorkspaceFolderDocument: BaseDocument {
    var workspace: Workspace!

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    override class var autosavesInPlace: Bool {
        false
    }

    override func makeWindowControllers() {
        addWindowController(WorkspaceWindowController(workspaceDocument: self))
    }

    override func read(from url: URL, ofType typeName: String) throws {
        try MainActor.assumeIsolated {
            workspace = try Workspace(url: url)
        }
    }

    override func write(to url: URL, ofType typeName: String) throws {
        // no-op
    }

    override func shouldCloseWindowController(_ windowController: NSWindowController, delegate: Any?, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Logger.documentLog.debug("WorkspaceFolderDocument.shouldCloseWindowController")

        // In a workspace window, the window should close if
        //   - All of the Documents in windows tabs are being shown in other windows, or
        //   - If all of the tabs that are only shown in this window successfully saved
        // - And
        //   - The window shouldClose (call super)

        assert(windowController.isWindowLoaded)

        let windowController = windowController as! WorkspaceWindowController

        Task {
            for controller in windowController.documentViewControllers {
                guard let document = controller.document else {
                    continue
                }

                let isOpenInOtherWindow = document.documentViewControllers.contains { vc in
                    vc.view.window != nil && vc.view.window != windowController.window
                }

                if isOpenInOtherWindow {
                    continue
                }

                if await !document.canClose() {
                    _ = (delegate as AnyObject?)?.perform(shouldCloseSelector, with: document, with: false, with: contextInfo)
                    return
                }
            }

            super.shouldCloseWindowController(windowController, delegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
        }
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Logger.documentLog.debug("WorkspaceFolderDocument.canClose")
        super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    override func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        super.restoreWindow(withIdentifier: identifier, state: state) { window, error in
            // Workspace window identifier is unique per window to allow for persisting NSOutlineView expanded states
            // for each window. We need to make sure each restored window is using the same identifier from the
            // previous time it was launched.
            //
            // TODO: This is kind of gross. It might be cleaner to roll our own NSOutlineView expanded state tracking
            // that uses NSWindow's restorable state system instead of UserDefaults.
            window?.identifier = identifier
            completionHandler(window, error)}
    }
}
