//
//  NSFilePromiseReceiver+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Cocoa

extension NSFilePromiseReceiver {
    enum Errors: Error {
        case noSelf
    }

    // TODO: replace with isolated(caller) or similar when this proposal gets implemented: https://forums.swift.org/t/pitch-inheriting-the-callers-actor-isolation/68391

    // Without @_unsafeInheritExecutor having this function be non-isolated (and thus run on the
    // global concurrent executor) causes a deadlock.
    @_unsafeInheritExecutor
    func receivePromisedFiles(atDestination destinationDir: URL, options: [AnyHashable : Any] = [:], operationQueue: OperationQueue) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            var urls: [URL] = []
            receivePromisedFiles(atDestination: destinationDir, options: options, operationQueue: operationQueue) { [weak self] url, error in
                guard let self else {
                    continuation.resume(throwing: Errors.noSelf)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                } else {
                    urls.append(url)
                    // TODO: is it safe to access self.fileNames from another queue?
                    if urls.count == fileNames.count {
                        continuation.resume(returning: urls)
                    }
                }
            }
        }
    }
}
