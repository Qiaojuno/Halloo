import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Combine

// MARK: - Firebase Database Service
class FirebaseDatabaseService: DatabaseServiceProtocol {
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listeners: [ListenerRegistration] = []
    
    // MARK: - Collections
    private enum Collection: String {
        case users = "users"
        case profiles = "profiles"
        case tasks = "tasks"
        case responses = "responses"
        case galleryEvents = "gallery_events"
        
        var path: String { rawValue }
    }
    
    // MARK: - User Operations
    
    func createUser(_ user: User) async throws {
        let userData = try encodeToFirestore(user)
        try await db.collection(Collection.users.path).document(user.id).setData(userData)
    }
    
    func getUser(_ userId: String) async throws -> User? {
        let document = try await db.collection(Collection.users.path).document(userId).getDocument()
        
        guard let data = document.data() else {
            return nil
        }
        
        return try decodeFromFirestore(data, as: User.self)
    }
    
    func updateUser(_ user: User) async throws {
        let userData = try encodeToFirestore(user)
        try await db.collection(Collection.users.path).document(user.id).updateData(userData)
    }
    
    func deleteUser(_ userId: String) async throws {
        let batch = db.batch()
        
        // Delete user document
        let userRef = db.collection(Collection.users.path).document(userId)
        batch.deleteDocument(userRef)
        
        // Delete all user's profiles
        let profilesQuery = db.collection(Collection.profiles.path).whereField("userId", isEqualTo: userId)
        let profilesSnapshot = try await profilesQuery.getDocuments()
        
        for profileDoc in profilesSnapshot.documents {
            batch.deleteDocument(profileDoc.reference)
            
            // Delete all tasks for this profile
            let tasksQuery = db.collection(Collection.tasks.path).whereField("profileId", isEqualTo: profileDoc.documentID)
            let tasksSnapshot = try await tasksQuery.getDocuments()
            
            for taskDoc in tasksSnapshot.documents {
                batch.deleteDocument(taskDoc.reference)
            }
        }
        
        // Delete all user's responses
        let responsesQuery = db.collection(Collection.responses.path).whereField("userId", isEqualTo: userId)
        let responsesSnapshot = try await responsesQuery.getDocuments()
        
        for responseDoc in responsesSnapshot.documents {
            batch.deleteDocument(responseDoc.reference)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Profile Operations
    
    func createElderlyProfile(_ profile: ElderlyProfile) async throws {
        let profileData = try encodeToFirestore(profile)
        try await db.collection(Collection.profiles.path).document(profile.id).setData(profileData)
        
        // Update user's profile count
        try await updateUserProfileCount(profile.userId)
    }
    
    func getElderlyProfile(_ profileId: String) async throws -> ElderlyProfile? {
        let document = try await db.collection(Collection.profiles.path).document(profileId).getDocument()
        
        guard let data = document.data() else {
            return nil
        }
        
        return try decodeFromFirestore(data, as: ElderlyProfile.self)
    }
    
    func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile] {
        let snapshot = try await db.collection(Collection.profiles.path)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: ElderlyProfile.self)
        }
    }
    
    func updateElderlyProfile(_ profile: ElderlyProfile) async throws {
        let profileData = try encodeToFirestore(profile)
        try await db.collection(Collection.profiles.path).document(profile.id).updateData(profileData)
    }
    
    func deleteElderlyProfile(_ profileId: String) async throws {
        let batch = db.batch()
        
        // Get profile to get userId
        let profileDoc = try await db.collection(Collection.profiles.path).document(profileId).getDocument()
        guard let profileData = profileDoc.data(),
              let userId = profileData["userId"] as? String else {
            throw DatabaseError.documentNotFound
        }
        
        // Delete profile
        batch.deleteDocument(profileDoc.reference)
        
        // Delete all tasks for this profile
        let tasksQuery = db.collection(Collection.tasks.path).whereField("profileId", isEqualTo: profileId)
        let tasksSnapshot = try await tasksQuery.getDocuments()
        
        for taskDoc in tasksSnapshot.documents {
            batch.deleteDocument(taskDoc.reference)
        }
        
        // Delete all responses for this profile
        let responsesQuery = db.collection(Collection.responses.path).whereField("profileId", isEqualTo: profileId)
        let responsesSnapshot = try await responsesQuery.getDocuments()
        
        for responseDoc in responsesSnapshot.documents {
            batch.deleteDocument(responseDoc.reference)
        }
        
        try await batch.commit()
        
        // Update user's profile count
        try await updateUserProfileCount(userId)
    }
    
    func getConfirmedProfiles(for userId: String) async throws -> [ElderlyProfile] {
        let query = db.collection(Collection.profiles.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "confirmed")
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: ElderlyProfile.self)
        }
    }
    
    // MARK: - Gallery History Event Operations
    
    func createGalleryHistoryEvent(_ event: GalleryHistoryEvent) async throws {
        let eventData = try encodeToFirestore(event)
        try await db.collection(Collection.galleryEvents.path).document(event.id).setData(eventData)
    }
    
    func getGalleryHistoryEvents(for userId: String) async throws -> [GalleryHistoryEvent] {
        let query = db.collection(Collection.galleryEvents.path)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: GalleryHistoryEvent.self)
        }
    }
    
    // MARK: - Task Operations
    
    func createTask(_ task: Task) async throws {
        let taskData = try encodeToFirestore(task)
        try await db.collection(Collection.tasks.path).document(task.id).setData(taskData)
        
        // Update user's task count
        try await updateUserTaskCount(task.userId)
    }
    
    func getTask(_ taskId: String) async throws -> Task? {
        let document = try await db.collection(Collection.tasks.path).document(taskId).getDocument()
        
        guard let data = document.data() else {
            return nil
        }
        
        return try decodeFromFirestore(data, as: Task.self)
    }
    
    func getProfileTasks(_ profileId: String) async throws -> [Task] {
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("profileId", isEqualTo: profileId)
            .order(by: "createdAt")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getTasks(for userId: String) async throws -> [Task] {
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getTasks(for profileId: String, userId: String) async throws -> [Task] {
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("profileId", isEqualTo: profileId)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getTasksScheduledFor(date: Date, userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: endOfDay))
            .order(by: "nextScheduledDate")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func archiveTask(_ taskId: String) async throws {
        try await db.collection(Collection.tasks.path).document(taskId).updateData([
            "status": TaskStatus.archived.rawValue,
            "archivedAt": FieldValue.serverTimestamp()
        ])
    }
    
    func getTodaysTasks(_ userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: tomorrow))
            .order(by: "nextScheduledDate")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getActiveTasks(for userId: String) async throws -> [Task] {
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: TaskStatus.active.rawValue)
            .order(by: "nextScheduledDate")
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func updateTask(_ task: Task) async throws {
        let taskData = try encodeToFirestore(task)
        try await db.collection(Collection.tasks.path).document(task.id).updateData(taskData)
    }
    
    func deleteTask(_ taskId: String) async throws {
        let batch = db.batch()
        
        // Get task to get userId
        let taskDoc = try await db.collection(Collection.tasks.path).document(taskId).getDocument()
        guard let taskData = taskDoc.data(),
              let userId = taskData["userId"] as? String else {
            throw DatabaseError.documentNotFound
        }
        
        // Delete task
        batch.deleteDocument(taskDoc.reference)
        
        // Delete all responses for this task
        let responsesQuery = db.collection(Collection.responses.path).whereField("taskId", isEqualTo: taskId)
        let responsesSnapshot = try await responsesQuery.getDocuments()
        
        for responseDoc in responsesSnapshot.documents {
            batch.deleteDocument(responseDoc.reference)
        }
        
        try await batch.commit()
        
        // Update user's task count
        try await updateUserTaskCount(userId)
    }
    
    // MARK: - Response Operations
    
    func createSMSResponse(_ response: SMSResponse) async throws {
        let responseData = try encodeToFirestore(response)
        try await db.collection(Collection.responses.path).document(response.id).setData(responseData)
    }
    
    func getSMSResponse(_ responseId: String) async throws -> SMSResponse? {
        let document = try await db.collection(Collection.responses.path).document(responseId).getDocument()
        
        guard let data = document.data() else {
            return nil
        }
        
        return try decodeFromFirestore(data, as: SMSResponse.self)
    }
    
    func getSMSResponses(for taskId: String) async throws -> [SMSResponse] {
        let snapshot = try await db.collection(Collection.responses.path)
            .whereField("taskId", isEqualTo: taskId)
            .order(by: "receivedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }
    
    func getSMSResponses(for profileId: String, userId: String) async throws -> [SMSResponse] {
        let snapshot = try await db.collection(Collection.responses.path)
            .whereField("profileId", isEqualTo: profileId)
            .whereField("userId", isEqualTo: userId)
            .order(by: "receivedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }
    
    func getSMSResponses(for userId: String, date: Date) async throws -> [SMSResponse] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let snapshot = try await db.collection(Collection.responses.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("receivedAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("receivedAt", isLessThan: Timestamp(date: endOfDay))
            .order(by: "receivedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }
    
    func getRecentSMSResponses(for userId: String, limit: Int) async throws -> [SMSResponse] {
        let snapshot = try await db.collection(Collection.responses.path)
            .whereField("userId", isEqualTo: userId)
            .order(by: "receivedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }
    
    func getConfirmationResponses(for profileId: String) async throws -> [SMSResponse] {
        let snapshot = try await db.collection(Collection.responses.path)
            .whereField("profileId", isEqualTo: profileId)
            .whereField("responseType", isEqualTo: ResponseType.text.rawValue)
            .order(by: "receivedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }
    
    func getCompletedResponsesWithPhotos() async throws -> [SMSResponse] {
        let snapshot = try await db.collection(Collection.responses.path)
            .whereField("isCompleted", isEqualTo: true)
            .whereField("responseType", in: [ResponseType.photo.rawValue, ResponseType.both.rawValue])
            .order(by: "receivedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: SMSResponse.self)
        }
    }
    
    func updateSMSResponse(_ response: SMSResponse) async throws {
        let responseData = try encodeToFirestore(response)
        try await db.collection(Collection.responses.path).document(response.id).updateData(responseData)
    }
    
    func deleteSMSResponse(_ responseId: String) async throws {
        try await db.collection(Collection.responses.path).document(responseId).delete()
    }
    
    // MARK: - Photo Storage Operations
    
    func uploadPhoto(_ photoData: Data, for responseId: String) async throws -> String {
        let storageRef = storage.reference()
        let photoRef = storageRef.child("responses/\(responseId)/photo.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await photoRef.putDataAsync(photoData, metadata: metadata)
        let downloadURL = try await photoRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func deletePhoto(at url: String) async throws {
        let photoRef = storage.reference(forURL: url)
        try await photoRef.delete()
    }
    
    // MARK: - Real-time Listeners
    
    func observeUserTasks(_ userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()
        
        let listener = db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .order(by: "nextScheduledDate")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                do {
                    let tasks = try documents.map { document in
                        try self.decodeFromFirestore(document.data(), as: Task.self)
                    }
                    subject.send(tasks)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }
        
        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }
    
    func observeUserProfiles(_ userId: String) -> AnyPublisher<[ElderlyProfile], Error> {
        let subject = PassthroughSubject<[ElderlyProfile], Error>()
        
        let listener = db.collection(Collection.profiles.path)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                do {
                    let profiles = try documents.map { document in
                        try self.decodeFromFirestore(document.data(), as: ElderlyProfile.self)
                    }
                    subject.send(profiles)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }
        
        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }
    
    // MARK: - Analytics and Reporting
    
    func getTaskCompletionStats(for userId: String, from startDate: Date, to endDate: Date) async throws -> TaskCompletionStats {
        let tasksSnapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("nextScheduledDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        let completedSnapshot = try await db.collection(Collection.responses.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("isCompleted", isEqualTo: true)
            .whereField("receivedAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("receivedAt", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        let totalTasks = tasksSnapshot.documents.count
        let completedTasks = completedSnapshot.documents.count
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        return TaskCompletionStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            completionRate: completionRate,
            averageResponseTime: 0, // Placeholder
            streakCount: 0, // Placeholder
            categoryBreakdown: [:], // Placeholder
            dailyCompletion: [:], // Placeholder
            responseTypeBreakdown: [:] // Placeholder
        )
    }
    
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics {
        // Placeholder implementation
        return ProfileAnalytics(
            profileId: profileId,
            totalTasks: 0,
            completedTasks: 0,
            averageResponseTime: 0,
            lastActiveDate: nil,
            responseRate: 0,
            preferredResponseType: nil,
            bestPerformingCategory: nil,
            worstPerformingCategory: nil,
            weeklyTrend: []
        )
    }
    
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics {
        // Placeholder implementation
        return UserAnalytics(
            userId: userId,
            totalProfiles: 0,
            activeProfiles: 0,
            totalTasks: 0,
            overallCompletionRate: 0,
            profileAnalytics: [],
            subscriptionUsage: SubscriptionUsage(
                planType: "trial",
                profilesUsed: 0,
                profilesLimit: 4,
                tasksCreated: 0,
                smssSent: 0,
                storageUsed: 0,
                billingPeriodStart: Date(),
                billingPeriodEnd: Date()
            ),
            generatedAt: Date()
        )
    }
    
    // MARK: - Batch Operations
    
    func batchUpdateTasks(_ tasks: [Task]) async throws {
        let batch = db.batch()
        
        for task in tasks {
            let taskData = try encodeToFirestore(task)
            let taskRef = db.collection(Collection.tasks.path).document(task.id)
            batch.updateData(taskData, forDocument: taskRef)
        }
        
        try await batch.commit()
    }
    
    func batchDeleteTasks(_ taskIds: [String]) async throws {
        let batch = db.batch()
        
        for taskId in taskIds {
            let taskRef = db.collection(Collection.tasks.path).document(taskId)
            batch.deleteDocument(taskRef)
        }
        
        try await batch.commit()
    }
    
    func batchCreateSMSResponses(_ responses: [SMSResponse]) async throws {
        let batch = db.batch()
        
        for response in responses {
            let responseData = try encodeToFirestore(response)
            let responseRef = db.collection(Collection.responses.path).document(response.id)
            batch.setData(responseData, forDocument: responseRef)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Search and Filtering
    
    func searchTasks(query: String, userId: String) async throws -> [Task] {
        // Placeholder implementation - Firestore doesn't support full text search natively
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            let task = try decodeFromFirestore(document.data(), as: Task.self)
            return task.title.lowercased().contains(query.lowercased()) ? task : nil
        }
    }
    
    func getTasksByCategory(_ category: TaskCategory, userId: String) async throws -> [Task] {
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("category", isEqualTo: category.rawValue)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getTasksByStatus(_ status: TaskStatus, userId: String) async throws -> [Task] {
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: status.rawValue)
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getOverdueTasks(for userId: String) async throws -> [Task] {
        let now = Date()
        let snapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: TaskStatus.active.rawValue)
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: now))
            .getDocuments()
        
        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    // MARK: - Data Synchronization
    
    func syncUserData(for userId: String) async throws {
        // Placeholder implementation
        print("Syncing user data for: \(userId)")
    }
    
    func getLastSyncTimestamp(for userId: String) async throws -> Date? {
        let document = try await db.collection(Collection.users.path).document(userId).getDocument()
        guard let data = document.data(),
              let timestamp = data["lastSyncTimestamp"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }
    
    func updateSyncTimestamp(for userId: String, timestamp: Date) async throws {
        try await db.collection(Collection.users.path).document(userId).updateData([
            "lastSyncTimestamp": Timestamp(date: timestamp)
        ])
    }
    
    // MARK: - Backup and Export
    
    func exportUserData(for userId: String) async throws -> UserDataExport {
        let user = try await getUser(userId)
        let profiles = try await getElderlyProfiles(for: userId)
        let tasks = try await getTasks(for: userId)
        let responses = try await getRecentSMSResponses(for: userId, limit: 1000)
        let analytics = try await getUserAnalytics(for: userId)
        
        return UserDataExport(
            userId: userId,
            user: user ?? User(id: userId, email: "", fullName: "", phoneNumber: "", createdAt: Date(), isOnboardingComplete: false, subscriptionStatus: .trial, trialEndDate: nil, quizAnswers: nil),
            profiles: profiles,
            tasks: tasks,
            responses: responses,
            analytics: analytics
        )
    }
    
    func importUserData(_ data: UserDataExport, for userId: String) async throws {
        // Placeholder implementation
        print("Importing user data for: \(userId)")
    }
    
    // MARK: - Helper Methods
    
    private func updateUserProfileCount(_ userId: String) async throws {
        let profilesSnapshot = try await db.collection(Collection.profiles.path)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let profileCount = profilesSnapshot.documents.count
        
        try await db.collection(Collection.users.path).document(userId).updateData([
            "profileCount": profileCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    private func updateUserTaskCount(_ userId: String) async throws {
        let tasksSnapshot = try await db.collection(Collection.tasks.path)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let taskCount = tasksSnapshot.documents.count
        
        try await db.collection(Collection.users.path).document(userId).updateData([
            "taskCount": taskCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeToFirestore<T: Codable>(_ object: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(object)
        let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dictionary ?? [:]
    }
    
    private func decodeFromFirestore<T: Codable>(_ data: [String: Any], as type: T.Type) throws -> T {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(type, from: jsonData)
    }
    
    deinit {
        // Remove all listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// Using DatabaseError from DatabaseServiceProtocol.swift

// MARK: - Time Range Helper
enum FirebaseTimeRange {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case custom(Date, Date)
    
    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
            
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
            return (startOfYear, endOfYear)
            
        case .custom(let start, let end):
            return (start, end)
        }
    }
}