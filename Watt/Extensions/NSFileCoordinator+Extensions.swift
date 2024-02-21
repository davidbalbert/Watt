//
//  NSFileCoordinator+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Foundation

fileprivate struct Cancel: @unchecked Sendable {
    let coordinator: NSFileCoordinator

    func callAsFunction() {
        coordinator.cancel()
    }
}

extension NSFileCoordinator {
    // TODO: replace with isolated(caller) or similar when this proposal gets implemented: https://forums.swift.org/t/pitch-inheriting-the-callers-actor-isolation/68391

    // While I haven't observed any deadlocks like I did with NSFilePromiseReceiver.receivePromisedFiles(atDestination:options:operationQueue:), I think this is still unsafe to use without inheriting our parent's actor isolation – NSFileCoordinator is not sendable
    @_unsafeInheritExecutor
    func coordinate<T>(with intents: [NSFileAccessIntent], queue: OperationQueue, byAccessor accessor: @escaping @Sendable () throws -> T) async throws -> T {
        // NSFileCoordinator.cancel() is thread-safe, so we wrap it in an unchecked Sendable struct.
        let cancel = Cancel(coordinator: self)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
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
        } onCancel: {
            cancel()
        }
    }

    func coordinate<T>(readingItemAt url: URL, options: NSFileCoordinator.ReadingOptions = [], byAccessor reader: (URL) throws -> T) throws -> T {
        var result: Result<T, Error>?
        var error: NSError?
        coordinate(readingItemAt: url, error: &error) { actualURL in
            result = Result {
                try reader(actualURL)
            }
        }
        if let error {
            throw error
        }
        return try result!.get()
    }
}
