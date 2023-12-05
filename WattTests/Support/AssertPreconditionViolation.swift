//
//  AssertPreconditionViolation.swift
//  WattTests
//
//  Created by David Albert on 12/5/23.
//

import Foundation
import XCTest

import CwlPreconditionTesting

func assertCrashes<T>(_ body: @escaping @autoclosure () -> T, file: StaticString = #file, line: UInt = #line) {
    let e = catchBadInstruction {
        _ = body()
    }
    if e == nil {
        XCTFail("Expected crash", file: file, line: line)
    }
}
