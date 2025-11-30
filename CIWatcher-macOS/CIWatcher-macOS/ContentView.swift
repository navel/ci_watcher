//
//  ContentView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import SwiftUI
import SharedCore

struct ContentView: View {
    @ObservedObject var ciService: CIService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("CIWatcher")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    if ciService.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if ciService.repositories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No repositories")
                        .font(.headline)
                    Text("Add a repository to start monitoring")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(ciService.repositories) { repository in
                            RepositoryView(
                                repository: repository,
                                workflowRuns: ciService.workflowRuns[repository.id] ?? []
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

struct RepositoryView: View {
    let repository: CIRepository
    let workflowRuns: [WorkflowRun]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Repository header
            HStack {
                Text(repository.fullName)
                    .font(.headline)
                Spacer()
                if repository.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Workflow runs
            if workflowRuns.isEmpty {
                Text("No workflow runs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(workflowRuns.prefix(5)) { run in
                    WorkflowRunRow(run: run)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WorkflowRunRow: View {
    let run: WorkflowRun
    
    var body: some View {
        HStack {
            Text(run.statusEmoji)
            Text(run.name)
                .font(.subheadline)
            Spacer()
            Text(run.createdAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView(ciService: CIService(token: "test"))
}
