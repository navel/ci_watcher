import Foundation
import Combine

@MainActor
public class CIService: ObservableObject {
    @Published public private(set) var repositories: [CIRepository] = []
    @Published public private(set) var workflowRuns: [CIRepository.ID: [WorkflowRun]] = [:]
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: Error?
    
    private var apiClient: GitHubAPIClient?
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 60.0 // 60 seconds
    private let repositoriesKey = "CIWatcher.TrackedRepositories"
    
    public init() {
        loadRepositories()
    }
    
    // MARK: - Authentication
    
    public var hasAPIClient: Bool {
        apiClient != nil
    }
    
    public func setAPIClient(_ client: GitHubAPIClient) {
        self.apiClient = client
    }
    
    public func updateAPIClient(config: GitHubAppConfig, installationID: Int? = nil) async throws {
        let client = try await GitHubAPIClient.withGitHubApp(
            config: config,
            installationID: installationID
        )
        self.apiClient = client
    }
    
    // MARK: - Repository Management
    
    public func addRepository(_ repository: CIRepository) {
        if !repositories.contains(where: { $0.id == repository.id }) {
            repositories.append(repository)
            saveRepositories()
        }
    }
    
    public func removeRepository(_ repository: CIRepository) {
        repositories.removeAll { $0.id == repository.id }
        workflowRuns.removeValue(forKey: repository.id)
        saveRepositories()
    }
    
    // MARK: - Persistence
    
    private func saveRepositories() {
        if let encoded = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(encoded, forKey: repositoriesKey)
        }
    }
    
    private func loadRepositories() {
        guard let data = UserDefaults.standard.data(forKey: repositoriesKey),
              let decoded = try? JSONDecoder().decode([CIRepository].self, from: data) else {
            return
        }
        repositories = decoded
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
        guard !repositories.isEmpty else {
            return
        }
        
        // Refresh API client to get a new installation token
        // Installation tokens expire after 1 hour, so we refresh before each fetch
        let config = GitHubAppConfig.default
        if config.hasPrivateKey() {
            do {
                try await updateAPIClient(config: config)
            } catch {
                // Continue with existing client, it might still be valid
            }
        }
        
        guard let apiClient = apiClient else {
            return
        }
        
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
                
                // Обрабатываем уведомления для этого репозитория
                await NotificationEngine.shared.processWorkflowRuns(
                    for: repository,
                    workflowRuns: response.workflowRuns
                )
            } catch {
                lastError = error
                // Continue with other repositories even if one fails
            }
        }
        
        isLoading = false
    }
    
    public func fetchWorkflowRuns(for repository: CIRepository) async {
        guard let apiClient = apiClient else {
            return
        }
        
        isLoading = true
        lastError = nil
        
        do {
            let response = try await apiClient.getWorkflowRuns(
                owner: repository.owner,
                repo: repository.name,
                perPage: 10
            )
            workflowRuns[repository.id] = response.workflowRuns
            
            // Обрабатываем уведомления для этого репозитория
            await NotificationEngine.shared.processWorkflowRuns(
                for: repository,
                workflowRuns: response.workflowRuns
            )
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    // MARK: - Status Helpers
    
    public func overallStatus() -> String {
        Self.computeOverallStatus(from: workflowRuns)
    }
    
    /// Computes aggregate status from the latest run of each workflow per repository.
    /// Runs are expected newest-first (as returned by the GitHub API).
    nonisolated static func computeOverallStatus(from workflowRuns: [CIRepository.ID: [WorkflowRun]]) -> String {
        var hasFailure = false
        var hasRunning = false
        
        for (_, runs) in workflowRuns {
            for run in runs.latestPerWorkflow() {
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

