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
    func receivePromisedFiles(atDestination destinationDir: URL, options: [AnyHashable : Any] = [:], operationQueue: OperationQueue) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            var urls: [URL] = []

            // From the docs:
            //
            //   NSFilePromiseProvider promises one file type per item. The count of fileTypes should tell you the
            //   number of promised files in this item, but that's not always guaranteed. Some legacy file promisers
            //   list each unique fileType only once.
            //
            // So in theory this could undercount the number of files received. As far as I can tell, fileNames.count
            // is always correct, but fileNames is an empty array until recievePromisedFiles is called, which means
            // it's not set until the callback, and I don't know whether reading fileNames.count on operationQueue
            // is thread-safe. Once inheriting actor isolation is supported, I think we should be able to know what
            // actor we're running on, and then within the callback run `urls.count == fileNames.count` back on the
            // actor we were called on, which should maintain thread safety.
            let nfiles = fileTypes.count

            // Unclear from the docs whether an error will cause the completion handler to be called only once or more
            // than once. As a precaution, just throw the first exception and ignore the rest.
            var thrown = false

            receivePromisedFiles(atDestination: destinationDir, options: options, operationQueue: operationQueue) { url, error in
                if thrown {
                    return
                }

                if let error {
                    thrown = true
                    continuation.resume(throwing: error)
                } else {
                    urls.append(url)
                    if urls.count == nfiles {
                        continuation.resume(returning: urls)
                    }
                }
            }
        }
    }
}
