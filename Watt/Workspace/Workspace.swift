//
//  Workspace.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Cocoa
import System

protocol WorkspaceDelegate: AnyObject {
    func workspaceDidChange(_ workspace: Workspace)
}

@MainActor
class Workspace {
    enum Errors: Error {
        case rootIsNotFolder
        case isNotInWorkspace(URL)
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

    private var showHiddenFilesObservation: NSKeyValueObservation?

    let fileQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Workspace File Queue"
        queue.qualityOfService = .userInitiated
        return queue
    }()

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

    private func delegateWorkspaceDidChange() {
        delegate?.workspaceDidChange(self)
    }

    // Doesn't care whether oldURL and newURL are present in the workspace. Returns the new dirent if it's present.
    @discardableResult
    func move(fileAt oldURL: URL, to newURL: URL, notifyDelegate: Bool = true) async throws -> Dirent? {
        let src: NSFileAccessIntent = .writingIntent(with: oldURL, options: .forMoving)
        let dst: NSFileAccessIntent = .writingIntent(with: newURL, options: .forReplacing)
        try await NSFileCoordinator().coordinate(with: [src, dst], queue: fileQueue) {
            try FileManager.default.moveItem(at: src.url, to: dst.url)
        }
        let actualURL = dst.url

        let oldParentURL = oldURL.deletingLastPathComponent()
        let actualParentURL = actualURL.deletingLastPathComponent()

        // TODO: we need to handle the case where root moves
        let newDirent: Dirent
        if root.hasDescendent(at: oldURL) && root.url != oldURL {
            var oldDirent: Dirent?
            try root.updateDescendent(withURL: oldParentURL) { parent in
                let i = parent._children!.firstIndex { $0.url == oldURL }
                oldDirent = parent._children!.remove(at: i!)
            }
            newDirent = Dirent(moving: oldDirent!, to: actualURL)
        } else {
            newDirent = try Dirent(for: actualURL)
        }

        var didAdd = false
        if root.hasDescendent(at: actualParentURL) {
            try root.updateDescendent(withURL: actualParentURL) { parent in
                if parent._children == nil {
                    return
                }

                parent._children!.append(newDirent)
                parent._children!.sort()
            }
            didAdd = true
        }

        if notifyDelegate {
            delegateWorkspaceDidChange()
        }
        return didAdd ? newDirent : nil
    }

    // Used for drag and drop from other apps. Throws if dstURL isn't in the workspace or
    // isn't loaded.
    func copy(fileAt srcURL: URL, intoWorkspaceAt dstURL: URL) async throws {
        let rootPath = FilePath(root.url.path)
        let dstPath = FilePath(dstURL.path)

        if dstPath == rootPath || !dstPath.starts(with: rootPath) {
            throw Errors.isNotInWorkspace(dstURL)
        }

        let src: NSFileAccessIntent = .readingIntent(with: srcURL)
        let dst: NSFileAccessIntent = .writingIntent(with: dstURL, options: .forReplacing)
        try await NSFileCoordinator().coordinate(with: [src, dst], queue: fileQueue) {
            try FileManager.default.copyItem(at: src.url, to: dst.url)
        }
        try add(direntFor: dst.url)

        delegateWorkspaceDidChange()
    }

    // Used for drag and drop from other apps. Throws if targetDirectoryURL isn't in the workspace
    // or isn't loaded.
    func receive(filesFrom filePromiseReceiver: NSFilePromiseReceiver, atDestination targetDirectoryURL: URL) async throws {
        let rootPath = FilePath(root.url.path)
        let dstPath = FilePath(targetDirectoryURL.path)

        if dstPath == rootPath || !dstPath.starts(with: rootPath) {
            throw Errors.isNotInWorkspace(targetDirectoryURL)
        }

        let urls = try await filePromiseReceiver.receivePromisedFiles(atDestination: targetDirectoryURL, operationQueue: fileQueue)
        for url in urls {
            try add(direntFor: url)
        }

        delegateWorkspaceDidChange()
    }

    private func add(direntFor url: URL) throws {
        let dirent = try Dirent(for: url)

        let parentURL = url.deletingLastPathComponent()
        try root.updateDescendent(withURL: parentURL) { parent in
            if parent._children == nil {
                return
            }

            let alreadyPresent = parent._children!.contains { $0.id == dirent.id }
            if !alreadyPresent {
                parent._children!.append(dirent)
                parent._children!.sort()
            }
        }
    }

    @discardableResult
    func loadDirectory(url: URL) throws -> [Dirent]? {
        // Don't load a directory unless we have somewhere to put it.
        if url != root.url && !loaded.contains(url.deletingLastPathComponent()) {
            return nil
        }

        let urls = try NSFileCoordinator().coordinate(readingItemAt: url) { actualURL in
            try FileManager.default.contentsOfDirectory(at: actualURL, includingPropertiesForKeys: Dirent.resourceKeys)
        }

        let children = try urls.map { try Dirent(for: $0) }.sorted()
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

            // Reload self to make sure we're up to date.
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

                let children: [Dirent]?
                do {
                    children = try loadDirectory(url: req.url)
                } catch let error as NSError {
                    // Consider the directory hierarchy /foo/bar. If bar is deleted, we get two FSEvents,
                    // One for /foo/bar and one for /foo. Processing /foo/bar will fail because bar doesn't
                    // exist any more. That's an expected case, so we don't want to log that message.
                    if !(error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError) {
                        print("Workspace.listen: error while loading children of \(req.url): \(error)")
                    }
                    continue
                }

                guard let children else {
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

            delegateWorkspaceDidChange()
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
