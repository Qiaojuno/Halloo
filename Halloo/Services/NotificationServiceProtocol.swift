import Foundation
import UserNotifications

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol {
    
    // MARK: - Permission Management
    func requestNotificationPermission() async throws -> Bool
    func getNotificationPermissionStatus() async -> UNAuthorizationStatus
    func openNotificationSettings() async
    
    // MARK: - Notification Scheduling
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        scheduledTime: Date,
        userInfo: [String: Any]
    ) async throws
    
    func scheduleRepeatingNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        repeats: Bool,
        userInfo: [String: Any]
    ) async throws
    
    func scheduleLocationBasedNotification(
        id: String,
        title: String,
        body: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        userInfo: [String: Any]
    ) async throws
    
    // MARK: - Notification Management
    func cancelNotification(withId id: String) async
    func cancelNotifications(withPrefix prefix: String) async throws
    func cancelAllNotifications() async
    func getPendingNotifications() async -> [UNNotificationRequest]
    func getDeliveredNotifications() async -> [UNNotification]
    
    // MARK: - Notification Content
    func updateNotificationContent(
        id: String,
        title: String,
        body: String,
        userInfo: [String: Any]
    ) async throws
    
    func addAttachmentToNotification(
        id: String,
        imageData: Data,
        identifier: String
    ) async throws
    
    // MARK: - Badge Management
    func setBadgeCount(_ count: Int) async
    func clearBadge() async
    func incrementBadgeCount() async
    func decrementBadgeCount() async
    
    // MARK: - Response Handling
    func handleNotificationResponse(_ response: UNNotificationResponse) async
    func handleNotificationReceived(_ notification: UNNotification) async
    
    // MARK: - Analytics
    func getNotificationAnalytics(from startDate: Date, to endDate: Date) async -> NotificationAnalytics
    func trackNotificationOpened(id: String) async
    func trackNotificationDismissed(id: String) async
    
    // MARK: - Service Lifecycle
    func initialize() async
    func requestPermission() async throws -> Bool
    func checkPendingNotifications() async
}

// MARK: - Notification Models

struct NotificationRequest: Codable {
    let id: String
    let title: String
    let body: String
    var scheduledTime: Date?
    let dateComponents: DateComponents?
    let repeats: Bool
    let userInfo: [String: String] // Simplified for Codable
    let category: NotificationCategory
    let priority: NotificationPriority
    let attachments: [NotificationAttachment]
    
    init(
        id: String,
        title: String,
        body: String,
        scheduledTime: Date? = nil,
        dateComponents: DateComponents? = nil,
        repeats: Bool = false,
        userInfo: [String: String] = [:],
        category: NotificationCategory = .general,
        priority: NotificationPriority = .normal,
        attachments: [NotificationAttachment] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.scheduledTime = scheduledTime
        self.dateComponents = dateComponents
        self.repeats = repeats
        self.userInfo = userInfo
        self.category = category
        self.priority = priority
        self.attachments = attachments
    }
}

struct NotificationAttachment: Codable {
    let identifier: String
    let url: String
    let type: AttachmentType
    
    enum AttachmentType: String, CaseIterable, Codable {
        case image = "image"
        case video = "video"
        case audio = "audio"
        case other = "other"
    }
}

struct NotificationAnalytics: Codable {
    let totalScheduled: Int
    let totalDelivered: Int
    let totalOpened: Int
    let totalDismissed: Int
    let deliveryRate: Double
    let openRate: Double
    let dismissalRate: Double
    let categoryBreakdown: [NotificationCategory: NotificationCategoryStats]
    let timeOfDayBreakdown: [Int: Int] // Hour of day -> count
    let generatedAt: Date
    
    var engagementRate: Double {
        return totalDelivered > 0 ? Double(totalOpened) / Double(totalDelivered) : 0
    }
}

struct NotificationCategoryStats: Codable {
    let category: NotificationCategory
    let scheduled: Int
    let delivered: Int
    let opened: Int
    let dismissed: Int
    let averageResponseTime: TimeInterval
    
    var openRate: Double {
        return delivered > 0 ? Double(opened) / Double(delivered) : 0
    }
}

// MARK: - Notification Enums

