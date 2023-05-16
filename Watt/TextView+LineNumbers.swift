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
        layoutLineNumberView()
    }

    func removeLineNumberView() {
        lineNumberView.removeFromSuperview()
    }

    func layoutLineNumberView() {
        lineNumberView.frame = CGRect(x: 0, y: 0, width: lineNumberView.intrinsicContentSize.width, height: frame.height)
    }

    func lineNumberViewFrameDidChange(_ notification: NSNotification) {
        updateTextContainerSize()
        needsLayout = true
    }

    func lineCount(for lineNumberView: LineNumberView) -> Int {
        layoutManager.lineCount
    }
}
