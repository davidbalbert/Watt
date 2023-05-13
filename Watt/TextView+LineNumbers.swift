//
//  TextView+LineNumbers.swift
//  Watt
//
//  Created by David Albert on 5/13/23.
//

import Cocoa

extension TextView {
    func addLineNumberView() {
        guard let enclosingScrollView else {
            return
        }

        if enclosingScrollView.documentView == self {
            enclosingScrollView.addFloatingSubview(lineNumberView, for: .vertical)
            let clipView = enclosingScrollView.contentView

            NSLayoutConstraint.activate([
                lineNumberView.topAnchor.constraint(equalTo: clipView.topAnchor),
                lineNumberView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
                lineNumberView.widthAnchor.constraint(equalToConstant: 40)
            ])
        }
    }

    func removeLineNumberView() {
        lineNumberView.removeFromSuperview()
    }
}
