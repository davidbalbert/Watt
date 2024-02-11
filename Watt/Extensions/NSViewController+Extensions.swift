//
//  NSViewController+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/20/24.
//

import Cocoa

extension NSViewController {
    func presentErrorAsSheet(_ error: Error) {
        if let window = view.window {
            presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
        } else {
            presentError(error)
        }
    }
}
