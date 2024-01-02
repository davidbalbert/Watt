//
//  File.swift
//  
//
//  Created by David Albert on 1/2/24.
//

import Foundation

extension String: TextContent {}

@available(macOS 12, iOS 15, *)
extension AttributedString.CharacterView: TextContent {}

extension NSAttributedString: TextContent {
    public var startIndex: String.Index {
        string.startIndex
    }

    public var endIndex: String.Index {
        string.endIndex
    }

    public subscript(position: String.Index) -> Character {
        string[position]
    }

    public subscript(bounds: Range<String.Index>) -> Substring {
        string[bounds]
    }

    public func index(after i: String.Index) -> String.Index {
        string.index(after: i)
    }

    public func index(before i: String.Index) -> String.Index {
        string.index(before: i)
    }
}
