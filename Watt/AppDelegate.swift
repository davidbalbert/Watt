//
//  AppDelegate.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            UserDefaults.Keys.textInsertionPointBlinkPeriodOn: 500,
            UserDefaults.Keys.textInsertionPointBlinkPeriodOff: 500,
            UserDefaults.Keys.workspaceBrowserAnimationsEnabled: false,
            UserDefaults.Keys.showHiddenFiles: false,
        ])

        NSWindow.allowsAutomaticWindowTabbing = false
        _ = DocumentController()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }
}

