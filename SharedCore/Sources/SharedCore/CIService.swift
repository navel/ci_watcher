import Foundation
import Combine

@MainActor
public class CIService: ObservableObject {
    @Published public private(set) var repositories: [CIRepository] = []
    @Published public private(set) var workflowRuns: [CIRepository.ID: [WorkflowRun]] = [:]
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: Error?
    
    private let apiClient: GitHubAPIClient
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 60.0 // 60 seconds
    
    public init(token: String) {
        self.apiClient = GitHubAPIClient(token: token)
    }
    
    // MARK: - Repository Management
    
    public func addRepository(_ repository: CIRepository) {
        if !repositories.contains(where: { $0.id == repository.id }) {
            repositories.append(repository)
        }
    }
    
    public func removeRepository(_ repository: CIRepository) {
        repositories.removeAll { $0.id == repository.id }
        workflowRuns.removeValue(forKey: repository.id)
    }
    
    // MARK: - Polling
    
    public func startPolling() {
        stopPolling()
        
        // Initial fetch
        Task {
            await fetchAllWorkflowRuns()
        }
        
        // Schedule periodic polling
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchAllWorkflowRuns()
            }
        }
        RunLoop.main.add(pollingTimer!, forMode: .common)
    }
    
    public func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Fetching
    
    public func fetchAllWorkflowRuns() async {
        guard !repositories.isEmpty else { return }
        
        isLoading = true
        lastError = nil
        
        for repository in repositories {
            do {
                let response = try await apiClient.getWorkflowRuns(
                    owner: repository.owner,
                    repo: repository.name,
                    perPage: 10
                )
                workflowRuns[repository.id] = response.workflowRuns
            } catch {
                lastError = error
                // Continue with other repositories even if one fails
            }
        }
        
        isLoading = false
    }
    
    public func fetchWorkflowRuns(for repository: CIRepository) async {
        isLoading = true
        lastError = nil
        
        do {
            let response = try await apiClient.getWorkflowRuns(
                owner: repository.owner,
                repo: repository.name,
                perPage: 10
            )
            workflowRuns[repository.id] = response.workflowRuns
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    // MARK: - Status Helpers
    
    public func overallStatus() -> String {
        var hasFailure = false
        var hasRunning = false
        
        for (_, runs) in workflowRuns {
            for run in runs {
                if run.displayStatus == "failure" {
                    hasFailure = true
                }
                if run.status == "in_progress" || run.status == "queued" {
                    hasRunning = true
                }
            }
        }
        
        if hasFailure {
            return "failure"
        } else if hasRunning {
            return "running"
        } else {
            return "success"
        }
    }
    
    public func statusEmoji() -> String {
        switch overallStatus() {
        case "failure":
            return "🔴"
        case "running":
            return "🟡"
        case "success":
            return "🟢"
        default:
            return "⚪"
        }
    }
}

