import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// This script adds test habit data to Firebase for the account nicholas0720h@gmail.com
// Run with: swift add_test_habits.swift

func addTestHabits() async {
    // Initialize Firebase
    FirebaseApp.configure()
    
    let db = Firestore.firestore()
    
    // Get current user
    guard let currentUser = Auth.auth().currentUser else {
        print("❌ No user logged in. Please log in to nicholas0720h@gmail.com first")
        return
    }
    
    let userId = currentUser.uid
    print("✅ Current user ID: \(userId)")
    
    // Fetch the existing profile
    do {
        let profilesSnapshot = try await db.collection("users").document(userId)
            .collection("profiles").limit(to: 1).getDocuments()
        
        guard let profileDoc = profilesSnapshot.documents.first else {
            print("❌ No profile found for this user")
            return
        }
        
        let profileId = profileDoc.documentID
        let profileData = profileDoc.data()
        let profileName = profileData["name"] as? String ?? "Profile"
        
        print("✅ Found profile: \(profileName) (ID: \(profileId))")
        
        let now = Date()
        let calendar = Calendar.current
        
        // Helper to create ISO8601 timestamp
        func isoTimestamp(_ date: Date) -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        // 1. Completed Photo Habit (completed today)
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
            "completionCount": 1,
            "lastCompletedAt": Timestamp(date: photoCompletedAt),
            "nextScheduledDate": Timestamp(date: calendar.date(byAdding: .day, value: 1, to: photoScheduledTime)!)
        ]
        
        // 2. Completed Text Habit (completed today)
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
            "completionCount": 1,
            "lastCompletedAt": Timestamp(date: textCompletedAt),
            "nextScheduledDate": Timestamp(date: calendar.date(byAdding: .day, value: 1, to: textScheduledTime)!)
        ]
        
        // 3. Upcoming Habit (scheduled for later today)
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
        
        // 4. Late Habit (overdue from earlier today)
        let lateHabitId = UUID().uuidString
        let lateScheduledTime = calendar.date(byAdding: .hour, value: -4, to: now)!
        let lateDeadline = calendar.date(byAdding: .hour, value: -3, to: now)! // 1 hour ago
        
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
        
        // Add habits to Firestore
        try await db.collection("users").document(userId)
            .collection("tasks").document(photoHabitId).setData(photoHabit)
        print("✅ Added photo habit: \(photoHabit["title"]!)")
        
        try await db.collection("users").document(userId)
            .collection("tasks").document(textHabitId).setData(textHabit)
        print("✅ Added text habit: \(textHabit["title"]!)")
        
        try await db.collection("users").document(userId)
            .collection("tasks").document(upcomingHabitId).setData(upcomingHabit)
        print("✅ Added upcoming habit: \(upcomingHabit["title"]!)")
        
        try await db.collection("users").document(userId)
            .collection("tasks").document(lateHabitId).setData(lateHabit)
        print("✅ Added late habit: \(lateHabit["title"]!)")
        
        // Add SMS responses for completed habits
        let photoResponseId = UUID().uuidString
        let photoResponseData: [String: Any] = [
            "id": photoResponseId,
            "taskId": photoHabitId,
            "profileId": profileId,
            "userId": userId,
            "textResponse": NSNull(),
            "photoData": Data([0xFF, 0xD8, 0xFF, 0xE0]), // Minimal JPEG header as placeholder
            "isCompleted": true,
            "receivedAt": Timestamp(date: photoCompletedAt),
            "responseType": "photo",
            "isConfirmationResponse": false,
            "isPositiveConfirmation": false,
            "responseScore": NSNull(),
            "processingNotes": NSNull()
        ]
        
        try await db.collection("users").document(userId)
            .collection("smsResponses").document(photoResponseId).setData(photoResponseData)
        print("✅ Added photo response for completed habit")
        
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
            .collection("smsResponses").document(textResponseId).setData(textResponseData)
        print("✅ Added text response for completed habit")
        
        print("\n🎉 Successfully added 4 test habits and 2 responses!")
        print("📊 Summary:")
        print("  - 1 completed photo habit")
        print("  - 1 completed text habit")
        print("  - 1 upcoming habit (in 3 hours)")
        print("  - 1 late habit (overdue by 3 hours)")
        
    } catch {
        print("❌ Error: \(error.localizedDescription)")
    }
}

// Run the async function
Task {
    await addTestHabits()
    exit(0)
}

// Keep the script running
RunLoop.main.run()
