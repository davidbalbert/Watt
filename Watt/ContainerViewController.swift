//
//  ContainerViewController.swift
//  Watt
//
//  Created by David Albert on 1/31/24.
//

import Cocoa

// A view controller with a single child view controller that can be swapped out when needed.
class ContainerViewController: NSViewController {
    var containedViewController: NSViewController? {
        didSet {
            updateChildViewControllers()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateChildViewControllers()
    }

    func updateChildViewControllers() {
        children = []
        view.subviews = []

        if let containedViewController {
            addChild(containedViewController)
            view.addSubview(containedViewController.view)
        }
    }
}
