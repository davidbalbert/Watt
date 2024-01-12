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
        case directory(URL, TaskPriority)
        case tree(URL, priority: TaskPriority, childPriority: TaskPriority)
    }

    enum Errors: Error {
        case hasNoMetadata
        case isNotDirectory
    }

    static func makeRoot(url: URL) throws -> Dirent {
        let rv = try url.resourceValues(forKeys: [.nameKey, .fileResourceIdentifierKey, .isDirectoryKey, .isPackageKey, .isHiddenKey])

        guard let resID = rv.fileResourceIdentifier, let isDirectory = rv.isDirectory, let isPackage = rv.isPackage else {
            throw Errors.hasNoMetadata
        }
        guard isDirectory && !isPackage else {
            throw Errors.isNotDirectory
        }

        return Dirent(
            id: FileID(id: resID),
            name: rv.name ?? url.lastPathComponent,
            url: url,
            isDirectory: isDirectory,
            isPackage: isPackage,
            isHidden: rv.isHidden ?? false,
            children: []
        )
    }

    let url: URL
    private(set) var root: Dirent {
        didSet {
            delegate?.workspaceDidChange(self)
        }
    }

    let userLoads: AsyncStream<LoadRequest>
    let userLoadsContinuation: AsyncStream<LoadRequest>.Continuation

    weak var delegate: WorkspaceDelegate?

    init(url: URL) throws {
        self.url = url
        self.root = try Workspace.makeRoot(url: url)
        (self.userLoads, self.userLoadsContinuation) = AsyncStream.makeStream()
    }

    func loadDirectory(url: URL, highPriority: Bool) {
        precondition(url.path.hasPrefix(self.url.path))
        userLoadsContinuation.yield(.directory(url, .userInitiated))
    }

    func listen() async {
        let fsevents = AsyncStream<FSEvent> { continuation in
            let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf)
            let stream = FSEventStream(path: url.path, fsEventStreamFlags: flags) { _, event in
                continuation.yield(event)
            }

            guard let stream else {
                continuation.finish()
                return
            }

            continuation.onTermination = { _ in
                stream.stopWatching()
            }
            stream.startWatching()
        }

        let fsLoads = fsevents.compactMap { event in
            switch event {
            case let .generic(path: path, eventId: _, fromUs: _):
                return LoadRequest.directory(URL(filePath: path), .medium)
            case let .mustScanSubDirs(path: path, reason: _):
                return LoadRequest.tree(URL(filePath: path), priority: .medium, childPriority: .medium)
            default:
                print("Unhandled FSEvent type: \(event)")
                return nil
            }
        }

        let initial = LoadRequest.tree(url, priority: .userInitiated, childPriority: .medium)
        let loadRequests = chain([initial].async, merge(userLoads, fsLoads))

        print("start listening")

        // read from load requests, processing load-requests

        for await req in loadRequests {
            switch req {
            case let .directory(url, _):
                print("dir", url)
                let dirents = Workspace.fetchChildren(of: url)
                updateChildren(of: url, to: dirents)
            case let .tree(url, priority: _, childPriority: _):
                print("tree", url)
                let dirents = Workspace.fetchChildren(of: url)
                updateChildren(of: url, to: dirents)
            }
        }


        print("done listening")

//        await withTaskGroup(of: (URL, [Dirent], [LoadRequest]?).self) { group in
//            for await req in loadRequests {
//                switch req {
//                case let .directory(url, priority):
//                    group.addTask(priority: priority) {
//                        let dirents = Workspace.fetchChildren(of: url)
////                        return (url, dirents, nil)
//                    }
//                case let .tree(url, priority, childPriority):
//                    group.addTask(priority: priority) {
//                        let dirents = Workspace.fetchChildren(of: url)
//                        let reqs: [LoadRequest] = dirents.map {
//                            // All descendents get fetched with childPriority.
//                            .tree($0.url, priority: childPriority, childPriority: childPriority)
//                        }
////                        return (url, dirents, reqs)
//                    }
//                }
//            }
//        }

//            // TODO: some way to make sure an older user-generated load request doesn't race a FSEvent request (which if it was created
//            // later, is more up to date).
//
//            for await (url, children, newReqs) in group {
//                updateChildren(of: url, to: children)
//                if let newReqs {
//                    for req in newReqs {
//                        userLoadsContinuation.yield(req)
//                    }
//                }
//            }

    }

    static nonisolated func fetchChildren(of target: URL) -> [Dirent] {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: Dirent.resourceKeys, options: [])
            
            var children: [Dirent] = []
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
                children.append(child)
            }

            children.sort()

            return children
        } catch {
            print("error fetching children of \(target): \(error)")
            return []
        }
    }

    func updateChildren(of target: URL, to newChildren: consuming [Dirent]) {
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
    }
}
