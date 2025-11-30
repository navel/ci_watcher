import Foundation

public struct WorkflowRun: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let status: String
    public let conclusion: String?
    public let createdAt: Date
    
    public init(id: Int, name: String, status: String, conclusion: String?, createdAt: Date) {
        self.id = id
        self.name = name
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
    public let status: String
    public let conclusion: String?
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case conclusion
        case createdAt = "created_at"
    }
    
    func toWorkflowRun() -> WorkflowRun? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: createdAt) else {
            return nil
        }
        
        return WorkflowRun(
            id: id,
            name: name,
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
        WorkflowRunsResponse(
            totalCount: totalCount,
            workflowRuns: workflowRuns.compactMap { $0.toWorkflowRun() }
        )
    }
}


