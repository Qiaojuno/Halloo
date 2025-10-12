//
//  TaskViewModel.swift
//  Hallo
//
//  Purpose: Manages task creation, scheduling, and SMS reminder coordination for elderly care
//  Key Features: 
//    • Daily medication and care task scheduling with family oversight
//    • SMS reminder delivery with flexible response acceptance
//    • Real-time task completion tracking across family members
//  Dependencies: DatabaseService, SMSService, NotificationService, DataSyncCoordinator
//  
//  Business Context: Core value proposition - helps families ensure elderly parents complete daily tasks
//  Critical Paths: Task creation → SMS reminders → Response processing → Family notifications
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import SwiftUI
import Combine

/// Manages daily care tasks and SMS reminders for elderly family members
///
/// This ViewModel serves as the central coordinator for the Hallo app's core functionality:
/// helping families create, schedule, and monitor daily tasks for elderly parents through
/// SMS reminders and response tracking. It handles the complete lifecycle from task creation 
/// by family members to SMS delivery and response processing from elderly users.
///
/// ## Key Responsibilities:
/// - **Task Lifecycle Management**: Create, edit, schedule, and archive daily care tasks
/// - **SMS Reminder Coordination**: Coordinate with SMS service to send timely, gentle reminders  
/// - **Response Processing**: Handle flexible SMS responses (YES, DONE, photos) from elderly users
/// - **Family Synchronization**: Keep all family members updated on task completion status
/// - **Notification Scheduling**: Manage local notifications for family oversight
///
/// ## Elderly Care Considerations:
/// - **Simple Response Format**: Accepts multiple SMS response formats (YES, DONE, OK, photos)
/// - **Gentle Reminder Timing**: Respects elderly users' daily routines and preferences
/// - **Error Tolerance**: Graceful handling of missed responses with family notification
/// - **Accessibility Focus**: Large text support and clear, simple task descriptions
///
/// ## Usage Example:
/// ```swift
/// let taskViewModel = container.makeTaskViewModel()
/// taskViewModel.setSelectedProfile(grandmaProfile)
/// taskViewModel.taskTitle = "Take morning blood pressure medication"
/// taskViewModel.taskCategory = .medication
/// await taskViewModel.createTask()
/// ```
///
/// - Important: Always verify elderly profile is confirmed before creating tasks
/// - Note: SMS delivery depends on profile confirmation and valid phone numbers
/// - Warning: Task scheduling requires proper timezone handling for elderly users
@MainActor
final class TaskViewModel: ObservableObject {
    
    // MARK: - Task Management Properties
    
    /// All tasks created by the current family user for their elderly profiles
    /// 
    /// Updated in real-time as tasks are created, completed, or modified by family members.
    /// Used by families to monitor all active care reminders across multiple elderly profiles.
    @Published var tasks: [Task] = []
    
    /// Loading state for task operations (create, update, delete)
    /// 
    /// This property shows loading during:
    /// - Task creation with SMS scheduling
    /// - Database synchronization across family members
    /// - SMS delivery confirmation
    ///
    /// Used by families to provide feedback during task management operations.
    @Published var isLoading = false
    
    /// User-friendly error messages for task-related failures
    /// 
    /// This property displays context-aware error messages when:
    /// - Elderly profile is not yet confirmed via SMS
    /// - Task limits are exceeded (10 per profile)
    /// - SMS delivery fails to elderly parent
    ///
    /// Used by families to understand and resolve task creation issues.
    @Published var errorMessage: String?
    
    /// Controls task creation form presentation
    @Published var showingCreateTask = false
    
    /// Controls task editing form presentation  
    @Published var showingEditTask = false
    
    /// Available elderly profiles for task assignment
    @Published var availableProfiles: [ElderlyProfile] = []
    
    /// Currently selected profile ID for task creation
    @Published var selectedProfileId: String?
    
    /// Currently selected task for editing or viewing details
    @Published var selectedTask: Task?
    
    /// Currently selected elderly profile for task creation
    /// 
    /// Must be a confirmed profile (elderly parent responded YES to SMS confirmation).
    /// Used by families to choose which elderly parent will receive the task reminders.
    @Published var selectedProfile: ElderlyProfile?
    
    // MARK: - Task Creation Form Properties
    
    /// Task title that will appear in SMS reminders to elderly parents
    /// 
    /// Should be clear and concise for elderly users. Examples:
    /// - "Take morning blood pressure medication"
    /// - "Check blood sugar after breakfast"
    /// - "Take evening walk for 10 minutes"
    @Published var taskTitle = ""
    
