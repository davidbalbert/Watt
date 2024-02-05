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
        case notDescendant(URL)
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

    init(id: FileID, url: URL, isDirectory: Bool, isPackage: Bool, isHidden: Bool, children: [Dirent]? = nil) {
        self.id = id
        self.url = url
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isHidden = isHidden
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self._children = children
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

    init(moving old: Dirent, to newURL: URL) {
        self.init(
            id: old.id,
            url: newURL,
            isDirectory: old.isDirectory,
            isPackage: old.isPackage,
            isHidden: old.isHidden,
            children: old._children?.map { Dirent(moving: $0, to: newURL.appendingPathComponent($0.nameWithExtension)) }
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

    mutating func updateDescendant(withURL target: URL, using block: (inout Dirent) -> Void) throws {
        guard target.isDescendant(ofFileURL: url) else {
            throw Errors.notDescendant(target)
        }

        func helper(_ dirent: inout Dirent) throws {
            if dirent.url == target {
                block(&dirent)
                return
            }

            if !dirent.isDirectory {
                throw Errors.isNotDirectory(target)
            }

            if dirent._children == nil {
                throw Errors.missingAncestor(target)
            }

            for i in 0..<dirent._children!.count {
                if target.isDescendant(ofFileURL: dirent._children![i].url) {
                    try helper(&dirent._children![i])
                    return
                }
            }

            throw Errors.missingChild(parent: dirent.url, target: target)
        }

        try helper(&self)
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

extension Dirent: Codable {
    enum CodingKeys: String, CodingKey {
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let url = try container.decode(URL.self, forKey: .url)
        try self.init(for: url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
    }
}


extension NSPasteboard.PasteboardType {
    static let dirent = NSPasteboard.PasteboardType("is.dave.Watt.ReferenceDirent")
}

class ReferenceDirent: NSObject {
    let url: URL

    init(_ dirent: Dirent) {
        self.url = dirent.url
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let data = propertyList as? Data, let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let url = URL(string: string) else {
            return nil
        }

        self.url = url
    }
}

extension ReferenceDirent: NSPasteboardReading, NSPasteboardWriting {
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.dirent]
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.dirent]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        Data(url.absoluteString.utf8)
    }
}
