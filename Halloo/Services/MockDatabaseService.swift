import Foundation
import Combine

// MARK: - Mock Database Service
class MockDatabaseService: DatabaseServiceProtocol {
    
    // MARK: - Mock Data Storage
    private var mockUsers: [String: User] = [:]
    private var mockProfiles: [String: ElderlyProfile] = [:]
    private var mockTasks: [String: Task] = [:]
    private var mockResponses: [String: SMSResponse] = [:]
    
    init() {
        // Create some mock data
        createMockData()
    }
    
    private func createMockData() {
        // Mock users
        let mockUser = User(
            id: "mock-user-1",
            email: "test@example.com",
            fullName: "Test User",
            phoneNumber: "+1234567890",
            createdAt: Date(),
            isOnboardingComplete: true,
            subscriptionStatus: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())
        )
        mockUsers[mockUser.id] = mockUser
        
        // Mock elderly profiles
        let mockProfile = ElderlyProfile(
            id: "mock-profile-1",
            userId: "mock-user-1",
            name: "Grandma Smith",
            phoneNumber: "+1987654321",
            relationship: "Grandmother",
            isEmergencyContact: false,
            timeZone: TimeZone.current.identifier,
            notes: "Takes blood pressure medication",
            photoURL: nil,
            status: .confirmed,
            createdAt: Date(),
            lastActiveAt: Date(),
            confirmedAt: Date()
        )
        mockProfiles[mockProfile.id] = mockProfile
        
        // Mock tasks
        let mockTask = Task(
            id: "mock-task-1",
            userId: "mock-user-1",
            profileId: "mock-profile-1",
            title: "Take Morning Medication",
            description: "Take blood pressure medication with breakfast",
            category: .health,
            frequency: .daily,
            scheduledTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
            nextScheduledDate: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        )
        mockTasks[mockTask.id] = mockTask
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
    
    func deleteTask(_ taskId: String) async throws {
        mockTasks.removeValue(forKey: taskId)
        mockResponses = mockResponses.filter { $0.value.taskId != taskId }
        print("📦 Mock: Deleted task and related responses")
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
        
        return mockResponses.values.filter { response in
            response.userId == userId &&
            response.receivedAt >= startOfDay &&
            response.receivedAt < endOfDay
        }
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
        // Return a mock URL
        return "https://mock-storage.example.com/\(responseId).jpg"
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
        return TaskCompletionStats(
            totalTasks: 10,
            completedTasks: 8,
            completionRate: 0.8,
            averageResponseTime: 300,
            streakCount: 5,
            categoryBreakdown: [:],
            dailyCompletion: [:],
            responseTypeBreakdown: [:]
        )
    }
    
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics {
        return ProfileAnalytics(
            profileId: profileId,
            totalTasks: 5,
            completedTasks: 4,
            averageResponseTime: 250,
            lastActiveDate: Date(),
            responseRate: 0.8,
            preferredResponseType: .text,
            bestPerformingCategory: .health,
            worstPerformingCategory: nil,
            weeklyTrend: []
        )
    }
    
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics {
        return UserAnalytics(
            userId: userId,
            totalProfiles: 1,
            activeProfiles: 1,
            totalTasks: 10,
            overallCompletionRate: 0.8,
            profileAnalytics: [],
            subscriptionUsage: SubscriptionUsage(
                planType: "trial",
                profilesUsed: 1,
                profilesLimit: 4,
                tasksCreated: 10,
                smssSent: 5,
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
        return Date().addingTimeInterval(-3600) // 1 hour ago
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
        
        return UserDataExport(
            userId: userId,
            user: user ?? User(id: userId, email: "", fullName: "", phoneNumber: "", createdAt: Date(), isOnboardingComplete: false, subscriptionStatus: .trial, trialEndDate: nil),
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