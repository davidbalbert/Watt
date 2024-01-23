//
//  WorkspaceFilePromiseProvider.swift
//  Watt
//
//  Created by David Albert on 1/23/24.
//

import Cocoa
import UniformTypeIdentifiers

// Having to subclass this is pretty gross. I had a ComposedPasteboardWriter where you could do
// ComposedPastboardWriter(writers: [filePromiseProvider, url as NSURL]), which seemed to work,
// however when using it, the drag pasteboard was missing the dyn.* types ("Apple files promise
// pasteboard type" and "NSPromiseContentsPboardType) as well as
// com.apple.pasteboard.promised-file-url. I don't know if that actually broke file promises, but
// I didn't want to mess with it.
class WorkspaceFilePromiseProvider: NSFilePromiseProvider {
    var dirent: Dirent

    init(dirent: Dirent, delegate: NSFilePromiseProviderDelegate) {
        self.dirent = dirent
        super.init()

        let type: UTType
        if dirent.isDirectory {
            type = .directory
        } else {
            type = UTType(filenameExtension: dirent.url.pathExtension) ?? .data
        }

        self.fileType = type.identifier
        self.delegate = delegate
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        super.writableTypes(for: pasteboard) + [.fileURL]
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL:
            (dirent.url as NSURL).pasteboardPropertyList(forType: type)
        default:
            super.pasteboardPropertyList(forType: type)
        }

    }

    public override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        super.writingOptions(forType: type, pasteboard: pasteboard)
    }
}
