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
    
    private var hasInitialized = false
    
    init() {
        // Create mock data only once
        if !hasInitialized {
            createMockData()
            hasInitialized = true
        }
    }
    
    private func createMockData() {
        // Mock users
        let mockUser = User(
            id: "mock-user-id",
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
            userId: "mock-user-id",
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
            confirmedAt: Date(),
            lastCompletionDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Completed yesterday
        )
        mockProfiles[mockProfile.id] = mockProfile
        
        // Mock tasks
        let now = Date()
        
        // 1. UPCOMING TASK - Evening medication (scheduled for later today)
        let upcomingTask = Task(
            id: "mock-task-upcoming",
            userId: "mock-user-id",
            profileId: "mock-profile-1",
            title: "Take Evening Medication",
            description: "Take blood pressure medication with dinner",
            category: .health,
            frequency: .daily,
            scheduledTime: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now,
            startDate: Calendar.current.startOfDay(for: now),
            nextScheduledDate: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        )
        mockTasks[upcomingTask.id] = upcomingTask
        
        // 2. COMPLETED TASK - Exercise walk (completed earlier today)
        var completedTask = Task(
            id: "mock-task-completed",
            userId: "mock-user-id",
            profileId: "mock-profile-1",
            title: "Daily Walk",
            description: "Take a 15-minute walk around the neighborhood",
            category: .exercise,
            frequency: .daily,
            scheduledTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now,
            startDate: Calendar.current.startOfDay(for: now),
            nextScheduledDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        )
        completedTask.lastCompletedAt = Calendar.current.date(byAdding: .hour, value: -2, to: now)
        completedTask.completionCount = 1
        mockTasks[completedTask.id] = completedTask
        
        // 3. ORIGINAL TASK - Keep for gallery responses
        var originalTask = Task(
            id: "mock-task-1",
            userId: "mock-user-id",
            profileId: "mock-profile-1",
            title: "Check Blood Pressure",
            description: "Use home blood pressure monitor",
            category: .health,
            frequency: .daily,
            scheduledTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now,
            startDate: Calendar.current.startOfDay(for: now),
            nextScheduledDate: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        )
        originalTask.lastCompletedAt = Calendar.current.date(byAdding: .hour, value: -4, to: now)
        originalTask.completionCount = 1
        mockTasks[originalTask.id] = originalTask
        
        // Create simple mock data for gallery demonstration
        createSimpleMockGalleryData()
    }
    
    private func createSimpleMockGalleryData() {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. ONE TEXT MOCKUP - Simple medication reminder response
        let textResponse = SMSResponse(
            id: "mock-text-response",
            taskId: "mock-task-1",
            profileId: "mock-profile-1",
            userId: "mock-user-id",
            textResponse: "Done! Feeling good today",
            photoData: nil,
            isCompleted: true,
            receivedAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
            responseType: .text,
            isConfirmationResponse: false,
            isPositiveConfirmation: true,
            responseScore: 0.9,
            processingNotes: nil
        )
        mockResponses[textResponse.id] = textResponse
        
        // 2. ONE PICTURE MOCKUP - Exercise photo response  
        let photoResponse = SMSResponse(
            id: "mock-photo-response",
            taskId: "mock-task-1", 
            profileId: "mock-profile-1",
            userId: "mock-user-id",
            textResponse: nil,
            photoData: Data("mock-photo-data".utf8), // Placeholder photo data
            isCompleted: true,
            receivedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            responseType: .photo,
            isConfirmationResponse: false,
            isPositiveConfirmation: true,
            responseScore: 1.0,
            processingNotes: nil
        )
        mockResponses[photoResponse.id] = photoResponse
        
        // 3. ONE TASK MOCKUP - Combined text and photo response
        let taskResponse = SMSResponse(
            id: "mock-task-response",
            taskId: "mock-task-1",
            profileId: "mock-profile-1", 
            userId: "mock-user-id",
            textResponse: "Completed my walk around the block",
            photoData: Data("mock-task-photo".utf8),
            isCompleted: true,
            receivedAt: calendar.date(byAdding: .hour, value: -4, to: now) ?? now,
            responseType: .both,
            isConfirmationResponse: false,
            isPositiveConfirmation: true,
            responseScore: 1.0,
            processingNotes: nil
        )
        mockResponses[taskResponse.id] = taskResponse
        
        // 4. Convert responses to gallery events
        // NOTE: Modified task IDs to avoid duplicates while keeping gallery content
        
        // Text event - no taskId, just a general message
        let textEvent = GalleryHistoryEvent.fromSMSResponse(textResponse)
        mockGalleryEvents[textEvent.id] = textEvent
        
        // Photo event - create new response with unique taskId for gallery
        let photoResponseForGallery = SMSResponse(
            id: "mock-gallery-photo",
            taskId: "gallery-photo-task", // Unique ID for gallery only
            profileId: photoResponse.profileId,
            userId: photoResponse.userId,
            textResponse: photoResponse.textResponse,
            photoData: photoResponse.photoData,
            isCompleted: photoResponse.isCompleted,
            receivedAt: photoResponse.receivedAt,
            responseType: photoResponse.responseType,
            isConfirmationResponse: photoResponse.isConfirmationResponse,
            isPositiveConfirmation: photoResponse.isPositiveConfirmation,
            responseScore: photoResponse.responseScore,
            processingNotes: photoResponse.processingNotes
        )
        let photoEvent = GalleryHistoryEvent.fromSMSResponse(photoResponseForGallery) 
        mockGalleryEvents[photoEvent.id] = photoEvent
        
        // Task event - create new response with unique taskId for gallery
        let taskResponseForGallery = SMSResponse(
            id: "mock-gallery-combined",
            taskId: "gallery-combined-task", // Unique ID for gallery only
            profileId: taskResponse.profileId,
            userId: taskResponse.userId,
            textResponse: taskResponse.textResponse,
            photoData: taskResponse.photoData,
            isCompleted: taskResponse.isCompleted,
            receivedAt: taskResponse.receivedAt,
            responseType: taskResponse.responseType,
            isConfirmationResponse: taskResponse.isConfirmationResponse,
            isPositiveConfirmation: taskResponse.isPositiveConfirmation,
            responseScore: taskResponse.responseScore,
            processingNotes: taskResponse.processingNotes
        )
        let taskEvent = GalleryHistoryEvent.fromSMSResponse(taskResponseForGallery)
        mockGalleryEvents[taskEvent.id] = taskEvent
        
        // 4. CREATE RESPONSES FOR NEW DASHBOARD TASKS
        // Response for completed "Daily Walk" task
        let walkResponse = SMSResponse(
            id: "mock-walk-response",
            taskId: "mock-task-completed",
            profileId: "mock-profile-1", 
            userId: "mock-user-id",
            textResponse: "Just finished my walk! Feeling energized",
            photoData: nil,
            isCompleted: true,
            receivedAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
            responseType: .text,
            isConfirmationResponse: false,
            isPositiveConfirmation: true,
            responseScore: 1.0,
            processingNotes: nil
        )
        mockResponses[walkResponse.id] = walkResponse
        
        // Convert walk response to gallery event
        let walkEvent = GalleryHistoryEvent.fromSMSResponse(walkResponse)
        mockGalleryEvents[walkEvent.id] = walkEvent
        
        // Response for completed "Check Blood Pressure" task  
        let bpResponse = SMSResponse(
            id: "mock-bp-response",
            taskId: "mock-task-1",
            profileId: "mock-profile-1",
            userId: "mock-user-id", 
            textResponse: "Blood pressure checked: 120/80",
            photoData: nil,
            isCompleted: true,
            receivedAt: calendar.date(byAdding: .hour, value: -4, to: now) ?? now,
            responseType: .text,
            isConfirmationResponse: false,
            isPositiveConfirmation: true,
            responseScore: 1.0,
            processingNotes: nil
        )
        mockResponses[bpResponse.id] = bpResponse
        
        // Convert BP response to gallery event
        let bpEvent = GalleryHistoryEvent.fromSMSResponse(bpResponse)
        mockGalleryEvents[bpEvent.id] = bpEvent
        
        // 5. ONE PROFILE MOCKUP - Add profile creation event  
        if let profile = mockProfiles["mock-profile-1"] {
            let profileEvent = GalleryHistoryEvent.fromProfileCreation(
                userId: "mock-user-id",
                profile: profile,
                profileSlot: 0
            )
            mockGalleryEvents[profileEvent.id] = profileEvent
        }
        
        // ADDITIONAL MOCK EVENTS TO TRIPLE GALLERY CONTENT
        
        // Text responses
        let textResponses = [
            ("text-1", "Took medication at 8:30 AM", -5),
            ("text-2", "Blood pressure is 120/80", -6),
            ("text-3", "Feeling great today!", -7),
            ("text-4", "Completed stretching exercises", -8),
            ("text-5", "Had a good breakfast", -9),
            ("text-6", "Went to doctor appointment", -10)
        ]
        
        for (suffix, message, hoursAgo) in textResponses {
            let response = SMSResponse(
                id: "mock-text-\(suffix)",
                taskId: "gallery-text-\(suffix)",
                profileId: "mock-profile-1",
                userId: "mock-user-id",
                textResponse: message,
                photoData: nil,
                isCompleted: true,
                receivedAt: calendar.date(byAdding: .hour, value: hoursAgo, to: now) ?? now,
                responseType: .text,
                isConfirmationResponse: false,
                isPositiveConfirmation: true,
                responseScore: 0.9,
                processingNotes: nil
            )
            mockResponses[response.id] = response
            let event = GalleryHistoryEvent.fromSMSResponse(response)
            mockGalleryEvents[event.id] = event
        }
        
        // Photo responses
        let photoResponses = [
            ("photo-1", -11),
            ("photo-2", -12),
            ("photo-3", -13),
            ("photo-4", -14),
            ("photo-5", -15),
            ("photo-6", -16)
        ]
        
        for (suffix, hoursAgo) in photoResponses {
            let response = SMSResponse(
                id: "mock-photo-\(suffix)",
                taskId: "gallery-photo-\(suffix)",
                profileId: "mock-profile-1",
                userId: "mock-user-id",
                textResponse: nil,
                photoData: Data("mock-photo-\(suffix)".utf8),
                isCompleted: true,
                receivedAt: calendar.date(byAdding: .hour, value: hoursAgo, to: now) ?? now,
                responseType: .photo,
                isConfirmationResponse: false,
                isPositiveConfirmation: true,
                responseScore: 1.0,
                processingNotes: nil
            )
            mockResponses[response.id] = response
            let event = GalleryHistoryEvent.fromSMSResponse(response)
            mockGalleryEvents[event.id] = event
        }
        
        // Mock data created silently
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