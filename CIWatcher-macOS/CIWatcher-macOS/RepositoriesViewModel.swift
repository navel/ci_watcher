//
//  RepositoriesViewModel.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import Foundation
import SwiftUI
import SharedCore

@MainActor
class RepositoriesViewModel: ObservableObject {
    @Published var installations: [Installation] = []
    @Published var repositoriesByInstallation: [Int: [InstallationRepository]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isRefreshing: Bool = false
    
    private let config = GitHubAppConfig.default
    
    func loadRepositories() async {
        guard config.hasPrivateKey() else {
            errorMessage = "GitHub App configuration error. Please configure in GitHub App settings."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let auth = try config.createAuth()
            installations = try await auth.getInstallations()
            
            // Load repositories for each installation
            for installation in installations {
                do {
                    let reposResponse = try await auth.getInstallationRepositories(installationID: installation.id)
                    repositoriesByInstallation[installation.id] = reposResponse.repositories
                } catch {
                    // Continue with other installations even if one fails
                }
            }
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Failed to load repositories: \(errorDescription)"
            installations = []
            repositoriesByInstallation = [:]
        }
        
        isLoading = false
    }
    
    func refreshRepositories() async {
        isRefreshing = true
        await loadRepositories()
        isRefreshing = false
    }
    
    func addRepositoryToTrack(_ repo: InstallationRepository, to ciService: CIService) async {
        let fullNameParts = repo.fullName.split(separator: "/")
        guard fullNameParts.count == 2 else { return }
        
        let owner = String(fullNameParts[0])
        let name = String(fullNameParts[1])
        
        let ciRepo = CIRepository(
            owner: owner,
            name: name,
            isPrivate: repo.private
        )
        
        ciService.addRepository(ciRepo)
        
        // Ensure API client is initialized
        if !ciService.hasAPIClient {
            do {
                try await ciService.updateAPIClient(config: config)
            } catch {
                return
            }
        }
        
        // Immediately fetch workflow runs for the new repository
        await ciService.fetchWorkflowRuns(for: ciRepo)
    }
    
    func isRepositoryTracked(_ repo: InstallationRepository, in ciService: CIService) -> Bool {
        let fullNameParts = repo.fullName.split(separator: "/")
        guard fullNameParts.count == 2 else { return false }
        
        let owner = String(fullNameParts[0])
        let name = String(fullNameParts[1])
        
        return ciService.repositories.contains { $0.owner == owner && $0.name == name }
    }
}

