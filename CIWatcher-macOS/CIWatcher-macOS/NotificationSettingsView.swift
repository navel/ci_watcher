//
//  NotificationSettingsView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import AppKit
import UserNotifications
import SharedCore

struct NotificationSettingsView: View {
    @ObservedObject var notificationEngine: NotificationEngine
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false
    
    var body: some View {
        Form {
            Section {
                if authorizationStatus != .authorized {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notifications Disabled")
                            .font(.headline)
                        
                        if authorizationStatus == .denied {
                            Text("Notification permission was denied. To enable notifications, open System Settings → Notifications → CIWatcher and enable notifications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Open Notification Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        } else {
                            Text("To receive notifications about CI statuses, you need to allow notifications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                Task {
                                    await requestPermission()
                                }
                            }) {
                                HStack {
                                    if isRequestingPermission {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(isRequestingPermission ? "Requesting permission..." : "Enable Notifications")
                                }
                            }
                            .disabled(isRequestingPermission)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Notify on successful completions", isOn: $notificationEngine.settings.notifyOnSuccess)
                        
                        Toggle("Notify on failed completions", isOn: $notificationEngine.settings.notifyOnFailure)
                        
                        Toggle("Notify when running workflows complete", isOn: $notificationEngine.settings.notifyOnRunningCompletion)
                            .help("Notify when a workflow that was in 'running' status completes (regardless of result)")
                        
                        Toggle("Notify on canceled workflows", isOn: $notificationEngine.settings.notifyOnCanceled)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Notifications")
            } footer: {
                if authorizationStatus == .authorized {
                    Text("Select the statuses you want to be notified about")
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await checkAuthorizationStatus()
        }
        .onAppear {
            // Update status when view appears
            Task {
                await checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() async {
        authorizationStatus = await notificationEngine.checkAuthorizationStatus()
    }
    
    private func requestPermission() async {
        await MainActor.run {
            isRequestingPermission = true
        }
        
        // Activate app so permission dialog is visible
        NSApp.activate(ignoringOtherApps: true)
        
        // Request permission
        let granted = await notificationEngine.requestAuthorization()
        
        // Small delay to give system time to update status
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Check current status after request
        let currentStatus = await notificationEngine.checkAuthorizationStatus()
        
        // Update UI on main thread
        await MainActor.run {
            isRequestingPermission = false
            authorizationStatus = currentStatus
        }
        
        // Log for debugging
        print("Notification permission requested. Granted: \(granted), Status: \(currentStatus.rawValue)")
    }
}

#Preview {
    NotificationSettingsView(notificationEngine: NotificationEngine.shared)
}

