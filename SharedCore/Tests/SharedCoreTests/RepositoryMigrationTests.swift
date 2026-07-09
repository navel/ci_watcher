import XCTest
@testable import SharedCore

final class RepositoryMigrationTests: XCTestCase {
    private let ownRepo = CIRepository(
        owner: "me",
        name: "my-app",
        isPrivate: true,
        source: .installation
    )
    private let foreignRepo = CIRepository(
        owner: "friend",
        name: "secret-app",
        isPrivate: true,
        source: .installation
    )
    private let publicManualRepo = CIRepository(
        owner: "apple",
        name: "swift",
        isPrivate: false,
        source: .manual
    )
    private let privateManualRepo = CIRepository(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        owner: "me",
        name: "private-manual",
        isPrivate: true,
        source: .manual
    )

    override func tearDown() {
        #if DEBUG
        RepositoryMigration.resetForTesting()
        #endif
        super.tearDown()
    }

    func testNeedsMigrationWhenVersionMissing() {
        XCTAssertTrue(RepositoryMigration.needsMigration())
    }

    func testMarksMigrationCompleted() {
        RepositoryMigration.markCompleted()
        XCTAssertFalse(RepositoryMigration.needsMigration())
    }

    func testRemovesForeignInstallationReposWhenConnected() {
        let removed = RepositoryMigration.repositoriesToRemove(
            from: [ownRepo, foreignRepo, publicManualRepo],
            accessibleInstallationFullNames: ["me/my-app"],
            isGitHubConnected: true,
            manualPrivateRepoHasAccess: []
        )

        XCTAssertEqual(removed.map(\.fullName), ["friend/secret-app"])
    }

    func testRemovesAllInstallationReposWhenNotConnected() {
        let removed = RepositoryMigration.repositoriesToRemove(
            from: [ownRepo, foreignRepo, publicManualRepo],
            accessibleInstallationFullNames: ["me/my-app"],
            isGitHubConnected: false,
            manualPrivateRepoHasAccess: []
        )

        XCTAssertEqual(Set(removed.map(\.fullName)), Set(["me/my-app", "friend/secret-app"]))
        XCTAssertFalse(removed.contains(where: { $0.fullName == "apple/swift" }))
    }

    func testRemovesPrivateManualReposWithoutAccess() {
        let removed = RepositoryMigration.repositoriesToRemove(
            from: [privateManualRepo, publicManualRepo],
            accessibleInstallationFullNames: [],
            isGitHubConnected: true,
            manualPrivateRepoHasAccess: []
        )

        XCTAssertEqual(removed.map(\.fullName), ["me/private-manual"])
    }

    func testKeepsPrivateManualReposWithAccess() {
        let removed = RepositoryMigration.repositoriesToRemove(
            from: [privateManualRepo],
            accessibleInstallationFullNames: [],
            isGitHubConnected: true,
            manualPrivateRepoHasAccess: [privateManualRepo.id]
        )

        XCTAssertTrue(removed.isEmpty)
    }
}
