//
//  TextContainer.swift
//  Watt
//
//  Created by David Albert on 5/6/23.
//

import Foundation

struct TextContainer: Equatable {
    var lineFragmentPadding: CGFloat = 5
    var size: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

    var width: CGFloat {
        size.width
    }

    var height: CGFloat {
        size.height
    }

    var bounds: CGRect {
        CGRect(origin: .zero, size: size)
    }

    var lineFragmentWidth: CGFloat {
        size.width - 2*lineFragmentPadding
    }
}
