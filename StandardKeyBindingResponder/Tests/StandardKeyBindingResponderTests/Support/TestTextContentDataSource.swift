//
//  TestTextContentDataSource.swift
//  
//
//  Created by David Albert on 12/6/23.
//

import Foundation
@testable import StandardKeyBindingResponder

struct TestTextContentDataSource: TextContentDataSource {
    var s: String

    init(_ s: String) {
        self.s = s
    }

    var documentRange: Range<String.Index> {
        s.startIndex..<s.endIndex
    }

    func index(_ i: String.Index, offsetBy distance: Int) -> String.Index {
        s.index(i, offsetBy: distance)
    }

    func distance(from start: String.Index, to end: String.Index) -> Int {
        s.distance(from: start, to: end)
    }

    subscript(index: String.Index) -> Character {
        s[index]
    }

    var characterCount: Int {
        s.count
    }
}

extension TestTextContentDataSource: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.s = value
    }
}
