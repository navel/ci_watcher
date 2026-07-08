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
    private var updaterController: UpdaterController?
    @MainActor var ciService: CIService = CIService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = UpdaterController()
        
        // Initialize status bar
        let statusBar = StatusBarController()
        self.statusBarController = statusBar
        
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        Task { @MainActor in
            // Request notification permissions
            _ = await NotificationEngine.shared.requestAuthorization()
            
            // Update ContentView with CI service
            statusBar.updateContentView(ContentView(ciService: ciService))
            
            // Try to initialize GitHub App authentication
            await initializeGitHubAppAuth()
            
            // Start polling
            ciService.startPolling()
            
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
    
    @MainActor
    private func initializeGitHubAppAuth() async {
        let config = GitHubAppConfig.default
        guard config.hasPrivateKey() else {
            return
        }
        
        do {
            try await ciService.updateAPIClient(config: config)
            
            // If there are saved repositories, fetch their workflow runs
            if !ciService.repositories.isEmpty {
                await ciService.fetchAllWorkflowRuns()
            }
        } catch {
            // Silently fail - user can configure in settings
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            ciService.stopPolling()
        }
    }
}

