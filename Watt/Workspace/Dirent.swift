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
    static let resourceKeys: [URLResourceKey] = [.fileResourceIdentifierKey, .nameKey, .isDirectoryKey, .isPackageKey, .creationDateKey, .isHiddenKey, .contentModificationDateKey]
    static let resourceSet = Set(resourceKeys)

    let id: FileID
    let name: String
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

    var isLoaded: Bool {
        isFolder && _children != nil
    }

    init(id: FileID, name: String, url: URL, isDirectory: Bool, isPackage: Bool, isHidden: Bool, children: [Dirent]? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isHidden = isHidden
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self._children = children
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
            print("Missing ancestor of \(target). Ignoring.")
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

