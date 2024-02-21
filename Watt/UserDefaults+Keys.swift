//
//  UserDefaults+Keys.swift
//  Watt
//
//  Created by David Albert on 1/15/24.
//

import Foundation

extension UserDefaults {
    enum Keys {
        static let textInsertionPointBlinkPeriodOn = "NSTextInsertionPointBlinkPeriodOn"
        static let textInsertionPointBlinkPeriodOff = "NSTextInsertionPointBlinkPeriodOff"
        static let workspaceBrowserAnimationsEnabled = "workspaceBrowserAnimationsEnabled"
        static let showHiddenFiles = "showHiddenFiles"
    }

    @objc var textInsertionPointBlinkPeriodOn: TimeInterval {
        get {
            double(forKey: Keys.textInsertionPointBlinkPeriodOn)
        }
        set {
            set(newValue, forKey: Keys.textInsertionPointBlinkPeriodOn)
        }
    }

    @objc var textInsertionPointBlinkPeriodOff: TimeInterval {
        get {
            double(forKey: Keys.textInsertionPointBlinkPeriodOff)
        }
        set {
            set(newValue, forKey: Keys.textInsertionPointBlinkPeriodOff)
        }
    }

    @objc var workspaceBrowserAnimationsEnabled: Bool {
        get {
            bool(forKey: Keys.workspaceBrowserAnimationsEnabled)
        }
        set {
            set(newValue, forKey: Keys.workspaceBrowserAnimationsEnabled)
        }
    }

    @objc var showHiddenFiles: Bool {
        get {
            bool(forKey: Keys.showHiddenFiles)
        }
        set {
            set(newValue, forKey: Keys.showHiddenFiles)
        }
    }
}
