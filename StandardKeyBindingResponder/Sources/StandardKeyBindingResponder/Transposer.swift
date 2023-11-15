//
//  Transposer.swift
//
//
//  Created by David Albert on 11/15/23.
//

import Foundation

public enum Transposer<DataSource> where DataSource: DocumentContentDataSource {
    public typealias Index = DataSource.Index

    public static func transposeIndices(inSelectedRange range: Range<Index>, dataSource: DataSource) -> (Index, Index)? {
        if dataSource.characterCount < 2 {
            return nil
        }

        guard range.isEmpty || dataSource.distance(from: range.lowerBound, to: range.upperBound) == 2 else {
            return nil
        }

        let i: DataSource.Index
        let lineStart = dataSource.index(roundedDownToParagraph: range.lowerBound)

        if !range.isEmpty {
            i = range.lowerBound
        } else if lineStart == range.lowerBound {
            i = lineStart
        } else if range.lowerBound == dataSource.endIndex {
            i = dataSource.index(range.lowerBound, offsetBy: -2)
        } else {
            i = dataSource.index(before: range.lowerBound)
        }

        return (i, dataSource.index(after: i))
    }
}
