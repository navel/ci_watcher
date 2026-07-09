//
//  SettingsView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import SharedCore

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var repositoriesViewModel = RepositoriesViewModel()
    @ObservedObject var ciService: CIService
    let updaterController: UpdaterController?
    
    init(ciService: CIService, updaterController: UpdaterController? = nil) {
        self.ciService = ciService
        self.updaterController = updaterController
    }
    
    var body: some View {
        TabView {
            GitHubAppSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("GitHub App", systemImage: "app.badge")
                }
            
            RepositoriesSettingsView(viewModel: repositoriesViewModel, ciService: ciService)
                .tabItem {
                    Label("Repositories", systemImage: "folder.fill")
                }
            
            NotificationSettingsView(notificationEngine: NotificationEngine.shared)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
            
            GeneralSettingsView(updaterController: updaterController)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            viewModel.ciServiceRefreshCallback = {
                try? await ciService.refreshAPIClient()
                if !ciService.repositories.isEmpty {
                    await ciService.fetchAllWorkflowRuns()
                }
            }
        }
    }
}

struct GeneralSettingsView: View {
    let updaterController: UpdaterController?
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
            
            Section {
                Link("GitHub Repository", destination: URL(string: "https://github.com/navel/ci_watcher")!)
                Link("Documentation", destination: URL(string: "https://github.com/navel/ci_watcher/blob/main/DEVELOPMENT.md")!)
            } header: {
                Text("Resources")
            }
            
            #if !APPSTORE
            if updaterController?.isAvailable == true {
                Section {
                    Button("Check for Updates…") {
                        updaterController?.checkForUpdates()
                    }
                } header: {
                    Text("Updates")
                }
            }
            #endif
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView(ciService: CIService())
}

