//
//  WorkspaceBrowser.swift
//  Watt
//
//  Created by David Albert on 1/3/24.
//

import SwiftUI

struct Dirent: Hashable, Identifiable {
    static let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .isPackageKey, .creationDateKey, .contentModificationDateKey, .isHiddenKey]
    static let resourceSet = Set(resourceKeys)

    let url: URL
    let children: [Dirent]?

    var id: URL { url }
    var name: String {
        url.lastPathComponent
    }

    var isDirectory: Bool {
        children != nil
    }

    init(url: URL, children: [Dirent]? = nil) {
        self.url = url
        self.children = children
    }

    init?(directoryURL url: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
            return nil
        }

        var children: [Dirent] = []
        for url in urls {
            guard let resourceValues = try? url.resourceValues(forKeys: Self.resourceSet) else {
                continue
            }

            if resourceValues.isHidden ?? false {
                continue
            }

            if (resourceValues.isDirectory ?? false) && !(resourceValues.isPackage ?? false) {
                guard let child = Dirent(directoryURL: url) else {
                    continue
                }

                children.append(child)
            } else {
                children.append(Dirent(url: url))
            }
        }

        children.sort()

        self.init(url: url, children: children)
    }
}

extension Dirent: Comparable {
    static func < (lhs: Dirent, rhs: Dirent) -> Bool {
        if lhs.isDirectory && !rhs.isDirectory {
            return true
        } else if !lhs.isDirectory && rhs.isDirectory {
            return false
        } else {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

@Observable
class Project {
    let url: URL
    let root: Dirent

    init?(url: URL) {
        guard let root = Dirent(directoryURL: url) else {
            return nil
        }

        self.url = url
        self.root = root
    }

    init(url: URL, root: Dirent) {
        self.url = url
        self.root = root
    }
}

struct WorkspaceBrowser: View {
    @State var project: Project

    var body: some View {
        List(project.root.children!, children: \.children) {
            Text($0.name)
                .lineLimit(1)
                .listRowSeparator(.hidden)
        }
    }
}

#if DEBUG
// Loaded out here because in #Preview, #file is in the DerivedData folder.
let previewData = Dirent(directoryURL: URL(filePath: #file).deletingLastPathComponent().deletingLastPathComponent())!
#endif

#Preview {
    WorkspaceBrowser(project: Project(url: URL(filePath: "/tmp"), root: previewData))
        .frame(width: 300, height: 600)
}
