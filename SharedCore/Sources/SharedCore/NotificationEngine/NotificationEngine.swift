import Foundation
import UserNotifications

/// Engine for sending notifications about CI workflow run statuses
/// Works on macOS and iOS
@MainActor
public class NotificationEngine: ObservableObject {
    public static let shared = NotificationEngine()
    
    private let settingsKey = "CIWatcher.NotificationSettings"
    private var previousWorkflowStates: [String: WorkflowState] = [:]
    
    /// Current notification settings
    @Published public var settings: NotificationSettings {
        didSet {
            saveSettings()
        }
    }
    
    private init() {
        self.settings = NotificationEngine.loadSettings()
    }
    
    // MARK: - Settings Management
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    private static func loadSettings() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: "CIWatcher.NotificationSettings"),
              let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return decoded
    }
    
    // MARK: - Permission Management
    
    /// Requests permission to send notifications
    public func requestAuthorization() async -> Bool {
        do {
            // On macOS, it may be necessary to check the current status first
            let currentSettings = await UNUserNotificationCenter.current().notificationSettings()
            
            // If already authorized, return true
            if currentSettings.authorizationStatus == .authorized {
                return true
            }
            
            // If already denied, don't show dialog again
            if currentSettings.authorizationStatus == .denied {
                print("Notification permission was previously denied. User needs to enable it in System Settings.")
                return false
            }
            
            // Request permission
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            
            print("Notification authorization request completed. Granted: \(granted)")
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    /// Checks if there is permission to send notifications
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Notification Processing
    
    /// Processes changes in workflow runs and sends notifications if needed
    /// - Parameters:
    ///   - repository: Repository
    ///   - workflowRuns: Current list of workflow runs
    public func processWorkflowRuns(
        for repository: CIRepository,
        workflowRuns: [WorkflowRun]
    ) async {
        // Check notification permission
        let authStatus = await checkAuthorizationStatus()
        guard authStatus == .authorized else {
            return
        }
        
        let repositoryKey = repository.id.uuidString
        
        // Get previous state for this repository
        let previousState = previousWorkflowStates[repositoryKey]
        
        // Create current state
        let currentState = WorkflowState(
            repository: repository,
            workflowRuns: workflowRuns
        )
        
        // Compare and send notifications
        if let previous = previousState {
            await sendNotificationsForChanges(
                previous: previous,
                current: currentState
            )
        }
        
        // Save current state
        previousWorkflowStates[repositoryKey] = currentState
    }
    
    private func sendNotificationsForChanges(
        previous: WorkflowState,
        current: WorkflowState
    ) async {
        // Create dictionary of previous states by ID
        let previousRunsById = Dictionary(uniqueKeysWithValues: previous.workflowRuns.map { ($0.id, $0) })
        
        // Check each current workflow run
        for currentRun in current.workflowRuns {
            guard let previousRun = previousRunsById[currentRun.id] else {
                // New workflow run - skip (don't notify about new runs)
                continue
            }
            
            // Check if status changed
            if previousRun.status != currentRun.status ||
               previousRun.conclusion != currentRun.conclusion {
                
                // Check if we should send notification
                if settings.shouldNotify(
                    for: currentRun.status,
                    conclusion: currentRun.conclusion,
                    previousStatus: previousRun.status
                ) {
                    await sendNotification(
                        for: currentRun,
                        repository: current.repository
                    )
                }
            }
        }
    }
    
    private func sendNotification(
        for workflowRun: WorkflowRun,
        repository: CIRepository
    ) async {
        let content = UNMutableNotificationContent()
        
        // Form notification title and text
        let statusText: String
        let emoji: String
        
        if workflowRun.status == "completed" {
            switch workflowRun.conclusion {
            case "success":
                statusText = "Completed successfully"
                emoji = "🟢"
            case "failure":
                statusText = "Completed with errors"
                emoji = "🔴"
            case "canceled":
                statusText = "Canceled"
                emoji = "⚪"
            default:
                statusText = "Completed"
                emoji = "⚪"
            }
        } else {
            statusText = workflowRun.status
            emoji = workflowRun.statusEmoji
        }
        
        content.title = "\(emoji) \(repository.fullName) — \(workflowRun.workflowName)"
        content.body = "\(workflowRun.name) — \(statusText)"
        content.sound = .default
        content.categoryIdentifier = "CI_WORKFLOW_STATUS"
        
        // Add repository information to userInfo for potential future use
        content.userInfo = [
            "repositoryId": repository.id.uuidString,
            "workflowRunId": workflowRun.id,
            "workflowName": workflowRun.workflowName,
            "status": workflowRun.status,
            "conclusion": workflowRun.conclusion ?? ""
        ]
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: "\(repository.id.uuidString)-\(workflowRun.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate notification
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    // MARK: - Helper Structures
    
    private struct WorkflowState {
        let repository: CIRepository
        let workflowRuns: [WorkflowRun]
    }
}

