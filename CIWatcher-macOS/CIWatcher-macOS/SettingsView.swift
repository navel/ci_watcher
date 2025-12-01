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
    
    init(ciService: CIService) {
        self.ciService = ciService
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
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 600, height: 500)
    }
}

struct GeneralSettingsView: View {
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
                Link("GitHub Repository", destination: URL(string: "https://github.com/navel/ci-watcher")!)
                Link("Documentation", destination: URL(string: "https://github.com/navel/ci-watcher")!)
            } header: {
                Text("Resources")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView(ciService: CIService())
}

