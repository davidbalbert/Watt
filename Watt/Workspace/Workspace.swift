//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation
import Cocoa
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

        init?(event: FSEvent) {
            switch event {
            case let .generic(path: path, eventId: _, fromUs: _, extendedData: _):
                self = .directory(URL(filePath: path))
            case let .mustScanSubDirs(path: path, reason: _, fromUs: _, extendedData: _):
                self = .tree(URL(filePath: path))
            default:
                return nil
            }
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
    func loadDirectory(url: URL) throws -> [Dirent] {
        // Don't load a directory unless we have somewhere to put it.
        guard url == root.url || loaded.contains(url.deletingLastPathComponent()) else {
            return []
        }

        let children = try Workspace.fetchChildren(of: url)
        try updateChildren(of: url, to: children)
        loaded.insert(url)

        return children
    }

    func listen() async {
        var continuation: AsyncStream<[LoadRequest]>.Continuation?

        let requestsStream = AsyncStream<[LoadRequest]> { cont in
            let stream = FSEventStream(root.url.path, flags: .ignoreSelf) { _, events in
                let requests = events.compactMap { event in
                    let req = LoadRequest(event: event)
                    if req == nil {
                        print("Unhandled FSEvent type: \(event)")
                    }
                    return req
                }
                cont.yield(requests)
            }

            guard let stream else {
                print("Couldn't subscribe to FSEvents")
                cont.finish()
                return
            }

            cont.onTermination = { _ in
                stream.stop()
            }

            stream.start()

            // Reload self ot make sure we're up to date.
            cont.yield([LoadRequest(tree: root.url)])
            continuation = cont
        }

        guard let continuation else {
            return
        }

        for await requests in requestsStream {
            for req in requests {
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
                    var newReqs: [LoadRequest] = []
                    for c in children {
                        // only reload directories where we already have data (which is now stale)
                        if loaded.contains(c.url) {
                            newReqs.append(LoadRequest(tree: c.url))
                        }
                    }
                    continuation.yield(newReqs)
                }
            }

            delegate?.workspaceDidChange(self)
        }
    }

    static func fetchChildren(of url: URL) throws -> [Dirent] {
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
