import Foundation
import UserNotifications
import Combine

// MARK: - Mock Notification Service
class MockNotificationService: NotificationServiceProtocol {
    
    // MARK: - Properties
    @Published var isPermissionGranted: Bool = false
    @Published var pendingNotifications: [PendingNotification] = []
    
    private var mockNotifications: [PendingNotification] = []
    
    // MARK: - NotificationServiceProtocol Implementation
    
    func initialize() async {
        print("🔔 Mock Notification Service initialized")
    }
    
    func requestNotificationPermission() async throws -> Bool {
        // Simulate permission request
        try await _Concurrency.Task.sleep(for: .milliseconds(500))
        
        let granted = Bool.random() // Randomly grant permission for testing
        await MainActor.run {
            isPermissionGranted = granted
        }
        
        print("🔔 Mock notification permission: \(granted ? "granted" : "denied")")
        return granted
    }
    
    func checkPermissionStatus() async -> Bool {
        return isPermissionGranted
    }
    
    func getNotificationPermissionStatus() async -> UNAuthorizationStatus {
        return isPermissionGranted ? .authorized : .denied
    }
    
    func openNotificationSettings() async {
        print("🔔 Mock: Opening notification settings")
    }
    
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        scheduledTime: Date,
        userInfo: [String: Any]
    ) async throws {
        let request = NotificationRequest(
            id: id,
            title: title,
            body: body,
            scheduledTime: scheduledTime,
            userInfo: userInfo.compactMapValues { $0 as? String },
            category: .general
        )
        
        let notification = PendingNotification(
            request: request,
            reason: .noPermission
        )
        
        mockNotifications.append(notification)
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        
        print("🔔 Mock notification scheduled: \(title)")
    }
    
    func scheduleRepeatingNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        repeats: Bool,
        userInfo: [String: Any]
    ) async throws {
        let request = NotificationRequest(
            id: id,
            title: title,
            body: body,
            dateComponents: dateComponents,
            repeats: repeats,
            userInfo: userInfo.compactMapValues { $0 as? String },
            category: .general
        )
        
        let notification = PendingNotification(
            request: request,
            reason: .noPermission
        )
        
        mockNotifications.append(notification)
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        
        print("🔔 Mock repeating notification scheduled: \(title)")
    }
    
    func scheduleTaskReminder(_ task: Task, for profile: ElderlyProfile) async throws {
        let request = NotificationRequest(
            id: UUID().uuidString,
            title: "Task Reminder",
            body: "Time for \(profile.name) to \(task.title)",
            scheduledTime: task.nextScheduledDate,
            userInfo: ["taskId": task.id, "profileId": profile.id],
            category: .taskReminder
        )
        
        let notification = PendingNotification(
            request: request,
            reason: .noPermission
        )
        
        mockNotifications.append(notification)
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        
        print("🔔 Mock notification scheduled: \(request.title)")
    }
    
    func scheduleTaskDeadline(_ task: Task, for profile: ElderlyProfile, deadline: Date) async throws {
        let request = NotificationRequest(
            id: UUID().uuidString,
            title: "Task Deadline",
            body: "Deadline approaching for \(profile.name)'s task: \(task.title)",
            scheduledTime: deadline,
            userInfo: ["taskId": task.id, "profileId": profile.id],
            category: .taskOverdue
        )
        
        let notification = PendingNotification(
            request: request,
            reason: .noPermission
        )
        
        mockNotifications.append(notification)
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        
        print("🔔 Mock deadline notification scheduled: \(request.title)")
    }
    
    func cancelTaskNotifications(for taskId: String) async throws {
        mockNotifications.removeAll { $0.request.userInfo["taskId"] == taskId }
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        
        print("🔔 Mock notifications cancelled for task: \(taskId)")
    }
    
    func cancelAllNotifications() async {
        mockNotifications.removeAll()
        await MainActor.run {
            pendingNotifications = []
        }
        
        print("🔔 All mock notifications cancelled")
    }
    
    func requestPermission() async throws -> Bool {
        // Alias for requestNotificationPermission required by protocol
        return try await requestNotificationPermission()
    }
    
    func checkPendingNotifications() async {
        // Simulate checking for pending notifications
        let now = Date()
        let expiredNotifications = mockNotifications.filter { 
            if let scheduledTime = $0.request.scheduledTime {
                return scheduledTime <= now
            }
            return false
        }
        
        for notification in expiredNotifications {
            print("🔔 Mock notification triggered: \(notification.request.title)")
        }
        
        // Remove expired notifications
        mockNotifications.removeAll { 
            if let scheduledTime = $0.request.scheduledTime {
                return scheduledTime <= now
            }
            return false
        }
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
    }
    
    func getNotificationAnalytics(from startDate: Date, to endDate: Date) async -> NotificationAnalytics {
        // Mock analytics - return empty/zero data
        return NotificationAnalytics(
            totalScheduled: 0,
            totalDelivered: 0,
            totalOpened: 0,
            totalDismissed: 0,
            deliveryRate: 0.0,
            openRate: 0.0,
            dismissalRate: 0.0,
            categoryBreakdown: [:],
            timeOfDayBreakdown: [:],
            generatedAt: Date()
        )
    }
    
    func trackNotificationOpened(id: String) async {
        print("🔔 Mock notification opened: \(id)")
    }
    
    func trackNotificationDismissed(id: String) async {
        print("🔔 Mock notification dismissed: \(id)")
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        print("🔔 Mock notification response handled: \(response.actionIdentifier)")
    }
    
    func handleNotificationReceived(_ notification: UNNotification) async {
        print("🔔 Mock notification received: \(notification.request.identifier)")
    }
    
    // MARK: - Missing Protocol Methods
    func scheduleLocationBasedNotification(
        id: String,
        title: String,
        body: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        userInfo: [String: Any]
    ) async throws {
        print("🔔 Mock location notification scheduled: \(title)")
    }
    
    func cancelNotification(withId id: String) async {
        mockNotifications.removeAll { $0.request.id == id }
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        print("🔔 Mock notification cancelled: \(id)")
    }
    
    func cancelNotifications(withPrefix prefix: String) async throws {
        mockNotifications.removeAll { $0.request.id.hasPrefix(prefix) }
        await MainActor.run {
            pendingNotifications = mockNotifications
        }
        print("🔔 Mock notifications cancelled with prefix: \(prefix)")
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return []  // Return empty array for mock
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return []  // Return empty array for mock
    }

    func incrementBadgeCount() async {
        print("🔔 Mock badge count incremented")
    }
    
    func decrementBadgeCount() async {
        print("🔔 Mock badge count decremented")
    }
    
    // MARK: - Additional Required Protocol Methods (SYSTEMATIC RESTORATION)
    // =====================================================
    // Missing methods from NotificationServiceProtocol - RESTORED
    // =====================================================
    func updateNotificationContent(
        id: String,
        title: String,
        body: String,
        userInfo: [String: Any]
    ) async throws {
        print("🔔 Mock notification content updated: \(id)")
    }
    
    func addAttachmentToNotification(
        id: String,
        imageData: Data,
        identifier: String
    ) async throws {
        print("🔔 Mock attachment added to notification: \(id)")
    }
    
    func setBadgeCount(_ count: Int) async {
        print("🔔 Mock badge count set to: \(count)")
    }
    
    func clearBadge() async {
        print("🔔 Mock badge cleared")
    }
}