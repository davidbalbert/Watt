//
//  TextContainer.swift
//  Watt
//
//  Created by David Albert on 5/6/23.
//

import Foundation

struct TextContainer: Equatable {
    var lineFragmentPadding: CGFloat = 5
    var size: CGSize = .zero

    var width: CGFloat {
        size.width
    }

    var height: CGFloat {
        size.height
    }

    var lineFragmentWidth: CGFloat {
        size.width - 2*lineFragmentPadding
    }
}
