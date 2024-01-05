//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation
import FSEventsWrapper

@Observable
class Workspace {
    let url: URL
    var root: Dirent

    init?(url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if !isDir.boolValue {
            return nil
        }

        self.url = url
        self.root = Dirent(directoryURL: url)!
    }

    #if DEBUG
    // Should only be used for preview
    init(url: URL, root: Dirent) {
        self.url = url
        self.root = root
    }
    #endif

    func watchForChanges() async {
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf)
        // make the iterator first to ensure we're listening to the underlying
        // FSEventStream and don't miss any events.
        let iter = FSEventAsyncStream(path: url.path, flags: flags).makeAsyncIterator()

        guard let root = Dirent(directoryURL: url) else { return }
        self.root = root

        for await _ in AsyncStream(iter) {
            guard let root = Dirent(directoryURL: url) else { return }
            self.root = root
        }
    }
}

