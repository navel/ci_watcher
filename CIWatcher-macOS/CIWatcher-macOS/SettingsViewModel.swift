//
//  SettingsViewModel.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import Foundation
import SwiftUI
import AppKit
import SharedCore

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var hasPrivateKey: Bool = false
    @Published var installations: [Installation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isCheckingInstallations: Bool = false
    
    private let config = GitHubAppConfig.default
    
    init() {
        checkPrivateKey()
    }
    
    func checkPrivateKey() {
        hasPrivateKey = config.hasPrivateKey()
    }
    
    func checkInstallations() async {
        guard hasPrivateKey else {
            errorMessage = "GitHub App configuration error. Please contact support."
            return
        }
        
        isCheckingInstallations = true
        errorMessage = nil
        
        do {
            let auth = try config.createAuth()
            installations = try await auth.getInstallations()
            
            if installations.isEmpty {
                // No error message - just show the connect button
                errorMessage = nil
            }
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Failed to check installations: \(errorDescription)"
            installations = []
        }
        
        isCheckingInstallations = false
    }
    
    func openInstallationURL() {
        let oauth = GitHubAppOAuth(clientID: config.clientID)
        if let url = oauth.getInstallationURL() {
            NSWorkspace.shared.open(url)
        }
    }
    
    func refreshInstallations() async {
        checkPrivateKey()
        await checkInstallations()
    }
}

