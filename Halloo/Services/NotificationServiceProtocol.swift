import Foundation
import UserNotifications

/// Simple notification service protocol for MVP
/// Handles basic iOS local notifications for task reminders
protocol NotificationServiceProtocol {

    /// Request notification permission from user
    func requestPermissions() async -> Bool

    /// Schedule a notification at a specific time
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        scheduledTime: Date
    ) async throws

    /// Cancel a specific notification
    func cancelNotification(withId id: String) async

    /// Cancel all pending notifications
    func cancelAllNotifications() async

    /// Get IDs of all pending notifications
    func getPendingNotificationIds() async -> [String]
}
