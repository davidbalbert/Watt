//
//  WorkspaceBrowser.swift
//  Watt
//
//  Created by David Albert on 1/3/24.
//

import SwiftUI

struct DirentLabel: View {
    let dirent: Dirent

    var body: some View {
        HStack {
            Image(nsImage: dirent.icon)
                .resizable()
                .frame(width: 16, height: 16)

            Text(dirent.name)
                .lineLimit(1)
        }
        .listRowSeparator(.hidden)
    }
}

struct DirentView: View {
    let dirent: Dirent

    var body: some View {
        if let children = dirent.children {
            DisclosureGroup {
                ForEach(children) { child in
                    DirentView(dirent: child)
                }
            } label: {
                DirentLabel(dirent: dirent)
            }
        } else {
            DirentLabel(dirent: dirent)
        }
    }
}


struct WorkspaceBrowser: View {
    @State var workspace: Workspace
    @State var selection: Set<URL> = []

    var body: some View {
        // Should never be nil because workspace is guaranteed to be a directory
        List {
            ForEach(workspace.root.children!) { dirent in
                DirentView(dirent: dirent)
            }
        }
    }
}

#Preview {
    return WorkspaceBrowser(workspace: Workspace(url: URL(filePath: "/Users/david/Developer/Watt/Watt")))
       .frame(width: 300, height: 600)
}
