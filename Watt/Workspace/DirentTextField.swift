//
//  DirentTextField.swift
//  Watt
//
//  Created by David Albert on 1/19/24.
//

import Cocoa

@objc protocol DirentTextFieldDelegate: NSTextFieldDelegate {
    @objc optional func textFieldDidBecomeFirstResponder(_ textField: DirentTextField)
    @objc optional func textFieldDidResignFirstResponder(_ textField: DirentTextField)
}

class DirentTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            (delegate as? DirentTextFieldDelegate)?.textFieldDidBecomeFirstResponder?(self)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            (delegate as? DirentTextFieldDelegate)?.textFieldDidResignFirstResponder?(self)
        }
        return result
    }
}
