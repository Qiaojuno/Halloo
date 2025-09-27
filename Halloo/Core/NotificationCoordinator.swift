import Foundation
import UIKit
import UserNotifications
import Combine

// MARK: - TimeRange Helper
struct TimeRange {
    let startDate: Date
    let endDate: Date
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Notification Coordinator
final class NotificationCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var scheduledNotifications: [ScheduledNotification] = []
    @Published var deliveredNotifications: [DeliveredNotification] = []
    @Published var badgeCount: Int = 0
    
    // MARK: - Dependencies
    private let notificationService: NotificationServiceProtocol?
    private let errorCoordinator: ErrorCoordinator?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let notificationQueue = DispatchQueue(label: "com.hallo.notifications", qos: .userInitiated)
    private var pendingNotifications: [PendingNotification] = []
    
    // MARK: - Configuration
    private let maxNotificationsPerDay = 20
    private let quietHoursStart = 22 // 10 PM
    private let quietHoursEnd = 7   // 7 AM
    
    // MARK: - Initialization
    
    init(
        notificationService: NotificationServiceProtocol? = nil,
        errorCoordinator: ErrorCoordinator? = nil
    ) {
        self.notificationService = notificationService
        self.errorCoordinator = errorCoordinator
        
        setupNotificationHandling()
        _Concurrency.Task {
            await checkPermissionStatus()
        }
    }
    
    // MARK: - Public Methods
    
    func requestPermission() async -> Bool {
        guard let service = notificationService else { return false }
        
        do {
            let granted = try await service.requestNotificationPermission()
            await updatePermissionStatus()
            return granted
        } catch {
            errorCoordinator?.handle(error, context: "Notification permission request", severity: .medium)
            return false
        }
    }
    
    func scheduleTaskReminder(for task: Task, profile: ElderlyProfile, at scheduledTime: Date) async {
        let notification = createTaskReminderNotification(task: task, profile: profile, scheduledTime: scheduledTime)
        await scheduleNotification(notification)
    }
    
    func scheduleProfileConfirmationReminder(for profile: ElderlyProfile, delay: TimeInterval = 3600) async {
        let scheduledTime = Date().addingTimeInterval(delay)
        let notification = createProfileConfirmationNotification(profile: profile, scheduledTime: scheduledTime)
        await scheduleNotification(notification)
    }
    
    func scheduleOverdueTaskAlert(for task: Task, profile: ElderlyProfile) async {
        let notification = createOverdueTaskNotification(task: task, profile: profile)
        await scheduleNotification(notification)
    }
    
    func scheduleDailySummary(for userId: String, at time: Date) async {
        let notification = createDailySummaryNotification(userId: userId, scheduledTime: time)
        await scheduleNotification(notification)
    }
    
    func scheduleWeeklyReport(for userId: String, at time: Date) async {
        let notification = createWeeklyReportNotification(userId: userId, scheduledTime: time)
        await scheduleNotification(notification)
    }
    
    func cancelTaskNotifications(for taskId: String) async {
        await cancelNotifications(withPrefix: "task_\(taskId)")
    }
    
    func cancelProfileNotifications(for profileId: String) async {
        await cancelNotifications(withPrefix: "profile_\(profileId)")
    }
    
    func cancelAllNotifications() async {
        guard let service = notificationService else { return }
        await service.cancelAllNotifications()
        await MainActor.run {
            scheduledNotifications.removeAll()
        }
    }
    
    func updateBadgeCount(_ count: Int) async {
        guard let service = notificationService else { return }
        await service.setBadgeCount(count)
        await MainActor.run {
            badgeCount = count
        }
    }
    
    func clearBadge() async {
        await updateBadgeCount(0)
    }
    
    // MARK: - Data Sync Notifications
    
    func notifyDataSyncCompleted(itemsSync: Int, duration: TimeInterval) {
        // Only notify for manual syncs or if there were significant changes
        guard itemsSync > 10 else { return }
        
        _Concurrency.Task {
            let notification = NotificationRequest(
                id: "sync_completed_\(Date().timeIntervalSince1970)",
                title: "Data Sync Complete",
                body: "Synced \(itemsSync) items in \(String(format: "%.1f", duration)) seconds",
                category: .systemUpdate,
                priority: .low
            )
            
            await scheduleImmediateNotification(notification)
        }
    }
    
