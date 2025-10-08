import Foundation
import Combine

// MARK: - Mock Database Service
class MockDatabaseService: DatabaseServiceProtocol {
    
    // MARK: - Mock Data Storage
    private var mockUsers: [String: User] = [:]
    private var mockProfiles: [String: ElderlyProfile] = [:]
    private var mockTasks: [String: Task] = [:]
    private var mockResponses: [String: SMSResponse] = [:]
    private var mockGalleryEvents: [String: GalleryHistoryEvent] = [:]

    init() {
        // No hardcoded data - all data must be created dynamically at runtime
    }

    
    // MARK: - User Operations
    func createUser(_ user: User) async throws {
        mockUsers[user.id] = user
        print("📦 Mock: Created user \(user.fullName)")
    }
    
    func getUser(_ userId: String) async throws -> User? {
        return mockUsers[userId]
    }
    
    func updateUser(_ user: User) async throws {
        mockUsers[user.id] = user
        print("📦 Mock: Updated user \(user.fullName)")
    }
    
    func deleteUser(_ userId: String) async throws {
        mockUsers.removeValue(forKey: userId)
        // Also clean up related data
        mockProfiles = mockProfiles.filter { $0.value.userId != userId }
        mockTasks = mockTasks.filter { $0.value.userId != userId }
        mockResponses = mockResponses.filter { $0.value.userId != userId }
        print("📦 Mock: Deleted user and related data")
    }
    
    // MARK: - Profile Operations
    func createElderlyProfile(_ profile: ElderlyProfile) async throws {
        mockProfiles[profile.id] = profile
        print("📦 Mock: Created profile for \(profile.name)")
    }
    
    func getElderlyProfile(_ profileId: String) async throws -> ElderlyProfile? {
        return mockProfiles[profileId]
    }
    
