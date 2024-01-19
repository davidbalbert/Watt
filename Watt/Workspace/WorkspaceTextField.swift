//
//  WorkspaceTextField.swift
//  Watt
//
//  Created by David Albert on 1/19/24.
//

import Cocoa

@objc protocol WorkspaceTextFieldDelegate: NSTextFieldDelegate {
    @objc optional func textFieldDidBecomeFirstResponder(_ textField: WorkspaceTextField)
    @objc optional func textFieldDidResignFirstResponder(_ textField: WorkspaceTextField)
}

class WorkspaceTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            (delegate as? WorkspaceTextFieldDelegate)?.textFieldDidBecomeFirstResponder?(self)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            (delegate as? WorkspaceTextFieldDelegate)?.textFieldDidResignFirstResponder?(self)
        }
        return result
    }
}
