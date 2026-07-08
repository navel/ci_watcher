import Foundation

public struct WorkflowJob: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let status: String
    public let conclusion: String?
    public let htmlURL: URL?
    
    public init(
        id: Int,
        name: String,
        status: String,
        conclusion: String?,
        htmlURL: URL?
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.htmlURL = htmlURL
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
        case "canceled", "skipped":
            return "⚪"
        default:
            return "⚪"
        }
    }
}

public struct WorkflowJobsResponse: Codable {
    public let jobs: [WorkflowJob]
}

struct WorkflowJobsAPIResponse: Codable {
    let jobs: [WorkflowJobAPI]
    
    func toWorkflowJobsResponse() -> WorkflowJobsResponse {
        WorkflowJobsResponse(jobs: jobs.map { $0.toWorkflowJob() })
    }
}

struct WorkflowJobAPI: Codable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let htmlURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case conclusion
        case htmlURL = "html_url"
    }
    
    func toWorkflowJob() -> WorkflowJob {
        WorkflowJob(
            id: id,
            name: name,
            status: status,
            conclusion: conclusion,
            htmlURL: htmlURL.flatMap(URL.init(string:))
        )
    }
}

public struct WorkflowRunKey: Hashable, Sendable {
    public let repositoryId: UUID
    public let runId: Int
    
    public init(repositoryId: UUID, runId: Int) {
        self.repositoryId = repositoryId
        self.runId = runId
    }
}
