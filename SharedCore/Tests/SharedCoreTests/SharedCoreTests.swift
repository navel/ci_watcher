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
    
    func testSortRepositoriesForDisplayOrdersByLatestWorkflowActivity() {
        let now = Date()
        let repoA = CIRepository(owner: "octocat", name: "a", isPrivate: false)
        let repoB = CIRepository(owner: "octocat", name: "b", isPrivate: false)
        let repoC = CIRepository(owner: "octocat", name: "c", isPrivate: false)
        let repoD = CIRepository(owner: "octocat", name: "d", isPrivate: false)
        
        let repositories = [repoA, repoB, repoC, repoD]
        let workflowRuns: [CIRepository.ID: [WorkflowRun]] = [
            repoA.id: [
                WorkflowRun(
                    id: 1,
                    name: "Old",
                    workflowName: "CI",
                    status: "completed",
                    conclusion: "success",
                    createdAt: now.addingTimeInterval(-7200)
                ),
            ],
            repoB.id: [
                WorkflowRun(
                    id: 2,
                    name: "Newest",
                    workflowName: "CI",
                    status: "completed",
                    conclusion: "failure",
                    createdAt: now
                ),
            ],
            repoC.id: [
                WorkflowRun(
                    id: 3,
                    name: "Middle",
                    workflowName: "CI",
                    status: "in_progress",
                    conclusion: nil,
                    createdAt: now.addingTimeInterval(-600)
                ),
            ],
        ]
        
        let sorted = CIService.sortRepositoriesForDisplay(repositories, workflowRuns: workflowRuns)
        
        XCTAssertEqual(sorted.map(\.name), ["b", "c", "a", "d"])
    }
    
    func testSortRepositoriesForDisplayPreservesOrderWhenActivityMatches() {
        let now = Date()
        let repoA = CIRepository(owner: "octocat", name: "a", isPrivate: false)
        let repoB = CIRepository(owner: "octocat", name: "b", isPrivate: false)
        let repoC = CIRepository(owner: "octocat", name: "c", isPrivate: false)
        
        let repositories = [repoA, repoB, repoC]
        let workflowRuns: [CIRepository.ID: [WorkflowRun]] = [
            repoA.id: [
                WorkflowRun(
                    id: 1,
                    name: "A",
                    workflowName: "CI",
                    status: "completed",
                    conclusion: "failure",
                    createdAt: now
                ),
            ],
            repoB.id: [
                WorkflowRun(
                    id: 2,
                    name: "B",
                    workflowName: "CI",
                    status: "completed",
                    conclusion: "failure",
                    createdAt: now
                ),
            ],
        ]
        
        let sorted = CIService.sortRepositoriesForDisplay(repositories, workflowRuns: workflowRuns)
        
        XCTAssertEqual(sorted.map(\.name), ["a", "b", "c"])
    }
    
    func testWorkflowRunStartLabelUsesRelativeWithinSixHours() {
        let now = Date()
        let run = WorkflowRun(
            id: 1,
            name: "Recent",
            workflowName: "CI",
            status: "completed",
            conclusion: "success",
            createdAt: now.addingTimeInterval(-3600)
        )
        
        XCTAssertTrue(run.usesRelativeStartLabel(relativeTo: now))
    }
    
    func testWorkflowRunStartLabelUsesAbsoluteAfterSixHours() {
        let now = Date()
        let run = WorkflowRun(
            id: 1,
            name: "Old",
            workflowName: "CI",
            status: "completed",
            conclusion: "success",
            createdAt: now.addingTimeInterval(-7 * 3600)
        )
        
        XCTAssertFalse(run.usesRelativeStartLabel(relativeTo: now))
        XCTAssertFalse(run.formattedAbsoluteStartLabel().isEmpty)
    }
    
    func testWorkflowRunDurationForCompletedRun() {
        let start = Date()
        let end = start.addingTimeInterval(125)
        let run = WorkflowRun(
            id: 1,
            name: "Done",
            workflowName: "CI",
            status: "completed",
            conclusion: "success",
            createdAt: start,
            updatedAt: end
        )
        
        XCTAssertEqual(run.formattedDuration(relativeTo: end), "2m 5s")
    }
    
    func testWorkflowRunAPIDecodingIncludesTimingFields() throws {
        let json = """
        {
          "id": 99,
          "name": "CI",
          "display_title": "Fix build",
          "status": "completed",
          "conclusion": "success",
          "created_at": "2026-03-20T10:00:00Z",
          "updated_at": "2026-03-20T10:05:30Z",
          "run_started_at": "2026-03-20T10:00:15Z"
        }
        """
        
        let api = try JSONDecoder().decode(WorkflowRunAPI.self, from: Data(json.utf8))
        let run = try XCTUnwrap(api.toWorkflowRun())
        
        XCTAssertEqual(run.name, "Fix build")
        XCTAssertEqual(run.formattedDuration(relativeTo: run.updatedAt), "5m 15s")
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


