//
//  EmptyWorkspaceViewController.swift
//  Watt
//
//  Created by David Albert on 1/31/24.
//

import Cocoa

class EmptyWorkspaceViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "Choose Folder", target: nil, action: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        view.addConstraints([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
