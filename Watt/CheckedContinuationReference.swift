//
//  CheckedContinuationReference.swift
//  Watt
//
//  Created by David Albert on 2/6/24.
//

import Foundation

// Used for passing a continuation into an argument that expects an UnsafeMutableRawPointer.
class CheckedContinuationReference<T, E> where E : Error {
    let continuation: CheckedContinuation<T, E>
    init(_ continuation: CheckedContinuation<T, E>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        continuation.resume(returning: value)
    }

    func resume(throwing error: E) {
        continuation.resume(throwing: error)
    }

    func resume(with result: Result<T, E>) {
        continuation.resume(with: result)
    }

    func resume<Er>(with result: Result<T, Er>) where E == Error, Er : Error {
        continuation.resume(with: result)
    }

    func resume() where T == () {
        continuation.resume()
    }
}