    func notifyDataSyncFailed(error: Error) {
        _Concurrency.Task {
            let notification = NotificationRequest(
                id: "sync_failed_\(Date().timeIntervalSince1970)",
                title: "Sync Failed",
                body: "Unable to sync your data. Changes will be synced when connection is restored.",
                category: .systemUpdate,
                priority: .normal
            )
            
            await scheduleImmediateNotification(notification)
        }
    }
    
    // MARK: - Emergency Notifications
    
    func sendEmergencyAlert(for profile: ElderlyProfile, message: String) async {
        let notification = NotificationRequest(
            id: "emergency_\(profile.id)_\(Date().timeIntervalSince1970)",
            title: "Emergency Alert - \(profile.name)",
            body: message,
            category: .emergencyAlert,
            priority: .critical
        )
        
        await scheduleImmediateNotification(notification, bypassQuietHours: true)
    }
    
    func sendCriticalTaskAlert(for task: Task, profile: ElderlyProfile) async {
        let notification = NotificationRequest(
            id: "critical_task_\(task.id)_\(Date().timeIntervalSince1970)",
            title: "Critical Task Overdue",
            body: "\(profile.name) has not completed: \(task.title)",
            category: .emergencyAlert,
            priority: .critical
        )
        
        await scheduleImmediateNotification(notification, bypassQuietHours: true)
    }
    
    // MARK: - Notification Response Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        guard let actionId = userInfo["actionId"] as? String,
              let notificationType = userInfo["type"] as? String else {
            return
        }
        
        switch notificationType {
        case "taskReminder":
            await handleTaskReminderResponse(response, actionId: actionId)
        case "profileConfirmation":
            await handleProfileConfirmationResponse(response, actionId: actionId)
        case "taskOverdue":
            await handleOverdueTaskResponse(response, actionId: actionId)
        default:
            break
        }
        
