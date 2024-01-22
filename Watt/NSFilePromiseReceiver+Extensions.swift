//
//  NSFilePromiseReceiver+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Cocoa

extension NSFilePromiseReceiver {
    // TODO: replace with isolated(caller) or similar when this proposal gets implemented: https://forums.swift.org/t/pitch-inheriting-the-callers-actor-isolation/68391

    // Without @_unsafeInheritExecutor having this function be non-isolated (and thus run on the
    // global concurrent executor) causes a deadlock.
    @_unsafeInheritExecutor
    func receivePromisedFiles(atDestination destinationDir: URL, options: [AnyHashable : Any] = [:], operationQueue: OperationQueue) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            receivePromisedFiles(atDestination: destinationDir, options: options, operationQueue: operationQueue) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: url)
                }
            }
        }
    }
}
