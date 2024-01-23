//
//  FileManager+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/22/24.
//

import Foundation

extension FileManager {
    func coordinatedCopyItem(at srcURL: URL, to dstURL: URL, operationQueue: OperationQueue) async throws -> URL {
        let srcIntent = NSFileAccessIntent.readingIntent(with: srcURL)
        let dstIntent = NSFileAccessIntent.writingIntent(with: dstURL, options: .forReplacing)
        let coordinator = NSFileCoordinator()

        return try await coordinator.coordinate(with: [srcIntent, dstIntent], queue: operationQueue) {
            try FileManager.default.copyItem(at: srcIntent.url, to: dstIntent.url)
            return dstIntent.url
        }
    }

    func coordinatedMoveItem(at srcURL: URL, to dstURL: URL, operationQueue: OperationQueue) async throws -> URL {
        let srcIntent = NSFileAccessIntent.writingIntent(with: srcURL, options: .forMoving)
        let dstIntent = NSFileAccessIntent.writingIntent(with: dstURL, options: .forReplacing)
        let coordinator = NSFileCoordinator()

        return try await coordinator.coordinate(with: [srcIntent, dstIntent], queue: operationQueue) {
            try FileManager.default.moveItem(at: srcIntent.url, to: dstIntent.url)
            return dstIntent.url
        }
    }

    func coordinatedRemoveItem(at url: URL, operationQueue: OperationQueue) async throws {
        let intent = NSFileAccessIntent.writingIntent(with: url, options: .forDeleting)
        let coordinator = NSFileCoordinator()

        try await coordinator.coordinate(with: [intent], queue: operationQueue) {
            try FileManager.default.removeItem(at: intent.url)
        }
    }
}
