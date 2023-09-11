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
    var type: UTType { get }
    var treeSitterClient: TreeSitterClient? { get }
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
            return .cHeader
        case .cSource:
            return .cSource
        default:
            return nil
        }
    }
}

enum Languages {}

extension Languages {
    struct PlainText: Language {
        var type: UTType {
            .plainText
        }

        var treeSitterClient: TreeSitterClient? {
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
    struct CSource: Language {
        var type: UTType {
            .cSource
        }

        var treeSitterClient: TreeSitterClient? {
            let treeSitterLanguage = TreeSitterLanguage(tsLanguage: tree_sitter_c())

            let url = bundle(forResource: "TreeSitterC_TreeSitterC")!
                .url(forResource: "queries/highlights", withExtension: "scm")!

            let highlightQuery = try! treeSitterLanguage.query(contentsOf: url)

            return TreeSitterClient(language: treeSitterLanguage, highlightQuery: highlightQuery)
        }
    }

    struct CHeader: Language {
        var type: UTType {
            .cHeader
        }

        var treeSitterClient: TreeSitterClient? {
            CSource().treeSitterClient
        }
    }
}

extension Language where Self == Languages.CSource {
    static var cSource: Self {
        Languages.CSource()
    }
}

extension Language where Self == Languages.CHeader {
    static var cHeader: Self {
        Languages.CHeader()
    }
}
