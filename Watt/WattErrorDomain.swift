//
//  WattErrorDomain.swift
//  Watt
//
//  Created by David Albert on 1/29/24.
//

import Foundation

let WattErrorDomain = "is.dave.Watt.ErrorDomain"

enum WattErrorCodes: Int {
    case invalidDirentID = 1
    case noDirentInWorkspace = 2
}

extension NSError {
    convenience init(wattErrorWithCode: WattErrorCodes, userInfo: [String: Any]? = nil) {
        self.init(domain: WattErrorDomain, code: wattErrorWithCode.rawValue, userInfo: userInfo)
    }
}
