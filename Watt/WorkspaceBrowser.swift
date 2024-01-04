//
//  WorkspaceBrowser.swift
//  Watt
//
//  Created by David Albert on 1/3/24.
//

import SwiftUI

struct Dirent: Hashable, Identifiable {
    var id: Self { self }

    let name: String
    let children: [Dirent]?

    init(name: String, children: [Dirent]? = nil) {
        self.name = name
        self.children = children
    }

    init?(url: URL) {
        // check if URL is a file or directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return nil
        }

        if isDir.boolValue {
            // read directory contents
            let contents = try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            let children = contents.compactMap(Dirent.init)
            self.init(name: url.lastPathComponent, children: children)
        } else {
            self.init(name: url.lastPathComponent)
        }
    }
}

@Observable
class Project {
    let url: URL
    let root: Dirent

    init?(url: URL) {
        guard let root = Dirent(url: url) else {
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
        List([project.root], children: \.children) {
            Text($0.name)
                .lineLimit(1)
                .listRowSeparator(.hidden)
        }
    }
}

#if DEBUG
let previewData =
    Dirent(name: "Watt", children: [
        Dirent(name: "LLDBInitFile"),
        Dirent(name: "Watt.xcconfig"),
        Dirent(name: "Developer.xcconfig"),
        Dirent(name: "WattUITests", children: [
            Dirent(name: "WattUITests.swift"),
            Dirent(name: "WattUITestsLaunchTests.swift")
        ]),
        Dirent(name: "Watt.xcodeproj"),
        Dirent(name: "lldb_utils.py"),
        Dirent(name: "README.md"),
        Dirent(name: "WattTests", children: [
            Dirent(name: "HeightsTests.swift"),
            Dirent(name: "SpansTests.swift"),
            Dirent(name: "UtilitiesTest.swift"),
            Dirent(name: "RopeTests.swift"),
            Dirent(name: "Support", children: [
                Dirent(name: "AssertPreconditionViolation.swift")
            ]),
            Dirent(name: "IntervalCacheTests.swift"),
            Dirent(name: "LayoutManagerTests.swift"),
            Dirent(name: "BufferTests.swift"),
            Dirent(name: "AttributedRopeTests.swift")
        ]),
        Dirent(name: "ACKNOWLEDGEMENTS.md"),
        Dirent(name: "StandardKeyBindingResponder", children: [
            Dirent(name: "Tests", children: [
                Dirent(name: "StandardKeyBindingResponderTests", children: [
                    Dirent(name: "TestTextLayoutDataSourceTests.swift"),
                    Dirent(name: "SelectionNavigatorTests.swift"),
                    Dirent(name: "TransposerTests.swift"),
                    Dirent(name: "TextLayoutDataSourceTests.swift"),
                    Dirent(name: "Support", children: [
                        Dirent(name: "TestTextLayoutDataSource.swift"),
                        Dirent(name: "TestSelection.swift"),
                        Dirent(name: "Foundation+Extensions.swift")
                    ]),
                    Dirent(name: "TestSelectionTests.swift")
                ])
            ]),
            Dirent(name: "README.md"),
            Dirent(name: "Package.swift"),
            Dirent(name: "Sources", children: [
                Dirent(name: "StandardKeyBindingResponder", children: [
                    Dirent(name: "SelectionNavigator.swift"),
                    Dirent(name: "Foundation+Extensions.swift"),
                    Dirent(name: "TextLayoutDataSource.swift"),
                    Dirent(name: "TextContent.swift"),
                    Dirent(name: "Transposer.swift")
                ])
            ]),
            Dirent(name: "LICENSE.txt"),
            Dirent(name: ".vscode", children: [
                Dirent(name: "settings.json")
            ])
        ]),
        Dirent(name: "Watt", children: [
            Dirent(name: "TextView+LineNumbers.swift"),
            Dirent(name: "Moby Dick.txt"),
            Dirent(name: "SelectionLayer.swift"),
            Dirent(name: "LayoutManager.swift"),
            Dirent(name: "Buffer.swift"),
            Dirent(name: "Language.swift"),
            Dirent(name: "Utilities.swift"),
            Dirent(name: ".DS_Store"),
            Dirent(name: "Spans.swift"),
            Dirent(name: "TextView+Pasteboard.swift"),
            Dirent(name: "CGSize+Extensions.swift"),
            Dirent(name: "String+Extensions.swift"),
            Dirent(name: "TextView+FirstResponder.swift"),
            Dirent(name: "TextView+Mouse.swift"),
            Dirent(name: "LineLayer.swift"),
            Dirent(name: "Watt.entitlements"),
            Dirent(name: "WorkspaceBrowser.swift"),
            Dirent(name: "TextView+KeyBinding.swift"),
            Dirent(name: "WindowController.swift"),
            Dirent(name: "Assets.xcassets", children: [
                Dirent(name: "AppIcon.appiconset", children: [
                    Dirent(name: "Contents.json")
                ]),
                Dirent(name: "AccentColor.colorset", children: [
                    Dirent(name: "Contents.json")
                ]),
                Dirent(name: "Contents.json")
            ]),
            Dirent(name: "TextView+Selection.swift"),
            Dirent(name: "Rope.swift"),
            Dirent(name: "Base.lproj", children: [
                Dirent(name: "MainMenu.xib")
            ]),
            Dirent(name: "LineFragment.swift"),
            Dirent(name: "NSRange+Extensions.swift"),
            Dirent(name: "BTree.swift"),
            Dirent(name: "TextView+Input.swift"),
            Dirent(name: "CGPoint+Extensions.swift"),
            Dirent(name: "TextContainer.swift"),
            Dirent(name: "Heights.swift"),
            Dirent(name: "Document.swift"),
            Dirent(name: "Line.swift"),
            Dirent(name: "AttributedRope.swift"),
            Dirent(name: "TextView.swift"),
            Dirent(name: "LineNumberView", children: [
                Dirent(name: "LineNumberView.swift"),
                Dirent(name: "LineNumberLayer.swift")
            ]),
            Dirent(name: "IntervalCache.swift"),
            Dirent(name: "TextView+Layout.swift"),
            Dirent(name: "AppDelegate.swift"),
            Dirent(name: "TextViewController.swift"),
            Dirent(name: "Theme.swift"),
            Dirent(name: "TreeSitter.swift"),
            Dirent(name: "ClipView.swift"),
            Dirent(name: "Selection.swift"),
            Dirent(name: "CGRect+Extensions.swift"),
            Dirent(name: "Themes", children: [
                Dirent(name: "Default (Light).xccolortheme"),
                Dirent(name: "Default (Dark).xccolortheme")
            ]),
            Dirent(name: "Highlighter.swift"),
            Dirent(name: "Collection+Extensions.swift"),
            Dirent(name: "Info.plist"),
            Dirent(name: "Comparable+Extensions.swift"),
            Dirent(name: "InsertionPointLayer.swift"),
            Dirent(name: "Weak.swift")
        ]),
        Dirent(name: "LICENSE.txt")
    ])
#endif

#Preview {
    WorkspaceBrowser(project: Project(url: URL(filePath: "/tmp"), root: previewData))
        .frame(width: 300, height: 600)
}
