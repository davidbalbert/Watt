//
//  TextView+FirstResponder.swift
//  Watt
//
//  Created by David Albert on 11/9/23.
//

import Cocoa

extension TextView {
    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    var isFirstResponder: Bool {
        window?.firstResponder == self
    }

    var windowIsKey: Bool {
        window?.isKeyWindow ?? false
    }

    override func becomeFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.resignFirstResponder()
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
    }

    @objc func windowDidResignKey(_ notification: Notification) {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
    }
}
