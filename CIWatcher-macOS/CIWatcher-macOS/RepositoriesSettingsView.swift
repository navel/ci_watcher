//
//  RepositoriesSettingsView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import SharedCore

struct RepositoriesSettingsView: View {
    @ObservedObject var viewModel: RepositoriesViewModel
    @ObservedObject var ciService: CIService
    
    var body: some View {
        Form {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Section {
                HStack(spacing: 8) {
                    Text("Repository")
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("", text: $viewModel.manualRepoInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task {
                                await viewModel.addManualRepository(to: ciService)
                            }
                        }
                        .onChange(of: viewModel.manualRepoInput) { _, _ in
                            viewModel.errorMessage = nil
                        }
                    
                    Button("Add") {
                        Task {
                            await viewModel.addManualRepository(to: ciService)
                        }
                    }
                    .disabled(viewModel.manualRepoInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAddingManual)
                }
                
                let manualRepositories = viewModel.manualRepositories(in: ciService)
                if manualRepositories.isEmpty {
                    Text("No manually added repositories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(manualRepositories) { repository in
                        ManualRepositoryRow(
                            repository: repository,
                            onRemove: {
                                viewModel.removeRepository(repository, from: ciService)
                            }
                        )
                    }
                }
            } header: {
                Text("Other Repositories")
            } footer: {
                Text("Add open source repositories by name or URL, for example https://github.com/apple/container. Public repositories work without installing the GitHub App. Private repositories require GitHub App access.")
            }
            
            Section {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading repositories...")
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.connectionStatus?.connected != true {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("GitHub not connected")
                            .font(.headline)
                        Text("Connect GitHub in the GitHub App tab to see repositories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("\(ciService.repositories.count) repository(ies) tracked")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                Task {
                                    await viewModel.refreshRepositories()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                            .disabled(viewModel.isRefreshing)
                        }

                        if let status = viewModel.connectionStatus {
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(.blue)
                                if let login = status.githubLogin, !login.isEmpty {
                                    Text(login)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                Text("\(viewModel.installationRepositories.count) repository(ies)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if viewModel.installationRepositories.isEmpty {
                            Text("No repositories available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.installationRepositories, id: \.id) { repo in
                                InstallationRepositoryRow(
                                    repository: repo,
                                    isTracked: viewModel.isRepositoryTracked(repo, in: ciService),
                                    onToggle: {
                                        Task {
                                            if viewModel.isRepositoryTracked(repo, in: ciService) {
                                                if let trackedRepo = ciService.repositories.first(where: { $0.fullName == repo.fullName }) {
                                                    ciService.removeRepository(trackedRepo)
                                                }
                                            } else {
                                                await viewModel.addRepositoryToTrack(repo, to: ciService)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("GitHub App Repositories")
            } footer: {
                if viewModel.connectionStatus?.connected == true {
                    Text("Repositories where CIWatcher is installed via the GitHub App.")
                }
            }
            
        }
        .formStyle(.grouped)
        .onAppear {
            Task {
                await viewModel.loadRepositories()
            }
        }
        .refreshable {
            await viewModel.refreshRepositories()
        }
    }
}

struct ManualRepositoryRow: View {
    let repository: CIRepository
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(repository.fullName)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    if repository.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Private")
                            .font(.caption2)
                    } else {
                        Image(systemName: "globe")
                            .font(.caption2)
                        Text("Public")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Remove", action: onRemove)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

struct InstallationRepositoryRow: View {
    let repository: InstallationRepository
    let isTracked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isTracked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isTracked ? .green : .secondary)
                .onTapGesture {
                    onToggle()
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(repository.fullName)
                    .font(.subheadline)
                if repository.private {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Private")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onToggle) {
                Text(isTracked ? "Remove" : "Add")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RepositoriesSettingsView(
        viewModel: RepositoriesViewModel(),
        ciService: CIService()
    )
    .frame(width: 600, height: 500)
}

