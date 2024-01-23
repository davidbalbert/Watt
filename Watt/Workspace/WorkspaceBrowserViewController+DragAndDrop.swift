//
//  WorkspaceBrowserViewController+DragAndDrop.swift
//  Watt
//
//  Created by David Albert on 1/21/24.
//

import Cocoa
import UniformTypeIdentifiers

extension WorkspaceBrowserViewController: OutlineViewDragAndDropDelegate {
    typealias Element = Dirent

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForElement dirent: Dirent) -> NSPasteboardWriting? {
        let type: UTType
        if dirent.isDirectory {
            type = .directory
        } else {
            type = UTType(filenameExtension: dirent.url.pathExtension) ?? .data
        }

        let provider = NSFilePromiseProvider(fileType: type.identifier, delegate: self)
        provider.userInfo = dirent.url
        return provider
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedElement element: Dirent?, proposedChildIndex index: Int) -> NSDragOperation {
        print("validateDrop url=\(element?.url) index=\(index) onItem=\(index == NSOutlineViewDropOnItemIndex)")
        if index == NSOutlineViewDropOnItemIndex {
            return []
        }

        let items = info.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self, NSURL.self], options: [:]) ?? []
        if items.count > 0 {
            return [.copy]
        }
        return []
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, element: Dirent?, childIndex index: Int) -> Bool {
        print("acceptDrop url=\(element?.url) isFolder=\(element?.isFolder) index=\(index) onItem=\(index == NSOutlineViewDropOnItemIndex)")

        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self, NSURL.self]) else {
            return false
        }

        let targetDirectoryURL = (element ?? workspace.root).url

        Task {
            do {
                try await withThrowingTaskGroup(of: URL.self) { group in
                    for item in items {
                        switch item {
                        case let receiver as NSFilePromiseReceiver:
                            group.addTask { @MainActor in
                                return try await receiver.receivePromisedFiles(atDestination: targetDirectoryURL, operationQueue: self.fileQueue)
                            }
                        case let srcURL as URL:
                            group.addTask { @MainActor in
                                let dstURL = targetDirectoryURL.appendingPathComponent(srcURL.lastPathComponent)
                                return try await FileManager.default.coordinatedCopyItem(at: srcURL, to: dstURL, operationQueue: self.fileQueue)
                            }
                        default:
                            break
                        }
                    }

                    for try await url in group {
                        try workspace.add(url: url)
                    }
                }
            } catch {
                presentErrorAsSheetWithFallback(error)
            }
        }
        return true
    }
}

extension WorkspaceBrowserViewController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let url = url(forFilePromiseProvider: filePromiseProvider)!
        return url.lastPathComponent
    }
    
    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo destinationURL: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            if let sourceURL = url(forFilePromiseProvider: filePromiseProvider) {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
            completionHandler(nil)
        } catch {
            Task { @MainActor in
                self.presentErrorAsSheetWithFallback(error)
            }
            completionHandler(error)
        }
    }
    
    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        fileQueue
    }

    nonisolated func url(forFilePromiseProvider filePromiseProvider: NSFilePromiseProvider) -> URL? {
        filePromiseProvider.userInfo as? URL
    }
}
