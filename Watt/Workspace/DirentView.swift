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

    // See comment in .onKeyPress(.escape)
    @State var didCancel: Bool = false

    @MainActor
    var isSelected: Bool {
        workspace.selection.contains(dirent.id)
    }

    @MainActor
    var isEditable: Bool {
        isSelected && workspace.selection.count == 1
    }

    func beginEditing() {
        isEditing = true
        isFocused = true
        name = dirent.name
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
//                        try! workspace.renameFile()
                    }
                    .onKeyPress(.escape) {
                        // Hack: using onExitCommand or .onCommand(#selector(NSResponder.cancelOperation(_:))) causes
                        // the NSOutlineView to lose first responder (gray selection, no keyboard navigation). Ditto
                        // for using onKeyPress and returning .handled.
                        //
                        // Instead, we use onKeyPress and let the key event bubble up to our superview. In addition, we
                        // set didCancel so that our change handler knows not to rename the file.
                        didCancel = true
                        isEditing = false
                        return .ignored
                    }
            } else {
                Text(dirent.name)
                    .lineLimit(1)
            }

            Spacer()
        }
        .allowsHitTesting(isEditable)
        .onTapGesture {
            beginEditing()
        }
        .onChange(of: isFocused) {
            if !isFocused && !didCancel {
                isEditing = false
            }
            didCancel = false
        }
    }
}
