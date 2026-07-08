//
//  ContentView.swift
//  CIWatcher-macOS
//
//  Created by Ivan Terekhov on 30.11.2025.
//

import AppKit
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
                    } else {
                        Button(action: {
                            Task {
                                await ciService.fetchAllWorkflowRuns()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh workflow runs")
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
                                ciService: ciService,
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
    @ObservedObject var ciService: CIService
    let repository: CIRepository
    let workflowRuns: [WorkflowRun]
    
    @State private var expandedRunKey: WorkflowRunKey?
    
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
                ForEach(workflowRuns) { run in
                    WorkflowRunRow(
                        ciService: ciService,
                        repository: repository,
                        run: run,
                        isExpanded: expandedRunKey == WorkflowRunKey(repositoryId: repository.id, runId: run.id),
                        onToggle: { toggleRun(run) }
                    )
                }
                
                if ciService.hasMoreWorkflowRuns(for: repository) {
                    Button {
                        Task {
                            await ciService.loadMoreWorkflowRuns(for: repository)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if ciService.isLoadingMore(for: repository) {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                            Text("Load more")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .disabled(ciService.isLoadingMore(for: repository))
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func toggleRun(_ run: WorkflowRun) {
        let key = WorkflowRunKey(repositoryId: repository.id, runId: run.id)
        
        if expandedRunKey == key {
            expandedRunKey = nil
            return
        }
        
        expandedRunKey = key
        
        Task {
            await ciService.fetchJobs(
                for: run,
                repository: repository,
                force: run.status == "in_progress" || run.status == "queued"
            )
        }
    }
}

struct WorkflowRunRow: View {
    @ObservedObject var ciService: CIService
    let repository: CIRepository
    let run: WorkflowRun
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)
                        .padding(.top, 3)
                    
                    Text(run.statusEmoji)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.workflowName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(run.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Text(run.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                jobsSection
                    .padding(.leading, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }
    
    @ViewBuilder
    private var jobsSection: some View {
        if ciService.isLoadingJobs(for: run, repository: repository) {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Loading jobs...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 8)
            .padding(.vertical, 4)
        } else if let jobs = ciService.jobs(for: run, repository: repository) {
            if jobs.isEmpty {
                Text("No jobs found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(jobs) { job in
                    WorkflowJobRow(job: job)
                }
            }
        }
    }
}

struct WorkflowJobRow: View {
    let job: WorkflowJob
    
    var body: some View {
        Button {
            if let url = job.htmlURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 6) {
                Text(job.statusEmoji)
                    .font(.system(size: 9))
                    .frame(width: 12, alignment: .center)
                Text(job.name)
                    .font(.caption2)
                Spacer()
                if job.htmlURL != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 8)
        .padding(.vertical, 2)
        .help(job.htmlURL?.absoluteString ?? "")
    }
}

#Preview {
    ContentView(ciService: CIService())
}
