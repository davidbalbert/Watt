//
//  LineNumberViewDelegate.swift
//  Watt
//
//  Created by David Albert on 5/13/23.
//

import Foundation

protocol LineNumberViewDelegate: AnyObject {
    func lineNumberViewFrameDidChange(_ notification: NSNotification)
    func lineCount(for lineNumberView: LineNumberView) -> Int
}
