//
//  WorkspaceBrowser.swift
//  Watt
//
//  Created by David Albert on 1/3/24.
//

import SwiftUI

struct WorkspaceBrowser: View {
    @State var workspace: Workspace
    @State var selection: Set<URL> = []

    var body: some View {
        // Should never be nil because workspace is guaranteed to be a directory
        List(workspace.root.children!, children: \.children, selection: $selection) { dirent in
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
}

#Preview {
    return WorkspaceBrowser(workspace: Workspace(url: URL(filePath: "/")))
       .frame(width: 300, height: 600)
}
