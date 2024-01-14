//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation
import Cocoa
import FSEventsWrapper
import AsyncAlgorithms

protocol WorkspaceDelegate: AnyObject {
    func workspaceDidChange(_ workspace: Workspace)
}

@MainActor
class Workspace {
    enum LoadRequest {
        case directory(URL)
        case tree(URL)

        init(directory url: URL) {
            self = .directory(url.standardizedFileURL)
        }

        init(tree url: URL) {
            self = .tree(url.standardizedFileURL)
        }

        var url: URL {
            switch self {
            case let .directory(url):
                url
            case let .tree(url):
                url
            }
        }

        var isRecursive: Bool {
            switch self {
            case .directory:
                false
            case .tree:
                true
            }
        }
    }

    enum Errors: Error {
        case rootIsNotFolder
    }

    var loaded: Set<URL> = []
    private(set) var root: Dirent

    weak var delegate: WorkspaceDelegate?

    init(url: URL) throws {
        let dirent = try Dirent(for: url)
        if !dirent.isFolder {
            throw Errors.rootIsNotFolder
        }

        self.root = dirent

        try loadDirectory(url: root.url)
    }

    @discardableResult
    func loadDirectory(url: URL, notifyDelegate: Bool = true) throws -> [Dirent] {
        print("loadDirectory", url)

        // Don't load a directory unless we have somewhere to put it.
        guard url == root.url || loaded.contains(url.deletingLastPathComponent()) else {
            print("skip!")
            return []
        }

        let children = try Workspace.fetchChildren(of: url)
        try updateChildren(of: url, to: children)
        loaded.insert(url)

        if notifyDelegate {
            delegate?.workspaceDidChange(self)
        }

        return children
    }

    func listen() async {
        var continuation: AsyncStream<LoadRequest>.Continuation?

        let reqs = AsyncStream<LoadRequest> { cont in
            let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf)
            let stream = FSEventStream(path: root.url.path, fsEventStreamFlags: flags) { _, event in
                switch event {
                case let .generic(path: path, eventId: _, fromUs: _):
                    cont.yield(LoadRequest(directory: (URL(filePath: path))))
                case let .mustScanSubDirs(path: path, reason: _):
                    cont.yield(LoadRequest(tree: (URL(filePath: path))))
                default:
                    print("Unhandled FSEvent type: \(event)")
                }
            }

            guard let stream else {
                print("Couldn't subscribe to FSEvents")
                cont.finish()
                return
            }

            cont.onTermination = { _ in
                stream.stopWatching()
            }
            stream.startWatching()

            // Reload self ot make sure we're up to date.
            cont.yield(LoadRequest(tree: root.url))

            continuation = cont
        }

        guard let continuation else {
            return
        }

        for await req in reqs {
            if !loaded.contains(req.url) {
                continue
            }
            
            let children: [Dirent]
            do {
                children = try loadDirectory(url: req.url)
                try updateChildren(of: req.url, to: children)
            } catch {
                print("Workspace.listen: error while loading children of \(req.url): \(error)")
                continue
            }

            if req.isRecursive {
                for c in children {
                    // only reload directories where we already have data (which is now stale)
                    if loaded.contains(c.url) {
                        continuation.yield(LoadRequest(tree: c.url))
                    }
                }
            }
        }
    }

    static nonisolated func fetchChildren(of url: URL) throws -> [Dirent] {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Dirent.resourceKeys, options: [])

            var children: [Dirent] = []
            for u in urls {
                children.append(try Dirent(for: u))
            }

            children.sort()

            return children
        } catch {
            print("error fetching children of \(url): \(error)")
            return []
        }
    }

    func updateChildren(of url: URL, to newChildren: consuming [Dirent]) throws {
        try root.updateDescendent(withURL: url) { dirent in
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
    }
}
