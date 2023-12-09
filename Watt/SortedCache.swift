//
//  SortedCache.swift
//  Watt
//
//  Created by David Albert on 12/8/23.
//

import Foundation

struct SortedCache<Element> {
    typealias Index = IndexSet.Index

    var dictionary: Dictionary<Int, Element>
    var keys: IndexSet

    subscript(key: Int) -> Element? {
        get {
            return dictionary[key]
        }
        set {
            if let value = newValue {
                if dictionary.updateValue(value, forKey: key) == nil {
                    assert(!keys.contains(key))
                    keys.insert(key)
                }
            } else {
                assert(dictionary.keys.contains(key) == keys.contains(key))

                if keys.contains(key) {
                    dictionary.removeValue(forKey: key)
                    keys.remove(key)
                }
            }
        }
    }

    mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        dictionary.removeAll(keepingCapacity: keepCapacity)
        keys.removeAll()
    }

    mutating func invalidate(range: Range<Int>) {
        for key in keys[keys.indexRange(in: range)] {
            dictionary.removeValue(forKey: key)
        }
        keys.remove(integersIn: range)
    }

    func key(before key: Int) -> Int? {
        keys.integerLessThan(key)
    }
}

extension SortedCache: BidirectionalCollection {
    var count: Int {
        assert(dictionary.count == keys.count)
        return dictionary.count
    }

    var startIndex: Index {
        keys.startIndex
    }

    var endIndex: Index {
        keys.endIndex
    }

    func index(before i: Index) -> Index {
        keys.index(before: i)
    }

    func index(after i: Index) -> Index {
        keys.index(after: i)
    }

    subscript(position: Index) -> (key: Int, element: Element) {
        (keys[position], dictionary[keys[position]]!)
    }
}

extension SortedCache: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (Int, Element)...) {
        self.init(elements)
    }
}

extension SortedCache {
    init<S: Sequence>(_ sequence: S) where S.Element == (Int, Element) {
        let d = Dictionary(sequence) { x, y in y }
        self.dictionary = d
        self.keys = IndexSet(d.keys)
    }
}

extension SortedCache: Equatable where Element: Equatable {
    static func ==(lhs: SortedCache, rhs: SortedCache) -> Bool {
        return lhs.dictionary == rhs.dictionary
    }
}

extension SortedCache: CustomStringConvertible {
    var description: String {
        dictionary.description
    }
}

extension SortedCache {
    static func + (lhs: SortedCache, rhs: SortedCache) -> SortedCache {
        var result = lhs
        for (key, value) in rhs {
            result[key] = value
        }
        return result
    }
}
