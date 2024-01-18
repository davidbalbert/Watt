//
//  Workspace+LoadRequest.swift
//  Watt
//
//  Created by David Albert on 1/18/24.
//

import Foundation

extension Workspace {
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
}