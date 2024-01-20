//
//  Dirent.swift
//  Watt
//
//  Created by David Albert on 1/10/24.
//

import Cocoa

struct FileID {
    let id: NSCopying & NSSecureCoding & NSObjectProtocol
}

extension FileID: Hashable {
    static func == (lhs: FileID, rhs: FileID) -> Bool {
        return lhs.id.isEqual(rhs.id)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.hash)
    }
}

struct Dirent: Identifiable {
    static let resourceKeys: [URLResourceKey] = [.fileResourceIdentifierKey, .isDirectoryKey, .isPackageKey, .isHiddenKey]
    static let resourceSet = Set(resourceKeys)

    enum Errors: Error {
        case isNotDirectory(URL)
        case missingAncestor(URL)
        case missingMetadata(URL)
        case missingChild(parent: URL, target: URL)
    }

    let id: FileID
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

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    var nameWithExtension: String {
        url.lastPathComponent
    }

    var isFolder: Bool {
        isDirectory && !isPackage
    }

    var isLoaded: Bool {
        isFolder && _children != nil
    }

    var directoryHint: URL.DirectoryHint {
        isDirectory ? .isDirectory : .notDirectory
    }

    init(id: FileID, url: URL, isDirectory: Bool, isPackage: Bool, isHidden: Bool) {
        self.id = id
        self.url = url
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isHidden = isHidden
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self._children = nil
    }

    init(for url: URL) throws {
        let url = url.standardizedFileURL
        let rv = try url.resourceValues(forKeys: Dirent.resourceSet)

        guard let resID = rv.fileResourceIdentifier, let isDirectory = rv.isDirectory, let isPackage = rv.isPackage, let isHidden = rv.isHidden else {
            throw Errors.missingMetadata(url)
        }

        self.init(
            id: FileID(id: resID),
            url: url,
            isDirectory: isDirectory,
            isPackage: isPackage,
            isHidden: isHidden
        )
    }

    func filteringChildren(showHidden: Bool) -> Dirent {
        if showHidden {
            return self
        } else {
            var copy = self
            copy._children = _children?.filter { !$0.isHidden }.map { $0.filteringChildren(showHidden: showHidden) }
            return copy
        }
    }

    mutating func updateDescendent(withURL target: URL, using block: (inout Dirent) -> Void) throws {
        if url == target {
            block(&self)
            return
        }

        if !isDirectory {
            throw Errors.isNotDirectory(target)
        }

        if _children == nil {
            throw Errors.missingAncestor(target)
        }

        let targetComponents = target.pathComponents
        for i in 0..<_children!.count {
            let childComponents = _children![i].url.pathComponents

            if childComponents[...] == targetComponents[0..<childComponents.count] {
                try _children![i].updateDescendent(withURL: target, using: block)
                return
            }
        }

        throw Errors.missingChild(parent: url, target: target)
    }
}

extension Dirent: Comparable {
    static func == (lhs: Dirent, rhs: Dirent) -> Bool {
        lhs.nameWithExtension.localizedCaseInsensitiveCompare(rhs.nameWithExtension) == .orderedSame
    }

    static func < (lhs: Dirent, rhs: Dirent) -> Bool {
        lhs.nameWithExtension.localizedCaseInsensitiveCompare(rhs.nameWithExtension) == .orderedAscending
    }
}

