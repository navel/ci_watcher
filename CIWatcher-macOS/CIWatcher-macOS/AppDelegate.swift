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
    private(set) var updaterController: UpdaterController? = UpdaterController()
    @MainActor var ciService: CIService = CIService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize status bar
        let statusBar = StatusBarController(appDelegate: self)
        self.statusBarController = statusBar
        
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        Task { @MainActor in
            // Request notification permissions
            _ = await NotificationEngine.shared.requestAuthorization()
            
            // Update ContentView with CI service
            statusBar.updateContentView(
                ContentView(ciService: ciService, onOpenSettings: { [weak self] in
                    self?.openSettings()
                })
            )
            
            await initializeGitHubAuth()
            
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
    private func initializeGitHubAuth() async {
        guard ciService.usesBackendAuth || GitHubAppConfig.default.hasPrivateKey() else {
            return
        }

        await ciService.migrateRepositoriesForBackendAuthIfNeeded()
        
        do {
            try await ciService.refreshAPIClient()
            
            if !ciService.repositories.isEmpty {
                await ciService.fetchAllWorkflowRuns()
            }
        } catch {
            // Silently fail - user can configure in settings
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }
    
    @MainActor
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "ciwatcher",
              url.host == "auth",
              url.path == "/callback" else {
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let success = queryItems.first(where: { $0.name == "success" })?.value == "1"
        let error = queryItems.first(where: { $0.name == "error" })?.value
        
        var userInfo: [String: Any] = ["success": success]
        if let error {
            userInfo["error"] = error
        }
        NotificationCenter.default.post(name: .ciwatcherAuthCallback, object: nil, userInfo: userInfo)
        
        if success {
            Task {
                await ciService.migrateRepositoriesForBackendAuthIfNeeded()
                try? await ciService.refreshAPIClient()
            }
        }
        
        openSettings()
    }
    
    func openSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.show(
                ciService: ciService,
                updaterController: updaterController
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            ciService.stopPolling()
        }
    }
}
