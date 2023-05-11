//
//  TextContainer.swift
//  Watt
//
//  Created by David Albert on 5/6/23.
//

import Foundation

class TextContainer<Storage> where Storage: TextStorage {
    var size: CGSize = .zero {
        didSet {
            layoutManager?.invalidateLayout()
        }
    }

    var width: CGFloat {
        size.width
    }

    var height: CGFloat {
        size.height
    }

    var lineWidth: CGFloat {
        size.width - 2*lineFragmentPadding
    }
    
    var lineFragmentPadding: CGFloat = 5
    weak var layoutManager: LayoutManager<Storage>?
}
