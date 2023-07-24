//
//  TextView+LineNumbers.swift
//  Watt
//
//  Created by David Albert on 5/13/23.
//

import Cocoa

extension TextView {
    func addLineNumberView() {
        guard let scrollView else {
            return
        }

        scrollView.addFloatingSubview(lineNumberView, for: .horizontal)

        NSLayoutConstraint.activate([
            lineNumberView.topAnchor.constraint(equalTo: topAnchor),
            lineNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateComputedTextContainerInset()
        updateTextContainerSizeIfNeeded()
    }

    func removeLineNumberView() {
        lineNumberView.removeFromSuperview()

        updateComputedTextContainerInset()
        updateTextContainerSizeIfNeeded()
    }

    @objc func lineNumberViewFrameDidChange(_ notification: NSNotification) {
        if lineNumberView.superview == nil {
            // we don't care about frame changes unless the line number
            // view is actually showing.
            return
        }

        updateComputedTextContainerInset()
        updateTextContainerSizeIfNeeded()
    }
}
