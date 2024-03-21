//
//  TextView+Transactions.swift
//  Watt
//
//  Created by David Albert on 3/19/24.
//

import Foundation
import OrderedCollections

extension TextView {
    enum Action {
        case textLayout
        case selectionLayout
        case insertionPointLayout
    }

    struct Transaction {
        var count: Int
        var actions: OrderedSet<Action>
        var committing: Bool

        init() {
            count = 0
            actions = []
            committing = false
        }
    }

    func beginTransaction() {
        precondition(!transaction.committing, "can't start a transaction while committing an existing one")
        transaction.count += 1
    }

    func endTransaction() {
        precondition(transaction.count >= 1)
        transaction.count -= 1

        guard transaction.count == 0 else {
            return
        }

        transaction.committing = true
        defer { transaction.committing = false }

        for action in transaction.actions {
            switch action {
            case .textLayout:
                layoutTextLayer()
            case .selectionLayout:
                layoutSelectionLayer()
            case .insertionPointLayout:
                layoutInsertionPointLayer()
            }
        }

        transaction.actions.removeAll(keepingCapacity: true)
     }

    @discardableResult
    func transaction<T>(block: () -> T) -> T {
        beginTransaction()
        defer { endTransaction() }
        return block()
    }

    func schedule(_ action: Action) {
        transaction {
            transaction.actions.append(action)
        }
    }
}
