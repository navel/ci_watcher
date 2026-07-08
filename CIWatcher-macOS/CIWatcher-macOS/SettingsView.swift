//
//  SettingsView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import AppKit
import SharedCore
#if !APPSTORE
import Sparkle
#endif

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
            
            NotificationSettingsView(notificationEngine: NotificationEngine.shared)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
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
                Link("GitHub Repository", destination: URL(string: "https://github.com/navel/ci_watcher")!)
                Link("Documentation", destination: URL(string: "https://github.com/navel/ci_watcher/blob/main/DEVELOPMENT.md")!)
            } header: {
                Text("Resources")
            }
            
            #if !APPSTORE
            Section {
                Button("Check for Updates…") {
                    NSApp.sendAction(#selector(SPUUpdater.checkForUpdates), to: nil, from: nil)
                }
            } header: {
                Text("Updates")
            }
            #endif
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView(ciService: CIService())
}

