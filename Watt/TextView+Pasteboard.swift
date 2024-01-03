//
//  TextView+Pasteboard.swift
//  Watt
//
//  Created by David Albert on 1/3/24.
//

import Cocoa

extension TextView {
    @objc func copy(_ sender: Any) {
        let string = String(buffer[selection.range])
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([string as NSString])
    }

    @objc func paste(_ sender: Any) {
        guard let string = NSPasteboard.general.readObjects(forClasses: [NSString.self])?.first else {
            return
        }
        replaceSubrange(selection.range, with: string as! String)
    }

    @objc func cut(_ sender: Any) {
        copy(sender)
        replaceSubrange(selection.range, with: "")
    }
}

extension TextView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(copy(_:)), #selector(cut(_:)):
            return !selection.range.isEmpty
        default:
            return true
        }
    }
}
