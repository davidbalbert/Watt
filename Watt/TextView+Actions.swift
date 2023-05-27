//
//  TextView+Actions.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

extension TextView {
    override func doCommand(by selector: Selector) {
        print("doCommand(by:)", selector)
        super.doCommand(by: selector)
    }
}
