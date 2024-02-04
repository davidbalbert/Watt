//
//  DocumentController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa
import UniformTypeIdentifiers

class DocumentController: NSDocumentController {
    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?, completionHandler: @escaping (Int) -> Void) {
        openPanel.canChooseDirectories = true
        super.beginOpenPanel(openPanel, forTypes: inTypes, completionHandler: completionHandler)
    }

    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        print("runModalOpenPanel")
        return super.runModalOpenPanel(openPanel, forTypes: types)
    }
}
