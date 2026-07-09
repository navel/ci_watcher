import Foundation

enum RepositoryMigration {
    static let currentVersion = 2
    static let versionKey = "CIWatcher.RepositoryMigrationVersion"

    static func needsMigration() -> Bool {
        UserDefaults.standard.integer(forKey: versionKey) < currentVersion
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: versionKey)
    }
    #endif

    /// Repositories that should be removed after switching to per-device backend auth.
    nonisolated static func repositoriesToRemove(
        from tracked: [CIRepository],
        accessibleInstallationFullNames: Set<String>,
        isGitHubConnected: Bool,
        manualPrivateRepoHasAccess: Set<UUID>
    ) -> [CIRepository] {
        tracked.filter { repository in
            shouldRemove(
                repository,
                accessibleInstallationFullNames: accessibleInstallationFullNames,
                isGitHubConnected: isGitHubConnected,
                manualPrivateRepoHasAccess: manualPrivateRepoHasAccess
            )
        }
    }

    nonisolated static func shouldRemove(
        _ repository: CIRepository,
        accessibleInstallationFullNames: Set<String>,
        isGitHubConnected: Bool,
        manualPrivateRepoHasAccess: Set<UUID>
    ) -> Bool {
        switch repository.source {
        case .installation:
            guard isGitHubConnected else {
                return true
            }
            return !accessibleInstallationFullNames.contains(repository.fullName.lowercased())

        case .manual where repository.isPrivate:
            guard isGitHubConnected else {
                return true
            }
            return !manualPrivateRepoHasAccess.contains(repository.id)

        case .manual:
            return false
        }
    }
}
