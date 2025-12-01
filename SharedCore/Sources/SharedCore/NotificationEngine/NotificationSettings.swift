import Foundation

/// Notification settings for workflow run statuses
public struct NotificationSettings: Codable {
    /// Notify on successful completions
    public var notifyOnSuccess: Bool
    /// Notify on failed completions
    public var notifyOnFailure: Bool
    /// Notify when running workflow completes (regardless of result)
    public var notifyOnRunningCompletion: Bool
    /// Notify on canceled workflows
    public var notifyOnCanceled: Bool
    
    public init(
        notifyOnSuccess: Bool = true,
        notifyOnFailure: Bool = true,
        notifyOnRunningCompletion: Bool = true,
        notifyOnCanceled: Bool = false
    ) {
        self.notifyOnSuccess = notifyOnSuccess
        self.notifyOnFailure = notifyOnFailure
        self.notifyOnRunningCompletion = notifyOnRunningCompletion
        self.notifyOnCanceled = notifyOnCanceled
    }
    
    /// Checks if a notification should be sent for the given status
    public func shouldNotify(for status: String, conclusion: String?, previousStatus: String?) -> Bool {
        // If workflow was in running status and completed
        if let prevStatus = previousStatus,
           (prevStatus == "in_progress" || prevStatus == "queued"),
           status == "completed" {
            return notifyOnRunningCompletion
        }
        
        // If workflow completed
        if status == "completed" {
            guard let conclusion = conclusion else {
                return false
            }
            
            switch conclusion {
            case "success":
                return notifyOnSuccess
            case "failure":
                return notifyOnFailure
            case "canceled":
                return notifyOnCanceled
            default:
                return false
            }
        }
        
        return false
    }
}

