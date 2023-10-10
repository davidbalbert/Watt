//
//  Language.swift
//  Watt
//
//  Created by David Albert on 9/10/23.
//

import Foundation
import UniformTypeIdentifiers

import TreeSitterC

protocol Language {
    var highlighter: Highlighter? { get }
}

extension Language {
    func bundle(forResource name: String) -> Bundle? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "bundle") else {
            return nil
        }

        return Bundle(url: url)
    }

    func url(forResource resourceName: String, withExtension ext: String?, in bundleName: String) -> URL? {
        bundle(forResource: bundleName)?.url(forResource: resourceName, withExtension: ext)
    }
}

extension UTType {
    var language: Language? {
        switch self {
        case .plainText:
            return .plainText
        case .cHeader:
            return .c
        case .cSource:
            return .c
        default:
            return nil
        }
    }
}

enum Languages {}

extension Languages {
    struct PlainText: Language {
        var highlighter: Highlighter? {
            nil
        }
    }
}

extension Language where Self == Languages.PlainText {
    static var plainText: Self {
        Languages.PlainText()
    }
}

extension Languages {
    struct C: Language {
        var highlighter: Highlighter? {
            let treeSitterLanguage = TreeSitterLanguage(tree_sitter_c())
            guard let parser = try? TreeSitterParser(language: treeSitterLanguage, encoding: .utf8) else {
                return nil
            }

            let url = url(forResource: "queries/highlights", withExtension: "scm", in: "TreeSitterC_TreeSitterC")!
            let highlightsQuery = try! treeSitterLanguage.query(contentsOf: url)

            return Highlighter(parser: parser, highlightsQuery: highlightsQuery)
        }
    }
}

extension Language where Self == Languages.C {
    static var c: Self {
        Languages.C()
    }
}
