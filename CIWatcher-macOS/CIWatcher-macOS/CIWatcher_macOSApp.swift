//
//  CIWatcher_macOSApp.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import SharedCore

@main
struct CIWatcher_macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView(ciService: appDelegate.ciService)
        }
    }
}
