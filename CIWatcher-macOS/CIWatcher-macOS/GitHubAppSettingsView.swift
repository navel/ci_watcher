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
                if !viewModel.isBackendConfigured {
                    Text("Backend API is not configured. Set CIWATCHER_API_BASE_URL in Secrets.xcconfig.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if viewModel.isCheckingConnection {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking connection...")
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.connectionStatus?.connected != true {
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

                        Button {
                            Task {
                                await viewModel.connectGitHub()
                            }
                        } label: {
                            Label("Connect GitHub", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.isConnecting)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to GitHub")
                                .font(.headline)
                            Spacer()
                            Button {
                                Task {
                                    await viewModel.refreshConnection()
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }

                        if let status = viewModel.connectionStatus {
                            ConnectedAccountRow(status: status)
                        }

                        Button {
                            Task {
                                await viewModel.connectGitHub()
                            }
                        } label: {
                            Label("Install on more repositories", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isConnecting)

                        Button(role: .destructive) {
                            Task {
                                await viewModel.disconnectGitHub()
                            }
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isDisconnecting)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("GitHub Connection")
            } footer: {
                if viewModel.connectionStatus?.connected != true {
                    Text("Click 'Connect GitHub' to install CIWatcher on your repositories. You can choose which repositories to monitor.")
                } else {
                    Text("CIWatcher is connected to your GitHub account only. Other users cannot see your repositories.")
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
            Task {
                await viewModel.refreshConnection()
            }
        }
        .refreshable {
            await viewModel.refreshConnection()
        }
    }
}

struct ConnectedAccountRow: View {
    let status: GitHubConnectionStatus

    var body: some View {
        HStack {
            Image(systemName: "building.2.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                if let login = status.githubLogin, !login.isEmpty {
                    Text(login)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else if let installationID = status.installationID {
                    Text("Installation #\(installationID)")
                        .font(.subheadline)
                }
                if let accountType = status.githubAccountType, !accountType.isEmpty {
                    Text(accountType.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