        // Track engagement
        await trackNotificationEngagement(
            notificationId: response.notification.request.identifier,
            actionId: actionId,
            responseTime: Date()
        )
    }
    
    // MARK: - Analytics and Insights
    
    func getNotificationAnalytics(for timeRange: TimeRange) async -> NotificationAnalytics {
        let notifications = scheduledNotifications.filter { notification in
            guard let scheduledTime = notification.scheduledTime else { return false }
            return scheduledTime >= timeRange.startDate && scheduledTime <= timeRange.endDate
        }
        
        let delivered = deliveredNotifications.filter { notification in
            notification.deliveredAt >= timeRange.startDate && notification.deliveredAt <= timeRange.endDate
        }
        
        let opened = delivered.filter { $0.wasOpened }
        let dismissed = delivered.filter { $0.wasDismissed }
        
        let groupedByCategory = Dictionary(grouping: notifications) { $0.category }
        let categoryBreakdown = groupedByCategory.mapValues { categoryNotifications in
            let notificationIds = Set(categoryNotifications.map { $0.id })
            
            let deliveredCount = delivered.filter { notificationIds.contains($0.id) }.count
            let openedCount = opened.filter { notificationIds.contains($0.id) }.count
            let dismissedCount = dismissed.filter { notificationIds.contains($0.id) }.count
            
            return NotificationCategoryStats(
                category: categoryNotifications.first?.category ?? .general,
                scheduled: categoryNotifications.count,
                delivered: deliveredCount,
                opened: openedCount,
                dismissed: dismissedCount,
                averageResponseTime: calculateAverageResponseTime(for: categoryNotifications)
            )
        }
        
        let timeOfDayBreakdown = Dictionary(grouping: notifications) { notification in
            Calendar.current.component(.hour, from: notification.scheduledTime ?? Date())
        }.mapValues { $0.count }
        
        return NotificationAnalytics(
            totalScheduled: notifications.count,
            totalDelivered: delivered.count,
            totalOpened: opened.count,
            totalDismissed: dismissed.count,
            deliveryRate: notifications.isEmpty ? 0 : Double(delivered.count) / Double(notifications.count),
            openRate: delivered.isEmpty ? 0 : Double(opened.count) / Double(delivered.count),
            dismissalRate: delivered.isEmpty ? 0 : Double(dismissed.count) / Double(delivered.count),
            categoryBreakdown: categoryBreakdown,
            timeOfDayBreakdown: timeOfDayBreakdown,
            generatedAt: Date()
        )
    }
    
    func getOptimalNotificationTimes(for userId: String) -> [Int] {
        // Analyze historical engagement to find optimal sending times
        let engagementByHour = deliveredNotifications
            .filter { $0.wasOpened }
            .reduce(into: [Int: Int]()) { result, notification in
                let hour = Calendar.current.component(.hour, from: notification.deliveredAt)
                result[hour, default: 0] += 1
            }
        
        return engagementByHour
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    // MARK: - Private Implementation
    
    private func scheduleNotification(_ notification: NotificationRequest) async {
        guard await hasPermission() else {
            pendingNotifications.append(PendingNotification(request: notification, reason: .noPermission))
            return
        }
        
        guard !isInQuietHours(notification.scheduledTime) || notification.priority == .critical else {
            let adjustedTime = adjustForQuietHours(notification.scheduledTime ?? Date())
            var adjustedNotification = notification
            adjustedNotification.scheduledTime = adjustedTime
            pendingNotifications.append(PendingNotification(request: adjustedNotification, reason: .quietHours))
            return
        }
        
        guard let service = notificationService else { return }
        
        do {
            let userInfo = createUserInfo(for: notification)
            
            if let scheduledTime = notification.scheduledTime {
                try await service.scheduleNotification(
                    id: notification.id,
                    title: notification.title,
                    body: notification.body,
                    scheduledTime: scheduledTime,
                    userInfo: userInfo
                )
            }
            
            await MainActor.run {
                scheduledNotifications.append(ScheduledNotification(
                    id: notification.id,
                    title: notification.title,
                    body: notification.body,
                    category: notification.category,
                    scheduledTime: notification.scheduledTime,
                    createdAt: Date()
                ))
            }
            
        } catch {
            errorCoordinator?.handle(error, context: "Scheduling notification", severity: .low)
        }
    }
    
    private func scheduleImmediateNotification(_ notification: NotificationRequest, bypassQuietHours: Bool = false) async {
        guard await hasPermission() else { return }
        
        if !bypassQuietHours && isInQuietHours(Date()) && notification.priority != .critical {
            var delayedNotification = notification
            delayedNotification.scheduledTime = adjustForQuietHours(Date())
            pendingNotifications.append(PendingNotification(request: delayedNotification, reason: .quietHours))
            return
        }
        
        guard let service = notificationService else { return }
        
        do {
            let userInfo = createUserInfo(for: notification)
            try await service.scheduleNotification(
                id: notification.id,
                title: notification.title,
                body: notification.body,
                scheduledTime: Date(),
                userInfo: userInfo
            )
        } catch {
            errorCoordinator?.handle(error, context: "Immediate notification", severity: .low)
        }
    }
    
    private func cancelNotifications(withPrefix prefix: String) async {
        guard let service = notificationService else { return }
        
        do {
            try await service.cancelNotifications(withPrefix: prefix)
            
            await MainActor.run {
                scheduledNotifications.removeAll { $0.id.hasPrefix(prefix) }
            }
        } catch {
            errorCoordinator?.handle(error, context: "Canceling notifications", severity: .low)
        }
    }
    
    // MARK: - Notification Creation
    
    private func createTaskReminderNotification(task: Task, profile: ElderlyProfile, scheduledTime: Date) -> NotificationRequest {
        let body = task.description.isEmpty ? 
            "Reminder for \(profile.name): \(task.title)" :
            "Reminder for \(profile.name): \(task.description)"
        
        return NotificationRequest(
            id: "task_\(task.id)_\(scheduledTime.timeIntervalSince1970)",
            title: "Task Reminder",
            body: body,
            scheduledTime: scheduledTime,
            userInfo: [
                "type": "taskReminder",
                "taskId": task.id,
                "profileId": profile.id
            ],
            category: .taskReminder,
            priority: task.category == .medication ? .high : .normal
        )
    }
    
    private func createProfileConfirmationNotification(profile: ElderlyProfile, scheduledTime: Date) -> NotificationRequest {
        return NotificationRequest(
            id: "profile_confirmation_\(profile.id)_\(scheduledTime.timeIntervalSince1970)",
            title: "Profile Confirmation Needed",
            body: "\(profile.name) hasn't confirmed their profile yet. Tap to resend confirmation.",
            scheduledTime: scheduledTime,
            userInfo: [
                "type": "profileConfirmation",
                "profileId": profile.id
            ],
            category: .profileConfirmation,
            priority: .normal
        )
    }
    
    private func createOverdueTaskNotification(task: Task, profile: ElderlyProfile) -> NotificationRequest {
        return NotificationRequest(
            id: "overdue_\(task.id)_\(Date().timeIntervalSince1970)",
            title: "Overdue Task",
            body: "\(profile.name) has not completed: \(task.title)",
            userInfo: [
                "type": "taskOverdue",
                "taskId": task.id,
                "profileId": profile.id
            ],
            category: .taskOverdue,
            priority: task.category == .medication ? .high : .normal
        )
    }
    
    private func createDailySummaryNotification(userId: String, scheduledTime: Date) -> NotificationRequest {
        return NotificationRequest(
            id: "daily_summary_\(userId)_\(scheduledTime.timeIntervalSince1970)",
            title: "Daily Summary",
            body: "Check today's task completion progress",
            scheduledTime: scheduledTime,
            userInfo: [
                "type": "dailySummary",
                "userId": userId
            ],
            category: .dailySummary,
            priority: .low
        )
    }
    
    private func createWeeklyReportNotification(userId: String, scheduledTime: Date) -> NotificationRequest {
        return NotificationRequest(
            id: "weekly_report_\(userId)_\(scheduledTime.timeIntervalSince1970)",
            title: "Weekly Report",
            body: "Your weekly family care report is ready",
            scheduledTime: scheduledTime,
            userInfo: [
                "type": "weeklyReport",
                "userId": userId
            ],
            category: .weeklyReport,
            priority: .low
        )
    }
    
    // MARK: - Response Handlers
    
    private func handleTaskReminderResponse(_ response: UNNotificationResponse, actionId: String) async {
        guard let taskId = response.notification.request.content.userInfo["taskId"] as? String,
              let profileId = response.notification.request.content.userInfo["profileId"] as? String else {
            return
        }
        
        switch actionId {
        case "complete":
            NotificationCenter.default.post(
                name: .taskMarkedCompleteFromNotification,
                object: nil,
                userInfo: ["taskId": taskId, "profileId": profileId]
            )
        case "snooze":
            // Reschedule for 30 minutes later
            let snoozeTime = Date().addingTimeInterval(30 * 60)
            NotificationCenter.default.post(
                name: .taskSnoozedFromNotification,
                object: nil,
                userInfo: ["taskId": taskId, "profileId": profileId, "snoozeTime": snoozeTime]
            )
        case "skip":
            NotificationCenter.default.post(
                name: .taskSkippedFromNotification,
                object: nil,
                userInfo: ["taskId": taskId, "profileId": profileId]
            )
        default:
            break
        }
    }
    
    private func handleProfileConfirmationResponse(_ response: UNNotificationResponse, actionId: String) async {
        guard let profileId = response.notification.request.content.userInfo["profileId"] as? String else {
            return
        }
        
        switch actionId {
        case "confirm":
            NotificationCenter.default.post(
                name: .profileConfirmedFromNotification,
                object: nil,
                userInfo: ["profileId": profileId]
            )
        case "resend":
            NotificationCenter.default.post(
                name: .resendConfirmationFromNotification,
                object: nil,
                userInfo: ["profileId": profileId]
            )
        default:
            break
        }
    }
    
    private func handleOverdueTaskResponse(_ response: UNNotificationResponse, actionId: String) async {
        guard let taskId = response.notification.request.content.userInfo["taskId"] as? String,
              let profileId = response.notification.request.content.userInfo["profileId"] as? String else {
            return
        }
        
        switch actionId {
        case "complete":
            NotificationCenter.default.post(
                name: .taskMarkedCompleteFromNotification,
                object: nil,
                userInfo: ["taskId": taskId, "profileId": profileId]
            )
        case "reschedule":
            NotificationCenter.default.post(
                name: .taskRescheduledFromNotification,
                object: nil,
                userInfo: ["taskId": taskId, "profileId": profileId]
            )
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupNotificationHandling() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                _Concurrency.Task {
                    await self?.checkPermissionStatus()
                    await self?.processPendingNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkPermissionStatus() async {
        guard let service = notificationService else { return }
        let status = await service.getNotificationPermissionStatus()
        await MainActor.run {
            permissionStatus = status
        }
    }
    
    private func hasPermission() async -> Bool {
        await checkPermissionStatus()
        return permissionStatus == .authorized
    }
    
    private func updatePermissionStatus() async {
        await checkPermissionStatus()
    }
    
    private func isInQuietHours(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= quietHoursStart || hour < quietHoursEnd
    }
    
    private func adjustForQuietHours(_ date: Date) -> Date {
        let calendar = Calendar.current
        let nextMorning = calendar.date(bySettingHour: quietHoursEnd, minute: 0, second: 0, of: date) ?? date
        
        if calendar.component(.hour, from: date) >= quietHoursStart {
            // If it's late at night, schedule for next morning
            return calendar.date(byAdding: .day, value: 1, to: nextMorning) ?? nextMorning
        } else {
            // If it's early morning, schedule for later that morning
            return nextMorning
        }
    }
    
    private func processPendingNotifications() async {
        let notifications = pendingNotifications
        pendingNotifications.removeAll()
        
        for pending in notifications {
            await scheduleNotification(pending.request)
        }
    }
    
    private func createUserInfo(for notification: NotificationRequest) -> [String: Any] {
        var userInfo = notification.userInfo
        userInfo["category"] = notification.category.rawValue
        userInfo["priority"] = String(notification.priority.rawValue)
        userInfo["createdAt"] = String(Date().timeIntervalSince1970)
        return userInfo
    }
    
    private func trackNotificationEngagement(notificationId: String, actionId: String, responseTime: Date) async {
        // Track engagement analytics
        let _ = NotificationEngagement(
            notificationId: notificationId,
            actionId: actionId,
            responseTime: responseTime,
            createdAt: Date()
        )
        
        // Store engagement data for analytics
        // This would typically be saved to a local database or sent to analytics service
    }
    
    private func calculateAverageResponseTime(for notifications: [ScheduledNotification]) -> TimeInterval {
        let responseTimes = deliveredNotifications
            .filter { delivered in
                notifications.contains { $0.id == delivered.id }
            }
            .compactMap { $0.responseTime }
        
        guard !responseTimes.isEmpty else { return 0 }
        
        let totalTime = responseTimes.reduce(0, +)
        return totalTime / Double(responseTimes.count)
    }
    
    // MARK: - Background Notifications
    
    /// Schedules background reminders for elderly care tasks
    func scheduleBackgroundReminders() async {
        print("🔔 Mock: Scheduling background reminders")
    }
}

// MARK: - Supporting Models

struct ScheduledNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let category: NotificationCategory
    var scheduledTime: Date?
    let createdAt: Date
}

struct DeliveredNotification: Identifiable {
    let id: String
    let deliveredAt: Date
    let wasOpened: Bool
    let wasDismissed: Bool
    let responseTime: TimeInterval?
}

struct PendingNotification {
    let request: NotificationRequest
    let reason: PendingReason
    
    enum PendingReason {
        case noPermission
        case quietHours
        case rateLimited
    }
}

struct NotificationEngagement {
    let notificationId: String
    let actionId: String
    let responseTime: Date
    let createdAt: Date
}

// MARK: - Notification Names

extension Notification.Name {
    static let taskMarkedCompleteFromNotification = Notification.Name("taskMarkedCompleteFromNotification")
    static let taskSnoozedFromNotification = Notification.Name("taskSnoozedFromNotification")
    static let taskSkippedFromNotification = Notification.Name("taskSkippedFromNotification")
    static let profileConfirmedFromNotification = Notification.Name("profileConfirmedFromNotification")
    static let resendConfirmationFromNotification = Notification.Name("resendConfirmationFromNotification")
    static let taskRescheduledFromNotification = Notification.Name("taskRescheduledFromNotification")
}
