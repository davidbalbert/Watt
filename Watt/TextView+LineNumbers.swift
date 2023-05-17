//
//  TextView+LineNumbers.swift
//  Watt
//
//  Created by David Albert on 5/13/23.
//

import Cocoa

extension TextView: LineNumberViewDelegate {
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
    }

    func removeLineNumberView() {
        lineNumberView.removeFromSuperview()
    }

    func lineNumberViewFrameDidChange(_ notification: NSNotification) {
        updateTextContainerSizeIfNecessary()
        needsLayout = true
    }

    func lineCount(for lineNumberView: LineNumberView) -> Int {
        layoutManager.lineCount
    }
}
