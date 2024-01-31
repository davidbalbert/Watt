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

    override func viewDidLoad() {
        super.viewDidLoad()
        updateChildViewControllers()
    }

    func updateChildViewControllers() {
        children = []
        view.subviews = []

        if let containedViewController {
            addChild(containedViewController)

            let subview = containedViewController.view
            subview.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(subview)

            view.addConstraints([
                subview.topAnchor.constraint(equalTo: view.topAnchor),
                subview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
    }
}
