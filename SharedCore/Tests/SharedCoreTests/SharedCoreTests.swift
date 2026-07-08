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
        XCTAssertEqual(repo.source, .installation)
        XCTAssertNotNil(repo.id)
    }
    
    func testCIRepositoryDecodesLegacyDataWithoutSource() throws {
        let json = """
        {
          "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
          "owner": "octocat",
          "name": "hello-world",
          "isPrivate": false
        }
        """
        
        let repo = try JSONDecoder().decode(CIRepository.self, from: Data(json.utf8))
        XCTAssertEqual(repo.source, .installation)
    }
    
    func testGitHubRepositoryAPIDecoding() throws {
        let json = """
        {
          "name": "next.js",
          "full_name": "vercel/next.js",
          "private": false,
          "owner": { "login": "vercel" }
        }
        """
        
        let repo = try JSONDecoder().decode(GitHubRepositoryAPI.self, from: Data(json.utf8)).toGitHubRepository()
        XCTAssertEqual(repo.fullName, "vercel/next.js")
        XCTAssertFalse(repo.isPrivate)
    }
    
    func testGitHubRepositoryReferenceParser() throws {
        let samples = [
            "apple/container",
            "https://github.com/apple/container",
            "github.com/apple/container/",
            "https://github.com/apple/container.git",
        ]
        
        for sample in samples {
            let parsed = try GitHubRepositoryReferenceParser.parse(sample)
            XCTAssertEqual(parsed.owner, "apple")
            XCTAssertEqual(parsed.name, "container")
        }
        
        XCTAssertThrowsError(try GitHubRepositoryReferenceParser.parse("https://gitlab.com/apple/container"))
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
    
    func testWorkflowJobStatusEmoji() {
        let successJob = WorkflowJob(
            id: 1,
            name: "build",
            status: "completed",
            conclusion: "success",
            htmlURL: nil
        )
        XCTAssertEqual(successJob.statusEmoji, "🟢")
        
        let failureJob = WorkflowJob(
            id: 2,
            name: "test",
            status: "completed",
            conclusion: "failure",
            htmlURL: nil
        )
        XCTAssertEqual(failureJob.statusEmoji, "🔴")
    }
    
    func testWorkflowJobAPIDecoding() throws {
        let json = """
        {
          "jobs": [
            {
              "id": 85964934332,
              "name": "test",
              "status": "completed",
              "conclusion": "success",
              "html_url": "https://github.com/example/repo/actions/runs/1/job/2"
            }
          ]
        }
        """
        
        let response = try JSONDecoder().decode(WorkflowJobsAPIResponse.self, from: Data(json.utf8))
        let jobs = response.toWorkflowJobsResponse().jobs
        
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].name, "test")
        XCTAssertEqual(jobs[0].statusEmoji, "🟢")
        XCTAssertEqual(jobs[0].htmlURL?.absoluteString, "https://github.com/example/repo/actions/runs/1/job/2")
    }
}


