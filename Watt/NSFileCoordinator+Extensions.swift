//
//  NSFileCoordinator+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Foundation

extension NSFileCoordinator {
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
