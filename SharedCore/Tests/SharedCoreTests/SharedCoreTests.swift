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
            name: "Test",
            status: "completed",
            conclusion: "success",
            createdAt: Date()
        )
        XCTAssertEqual(successRun.statusEmoji, "🟢")
        
        let failureRun = WorkflowRun(
            id: 2,
            name: "Test",
            status: "completed",
            conclusion: "failure",
            createdAt: Date()
        )
        XCTAssertEqual(failureRun.statusEmoji, "🔴")
        
        let runningRun = WorkflowRun(
            id: 3,
            name: "Test",
            status: "in_progress",
            conclusion: nil,
            createdAt: Date()
        )
        XCTAssertEqual(runningRun.statusEmoji, "🟡")
    }
}


