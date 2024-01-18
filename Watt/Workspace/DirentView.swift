//
//  DirentView.swift
//  Watt
//
//  Created by David Albert on 1/17/24.
//

import SwiftUI

struct DirentView: View {
    let dirent: Dirent
    @Bindable var workspace: Workspace
    @State var name: String = ""
    @State var isEditing: Bool = false
    @FocusState var isFocused: Bool

    @MainActor
    var isSelected: Bool {
        workspace.selection.contains(dirent.id)
    }

    @MainActor
    var isEditable: Bool {
        isSelected && workspace.selection.count == 1
    }

    var body: some View {
        HStack {
            Image(nsImage: dirent.icon)
                .resizable()
                .frame(width: 16, height: 16)

            if isEditing {
                TextField("", text: $name)
                    .accessibilityLabel("File name")
                    .textFieldStyle(.plain)
                    .background(.white)
                    .focused($isFocused)
                    .onSubmit {
                        // TODO: something other than try!
                        try! workspace.renameFile()
                    }
            } else {
                Text(dirent.name)
                    .lineLimit(1)
            }

            Spacer()
        }
        .listRowSeparator(.hidden)
        .allowsHitTesting(isEditable)
        .onTapGesture {
            isEditing = true
            isFocused = true
            name = dirent.name
        }
        .onChange(of: isFocused) {
            if !isFocused {
                isEditing = false
            }
        }
    }
}
