//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation
import Cocoa
import FSEventsWrapper

@Observable
class Workspace {
    let url: URL
    var root: Dirent
    var tasks: [URL: Task<(), Never>] = [:]

    init(url: URL) {
        // TODO: Don't force unwrap. Throw errors and show an alert.
        let resourceValues = try! url.resourceValues(forKeys: [.nameKey, .fileResourceIdentifierKey])
        let id = FileID(id: resourceValues.fileResourceIdentifier!)
        let name = resourceValues.name ?? url.lastPathComponent

        self.url = url
        self.root = Dirent(id: id, name: name, url: url, isDirectory: true, isPackage: false, isHidden: false)

        fetchChildren(url: url)
    }

    func fetchChildren(url target: URL) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: Dirent.resourceKeys, options: [])
            
            var newChildren: [Dirent] = []
            for u in urls {
                guard let resourceValues = try? u.resourceValues(forKeys: Dirent.resourceSet) else {
                    continue
                }

                guard let id = resourceValues.fileResourceIdentifier else {
                    print("missing fileResourceIdentifier for \(u)")
                    continue
                }

                let child = Dirent(
                    id: FileID(id: id),
                    name: resourceValues.name ?? u.lastPathComponent,
                    url: u,
                    isDirectory: resourceValues.isDirectory ?? false,
                    isPackage: resourceValues.isPackage ?? false,
                    isHidden: resourceValues.isHidden ?? false
                )
                newChildren.append(child)
            }

            newChildren.sort()

            root.updateDescendent(withURL: target) { dirent in
                let pairs = dirent._children?.enumerated().map { ($0.element.url, $0.offset) } ?? []
                let urlToIndex = Dictionary(uniqueKeysWithValues: pairs)

                // copy over grandchildren
                for i in 0..<newChildren.count {
                    if let j = urlToIndex[newChildren[i].url] {
                        newChildren[i]._children = dirent._children?[j]._children
                    }
                }

                dirent._children = newChildren
            }
        } catch {
            print(error)
        }
    }

    func watchForChanges() async {
//        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf)
//        // make the iterator first to ensure we're listening to the underlying
//        // FSEventStream and don't miss any events.
//        let iter = FSEventAsyncStream(path: url.path, flags: flags).makeAsyncIterator()
//
//        guard let root = Dirent(directoryURL: url) else { return }
//        self.root = root
//
//        for await _ in AsyncStream(iter) {
//            guard let root = Dirent(directoryURL: url) else { return }
//            self.root = root
//        }
    }
}

