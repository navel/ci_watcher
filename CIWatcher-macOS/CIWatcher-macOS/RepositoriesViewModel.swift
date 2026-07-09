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
    @Published var connectionStatus: GitHubConnectionStatus?
    @Published var installationRepositories: [InstallationRepository] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isRefreshing: Bool = false
    @Published var manualRepoInput: String = ""
    @Published var isAddingManual: Bool = false

    private let backendAuthClient: BackendAuthClient?
    private let credentials = DeviceCredentials.loadOrCreate()

    init(backendAuthClient: BackendAuthClient? = nil) {
        self.backendAuthClient = backendAuthClient ?? BackendAuthClient.makeDefault()
    }

    func loadRepositories() async {
        guard let backendAuthClient else {
            errorMessage = "Backend API is not configured."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            connectionStatus = try await backendAuthClient.fetchConnectionStatus(credentials: credentials)

            guard connectionStatus?.connected == true else {
                installationRepositories = []
                isLoading = false
                return
            }

            let tokenResponse = try await backendAuthClient.fetchInstallationToken(credentials: credentials)
            let client = GitHubAPIClient(token: tokenResponse.token)
            let reposResponse = try await client.getInstallationRepositories()
            installationRepositories = reposResponse.repositories
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Failed to load repositories: \(errorDescription)"
            connectionStatus = nil
            installationRepositories = []
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
            isPrivate: repo.private,
            source: .installation
        )

        ciService.addRepository(ciRepo)

        if !ciService.hasAPIClient {
            do {
                try await ciService.refreshAPIClient()
            } catch {
                return
            }
        }

        await ciService.fetchWorkflowRuns(for: ciRepo)
    }

    func isRepositoryTracked(_ repo: InstallationRepository, in ciService: CIService) -> Bool {
        let fullNameParts = repo.fullName.split(separator: "/")
        guard fullNameParts.count == 2 else { return false }

        let owner = String(fullNameParts[0])
        let name = String(fullNameParts[1])

        return ciService.repositories.contains { $0.owner == owner && $0.name == name }
    }

    func manualRepositories(in ciService: CIService) -> [CIRepository] {
        ciService.repositories.filter { $0.source == .manual }
    }

    func addManualRepository(to ciService: CIService) async {
        let input = manualRepoInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isAddingManual = true
        errorMessage = nil

        do {
            try await ciService.addManualRepository(fullName: input)
            manualRepoInput = ""
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = errorDescription
        }

        isAddingManual = false
    }

    func removeRepository(_ repository: CIRepository, from ciService: CIService) {
        ciService.removeRepository(repository)
    }
}