    func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile] {
        return mockProfiles.values.filter { $0.userId == userId }.sorted { $0.createdAt < $1.createdAt }
    }
    
    func updateElderlyProfile(_ profile: ElderlyProfile) async throws {
        mockProfiles[profile.id] = profile
        print("📦 Mock: Updated profile for \(profile.name)")
    }
    
    func deleteElderlyProfile(_ profileId: String) async throws {
        mockProfiles.removeValue(forKey: profileId)
        // Clean up related tasks and responses
        mockTasks = mockTasks.filter { $0.value.profileId != profileId }
        mockResponses = mockResponses.filter { $0.value.profileId != profileId }
        print("📦 Mock: Deleted profile and related data")
    }
    
    func getConfirmedProfiles(for userId: String) async throws -> [ElderlyProfile] {
        return mockProfiles.values.filter { profile in
            profile.userId == userId && profile.status == .confirmed
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Gallery History Event Operations
    func createGalleryHistoryEvent(_ event: GalleryHistoryEvent) async throws {
        mockGalleryEvents[event.id] = event
        print("📦 Mock: Created gallery history event for profile \(event.profileId)")
    }
    
    func getGalleryHistoryEvents(for userId: String) async throws -> [GalleryHistoryEvent] {
        return mockGalleryEvents.values.filter { event in
            event.userId == userId
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Task Operations
    func createTask(_ task: Task) async throws {
        mockTasks[task.id] = task
        print("📦 Mock: Created task '\(task.title)'")
    }
    
    func getTask(_ taskId: String) async throws -> Task? {
        return mockTasks[taskId]
    }
    
    func getProfileTasks(_ profileId: String) async throws -> [Task] {
        return mockTasks.values.filter { $0.profileId == profileId }.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    func getTasks(for userId: String) async throws -> [Task] {
        return mockTasks.values.filter { $0.userId == userId }.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    func getTasks(for profileId: String, userId: String) async throws -> [Task] {
        return mockTasks.values.filter { $0.profileId == profileId && $0.userId == userId }
    }
    
    func getTasksScheduledFor(date: Date, userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return mockTasks.values.filter { task in
            task.userId == userId &&
            task.nextScheduledDate >= startOfDay &&
            task.nextScheduledDate < endOfDay
        }
    }
    
    func getTodaysTasks(_ userId: String) async throws -> [Task] {
        return try await getTasksScheduledFor(date: Date(), userId: userId)
    }
    
    func getActiveTasks(for userId: String) async throws -> [Task] {
        return mockTasks.values.filter { $0.userId == userId && $0.status == .active }
    }
    
    func updateTask(_ task: Task) async throws {
        mockTasks[task.id] = task
        print("📦 Mock: Updated task '\(task.title)'")
    }
    
    func deleteTask(_ taskId: String, userId: String, profileId: String) async throws {
        mockTasks.removeValue(forKey: taskId)
        mockResponses = mockResponses.filter { $0.value.taskId != taskId }
        print("📦 Mock: Deleted task and related responses (userId: \(userId), profileId: \(profileId))")
    }
    
    func archiveTask(_ taskId: String) async throws {
        if var task = mockTasks[taskId] {
            task.status = .archived
            mockTasks[taskId] = task
            print("📦 Mock: Archived task")
        }
    }
    
    // MARK: - SMS Response Operations
    func createSMSResponse(_ response: SMSResponse) async throws {
        mockResponses[response.id] = response
        print("📦 Mock: Created SMS response")
    }
    
    func getSMSResponse(_ responseId: String) async throws -> SMSResponse? {
        return mockResponses[responseId]
    }
    
    func getSMSResponses(for taskId: String) async throws -> [SMSResponse] {
        return mockResponses.values.filter { $0.taskId == taskId }.sorted { $0.receivedAt > $1.receivedAt }
    }
    
    func getSMSResponses(for profileId: String, userId: String) async throws -> [SMSResponse] {
        return mockResponses.values.filter { $0.profileId == profileId && $0.userId == userId }
    }
    
    func getSMSResponses(for userId: String, date: Date) async throws -> [SMSResponse] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        let responses = mockResponses.values.filter { response in
            response.userId == userId &&
            response.receivedAt >= startOfDay &&
            response.receivedAt < endOfDay
        }
        print("📦 Mock: getSMSResponses for userId \(userId) on \(date) - found \(responses.count) responses")
        for response in responses {
            print("📦 Mock: Response for task \(response.taskId ?? "nil") - completed: \(response.isCompleted)")
        }
        return responses
    }
    
    func getRecentSMSResponses(for userId: String, limit: Int) async throws -> [SMSResponse] {
        return Array(mockResponses.values.filter { $0.userId == userId }
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(limit))
    }
    
    func getConfirmationResponses(for profileId: String) async throws -> [SMSResponse] {
        return mockResponses.values.filter { $0.profileId == profileId && $0.isConfirmationResponse }
    }
    
    func getCompletedResponsesWithPhotos() async throws -> [SMSResponse] {
        return mockResponses.values.filter { $0.isCompleted && $0.hasPhotoResponse }
    }
    
    func updateSMSResponse(_ response: SMSResponse) async throws {
        mockResponses[response.id] = response
        print("📦 Mock: Updated SMS response")
    }
    
    func deleteSMSResponse(_ responseId: String) async throws {
        mockResponses.removeValue(forKey: responseId)
        print("📦 Mock: Deleted SMS response")
    }
    
    // MARK: - Photo Storage Operations
    func uploadPhoto(_ photoData: Data, for responseId: String) async throws -> String {
        // Return a dynamic mock URL using the responseId
        return "mock://storage/\(responseId)/\(UUID().uuidString).jpg"
    }
    
    func deletePhoto(at url: String) async throws {
        print("📦 Mock: Deleted photo at \(url)")
    }
    
    // MARK: - Real-time Listeners (Mock Publishers)
    func observeUserTasks(_ userId: String) -> AnyPublisher<[Task], Error> {
        let tasks = mockTasks.values.filter { $0.userId == userId }
        return Just(Array(tasks))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func observeUserProfiles(_ userId: String) -> AnyPublisher<[ElderlyProfile], Error> {
        let profiles = mockProfiles.values.filter { $0.userId == userId }
        return Just(Array(profiles))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Analytics (Mock Data)
    func getTaskCompletionStats(for userId: String, from startDate: Date, to endDate: Date) async throws -> TaskCompletionStats {
        // Calculate actual stats from stored data
        let userTasks = mockTasks.values.filter { $0.userId == userId }
        let completedTasks = userTasks.filter { $0.completionCount > 0 }

        return TaskCompletionStats(
            totalTasks: userTasks.count,
            completedTasks: completedTasks.count,
            completionRate: userTasks.isEmpty ? 0 : Double(completedTasks.count) / Double(userTasks.count),
            averageResponseTime: 0,
            streakCount: 0,
            categoryBreakdown: [:],
            dailyCompletion: [:],
            responseTypeBreakdown: [:]
        )
    }

    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics {
        // Calculate actual analytics from stored data
        let profileTasks = mockTasks.values.filter { $0.profileId == profileId && $0.userId == userId }
        let completedTasks = profileTasks.filter { $0.completionCount > 0 }
        let profile = mockProfiles[profileId]

        return ProfileAnalytics(
            profileId: profileId,
            totalTasks: profileTasks.count,
            completedTasks: completedTasks.count,
            averageResponseTime: 0,
            lastActiveDate: profile?.lastActiveAt ?? Date(),
            responseRate: profileTasks.isEmpty ? 0 : Double(completedTasks.count) / Double(profileTasks.count),
            preferredResponseType: .text,
            bestPerformingCategory: nil,
            worstPerformingCategory: nil,
            weeklyTrend: []
        )
    }

    func getUserAnalytics(for userId: String) async throws -> UserAnalytics {
        // Calculate actual analytics from stored data
        let profiles = mockProfiles.values.filter { $0.userId == userId }
        let tasks = mockTasks.values.filter { $0.userId == userId }
        let responses = mockResponses.values.filter { $0.userId == userId }

        return UserAnalytics(
            userId: userId,
            totalProfiles: profiles.count,
            activeProfiles: profiles.filter { $0.status == .confirmed }.count,
            totalTasks: tasks.count,
            overallCompletionRate: 0,
            profileAnalytics: [],
            subscriptionUsage: SubscriptionUsage(
                planType: "trial",
                profilesUsed: profiles.count,
                profilesLimit: 4,
                tasksCreated: tasks.count,
                smssSent: responses.count,
                storageUsed: 0,
                billingPeriodStart: Date(),
                billingPeriodEnd: Date()
            ),
            generatedAt: Date()
        )
    }
    
    // MARK: - Additional Mock Methods
    func getOverdueTasks(for userId: String) async throws -> [Task] {
        let now = Date()
        return mockTasks.values.filter { 
            $0.userId == userId && 
            $0.status == .active && 
            $0.nextScheduledDate < now 
        }
    }
    
    func searchTasks(query: String, userId: String) async throws -> [Task] {
        return mockTasks.values.filter { 
            $0.userId == userId && 
            $0.title.lowercased().contains(query.lowercased()) 
        }
    }
    
    func getTasksByCategory(_ category: TaskCategory, userId: String) async throws -> [Task] {
        return mockTasks.values.filter { $0.userId == userId && $0.category == category }
    }
    
    func getTasksByStatus(_ status: TaskStatus, userId: String) async throws -> [Task] {
        return mockTasks.values.filter { $0.userId == userId && $0.status == status }
    }
    
    // MARK: - Batch Operations (Mock)
    func batchUpdateTasks(_ tasks: [Task]) async throws {
        for task in tasks {
            mockTasks[task.id] = task
        }
        print("📦 Mock: Batch updated \(tasks.count) tasks")
    }
    
    func batchDeleteTasks(_ taskIds: [String]) async throws {
        for taskId in taskIds {
            mockTasks.removeValue(forKey: taskId)
        }
        print("📦 Mock: Batch deleted \(taskIds.count) tasks")
    }
    
    func batchCreateSMSResponses(_ responses: [SMSResponse]) async throws {
        for response in responses {
            mockResponses[response.id] = response
        }
        print("📦 Mock: Batch created \(responses.count) SMS responses")
    }
    
    // MARK: - Sync Operations (Mock)
    func syncUserData(for userId: String) async throws {
        print("📦 Mock: Synced user data for \(userId)")
    }

    func getLastSyncTimestamp(for userId: String) async throws -> Date? {
        return nil // No hardcoded timestamp
    }
    
    func updateSyncTimestamp(for userId: String, timestamp: Date) async throws {
        print("📦 Mock: Updated sync timestamp for \(userId)")
    }
    
    // MARK: - Export Operations (Mock)
    func exportUserData(for userId: String) async throws -> UserDataExport {
        let user = mockUsers[userId]
        let profiles = mockProfiles.values.filter { $0.userId == userId }
        let tasks = mockTasks.values.filter { $0.userId == userId }
        let responses = mockResponses.values.filter { $0.userId == userId }
        let analytics = try await getUserAnalytics(for: userId)

        // Return nil user if not found - no hardcoded fallback
        guard let user = user else {
            throw NSError(domain: "MockDatabaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }

        return UserDataExport(
            userId: userId,
            user: user,
            profiles: Array(profiles),
            tasks: Array(tasks),
            responses: Array(responses),
            analytics: analytics
        )
    }
    
    func importUserData(_ data: UserDataExport, for userId: String) async throws {
        print("📦 Mock: Imported user data for \(userId)")
    }
}