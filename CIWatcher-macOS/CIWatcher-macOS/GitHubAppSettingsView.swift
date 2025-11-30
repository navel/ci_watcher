//
//  GitHubAppSettingsView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import SharedCore

struct GitHubAppSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                // Installations Status
                if viewModel.isCheckingInstallations {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking installations...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    if viewModel.installations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Connect GitHub")
                                        .font(.headline)
                                    Text("Install CIWatcher on your repositories to start monitoring CI workflows")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Button(action: {
                                viewModel.openInstallationURL()
                            }) {
                                Label("Connect GitHub", systemImage: "arrow.right.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(viewModel.installations.count) installation(s)")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    Task {
                                        await viewModel.refreshInstallations()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            ForEach(viewModel.installations, id: \.id) { installation in
                                InstallationRow(installation: installation)
                            }
                            
                            Button(action: {
                                viewModel.openInstallationURL()
                            }) {
                                Label("Install on more repositories", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("GitHub Connection")
            } footer: {
                if viewModel.installations.isEmpty {
                    Text("Click 'Connect GitHub' to install CIWatcher on your repositories. You can choose which repositories to monitor.")
                } else {
                    Text("CIWatcher is installed on the repositories above. You can install on more repositories or manage installations on GitHub.")
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.checkPrivateKey()
            Task {
                await viewModel.checkInstallations()
            }
        }
        .refreshable {
            viewModel.checkPrivateKey()
            await viewModel.refreshInstallations()
        }
    }
}

struct InstallationRow: View {
    let installation: Installation
    
    var body: some View {
        HStack {
            Image(systemName: "building.2.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                if let account = installation.account {
                    Text(account.login)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(account.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Installation #\(installation.id)")
                        .font(.subheadline)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GitHubAppSettingsView(viewModel: SettingsViewModel())
        .frame(width: 600, height: 500)
}

