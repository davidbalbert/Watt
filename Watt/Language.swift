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
    var parser: TreeSitterParser? { get }
    
    func query(forContentsOf: URL) -> TreeSitterQuery?
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
        
        var parser: TreeSitterParser? {
            nil
        }
        
        func query(forContentsOf url: URL) -> TreeSitterQuery? {
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
        
        var parser: TreeSitterParser? {
            TreeSitterParser()
        }
        
        func query(forContentsOf url: URL) -> TreeSitterQuery? {
            nil
        }
    }

    struct CHeader: Language {
        var type: UTType {
            .cHeader
        }
        
        var parser: TreeSitterParser? {
            TreeSitterParser()
        }
        
        func query(forContentsOf url: URL) -> TreeSitterQuery? {
            nil
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
