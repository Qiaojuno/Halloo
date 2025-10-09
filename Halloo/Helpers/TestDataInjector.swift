import Foundation
import FirebaseFirestore

/// **DEV ONLY**: Helper to inject test habit data into Firebase
/// Call this once from a debug button or app launch to populate test data
class TestDataInjector {

    private let db = Firestore.firestore()

    /// Adds 4 test habits to the current user's account
    /// - 1 completed photo habit (2 hours ago)
    /// - 1 completed text habit (1 hour ago)
    /// - 1 upcoming habit (in 3 hours)
    /// - 1 late/overdue habit (4 hours ago, deadline passed)
    func addTestHabits(userId: String, profileId: String) async throws {
        let calendar = Calendar.current
        let now = Date()

        print("🧪 Adding test habits for user: \(userId), profile: \(profileId)")

        // 1. COMPLETED PHOTO HABIT
        let photoHabitId = UUID().uuidString
        let photoCompletedAt = calendar.date(byAdding: .hour, value: -2, to: now)!
        let photoScheduledTime = calendar.date(byAdding: .hour, value: -3, to: now)!

        let photoHabit: [String: Any] = [
            "id": photoHabitId,
            "userId": userId,
            "profileId": profileId,
            "title": "Take medication with water",
            "description": "Remember to take your morning pills with a full glass of water",
            "category": "medication",
            "frequency": "daily",
            "scheduledTime": Timestamp(date: photoScheduledTime),
            "deadlineMinutes": 60,
            "requiresPhoto": true,
            "requiresText": false,
            "customDays": [],
            "startDate": Timestamp(date: calendar.startOfDay(for: now)),
            "endDate": NSNull(),
            "status": "active",
            "createdAt": Timestamp(date: calendar.date(byAdding: .day, value: -7, to: now)!),
            "lastModifiedAt": Timestamp(date: photoCompletedAt),
            "completionCount": 7,
            "lastCompletedAt": Timestamp(date: photoCompletedAt),
            "nextScheduledDate": Timestamp(date: calendar.date(byAdding: .day, value: 1, to: photoScheduledTime)!)
        ]

        try await db.collection("users").document(userId)
            .collection("profiles").document(profileId)
            .collection("habits").document(photoHabitId).setData(photoHabit)
        print("✅ Added photo habit")

        // Add SMS photo response
        let photoResponseId = UUID().uuidString
        let photoResponseData: [String: Any] = [
            "id": photoResponseId,
            "taskId": photoHabitId,
            "profileId": profileId,
            "userId": userId,
            "textResponse": NSNull(),
            "photoData": createPlaceholderPhotoData(),
            "isCompleted": true,
            "receivedAt": Timestamp(date: photoCompletedAt),
            "responseType": "photo",
            "isConfirmationResponse": false,
            "isPositiveConfirmation": false,
            "responseScore": NSNull(),
            "processingNotes": NSNull()
        ]

        try await db.collection("users").document(userId)
            .collection("profiles").document(profileId)
            .collection("messages").document(photoResponseId).setData(photoResponseData)
        print("✅ Added photo response")

        // Create gallery event for photo response
        let photoGalleryEventId = UUID().uuidString
        let photoGalleryEvent: [String: Any] = [
            "id": photoGalleryEventId,
            "userId": userId,
            "profileId": profileId,
            "eventType": "taskResponse",
            "createdAt": Timestamp(date: photoCompletedAt),
            "eventData": [
                "taskResponse": [
                    "_0": [  // Swift enum associated value wrapper
                        "taskId": photoHabitId,
                        "textResponse": NSNull(),
                        "photoData": createPlaceholderPhotoData(),
                        "responseType": "photo",
                        "taskTitle": "Take medication with water"
                    ]
                ]
            ]
        ]

        try await db.collection("users").document(userId)
            .collection("gallery_events").document(photoGalleryEventId)
            .setData(photoGalleryEvent)
        print("✅ Added photo gallery event")

        // 2. COMPLETED TEXT HABIT
        let textHabitId = UUID().uuidString
        let textCompletedAt = calendar.date(byAdding: .hour, value: -1, to: now)!
        let textScheduledTime = calendar.date(byAdding: .hour, value: -2, to: now)!

        let textHabit: [String: Any] = [
            "id": textHabitId,
            "userId": userId,
            "profileId": profileId,
            "title": "Drink water",
            "description": "Stay hydrated by drinking a glass of water",
            "category": "health",
            "frequency": "daily",
            "scheduledTime": Timestamp(date: textScheduledTime),
            "deadlineMinutes": 30,
            "requiresPhoto": false,
            "requiresText": true,
            "customDays": [],
            "startDate": Timestamp(date: calendar.startOfDay(for: now)),
            "endDate": NSNull(),
            "status": "active",
            "createdAt": Timestamp(date: calendar.date(byAdding: .day, value: -5, to: now)!),
            "lastModifiedAt": Timestamp(date: textCompletedAt),
            "completionCount": 5,
            "lastCompletedAt": Timestamp(date: textCompletedAt),
            "nextScheduledDate": Timestamp(date: calendar.date(byAdding: .day, value: 1, to: textScheduledTime)!)
        ]

        try await db.collection("users").document(userId)
            .collection("profiles").document(profileId)
            .collection("habits").document(textHabitId).setData(textHabit)
        print("✅ Added text habit")

        // Add SMS text response
        let textResponseId = UUID().uuidString
        let textResponseData: [String: Any] = [
            "id": textResponseId,
            "taskId": textHabitId,
            "profileId": profileId,
            "userId": userId,
            "textResponse": "Done! Feeling refreshed 💧",
            "photoData": NSNull(),
            "isCompleted": true,
            "receivedAt": Timestamp(date: textCompletedAt),
            "responseType": "text",
            "isConfirmationResponse": false,
            "isPositiveConfirmation": false,
            "responseScore": NSNull(),
            "processingNotes": NSNull()
        ]

        try await db.collection("users").document(userId)
            .collection("profiles").document(profileId)
            .collection("messages").document(textResponseId).setData(textResponseData)
        print("✅ Added text response")

        // Create gallery event for text response
        let textGalleryEventId = UUID().uuidString
        let textGalleryEvent: [String: Any] = [
            "id": textGalleryEventId,
            "userId": userId,
            "profileId": profileId,
            "eventType": "taskResponse",
            "createdAt": Timestamp(date: textCompletedAt),
            "eventData": [
                "taskResponse": [
                    "_0": [  // Swift enum associated value wrapper
                        "taskId": textHabitId,
                        "textResponse": "Done! Feeling refreshed 💧",
                        "photoData": NSNull(),
                        "responseType": "text",
                        "taskTitle": "Drink water"
                    ]
                ]
            ]
        ]

        try await db.collection("users").document(userId)
            .collection("gallery_events").document(textGalleryEventId)
            .setData(textGalleryEvent)
        print("✅ Added text gallery event")

        // 3. UPCOMING HABIT (scheduled for later today)
        let upcomingHabitId = UUID().uuidString
        let upcomingScheduledTime = calendar.date(byAdding: .hour, value: 3, to: now)!

        let upcomingHabit: [String: Any] = [
            "id": upcomingHabitId,
            "userId": userId,
            "profileId": profileId,
            "title": "Evening walk",
            "description": "Take a 15-minute walk around the neighborhood",
            "category": "exercise",
            "frequency": "daily",
            "scheduledTime": Timestamp(date: upcomingScheduledTime),
            "deadlineMinutes": 120,
            "requiresPhoto": false,
            "requiresText": true,
            "customDays": [],
            "startDate": Timestamp(date: calendar.startOfDay(for: now)),
            "endDate": NSNull(),
            "status": "active",
            "createdAt": Timestamp(date: calendar.date(byAdding: .day, value: -3, to: now)!),
            "lastModifiedAt": Timestamp(date: calendar.date(byAdding: .day, value: -3, to: now)!),
            "completionCount": 0,
            "lastCompletedAt": NSNull(),
            "nextScheduledDate": Timestamp(date: upcomingScheduledTime)
        ]

        try await db.collection("users").document(userId)
            .collection("profiles").document(profileId)
            .collection("habits").document(upcomingHabitId).setData(upcomingHabit)
        print("✅ Added upcoming habit")

        // 4. LATE/OVERDUE HABIT (past deadline)
        let lateHabitId = UUID().uuidString
        let lateScheduledTime = calendar.date(byAdding: .hour, value: -4, to: now)!

        let lateHabit: [String: Any] = [
            "id": lateHabitId,
            "userId": userId,
            "profileId": profileId,
            "title": "Take vitamins",
            "description": "Don't forget your daily vitamin supplements",
            "category": "medication",
            "frequency": "daily",
            "scheduledTime": Timestamp(date: lateScheduledTime),
            "deadlineMinutes": 60,
            "requiresPhoto": false,
            "requiresText": true,
            "customDays": [],
            "startDate": Timestamp(date: calendar.startOfDay(for: now)),
            "endDate": NSNull(),
            "status": "active",
            "createdAt": Timestamp(date: calendar.date(byAdding: .day, value: -10, to: now)!),
            "lastModifiedAt": Timestamp(date: calendar.date(byAdding: .day, value: -1, to: now)!),
            "completionCount": 9,
            "lastCompletedAt": Timestamp(date: calendar.date(byAdding: .day, value: -1, to: now)!),
            "nextScheduledDate": Timestamp(date: lateScheduledTime)
        ]

        try await db.collection("users").document(userId)
            .collection("profiles").document(profileId)
            .collection("habits").document(lateHabitId).setData(lateHabit)
        print("✅ Added late/overdue habit")

        print("\n🎉 Successfully added test data!")
        print("📊 Summary:")
        print("  ✅ 4 habits created")
        print("  ✅ 2 SMS responses created")
        print("  ✅ 2 gallery events created")
        print("\n📸 Gallery events:")
        print("  📷 Photo response (2 hours ago) - 'Take medication with water'")
        print("  💬 Text response (1 hour ago) - 'Drink water'")
        print("\n📋 Habits breakdown:")
        print("  ✅ 1 completed photo habit (2 hours ago)")
        print("  ✅ 1 completed text habit (1 hour ago)")
        print("  ⏰ 1 upcoming habit (in 3 hours)")
        print("  ⚠️ 1 late habit (overdue by 3 hours)")
    }

    /// Creates minimal JPEG placeholder data for testing
    private func createPlaceholderPhotoData() -> Data {
        // Minimal JPEG header to make it valid photo data
        return Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10,
                     0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
    }
}
