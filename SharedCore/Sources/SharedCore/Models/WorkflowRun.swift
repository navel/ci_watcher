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
    
    public init(
        id: Int,
        name: String,
        workflowName: String,
        status: String,
        conclusion: String?,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.workflowName = workflowName
        self.status = status
        self.conclusion = conclusion
        self.createdAt = createdAt
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayTitle = "display_title"
        case status
        case conclusion
        case createdAt = "created_at"
    }
    
    func toWorkflowRun() -> WorkflowRun? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: createdAt) else {
            // Try without fractional seconds
            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter2.date(from: createdAt) else {
                return nil
            }
            return WorkflowRun(
                id: id,
                name: displayTitle ?? name,
                workflowName: name,
                status: status,
                conclusion: conclusion,
                createdAt: date2
            )
        }
        
        return WorkflowRun(
            id: id,
            name: displayTitle ?? name,
            workflowName: name,
            status: status,
            conclusion: conclusion,
            createdAt: date
        )
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


