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
    var res: T?
    let e = catchBadInstruction {
        res = body()
    }
    if e == nil {
        XCTFail("expected crash, got \(res!)", file: file, line: line)
    }
}
