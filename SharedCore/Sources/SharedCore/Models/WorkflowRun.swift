import Foundation

public struct WorkflowRun: Identifiable, Codable, Hashable {
    public let id: Int
    /// Commit/PR title shown in the UI.
    public let name: String
    /// Workflow name from GitHub API (e.g. "CI", "Release").
    public let workflowName: String
    public let status: String
    public let conclusion: String?
    public let createdAt: Date
    public let updatedAt: Date
    /// When the run actually started on GitHub runners, if known.
    public let runStartedAt: Date?
    
    public init(
        id: Int,
        name: String,
        workflowName: String,
        status: String,
        conclusion: String?,
        createdAt: Date,
        updatedAt: Date? = nil,
        runStartedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.workflowName = workflowName
        self.status = status
        self.conclusion = conclusion
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.runStartedAt = runStartedAt
    }
    
    /// Time shown as "start" in the UI (runner start when available).
    public var startTime: Date {
        runStartedAt ?? createdAt
    }
    
    public var displayStatus: String {
        if status == "completed" {
            return conclusion ?? "unknown"
        }
        return status
    }
    
    public var statusEmoji: String {
        switch displayStatus {
        case "success":
            return "🟢"
        case "failure":
            return "🔴"
        case "in_progress", "queued":
            return "🟡"
        case "canceled":
            return "⚪"
        default:
            return "⚪"
        }
    }
    
    private static let relativeStartThreshold: TimeInterval = 6 * 60 * 60
    
    public func usesRelativeStartLabel(relativeTo now: Date = Date()) -> Bool {
        now.timeIntervalSince(startTime) < Self.relativeStartThreshold
    }
    
    public func formattedAbsoluteStartLabel() -> String {
        Self.absoluteStartFormatter.string(from: startTime)
    }
    
    public func formattedDuration(relativeTo now: Date = Date()) -> String? {
        let endDate: Date
        switch status {
        case "completed":
            endDate = updatedAt
        case "in_progress", "queued":
            endDate = now
        default:
            endDate = updatedAt
        }
        
        let seconds = endDate.timeIntervalSince(startTime)
        guard seconds >= 1 else { return nil }
        return Self.formatDuration(seconds)
    }
    
    private static let absoluteStartFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }
}

extension Array where Element == WorkflowRun {
    /// Keeps the newest run for each workflow name. Assumes runs are sorted newest-first.
    func latestPerWorkflow() -> [WorkflowRun] {
        var seen = Set<String>()
        var result: [WorkflowRun] = []
        result.reserveCapacity(count)
        
        for run in self {
            if seen.insert(run.workflowName).inserted {
                result.append(run)
            }
        }
        
        return result
    }
}

// GitHub API Response Models
public struct WorkflowRunsResponse: Codable {
    public let totalCount: Int
    public let workflowRuns: [WorkflowRun]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

public struct WorkflowRunAPI: Codable {
    public let id: Int
    public let name: String
    public let displayTitle: String?
    public let status: String
    public let conclusion: String?
    public let createdAt: String
    public let updatedAt: String
    public let runStartedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayTitle = "display_title"
        case status
        case conclusion
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runStartedAt = "run_started_at"
    }
    
    func toWorkflowRun() -> WorkflowRun? {
        guard let createdDate = GitHubISO8601Date.parse(createdAt) else {
            return nil
        }
        let updatedDate = GitHubISO8601Date.parse(updatedAt) ?? createdDate
        let startedDate = runStartedAt.flatMap(GitHubISO8601Date.parse)
        
        return WorkflowRun(
            id: id,
            name: displayTitle ?? name,
            workflowName: name,
            status: status,
            conclusion: conclusion,
            createdAt: createdDate,
            updatedAt: updatedDate,
            runStartedAt: startedDate
        )
    }
}

enum GitHubISO8601Date {
    static func parse(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string)
    }
}

public struct WorkflowRunsAPIResponse: Codable {
    public let totalCount: Int
    public let workflowRuns: [WorkflowRunAPI]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
    
    func toWorkflowRunsResponse() -> WorkflowRunsResponse {
        let converted = workflowRuns.compactMap { $0.toWorkflowRun() }
        return WorkflowRunsResponse(
            totalCount: totalCount,
            workflowRuns: converted
        )
    }
}

