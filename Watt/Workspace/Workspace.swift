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
    enum Errors: Error, LocalizedError {
        case rootIsNotFolder
        case cantMoveRoot
        case isNotInWorkspace(URL)

        var errorDescription: String? {
            switch self {
            case .rootIsNotFolder:
                return String(localized: "The workspace root must be a folder.")
            case .cantMoveRoot:
                return String(localized: "Can't move the workspace root.")
            case .isNotInWorkspace(let url):
                return String(localized: "The URL \(url.absoluteString) is not in the workspace.")
            }
        }

        var failureReason: String? {
            String(localized: "This is a bug in Watt. Please report it.")
        }
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

    func isInWorkspace(_ url: URL) -> Bool {
        return url != root.url && FilePath(url.path).starts(with: FilePath(root.url.path))
    }

    // Doesn't care whether oldURL and newURL are in the workspace. Returns the actual new URL.
    @discardableResult
    func move(filesAt oldURLs: [URL], to newURLs: [URL]) async throws -> [URL] {
        precondition(oldURLs.count == newURLs.count)

        if oldURLs.contains(root.url) || newURLs.contains(root.url) {
            throw Errors.cantMoveRoot
        }

        let srcIntents = oldURLs.map { NSFileAccessIntent.writingIntent(with: $0, options: .forMoving) }
        let dstIntents = newURLs.map { NSFileAccessIntent.writingIntent(with: $0, options: .forReplacing) }

        try await NSFileCoordinator().coordinate(with: srcIntents + dstIntents, queue: fileQueue) {
            for (src, dst) in zip(srcIntents, dstIntents) {
                try FileManager.default.moveItem(at: src.url, to: dst.url)
            }
        }

        for i in 0..<oldURLs.count {
            let oldURL = oldURLs[i]
            let srcURL = srcIntents[i].url
            let dstURL = dstIntents[i].url

            // None of these URLs are guaranteed to be in the workspace, so just ignore errors.
            let d1 = try? remove(direntFor: oldURL)
            let d2 = try? remove(direntFor: srcURL)
            let oldDirent = d2 ?? d1

            if let oldDirent, isInWorkspace(dstURL) {
                let newDirent = Dirent(moving: oldDirent, to: dstURL)
                try add(dirent: newDirent)
            } else if isInWorkspace(dstURL) {
                try add(direntFor: dstURL)
            }
        }

        delegateWorkspaceDidChange()

        return dstIntents.map(\.url)
    }

    // Used for drag and drop from other apps. Throws if dstURL isn't in the workspace or
    // isn't loaded.
    @discardableResult
    func copy(filesAt srcURLs: [URL], intoWorkspaceAt dstURLs: [URL]) async throws -> [URL] {
        precondition(srcURLs.count == dstURLs.count)

        for dstURL in dstURLs {
            if !isInWorkspace(dstURL) {
                throw Errors.isNotInWorkspace(dstURL)
            }
        }

        let srcIntents = srcURLs.map { NSFileAccessIntent.readingIntent(with: $0) }
        let dstIntents = dstURLs.map { NSFileAccessIntent.writingIntent(with: $0, options: .forReplacing) }

        try await NSFileCoordinator().coordinate(with: srcIntents + dstIntents, queue: fileQueue) {
            for (src, dst) in zip(srcIntents, dstIntents) {
                try FileManager.default.copyItem(at: src.url, to: dst.url)
            }
        }

        for dst in dstIntents {
            try add(direntFor: dst.url)
        }

        delegateWorkspaceDidChange()

        return dstIntents.map(\.url)
    }

    func trash(filesAt urls: [URL]) async throws {
        let intents = urls.map { NSFileAccessIntent.writingIntent(with: $0, options: .forDeleting) }
        try await NSFileCoordinator().coordinate(with: intents, queue: fileQueue) {
            for intent in intents {
                try FileManager.default.trashItem(at: intent.url, resultingItemURL: nil)
            }
        }

        for url in urls {
            try remove(direntFor: url)
        }

        delegateWorkspaceDidChange()
    }

    // Used for drag and drop from other apps. Throws if targetDirectoryURL isn't in the workspace
    // or isn't loaded.
    @discardableResult
    func receive(filesFrom filePromiseReceivers: [NSFilePromiseReceiver], atDestination targetDirectoryURL: URL) async throws -> [URL] {
        guard targetDirectoryURL == root.url || isInWorkspace(targetDirectoryURL) else {
            throw Errors.isNotInWorkspace(targetDirectoryURL)
        }

        let urls = try await withThrowingTaskGroup(of: [URL].self) { group in
            for receiver in filePromiseReceivers {
                group.addTask { @MainActor in
                    let urls = try await receiver.receivePromisedFiles(atDestination: targetDirectoryURL, operationQueue: self.fileQueue)
                    for url in urls {
                        try self.add(direntFor: url)
                    }
                    return urls
                }
            }

            var result: [URL] = []
            for try await urls in group {
                result.append(contentsOf: urls)
            }
            return result
        }

        delegateWorkspaceDidChange()

        return urls
    }

    private func add(direntFor url: URL) throws {
        let dirent = try Dirent(for: url)
        try add(dirent: dirent)
    }

    private func add(dirent: Dirent) throws {
        let parentURL = dirent.url.deletingLastPathComponent()
        try root.updateDescendant(withURL: parentURL) { parent in
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
    private func remove(direntFor url: URL) throws -> Dirent? {
        let parentURL = url.deletingLastPathComponent()
        var dirent: Dirent?
        try root.updateDescendant(withURL: parentURL) { parent in
            if parent._children == nil {
                return
            }

            let i = parent._children!.firstIndex { $0.url == url }
            if let i {
                dirent = parent._children!.remove(at: i)
            }
        }
        return dirent
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

        var children = try urls.map { try Dirent(for: $0) }.sorted()
        try updateChildren(of: url, to: &children)
        loaded.insert(url)

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
                cont.yield(requests.removingDuplicates())
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

    func updateChildren(of url: URL, to newChildren: inout [Dirent]) throws {
        try root.updateDescendant(withURL: url) { dirent in
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
