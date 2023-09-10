//
//  Highlighter.swift
//  Watt
//
//  Created by David Albert on 9/10/23.
//

import Foundation
import UniformTypeIdentifiers

import TreeSitterC

class Highlighter {
    weak var buffer: Buffer?

    var parser: TreeSitterParser
    var tree: TreeSitterTree?

    init?(for buffer: Buffer) {
        self.buffer = buffer

        guard let l = TreeSitterLanguage(forType: buffer.language.type) else {
            return nil
        }

        let parser = TreeSitterParser()
        guard (try? parser.setLanguage(l)) != nil else {
            return nil
        }

        self.parser = parser
    }

    func highlight() {
        guard let buffer else {
            return
        }
        
        self.tree = parser.parse(buffer.text, oldTree: tree)
    }
}

extension TreeSitterLanguage {
    init?(forType type: UTType) {
        switch type {
        case .cHeader, .cSource:
            self.init(tsLanguage: tree_sitter_c())
        default:
            return nil
        }
    }
}
