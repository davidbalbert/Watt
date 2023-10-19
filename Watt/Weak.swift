//
//  WeakDictionary.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Foundation

// NSMapTable, but the keys can be any Hashable (if keys
// are objects, they are held strongly).

struct WeakDictionary<Key: Hashable, Value: AnyObject> {
    struct WeakRef {
        weak var value: Value?
    }

    private var storage: [Key: WeakRef]

    init() {
        storage = [:]
    }

    var count: Int {
        storage.count
    }

    var limit: Int {
        256
    }

    subscript(key: Key) -> Value? {
        mutating get {
            if storage.count > limit {
                compact()
            }

            guard let ref = storage[key] else {
                return nil
            }

            if ref.value == nil {
                storage.removeValue(forKey: key)
                return nil
            }

            return ref.value
        }

        set {
            if let newValue = newValue {
                storage[key] = WeakRef(value: newValue)
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }

    mutating func compact() {
        var toRemove: [Key] = []

        for (k, v) in storage {
            if v.value == nil {
                toRemove.append(k)
            }
        }

        for k in toRemove {
            storage.removeValue(forKey: k)
        }
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
    }
}

struct WeakSet<Element> where Element: AnyObject {

}
