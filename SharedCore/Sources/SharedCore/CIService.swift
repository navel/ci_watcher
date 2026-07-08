import Foundation
import Combine

@MainActor
public class CIService: ObservableObject {
    @Published public private(set) var repositories: [CIRepository] = []
    @Published public private(set) var workflowRuns: [CIRepository.ID: [WorkflowRun]] = [:]
    @Published public private(set) var workflowJobs: [WorkflowRunKey: [WorkflowJob]] = [:]
    @Published public private(set) var loadingJobKeys: Set<WorkflowRunKey> = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: Error?
    
    private var apiClient: GitHubAPIClient?
    private let publicAPIClient = GitHubAPIClient.publicAccess
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
        if !repositories.contains(where: {
            $0.owner.caseInsensitiveCompare(repository.owner) == .orderedSame &&
            $0.name.caseInsensitiveCompare(repository.name) == .orderedSame
        }) {
            repositories.append(repository)
            saveRepositories()
        }
    }
    
    public func addManualRepository(fullName: String) async throws {
        let (owner, name) = try GitHubRepositoryReferenceParser.parse(fullName)
        
        if repositories.contains(where: {
            $0.owner.caseInsensitiveCompare(owner) == .orderedSame &&
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) {
            throw RepositoryAddError.alreadyTracked
        }
        
        let lookupClient = apiClient ?? publicAPIClient
        let repoInfo: GitHubRepository
        do {
            repoInfo = try await lookupClient.getRepository(owner: owner, repo: name)
        } catch GitHubAPIError.unauthorized, GitHubAPIError.invalidResponse {
            throw RepositoryAddError.notFound
        } catch {
            throw RepositoryAddError.notFound
        }
        
        if repoInfo.isPrivate, apiClient == nil {
            throw RepositoryAddError.notConnected
        }
        
        let workflowClient = apiClient(for: CIRepository(
            owner: owner,
            name: name,
            isPrivate: repoInfo.isPrivate,
            source: .manual
        ))
        
        guard let workflowClient else {
            throw RepositoryAddError.notConnected
        }
        
        do {
            _ = try await workflowClient.getWorkflowRuns(owner: owner, repo: name, perPage: 1)
        } catch {
            throw RepositoryAddError.noAccess
        }
        
        let ciRepo = CIRepository(
            owner: repoInfo.owner,
            name: repoInfo.name,
            isPrivate: repoInfo.isPrivate,
            source: .manual
        )
        addRepository(ciRepo)
        await fetchWorkflowRuns(for: ciRepo)
    }
    
    public func removeRepository(_ repository: CIRepository) {
        repositories.removeAll { $0.id == repository.id }
        workflowRuns.removeValue(forKey: repository.id)
        workflowJobs = workflowJobs.filter { $0.key.repositoryId != repository.id }
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
        
        isLoading = true
        lastError = nil
        
        for repository in repositories {
            guard let client = apiClient(for: repository) else {
                continue
            }
            
            do {
                let response = try await client.getWorkflowRuns(
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
        guard let client = apiClient(for: repository) else {
            return
        }
        
        isLoading = true
        lastError = nil
        
        do {
            let response = try await client.getWorkflowRuns(
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
    
    // MARK: - Workflow Jobs
    
    public func jobs(for run: WorkflowRun, repository: CIRepository) -> [WorkflowJob]? {
        workflowJobs[WorkflowRunKey(repositoryId: repository.id, runId: run.id)]
    }
    
    public func isLoadingJobs(for run: WorkflowRun, repository: CIRepository) -> Bool {
        loadingJobKeys.contains(WorkflowRunKey(repositoryId: repository.id, runId: run.id))
    }
    
    public func fetchJobs(for run: WorkflowRun, repository: CIRepository, force: Bool = false) async {
        let key = WorkflowRunKey(repositoryId: repository.id, runId: run.id)
        
        if !force, workflowJobs[key] != nil {
            return
        }
        
        guard let client = apiClient(for: repository) else {
            return
        }
        
        loadingJobKeys.insert(key)
        defer { loadingJobKeys.remove(key) }
        
        do {
            let response = try await client.getWorkflowRunJobs(
                owner: repository.owner,
                repo: repository.name,
                runId: run.id
            )
            workflowJobs[key] = response.jobs
        } catch {
            lastError = error
        }
    }
    
    private func apiClient(for repository: CIRepository) -> GitHubAPIClient? {
        switch repository.source {
        case .manual where !repository.isPrivate:
            return publicAPIClient
        case .manual, .installation:
            return apiClient
        }
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

