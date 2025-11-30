//
//  AppDelegate.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import AppKit
import SwiftUI
import SharedCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var ciService: CIService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize status bar
        let statusBar = StatusBarController()
        self.statusBarController = statusBar
        
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        Task { @MainActor in
            let service = CIService(token: "")
            self.ciService = service
            
            // Update ContentView with CI service
            statusBar.updateContentView(ContentView(ciService: service))
            
            // Start polling
            service.startPolling()
            
            // Update status bar emoji periodically
            let statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let service = self?.ciService,
                          let statusBar = self?.statusBarController else { return }
                    statusBar.updateStatusEmoji(service.statusEmoji())
                }
            }
            RunLoop.main.add(statusTimer, forMode: .common)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ciService?.stopPolling()
    }
}

