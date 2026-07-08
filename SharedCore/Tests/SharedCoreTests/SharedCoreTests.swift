import XCTest
@testable import SharedCore

final class SharedCoreTests: XCTestCase {
    func testCIRepository() {
        let repo = CIRepository(
            owner: "octocat",
            name: "hello-world",
            isPrivate: false
        )
        
        XCTAssertEqual(repo.fullName, "octocat/hello-world")
        XCTAssertNotNil(repo.id)
    }
    
    func testWorkflowRunStatusEmoji() {
        let successRun = WorkflowRun(
            id: 1,
            name: "Fix something",
            workflowName: "CI",
            status: "completed",
            conclusion: "success",
            createdAt: Date()
        )
        XCTAssertEqual(successRun.statusEmoji, "🟢")
        
        let failureRun = WorkflowRun(
            id: 2,
            name: "Broken build",
            workflowName: "CI",
            status: "completed",
            conclusion: "failure",
            createdAt: Date()
        )
        XCTAssertEqual(failureRun.statusEmoji, "🔴")
        
        let runningRun = WorkflowRun(
            id: 3,
            name: "Running checks",
            workflowName: "CI",
            status: "in_progress",
            conclusion: nil,
            createdAt: Date()
        )
        XCTAssertEqual(runningRun.statusEmoji, "🟡")
    }
    
    func testLatestPerWorkflow() {
        let runs = [
            WorkflowRun(id: 1, name: "Commit A", workflowName: "CI", status: "completed", conclusion: "success", createdAt: Date()),
            WorkflowRun(id: 2, name: "Commit B", workflowName: "Release", status: "completed", conclusion: "success", createdAt: Date()),
            WorkflowRun(id: 3, name: "Commit C", workflowName: "CI", status: "completed", conclusion: "failure", createdAt: Date().addingTimeInterval(-3600)),
        ]
        
        let latest = runs.latestPerWorkflow()
        XCTAssertEqual(latest.count, 2)
        XCTAssertEqual(latest.map(\.id).sorted(), [1, 2])
    }
    
    func testOverallStatusIgnoresOlderFailures() {
        let repoID = CIRepository(owner: "octocat", name: "hello-world", isPrivate: false).id
        let runs: [CIRepository.ID: [WorkflowRun]] = [
            repoID: [
                WorkflowRun(id: 1, name: "New commit", workflowName: "CI", status: "completed", conclusion: "success", createdAt: Date()),
                WorkflowRun(id: 2, name: "Old commit", workflowName: "CI", status: "completed", conclusion: "failure", createdAt: Date().addingTimeInterval(-3600)),
            ]
        ]
        
        XCTAssertEqual(CIService.computeOverallStatus(from: runs), "success")
    }
    
    func testOverallStatusFailsOnLatestRun() {
        let repoID = CIRepository(owner: "octocat", name: "hello-world", isPrivate: false).id
        let runs: [CIRepository.ID: [WorkflowRun]] = [
            repoID: [
                WorkflowRun(id: 1, name: "Broken", workflowName: "CI", status: "completed", conclusion: "failure", createdAt: Date()),
                WorkflowRun(id: 2, name: "Was fine", workflowName: "CI", status: "completed", conclusion: "success", createdAt: Date().addingTimeInterval(-3600)),
            ]
        ]
        
        XCTAssertEqual(CIService.computeOverallStatus(from: runs), "failure")
    }
    
    func testOverallStatusUsesDistinctWorkflowNames() {
        let repoID = CIRepository(owner: "octocat", name: "hello-world", isPrivate: false).id
        let runs: [CIRepository.ID: [WorkflowRun]] = [
            repoID: [
                WorkflowRun(id: 1, name: "Latest CI", workflowName: "CI", status: "completed", conclusion: "success", createdAt: Date()),
                WorkflowRun(id: 2, name: "Latest Release", workflowName: "Release", status: "completed", conclusion: "success", createdAt: Date()),
                WorkflowRun(id: 3, name: "Old failed release", workflowName: "Release", status: "completed", conclusion: "failure", createdAt: Date().addingTimeInterval(-3600)),
            ]
        ]
        
        XCTAssertEqual(CIService.computeOverallStatus(from: runs), "success")
    }
}


