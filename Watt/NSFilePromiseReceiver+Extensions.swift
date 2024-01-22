//
//  NSFilePromiseReceiver+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Cocoa

extension NSFilePromiseReceiver {
    func receivePromisedFiles(atDestination destinationDir: URL, options: [AnyHashable : Any] = [:], operationQueue: OperationQueue) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            print("about to receive to", destinationDir)
            receivePromisedFiles(atDestination: destinationDir, options: options, operationQueue: operationQueue) { url, error in
                print("received!", url)
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: url)
                }
            }
        }
    }
}
