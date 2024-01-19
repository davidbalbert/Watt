//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation
import Cocoa

protocol WorkspaceDelegate: AnyObject {
    func workspaceDidChange(_ workspace: Workspace)
}

@MainActor
class Workspace {
    enum Errors: Error {
        case rootIsNotFolder
    }

    private(set) var root: Dirent
    var children: [Dirent] {
        return root.filteringChildren(showHidden: showHidden).children!
    }

    var showHidden: Bool {
        didSet {
            delegate?.workspaceDidChange(self)
        }
    }

    weak var delegate: WorkspaceDelegate?

    private var loaded: Set<URL> = []
    private var index: [Dirent.ID: Dirent]

    var showHiddenFilesObservation: NSKeyValueObservation?

    func renameFile() throws {
        // guard let id = editState.id, let dirent = index[id] else {
        //     return
        // }

        // let newURL = dirent.url.deletingLastPathComponent().appending(component: editState.name, directoryHint: dirent.isDirectory ? .isDirectory : .notDirectory)

        // try FileManager.default.moveItem(at: dirent.url, to: newURL)

        // editState = EditState()
    }


    init(url: URL) throws {
        let dirent = try Dirent(for: url)
        if !dirent.isFolder {
            throw Errors.rootIsNotFolder
        }

        self.root = dirent
        self.showHidden = UserDefaults.standard.showHiddenFiles
        self.index = [:]

        showHiddenFilesObservation = UserDefaults.standard.observe(\.showHiddenFiles) { _, _ in
            MainActor.assumeIsolated { [weak self] in
                self?.showHidden = UserDefaults.standard.showHiddenFiles
            }
        }

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

        for c in children {
            index[c.id] = c
        }

        return children
    }

    func listen() async {
        var continuation: AsyncStream<[LoadRequest]>.Continuation?
        let requestsStream = AsyncStream<[LoadRequest]> { cont in
            let stream = FSEventStream(root.url.path) { _, events in
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