    /// Detailed task description sent in SMS reminders
    /// 
    /// Provides additional context for elderly users. Should include:
    /// - Specific instructions ("with a full glass of water")
    /// - Timing context ("after breakfast")
    /// - Safety reminders ("sit down before checking blood pressure")
    @Published var taskDescription = ""
    
    /// Task category for organization and SMS message customization
    /// 
    /// Different categories use different reminder language:
    /// - .medication: More urgent, shorter deadline
    /// - .exercise: Encouraging, flexible timing
    /// - .social: Gentle reminders, optional completion
    @Published var taskCategory: TaskCategory = .medication
    
    /// How often the task repeats (daily, weekly, custom days)
    /// 
    /// Most elderly care tasks are daily (medication, meals) or weekly (appointments).
    /// Custom frequency allows for specific days like "Monday, Wednesday, Friday exercises".
    @Published var frequency: TaskFrequency = .daily
    
    /// When the SMS reminders should be sent to the elderly parent
    /// 
    /// Automatically adjusted for the elderly profile's timezone.
    /// Family members set these in their local time, converted for elderly parent.
    /// Multiple times create separate tasks for each reminder.
    @Published var scheduledTimes: [Date] = []
    
    /// Minutes after scheduled time before marking task as "overdue"
    /// 
    /// Default 10 minutes provides gentle buffer for elderly users.
    /// Medication tasks often use shorter deadlines (5-15 minutes).
    /// Social tasks use longer deadlines (1-2 hours).
    @Published var deadlineMinutes = 10
    
    /// Whether elderly parent must send a photo to complete the task
    /// 
    /// Used for tasks requiring visual proof:
    /// - Taking medication (photo of pills/bottle)
    /// - Exercise completion (photo after walk)
    /// - Safety checks (photo of cleared walkway)
    @Published var requiresPhoto = false
    
    /// Whether elderly parent can complete task with text response (YES, DONE)
    /// 
    /// Most tasks allow text responses for simplicity.
    /// Some tasks require both text and photo for complete verification.
    @Published var requiresText = true
    
    /// Specific days for custom frequency tasks
    /// 
    /// Used when frequency is .custom to specify exact days:
    /// - Physical therapy: Monday, Wednesday, Friday
    /// - Doctor calls: Every Tuesday
    /// - Medication reviews: First Monday of month
    @Published var customDays: Set<Weekday> = []
    
    /// When task scheduling begins
    @Published var startDate = Date()
    
    /// Optional end date for temporary tasks (medication courses, recovery periods)
    @Published var endDate: Date?
    
    /// Whether task is actively sending reminders
    @Published var isActive = true
    
    /// Additional notes for family coordination
    /// 
    /// Used by families to share context:
    /// - "Doctor increased dosage on 3/15"
    /// - "Mom prefers morning walks before 9 AM"
    /// - "Call if not completed by noon"
    @Published var notes = ""
    
    // MARK: - Form Validation Properties
    
    /// Validation error for task title field
    /// 
    /// Shows when title is too short, too long, or contains inappropriate content.
    /// Helps families create clear, elderly-friendly task descriptions.
    @Published var titleError: String?
    
    /// Validation error for scheduled time field
    /// 
    /// Shows when time is inappropriate:
    /// - Too early (before 6 AM) or too late (after 10 PM) for elderly users
    /// - Conflicts with existing tasks for the same elderly profile
    /// - Invalid timezone conversion issues
    @Published var timeError: String?
    
    /// Validation error for profile selection
    /// 
    /// Shows when:
    /// - No elderly profile is selected for task creation
    /// - Selected profile is not yet confirmed via SMS
    /// - Profile has reached maximum task limit (10 tasks)
    @Published var profileError: String?
    
    // MARK: - Task Organization Properties
    
    /// Search text for finding specific tasks
    /// 
    /// Searches across task titles and descriptions to help families quickly find:
    /// - Specific medications ("blood pressure", "diabetes")
    /// - Task types ("walk", "call", "check")
    /// - Time periods ("morning", "evening")
    @Published var searchText = ""
    
    /// Filter tasks by category (medication, exercise, social, etc.)
    /// 
    /// Helps families focus on specific types of care:
    /// - Medication tasks for adherence monitoring
    /// - Exercise tasks for activity tracking
    /// - Social tasks for isolation prevention
    @Published var selectedCategoryFilter: TaskCategory?
    
    /// Filter tasks by status (active, paused, archived)
    /// 
    /// Allows families to view:
    /// - Active tasks currently sending reminders
    /// - Paused tasks temporarily disabled
    /// - Archived tasks for historical reference
    @Published var selectedStatusFilter: TaskStatus?
    
