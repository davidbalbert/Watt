//
//  Workspace+LoadRequest.swift
//  Watt
//
//  Created by David Albert on 1/18/24.
//

import Foundation

extension Workspace {
    enum LoadRequest: Hashable {
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
            case let .itemClonedAtPath(path: path, itemType: _, eventId: _, fromUs: _, extendedData: _):
                // I don't know why we're getting this. The docs say "This flag is only ever set if you
                // specified the FileEvents flag when creating the stream," which we're not doing. But
                // we're getting it, and responding to it fixes a bug:
                //
                // When I chose "Move to Trash" inside Tower, we don't get a .generic event for the containing
                // directory, but we do seem to get an .itemClonedAtPath, so we respond to it to reload
                // the directory.
                let url = URL(filePath: path, directoryHint: .checkFileSystem)

                if url.hasDirectoryPath {
                    self = .directory(url)
                } else {
                    return nil
                }
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
}
