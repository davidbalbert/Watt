//
//  Weak.swift
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

struct WeakSet<Element> {
    private var storage: NSHashTable<AnyObject>

    init() {
        storage = .weakObjects()
    }

    @discardableResult
    mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        if !isKnownUniquelyReferenced(&storage) {
            // Is this thread safe? who knows?
            storage = NSCopyHashTableWithZone(storage, nil)
        }

        if let old = storage.member(newMember as AnyObject) {
            return (false, old as! Element)
        }

        storage.add(newMember as AnyObject)
        return (true, newMember)
    }

    @discardableResult
    mutating func remove(_ member: Element) -> Element? {
        if !isKnownUniquelyReferenced(&storage) {
            storage = NSCopyHashTableWithZone(storage, nil)
        }

        if let old = storage.member(member as AnyObject) {
            storage.remove(old)
            return (old as! Element)
        }

        return nil
    }

    func contains(_ member: Element) -> Bool {
        storage.contains(member as AnyObject)
    }
}

extension WeakSet: Sequence {
    struct Iterator: IteratorProtocol {
        var inner: NSFastEnumerationIterator

        init(_ storage: NSHashTable<AnyObject>) {
            self.inner = NSFastEnumerationIterator(storage)
        }

        mutating func next() -> Element? {
            guard let el = inner.next() else {
                return nil
            }

            return (el as! Element)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(storage)
    }
}