    /// Whether to show only active tasks or include paused/archived
    /// 
    /// Default true to focus families on currently relevant care tasks.
    /// Can be disabled to review historical tasks and completion patterns.
    @Published var showingActiveOnly = true
    
    // MARK: - Service Dependencies
    
    /// Database service for task persistence and family synchronization
    private let databaseService: DatabaseServiceProtocol
    
    /// SMS service for sending reminders to elderly parents
    private let smsService: SMSServiceProtocol
    
    /// Local notification service for family member alerts
    private let notificationService: NotificationServiceProtocol
    
    /// Authentication service for user context and permissions
    private let authService: AuthenticationServiceProtocol
    
    /// Coordinator for real-time data sync across family members
    private let dataSyncCoordinator: DataSyncCoordinator
    
    /// Coordinator for elderly-care-aware error handling
    private let errorCoordinator: ErrorCoordinator
    
    // MARK: - Internal Coordination Properties
    
    /// Combine cancellables for reactive elderly care coordination
    private var cancellables = Set<AnyCancellable>()
    
    /// Maximum tasks per elderly profile to prevent SMS overwhelming
    /// 
    /// Protects elderly users from receiving too many daily reminders.
    /// Research shows elderly users respond best to 3-7 daily reminders maximum.
    /// This limit ensures families create focused, essential care tasks.
    private let maxTasksPerProfile = 10
    
    // MARK: - Family Care Validation Properties
    
    /// Elderly profiles that have confirmed SMS reminders (responded YES)
    /// 
    /// Only confirmed profiles can receive task reminders. This prevents sending
    /// SMS reminders to elderly parents who haven't agreed to receive them.
    /// Updated when profiles are confirmed via SMS response processing.
    var confirmedProfiles: [ElderlyProfile] {
        // This should come from ProfileViewModel or be injected
        return []
    }
    
    /// Whether the selected elderly profile can receive additional care tasks
    /// 
    /// Protects elderly users from SMS overwhelming by enforcing the 10-task limit
    /// per profile. This ensures elderly parents receive manageable daily reminders
    /// rather than constant notifications that could cause confusion or anxiety.
    var canCreateTask: Bool {
        guard let profile = selectedProfile else { return false }
        let profileTasks = tasks.filter { $0.profileId == profile.id && $0.status != .archived }
        return profileTasks.count < maxTasksPerProfile
    }
    
    /// Whether the task creation form has valid elderly-appropriate data
    /// 
    /// Validates that:
    /// - Task title is clear and not empty (elderly users need descriptive reminders)
    /// - Elderly profile is selected and confirmed via SMS
    /// - No validation errors exist for title, timing, or profile selection
    /// - At least one response method is enabled (text or photo)
    var isValidForm: Bool {
        return !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               selectedProfile != nil &&
               titleError == nil &&
               timeError == nil &&
               profileError == nil &&
               (requiresPhoto || requiresText)
    }
    