enum NotificationCategory: String, CaseIterable, Codable {
    case taskReminder = "taskReminder"
    case profileConfirmation = "profileConfirmation"
    case taskOverdue = "taskOverdue"
    case dailySummary = "dailySummary"
    case weeklyReport = "weeklyReport"
    case emergencyAlert = "emergencyAlert"
    case systemUpdate = "systemUpdate"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .taskReminder:
            return "Task Reminder"
        case .profileConfirmation:
            return "Profile Confirmation"
        case .taskOverdue:
            return "Overdue Task"
        case .dailySummary:
            return "Daily Summary"
        case .weeklyReport:
            return "Weekly Report"
        case .emergencyAlert:
            return "Emergency Alert"
        case .systemUpdate:
            return "System Update"
        case .general:
            return "General"
        }
    }
    
    var identifier: String {
        return rawValue
    }
    
    var actions: [NotificationAction] {
        switch self {
        case .taskReminder:
            return [
                NotificationAction(id: "complete", title: "Mark Complete", style: .default),
                NotificationAction(id: "snooze", title: "Remind Later", style: .default),
                NotificationAction(id: "skip", title: "Skip", style: .destructive)
            ]
        case .profileConfirmation:
            return [
                NotificationAction(id: "confirm", title: "Confirm", style: .default),
                NotificationAction(id: "resend", title: "Resend SMS", style: .default)
            ]
        case .taskOverdue:
            return [
                NotificationAction(id: "complete", title: "Mark Complete", style: .default),
                NotificationAction(id: "reschedule", title: "Reschedule", style: .default)
            ]
        default:
            return [
                NotificationAction(id: "view", title: "View", style: .default),
                NotificationAction(id: "dismiss", title: "Dismiss", style: .cancel)
            ]
        }
    }
    
    var sound: NotificationSound {
        switch self {
        case .emergencyAlert:
            return .critical
        case .taskReminder, .taskOverdue:
            return .important
        default:
            return .default
        }
    }
    
    var priority: NotificationPriority {
        switch self {
        case .emergencyAlert:
            return .critical
        case .taskReminder, .taskOverdue:
            return .high
        case .profileConfirmation:
            return .normal
        default:
            return .low
        }
    }
}

enum NotificationPriority: Int, CaseIterable, Codable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    var interruptionLevel: String {
        switch self {
        case .low:
            return "passive"
        case .normal:
            return "active"
        case .high:
            return "timeSensitive"
        case .critical:
            return "critical"
        }
    }
}

enum NotificationSound: String, CaseIterable, Codable {
    case `default` = "default"
    case important = "important"
    case critical = "critical"
    case gentle = "gentle"
    case silent = "silent"
    
    var fileName: String? {
        switch self {
        case .default:
            return nil // Use system default
        case .important:
            return "notification_important.caf"
        case .critical:
            return "notification_critical.caf"
        case .gentle:
            return "notification_gentle.caf"
        case .silent:
            return nil
        }
    }
}

struct NotificationAction: Codable {
    let id: String
    let title: String
    let style: ActionStyle
    let requiresAuthentication: Bool
    let requiresForeground: Bool
    
    enum ActionStyle: String, CaseIterable, Codable {
        case `default` = "default"
        case destructive = "destructive"
        case cancel = "cancel"
    }
    
    init(
        id: String,
        title: String,
        style: ActionStyle = .default,
        requiresAuthentication: Bool = false,
        requiresForeground: Bool = false
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.requiresAuthentication = requiresAuthentication
        self.requiresForeground = requiresForeground
    }
}

// MARK: - Notification Errors

enum NotificationError: LocalizedError {
    case permissionDenied
    case permissionNotRequested
    case invalidNotificationId
    case notificationNotFound
    case schedulingFailed
    case attachmentFailed
    case quotaExceeded
    case systemError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied. Please enable notifications in Settings."
        case .permissionNotRequested:
            return "Notification permission not requested. Please request permission first."
        case .invalidNotificationId:
            return "Invalid notification ID provided."
        case .notificationNotFound:
            return "Notification not found."
        case .schedulingFailed:
            return "Failed to schedule notification."
        case .attachmentFailed:
            return "Failed to attach media to notification."
        case .quotaExceeded:
            return "Notification quota exceeded. Too many notifications scheduled."
        case .systemError(let message):
            return "System notification error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Notifications > Hallo to enable notifications."
        case .permissionNotRequested:
            return "Request notification permission before scheduling notifications."
        case .quotaExceeded:
            return "Cancel some existing notifications before scheduling new ones."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}