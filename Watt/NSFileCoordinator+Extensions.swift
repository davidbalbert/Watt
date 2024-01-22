//
//  NSFileCoordinator+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Foundation

extension NSFileCoordinator {
    // TODO: replace with isolated(caller) or similar when this proposal gets implemented: https://forums.swift.org/t/pitch-inheriting-the-callers-actor-isolation/68391

    // While I haven't observed any deadlocks like I did with NSFilePromiseReceiver.receivePromisedFiles(atDestination:options:operationQueue:), I think this is still unsafe to use without inheriting our parent's actor isolation – NSFileCoordinator is unsafe
    @_unsafeInheritExecutor
    func coordinate<T>(with intents: [NSFileAccessIntent], queue: OperationQueue, byAccessor accessor: @escaping @Sendable () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            coordinate(with: intents, queue: queue) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    do {
                        continuation.resume(returning: try accessor())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