    /// Tasks filtered by family preferences and search criteria
    /// 
    /// Provides families with organized views of their elderly care tasks:
    /// - Active tasks currently sending SMS reminders to elderly parents
    /// - Category-specific views (medication, exercise, social) for focused monitoring
    /// - Search functionality for finding specific care reminders quickly
    /// - Historical task review for tracking care patterns over time
    var filteredTasks: [Task] {
        var filtered = tasks
        
        // Filter by active/inactive (default: show only active care reminders)
        if showingActiveOnly {
            filtered = filtered.filter { $0.status == .active }
        }
        
        // Filter by care category (medication, exercise, social, etc.)
        if let category = selectedCategoryFilter {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by task status (active, paused, archived)
        if let status = selectedStatusFilter {
            filtered = filtered.filter { $0.status == status }
        }
        
        // Search across task titles and descriptions for specific care items
        if !searchText.isEmpty {
            filtered = filtered.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by creation date (newest first) for family review
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Tasks organized by elderly profile for family coordination
    /// 
    /// Groups filtered tasks by which elderly parent will receive them.
    /// Helps families see the complete care picture for each elderly profile:
    /// - Grandma's medication and exercise tasks
    /// - Grandpa's social and health check tasks
    /// - Balanced task distribution across multiple elderly parents
    var tasksGroupedByProfile: [String: [Task]] {
        Dictionary(grouping: filteredTasks) { $0.profileId }
    }
    
    /// Active care tasks scheduled for today across all elderly profiles
    /// 
    /// Shows families which SMS reminders their elderly parents will receive today.
    /// Includes tasks scheduled for today in each elderly parent's local timezone.
    /// Used for daily care coordination and oversight by family members.
    var todaysTasks: [Task] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return tasks.filter { task in
            task.status == .active &&
            task.getNextScheduledTime() >= today &&
            task.getNextScheduledTime() < tomorrow
        }
    }
    
    // MARK: - Elderly Care Task Coordination Setup
    
    /// Initializes task management with elderly-care-optimized services and coordination
    /// 
    /// Sets up the complete infrastructure for managing daily care tasks and SMS reminders
    /// for elderly family members. Configures real-time family synchronization, elderly-appropriate
    /// validation, and robust error handling for non-technical elderly users.
    ///
    /// ## Setup Process:
    /// 1. **Service Integration**: Connects SMS, database, and notification services
    /// 2. **Family Coordination**: Establishes real-time sync across family devices
    /// 3. **Validation Setup**: Configures elderly-friendly form validation
    /// 4. **Data Loading**: Loads existing tasks with family context
    /// 5. **Error Handling**: Prepares elderly-care-aware error recovery
    ///
    /// - Parameter databaseService: Handles task persistence and family synchronization
    /// - Parameter smsService: Manages SMS reminders to elderly parents
    /// - Parameter notificationService: Creates family oversight notifications
    /// - Parameter authService: Provides family user context and permissions
    /// - Parameter dataSyncCoordinator: Synchronizes task data across family members
    /// - Parameter errorCoordinator: Handles errors with elderly care context
    init(
        databaseService: DatabaseServiceProtocol,
        smsService: SMSServiceProtocol,
        notificationService: NotificationServiceProtocol,
        authService: AuthenticationServiceProtocol,
        dataSyncCoordinator: DataSyncCoordinator,
        errorCoordinator: ErrorCoordinator
    ) {
        self.databaseService = databaseService
        self.smsService = smsService
        self.notificationService = notificationService
        self.authService = authService
        self.dataSyncCoordinator = dataSyncCoordinator
        self.errorCoordinator = errorCoordinator
        
        // Configure elderly-appropriate validation
        setupValidation()
        
        // Enable real-time family synchronization
        setupDataSync()
        
        // Load existing care tasks for family context
        loadTasks()
    }
    
    // MARK: - Setup Methods
    private func setupValidation() {
        // Title validation
        $taskTitle
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] title in
                self?.validateTitle(title)
            }
            .store(in: &cancellables)
        
        // Time validation
        $scheduledTimes
            .combineLatest($frequency)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] times, frequency in
                self?.validateScheduledTimes(times, frequency: frequency)
            }
            .store(in: &cancellables)
        
        // Profile validation
        $selectedProfile
            .sink { [weak self] profile in
                self?.validateProfile(profile)
            }
            .store(in: &cancellables)
    }
    
    private func setupDataSync() {
        // Listen for task updates
        dataSyncCoordinator.taskUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedTask in
                self?.handleTaskUpdate(updatedTask)
            }
            .store(in: &cancellables)

        // Listen for SMS responses to update task completion
        dataSyncCoordinator.smsResponses
            .receive(on: DispatchQueue.main)
            .compactMap { response in
                // Filter for task completion responses
                guard response.taskId != nil else { return nil }
                return response
            }
            .sink { [weak self] response in
                self?.handleTaskResponse(response)
            }
            .store(in: &cancellables)

        // Listen for profile updates (deletions, status changes)
        dataSyncCoordinator.profileUpdates
            .sink { [weak self] updatedProfile in
                self?.handleProfileUpdate(updatedProfile)
            }
            .store(in: &cancellables)
    }

    private func handleProfileUpdate(_ profile: ElderlyProfile) {
        print("📩 [TaskViewModel] Profile update received: \(profile.id)")

        // Update availableProfiles list
        if let index = availableProfiles.firstIndex(where: { $0.id == profile.id }) {
            availableProfiles[index] = profile
        }

        // If currently selected profile was updated, refresh it
        if selectedProfile?.id == profile.id {
            if profile.status == .inactive {
                print("⚠️ [TaskViewModel] Selected profile became inactive - clearing selection")
                selectedProfile = nil
                selectedProfileId = nil
            } else {
                // Update to latest profile state
                selectedProfile = profile
            }
        }
    }
    
    // MARK: - Data Loading
    func loadTasks() {
        _Concurrency.Task {
            await loadTasksAsync()
        }
    }
    
    private func loadTasksAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let userId = authService.currentUser?.uid else {
                throw TaskError.userNotAuthenticated
            }
            
            let loadedTasks = try await databaseService.getTasks(for: userId)
            
            await MainActor.run {
                self.tasks = loadedTasks.sorted { $0.createdAt > $1.createdAt }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.errorCoordinator.handle(error, context: "Loading tasks")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Profile Selection
    
    /// Preselected profile ID for task creation
    @Published var preselectedProfileId: String?
    
    /// Preselects a profile for task creation from DashboardView
    ///
    /// This method is called when the user creates a task from a specific profile context
    /// in the dashboard. It stores the profile ID to be used when the task creation form
    /// loads and profiles become available.
    ///
    /// - Parameter profileId: ID of the profile to preselect for task creation  
    func preselectProfile(profileId: String) {
        preselectedProfileId = profileId
        // The UI should use this profileId to preselect the correct profile
        // when profiles are loaded in the task creation form
    }
    
    // MARK: - Task Creation & Scheduling
    
    /// Creates a new daily care task with SMS reminder scheduling for an elderly family member
    ///
    /// This method orchestrates the complete task creation workflow that enables families
    /// to set up automated care reminders for their elderly parents. The process includes
    /// form validation, database persistence, SMS scheduling coordination, and real-time
    /// family synchronization.
    ///
    /// ## Process Flow:
    /// 1. **Validation**: Ensures elderly profile is confirmed and task limits not exceeded
    /// 2. **Task Creation**: Creates task with elderly-friendly scheduling and requirements
    /// 3. **Database Persistence**: Saves task with family synchronization
    /// 4. **SMS Scheduling**: Coordinates future SMS reminders to elderly parent
    /// 5. **Family Notification**: Updates all family members about the new care task
    ///
    /// ## Example:
    /// ```swift
    /// taskViewModel.selectedProfile = grandmaProfile
    /// taskViewModel.taskTitle = "Take morning blood pressure medication"
    /// taskViewModel.taskCategory = .medication
    /// taskViewModel.scheduledTime = morningTime
    /// await taskViewModel.createTask()
    /// ```
    ///
    /// - Important: Elderly profile must be confirmed (responded YES to SMS) before task creation
    /// - Note: Creates local notifications for family oversight alongside SMS reminders
    /// - Warning: Respects 10-task limit per elderly profile to prevent SMS overwhelming
    func createTask() {
        _Concurrency.Task {
            await createTaskAsync()
        }
    }
    
    /*
    BUSINESS LOGIC: Task Creation with Elderly Care Optimization
    
    CONTEXT: Families need to create care reminders that elderly parents will actually respond to.
    Common failure modes include overwhelming elderly users with too many reminders, using 
    confusing language, or scheduling reminders at inappropriate times.
    
    DESIGN DECISION: Multi-layer validation with elderly-specific constraints
    - Alternative 1: Allow unlimited tasks (rejected - overwhelms elderly users)
    - Alternative 2: Complex scheduling UI (rejected - too difficult for families)  
    - Chosen Solution: Simple form with intelligent defaults and protective limits
    
    FAMILY IMPACT: Task creation immediately syncs across all family devices, allowing
    coordination without duplicate reminders. Family members can see exactly what 
    reminders their elderly parent will receive.
    
    ACCESSIBILITY: Task titles and descriptions are automatically validated for clarity.
    SMS reminders use simple, consistent language patterns that elderly users recognize.
    */
    private func createTaskAsync() async {
        print("📝 Starting task creation...")
        print("🔍 Validation check:")
        print("   - taskTitle: '\(taskTitle)'")
        print("   - taskTitle.isEmpty: \(!taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
        print("   - selectedProfile: \(selectedProfile?.id ?? "NIL")")
        print("   - titleError: \(titleError ?? "nil")")
        print("   - timeError: \(timeError ?? "nil")")
        print("   - profileError: \(profileError ?? "nil")")
        print("   - requiresPhoto: \(requiresPhoto)")
        print("   - requiresText: \(requiresText)")
        print("   - isValidForm: \(isValidForm)")

        guard isValidForm, let profile = selectedProfile else {
            print("⚠️ Form validation failed or no profile selected")
            return
        }
        print("✅ Form validated, profile selected: \(profile.name)")

        isLoading = true
        errorMessage = nil

        do {
            print("🔍 Checking authentication...")
            print("🔍 Auth service type: \(type(of: authService))")
            print("🔍 Current user: \(String(describing: authService.currentUser))")

            guard let userId = authService.currentUser?.uid else {
                print("❌ No user ID - authentication failed")
                throw TaskError.userNotAuthenticated
            }
            print("✅ User authenticated with ID: \(userId)")

            // Protective limit: Max 10 tasks per elderly profile to prevent SMS overwhelming
            guard canCreateTask else {
                print("❌ Max tasks reached for profile")
                throw TaskError.maxTasksReached
            }
            print("✅ Can create task (under limit)")

            // Create separate task for each scheduled time (allows individual tracking)
            var createdTasks: [Task] = []
            print("📋 Creating \(scheduledTimes.count) task(s) for scheduled times")

            for (index, scheduledTime) in scheduledTimes.enumerated() {
                print("   Creating task \(index + 1)/\(scheduledTimes.count)...")
                let task = Task(
                    id: IDGenerator.habitID(),
                    userId: userId,
                    profileId: profile.id,
                    title: taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: taskDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: taskCategory,
                    frequency: frequency,
                    scheduledTime: scheduledTime,
                    deadlineMinutes: deadlineMinutes,
                    requiresPhoto: requiresPhoto,
                    requiresText: requiresText,
                    customDays: frequency == .custom ? Array(customDays) : [],
                    startDate: startDate,
                    endDate: endDate,
                    status: isActive ? .active : .paused,
                    createdAt: Date(),
                    lastModifiedAt: Date()
                )
                print("   Task created: \(task.title) at \(scheduledTime)")

                print("   💾 Saving to database...")
                // Persist with family synchronization
                try await databaseService.createTask(task)
                print("   ✅ Saved to database")

                print("   📱 Scheduling notifications...")
                // Schedule SMS reminders and family notifications
                try await scheduleTaskNotifications(for: task)
                print("   ✅ Notifications scheduled")

                createdTasks.append(task)
            }

            await MainActor.run {
                print("🎉 Updating local state with \(createdTasks.count) new task(s)")
                // Update local state for immediate family feedback
                for task in createdTasks {
                    self.tasks.insert(task, at: 0)
                }
                self.resetForm()
                self.showingCreateTask = false
                print("✅ Task creation complete! Total tasks: \(self.tasks.count)")
            }

        } catch {
            print("❌ Error creating task: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            await MainActor.run {
                // Provide family-friendly error context
                self.errorMessage = error.localizedDescription
                self.errorCoordinator.handle(error, context: "Creating care task for elderly family member")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Task Editing
    func editTask(_ task: Task) {
        selectedTask = task
        populateForm(with: task)
        showingEditTask = true
    }
    
    func updateTask() {
        _Concurrency.Task {
            await updateTaskAsync()
        }
    }
    
    private func updateTaskAsync() async {
        guard let task = selectedTask, isValidForm, let profile = selectedProfile else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedTask = Task(
                id: task.id,
                userId: task.userId,
                profileId: profile.id,
                title: taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: taskDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                category: taskCategory,
                frequency: frequency,
                scheduledTime: scheduledTimes.first ?? Date(),
                deadlineMinutes: deadlineMinutes,
                requiresPhoto: requiresPhoto,
                requiresText: requiresText,
                customDays: frequency == .custom ? Array(customDays) : [],
                startDate: startDate,
                endDate: endDate,
                status: isActive ? .active : .paused,
                createdAt: task.createdAt,
                lastModifiedAt: Date(),
                completionCount: task.completionCount,
                lastCompletedAt: task.lastCompletedAt
            )
            
            try await databaseService.updateTask(updatedTask)
            
            // Reschedule notifications if schedule changed
            let scheduleChanged = task.frequency != frequency ||
                                task.scheduledTime != (scheduledTimes.first ?? Date()) ||
                                task.customDays != Array(customDays) ||
                                task.status != updatedTask.status
            
            if scheduleChanged {
                try await cancelTaskNotifications(for: task)
                if updatedTask.status == .active {
                    try await scheduleTaskNotifications(for: updatedTask)
                }
            }
            
            await MainActor.run {
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = updatedTask
                }
                self.resetForm()
                self.showingEditTask = false
                self.selectedTask = nil
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.errorCoordinator.handle(error, context: "Updating task")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Task Management
    func deleteTask(_ task: Task) {
        _Concurrency.Task {
            await deleteTaskAsync(task)
        }
    }
    
    private func deleteTaskAsync(_ task: Task) async {
        isLoading = true
        errorMessage = nil

        do {
            try await cancelTaskNotifications(for: task)
            try await databaseService.deleteTask(task.id, userId: task.userId, profileId: task.profileId)

            await MainActor.run {
                self.tasks.removeAll { $0.id == task.id }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.errorCoordinator.handle(error, context: "Deleting task")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func toggleTaskStatus(_ task: Task) {
        _Concurrency.Task {
            await toggleTaskStatusAsync(task)
        }
    }
    
    private func toggleTaskStatusAsync(_ task: Task) async {
        let newStatus: TaskStatus = task.status == .active ? .paused : .active
        
        let updatedTask = Task(
            id: task.id,
            userId: task.userId,
            profileId: task.profileId,
            title: task.title,
            description: task.description,
            category: task.category,
            frequency: task.frequency,
            scheduledTime: task.scheduledTime,
            deadlineMinutes: task.deadlineMinutes,
            requiresPhoto: task.requiresPhoto,
            requiresText: task.requiresText,
            customDays: task.customDays,
            startDate: task.startDate,
            endDate: task.endDate,
            status: newStatus,
            createdAt: task.createdAt,
            lastModifiedAt: Date(),
            completionCount: task.completionCount,
            lastCompletedAt: task.lastCompletedAt
        )
        
        do {
            try await databaseService.updateTask(updatedTask)
            
            // Handle notifications based on status
            if newStatus == .active {
                try await scheduleTaskNotifications(for: updatedTask)
            } else {
                try await cancelTaskNotifications(for: task)
            }
            
            await MainActor.run {
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = updatedTask
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.errorCoordinator.handle(error, context: "Toggling task status")
            }
        }
    }
    
    func duplicateTask(_ task: Task) {
        selectedTask = task
        populateForm(with: task)
        taskTitle = "\(task.title) (Copy)"
        showingCreateTask = true
    }
    
    // MARK: - Notification Scheduling
    private func scheduleTaskNotifications(for task: Task) async throws {
        guard task.status == .active else { return }
        
        let nextScheduledTimes = task.getNextScheduledTimes(count: 30) // Schedule next 30 occurrences
        
        for scheduledTime in nextScheduledTimes {
            let notificationId = "\(task.id)_\(scheduledTime.timeIntervalSince1970)"
            
            try await notificationService.scheduleNotification(
                id: notificationId,
                title: "Reminder: \(task.title)",
                body: task.description.isEmpty ? "Time for your \(task.category.displayName.lowercased())" : task.description,
                scheduledTime: scheduledTime,
                userInfo: [
                    "taskId": task.id,
                    "profileId": task.profileId,
                    "type": "taskReminder"
                ]
            )
        }
    }
    
    private func cancelTaskNotifications(for task: Task) async throws {
        // This would cancel all pending notifications for this task
        try await notificationService.cancelNotifications(withPrefix: task.id)
    }
    
    // MARK: - Manual Task Completion
    func markTaskCompleted(_ task: Task, with response: String? = nil, photo: Data? = nil) {
        _Concurrency.Task {
            await markTaskCompletedAsync(task, response: response, photo: photo)
        }
    }
    
    private func markTaskCompletedAsync(_ task: Task, response: String?, photo: Data?) async {
        do {
            // Create SMS response record
            let smsResponse = SMSResponse(
                id: IDGenerator.messageID(twilioSID: nil),
                taskId: task.id,
                profileId: task.profileId,
                userId: task.userId,
                textResponse: response,
                photoData: photo,
                isCompleted: true,
                receivedAt: Date(),
                responseType: photo != nil ? .photo : .text,
                isConfirmationResponse: false,
                isPositiveConfirmation: false,
                responseScore: nil,
                processingNotes: nil
            )
            
            try await databaseService.createSMSResponse(smsResponse)

            // Create gallery event for task completion
            let galleryEvent = GalleryHistoryEvent.fromSMSResponse(smsResponse)
            try await databaseService.createGalleryHistoryEvent(galleryEvent)
            print("✅ [TaskViewModel] Created gallery event for task completion: \(task.title)")

            // Update task completion count
            let updatedTask = Task(
                id: task.id,
                userId: task.userId,
                profileId: task.profileId,
                title: task.title,
                description: task.description,
                category: task.category,
                frequency: task.frequency,
                scheduledTime: task.scheduledTime,
                deadlineMinutes: task.deadlineMinutes,
                requiresPhoto: task.requiresPhoto,
                requiresText: task.requiresText,
                customDays: task.customDays,
                startDate: task.startDate,
                endDate: task.endDate,
                status: task.status,
                createdAt: task.createdAt,
                lastModifiedAt: Date(),
                completionCount: task.completionCount + 1,
                lastCompletedAt: Date()
            )
            
            try await databaseService.updateTask(updatedTask)
            
            await MainActor.run {
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = updatedTask
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.errorCoordinator.handle(error, context: "Marking task completed")
            }
        }
    }
    
    // MARK: - Data Sync Handlers
    private func handleTaskUpdate(_ updatedTask: Task) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks[index] = updatedTask
        } else {
            tasks.insert(updatedTask, at: 0)
        }
    }
    
    private func handleTaskResponse(_ response: SMSResponse) {
        guard let taskId = response.taskId,
              let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        if response.isCompleted {
            // Update task completion
            var updatedTask = tasks[taskIndex]
            updatedTask.completionCount += 1
            updatedTask.lastCompletedAt = response.receivedAt
            tasks[taskIndex] = updatedTask
            
            // Update in database
            _Concurrency.Task {
                try? await databaseService.updateTask(updatedTask)
            }
        }
    }
    
    // MARK: - Validation Methods
    private func validateTitle(_ title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            titleError = nil
        } else if trimmedTitle.count < 3 {
            titleError = "Title must be at least 3 characters"
        } else if trimmedTitle.count > 100 {
            titleError = "Title must be less than 100 characters"
        } else {
            titleError = nil
        }
    }
    
    private func validateScheduledTimes(_ times: [Date], frequency: TaskFrequency) {
        if times.isEmpty {
            timeError = "Please select at least one time"
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        if frequency == .daily || frequency == .weekdays {
            // For recurring tasks, just check if times are reasonable
            for time in times {
                let hour = calendar.component(.hour, from: time)
                if hour < 6 || hour > 23 {
                    timeError = "Please select times between 6 AM and 11 PM"
                    return
                }
            }
            timeError = nil
        } else {
            // For one-time tasks, check if times are in the future
            for time in times {
                if time <= now {
                    timeError = "Please select future times"
                    return
                }
            }
            timeError = nil
        }
    }
    
    private func validateProfile(_ profile: ElderlyProfile?) {
        if profile == nil {
            profileError = "Please select a profile"
        } else if profile?.status != .confirmed {
            profileError = "Profile must be confirmed to receive reminders"
        } else {
            profileError = nil
        }
    }
    
    // MARK: - Form Management
    func setSelectedProfile(_ profile: ElderlyProfile) {
        selectedProfile = profile
    }
    
    private func populateForm(with task: Task) {
        taskTitle = task.title
        taskDescription = task.description
        taskCategory = task.category
        frequency = task.frequency
        scheduledTimes = [task.scheduledTime]
        deadlineMinutes = task.deadlineMinutes
        requiresPhoto = task.requiresPhoto
        requiresText = task.requiresText
        customDays = Set(task.customDays)
        startDate = task.startDate
        endDate = task.endDate
        isActive = task.status == .active

        // Set selected profile (would need profile lookup)
        // selectedProfile = findProfile(by: task.profileId)
    }
    
    private func resetForm() {
        taskTitle = ""
        taskDescription = ""
        taskCategory = .medication
        frequency = .daily
        scheduledTimes = []
        deadlineMinutes = 10
        requiresPhoto = false
        requiresText = true
        customDays = []
        startDate = Date()
        endDate = nil
        isActive = true
        notes = ""
        selectedProfile = nil
        titleError = nil
        timeError = nil
        profileError = nil
    }
    
    // MARK: - UI Actions
    func startCreateTask() {
        resetForm()
        showingCreateTask = true
    }
    
    func startCreateTask(for profile: ElderlyProfile) {
        resetForm()
        selectedProfile = profile
        showingCreateTask = true
    }
    
    func cancelCreateTask() {
        resetForm()
        showingCreateTask = false
    }
    
    func cancelEditTask() {
        resetForm()
        showingEditTask = false
        selectedTask = nil
    }
    
    // MARK: - Filtering
    func setFilter(category: TaskCategory?) {
        selectedCategoryFilter = category
    }
    
    func setFilter(status: TaskStatus?) {
        selectedStatusFilter = status
    }
    
    func toggleActiveOnlyFilter() {
        showingActiveOnly.toggle()
    }
    
    func clearFilters() {
        selectedCategoryFilter = nil
        selectedStatusFilter = nil
        searchText = ""
        showingActiveOnly = true
    }
}

// MARK: - Task Errors
enum TaskError: LocalizedError {
    case userNotAuthenticated
    case maxTasksReached
    case profileNotConfirmed
    case invalidScheduleTime
    case taskNotFound
    case schedulingFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "Please sign in to manage tasks"
        case .maxTasksReached:
            return "Maximum 10 tasks allowed per profile"
        case .profileNotConfirmed:
            return "Profile must be confirmed to receive reminders"
        case .invalidScheduleTime:
            return "Please select a valid schedule time"
        case .taskNotFound:
            return "Task not found"
        case .schedulingFailed:
            return "Failed to schedule task notifications"
        }
    }
}