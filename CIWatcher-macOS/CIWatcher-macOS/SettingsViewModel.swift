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
    @Published var connectionStatus: GitHubConnectionStatus?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isCheckingConnection: Bool = false
    @Published var isConnecting: Bool = false
    @Published var isDisconnecting: Bool = false

    private let backendAuthClient: BackendAuthClient?
    private let credentials = DeviceCredentials.loadOrCreate()
    private var authCallbackObserver: NSObjectProtocol?
    private var refreshConnectionTask: Task<Void, Never>?

    var isBackendConfigured: Bool {
        backendAuthClient != nil
    }

    init(backendAuthClient: BackendAuthClient? = nil) {
        self.backendAuthClient = backendAuthClient ?? BackendAuthClient.makeDefault()
        authCallbackObserver = NotificationCenter.default.addObserver(
            forName: .ciwatcherAuthCallback,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let success = notification.userInfo?["success"] as? Bool ?? false
            if success {
                Task {
                    await self.refreshConnection()
                    await self.ciServiceRefreshCallback?()
                }
            } else if let error = notification.userInfo?["error"] as? String {
                self.errorMessage = error
            }
        }
    }

    deinit {
        refreshConnectionTask?.cancel()
        if let authCallbackObserver {
            NotificationCenter.default.removeObserver(authCallbackObserver)
        }
    }

    var ciServiceRefreshCallback: (() async -> Void)?

    func refreshConnection() async {
        refreshConnectionTask?.cancel()
        let task = Task { @MainActor in
            await performRefreshConnection()
        }
        refreshConnectionTask = task
        await task.value
    }

    private func performRefreshConnection() async {
        guard !Task.isCancelled else { return }

        guard let backendAuthClient else {
            errorMessage = "Backend API is not configured."
            connectionStatus = nil
            return
        }

        isCheckingConnection = true
        defer { isCheckingConnection = false }

        errorMessage = nil

        do {
            connectionStatus = try await backendAuthClient.fetchConnectionStatus(credentials: credentials)
        } catch {
            guard !Task.isCancelled else { return }
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Failed to check connection: \(errorDescription)"
            connectionStatus = nil
        }
    }

    func connectGitHub() async {
        guard let backendAuthClient else {
            errorMessage = "Backend API is not configured."
            return
        }

        isConnecting = true
        defer { isConnecting = false }

        errorMessage = nil

        do {
            let response = try await backendAuthClient.startAuth(credentials: credentials)
            guard let url = response.url else {
                errorMessage = "Invalid auth URL from backend."
                return
            }
            NSWorkspace.shared.open(url)
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Failed to start GitHub connection: \(errorDescription)"
        }
    }

    func disconnectGitHub() async {
        guard let backendAuthClient else {
            return
        }

        isDisconnecting = true
        defer { isDisconnecting = false }

        errorMessage = nil

        do {
            try await backendAuthClient.disconnect(credentials: credentials)
            connectionStatus = GitHubConnectionStatus(
                connected: false,
                installationID: nil,
                githubLogin: nil,
                githubAccountType: nil
            )
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Failed to disconnect: \(errorDescription)"
        }
    }
}
