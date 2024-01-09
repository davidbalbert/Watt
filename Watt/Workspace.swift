//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation
import Cocoa
import FSEventsWrapper

struct Dirent: Identifiable {
    static let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .isPackageKey, .creationDateKey, .contentModificationDateKey, .isHiddenKey]
    static let resourceSet = Set(resourceKeys)

    let url: URL
    let isDirectory: Bool
    let isPackage: Bool
    let isHidden: Bool
    let icon: NSImage

    var _children: [Dirent]?
    var children: [Dirent]? {
        if isFolder {
            return _children ?? []
        } else {
            return nil
        }
    }

    var isFolder: Bool {
        isDirectory && !isPackage
    }

    var id: URL { url }
    var name: String {
        url.lastPathComponent
    }

    init(url: URL, isDirectory: Bool, isPackage: Bool, isHidden: Bool, children: [Dirent]? = nil) {
        self.url = url
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isHidden = isHidden
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self._children = children
    }

    subscript(url: URL) -> Dirent? {
        if self.url == url {
            return self
        }

        if !isDirectory || !isPackage {
            return nil
        }

        if _children == nil {
            return nil
        }

        for child in _children! {
            if let result = child[url] {
                return result
            }
        }

        return nil
    }

    mutating func updateDescendent(withURL target: URL, using block: (inout Dirent) -> Void) {
        if url == target {
            block(&self)
            return
        }

        if !isDirectory && !isPackage {
            print("expected directory or package")
            return
        }

        if _children == nil {
            print("missing children")
            return
        }

        let targetComponents = target.pathComponents
        for i in 0..<_children!.count {
            let childComponents = _children![i].url.pathComponents

            if childComponents[...] == targetComponents[0..<childComponents.count] {
                _children![i].updateDescendent(withURL: target, using: block)
                return
            }
        }

        print("couldn't find child with url \(target)")
    }
}

extension Dirent: Comparable {
    static func < (lhs: Dirent, rhs: Dirent) -> Bool {
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

@Observable
class Workspace {
    let url: URL
    var root: Dirent
    var tasks: [URL: Task<(), Never>] = [:]

    init(url: URL) {
        self.url = url
        self.root = Dirent(url: url, isDirectory: true, isPackage: false, isHidden: false)

        scheduleFetchChildren(url: url)
    }

    func fetchChildren(url target: URL) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: Dirent.resourceKeys, options: [])
            
            var newChildren: [Dirent] = []
            for u in urls {
                guard let resourceValues = try? u.resourceValues(forKeys: Dirent.resourceSet) else {
                    continue
                }

                let child = Dirent(
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

    func scheduleFetchChildren(url target: URL) {
        if tasks[target] != nil {
            return
        }

        tasks[target] = Task {
            fetchChildren(url: target)
        }
    }
    deinit {
        for task in tasks.values {
            task.cancel()
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

