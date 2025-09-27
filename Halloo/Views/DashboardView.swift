import SwiftUI

/**
 * Gallery presentation data for fullScreenCover
 */
struct GalleryPresentationData: Identifiable {
    let id = UUID()
    let event: GalleryHistoryEvent
    let index: Int
    let total: Int
}

/**
 * DASHBOARD VIEW - Main Home Screen for Elderly Care Coordination
 *
 * PURPOSE: This is the primary interface families use to coordinate elderly care.
 * Shows today's tasks for selected elderly family member, allows creating new habits,
 *  * and provides quick access to profile management.
 *
 * KEY BUSINESS LOGIC:
 * - Families can manage up to 4 elderly profiles
 * - Tasks are filtered by selected profile (not "show all")
 * - Only today's tasks are displayed (upcoming vs completed)
 * - Profile-specific task creation with preselected family member
 *
 * NAVIGATION: Custom pill-shaped bottom nav (home active, gallery inactive)
 * SHEETS: ProfileCreationView and TaskCreationView with proper ViewModel injection
 */
struct DashboardView: View {
    
    // MARK: - Environment & Dependencies
    /// Dependency injection container providing access to all app services
    /// (DatabaseService, AuthenticationService, NotificationService, etc.)
    @Environment(\.container) private var container
    
    /// Reactive data source for dashboard content (profiles, tasks, filtering logic)
    /// Uses @Published properties to automatically update UI when data changes
    @EnvironmentObject private var viewModel: DashboardViewModel
    
    /// Profile management for onboarding flow - shared across Dashboard and ProfileCreation
    /// Fixes ViewModel instance isolation by using same instance for profile creation
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    // MARK: - Navigation State
    /// Tab selection binding from parent ContentView for floating pill navigation
    @Binding var selectedTab: Int
    
    // MARK: - UI State Management
    /// Tracks which elderly profile is currently selected (0-3 max)
    /// IMPORTANT: This drives task filtering - only selected profile's tasks show
    @State private var selectedProfileIndex: Int = 0
    
    
    /// Controls TaskCreationView conditional presentation with profile preselection
    /// Triggered by + button in "Create Custom Habit" section
    @State private var showingTaskCreation = false
    
    /// Controls direct ProfileOnboardingFlow presentation
    /// Alternative to ProfileCreationView sheet for smoother UX
    @State private var showingDirectOnboarding = false
    
    /// Controls action sheet for unified create button
    @State private var showingCreateActionSheet = false
    
    /// Controls GalleryDetailView presentation for completed task viewing
    @State private var selectedTaskForGalleryDetail: GalleryPresentationData?
    
    /// Tracks all gallery events for today's completed tasks for navigation
    @State private var todaysGalleryEvents: [GalleryHistoryEvent] = []
    
    /// Current index in the gallery events array
    @State private var currentGalleryIndex: Int = 0
    
    /// Current total events count for navigation
    @State private var currentTotalEvents: Int = 0
    
    var body: some View {
        Group {
            if showingDirectOnboarding {
                // TODO: Replace with new profile creation view
                VStack {
                    Text("Add Family Member")
                        .font(.title)
                    Text("Coming Soon - Will build new profile creation flow")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Cancel") {
                        showingDirectOnboarding = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .transition(.identity)
                .animation(nil, value: showingDirectOnboarding)
            } else if showingTaskCreation {
                // Show task creation flow without animation
                TaskCreationView(
                    preselectedProfileId: selectedProfile?.id,
                    dismissAction: {
                        showingTaskCreation = false
                    }
                )
                .environmentObject(container.makeTaskViewModel())
                .transition(.identity)
                .animation(nil, value: showingTaskCreation)
            } else {
                // Show dashboard
                dashboardContent
                    .transition(.identity)
                    .animation(nil, value: showingDirectOnboarding)
                    .animation(nil, value: showingTaskCreation)
            }
        }
        .animation(nil) // Disable all animations
    }
    
    private var dashboardContent: some View {
        /*
         * RESPONSIVE LAYOUT STRUCTURE:
         * GeometryReader provides actual screen dimensions for responsive design
         * Uses 5% screen padding and proportional sizing for different devices
         */
        GeometryReader { geometry in
            ZStack {
                /*
                 * MAIN SCROLLABLE CONTENT AREA:
                 * Contains all dashboard sections in vertical flow
                 * Background: Light gray (#f9f9f9) for card contrast
                 */
                ScrollView {
                    VStack(spacing: 10) { // Reduced spacing between cards by half
                        
                        // 🏠 HEADER: App branding + account access
                        headerSection
                        
                        // ✅ COMPLETED: Interactive card stack showing task evidence
                        // Replaces detailed view system with swipeable playing card stack
                        cardStackSection
                        
                        // ⏰ UPCOMING: Today's pending tasks for selected profile only
                        // Shows tasks that still need to be completed today
                        upcomingSection
                        
                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // Match GalleryView (96% width)
                }
                .background(Color(hex: "f9f9f9")) // Light gray app background
                
                /*
                 * 🧭 FLOATING BOTTOM ELEMENTS:
                 * Both navigation pill and create habit button on same level
                 * Button centered, pill on right - no conflict
                 */
                VStack {
                    Spacer()
                    
                    ZStack {
                        // Create Custom Habit Button - centered, aligned to nav pill bottom edge
                        HStack {
                            Spacer()
                            createHabitButton
                            Spacer()
                        }
                        .padding(.bottom, -28) // Very close to bottom edge - button well below nav pill
                        
                        // Navigation pill - bottom right
                        bottomTabNavigation
                    }
                }
            }
        }
// Removed .ignoresSafeArea to match GalleryView and prevent black bar
        .onAppear {
            /*
             * DATA LOADING & PROFILE SELECTION:
             * Load dashboard data and auto-select first profile for task filtering
             */
            loadData()
        }
        /*
         * 📱 GALLERY DETAIL VIEW:
         * Full-screen detailed view of completed task gallery events
         * Presents GalleryDetailView when "view" button tapped on completed task
         */
        .fullScreenCover(item: $selectedTaskForGalleryDetail, onDismiss: {
            // Reset when dismissed
            todaysGalleryEvents = []
            currentGalleryIndex = 0
            currentTotalEvents = 0
        }) { galleryData in
            GalleryDetailView(
                event: galleryData.event,
                selectedTab: $selectedTab,
                currentIndex: galleryData.index,
                totalEvents: galleryData.total,
                onPrevious: { navigateToPreviousTask() },
                onNext: { navigateToNextTask() }
            )
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }
    
    // MARK: - Helper Methods
    private func navigateToPreviousTask() {
        print("DEBUG: navigateToPreviousTask called. Current index: \(currentGalleryIndex), Total events: \(todaysGalleryEvents.count)")
        guard currentGalleryIndex > 0 else { 
            print("DEBUG: Cannot navigate to previous - already at first item")
            return 
        }
        
        let newIndex = currentGalleryIndex - 1
        let newEvent = todaysGalleryEvents[newIndex]
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentGalleryIndex = newIndex
            selectedTaskForGalleryDetail = GalleryPresentationData(event: newEvent, index: newIndex, total: todaysGalleryEvents.count)
        }
        print("DEBUG: Navigated to previous task. New index: \(currentGalleryIndex)/\(todaysGalleryEvents.count)")
    }
    
    private func navigateToNextTask() {
        print("DEBUG: navigateToNextTask called. Current index: \(currentGalleryIndex), Total events: \(todaysGalleryEvents.count)")
        guard currentGalleryIndex < todaysGalleryEvents.count - 1 else { 
            print("DEBUG: Cannot navigate to next - already at last item")
            return 
        }
        
        let newIndex = currentGalleryIndex + 1
        let newEvent = todaysGalleryEvents[newIndex]
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentGalleryIndex = newIndex
            selectedTaskForGalleryDetail = GalleryPresentationData(event: newEvent, index: newIndex, total: todaysGalleryEvents.count)
        }
        print("DEBUG: Navigated to next task. New index: \(currentGalleryIndex)/\(todaysGalleryEvents.count)")
    }
    
    private func loadTodaysGalleryEvents() async {
        do {
            let authService = container.resolve(AuthenticationServiceProtocol.self)
            guard let userId = authService.currentUser?.uid else { return }
            
            let databaseService = container.resolve(DatabaseServiceProtocol.self)
            let allEvents = try await databaseService.getGalleryHistoryEvents(for: userId)
            
            // Get task IDs from today's completed tasks IN ORDER
            let todaysTasks = viewModel.todaysCompletedTasks
            let todaysTaskIds = todaysTasks.map { $0.task.id }
            print("DEBUG: ========================================")
            print("DEBUG: Loading gallery events for \(todaysTasks.count) completed tasks")
            for (index, task) in todaysTasks.enumerated() {
                print("DEBUG: Task \(index): ID=\(task.task.id), Title=\(task.task.title)")
            }
            print("DEBUG: ========================================")
            
            // Create a map of task ID to gallery event
            var taskEventMap: [String: GalleryHistoryEvent] = [:]
            print("DEBUG: Total gallery events from database: \(allEvents.count)")
            for event in allEvents {
                switch event.eventData {
                case .taskResponse(let data):
                    if let taskId = data.taskId {
                        print("DEBUG: Found event with taskId: \(taskId)")
                        if todaysTaskIds.contains(taskId) {
                            // Only keep the first event for each task (avoid duplicates)
                            if taskEventMap[taskId] == nil {
                                taskEventMap[taskId] = event
                                print("DEBUG: Mapped event for task \(taskId)")
                            } else {
                                print("DEBUG: Duplicate event for task \(taskId), skipping")
                            }
                        }
                    }
                case .profileCreated(_):
                    break // Skip profile events
                }
            }
            print("DEBUG: Task event map has \(taskEventMap.count) entries")
            
            // Build the gallery events array in the same order as completed tasks
            var orderedEvents: [GalleryHistoryEvent] = []
            for task in todaysTasks {
                if let event = taskEventMap[task.task.id] {
                    orderedEvents.append(event)
                } else {
                    print("DEBUG: Warning - No gallery event found for task \(task.task.id)")
                }
            }
            
            await MainActor.run {
                todaysGalleryEvents = orderedEvents
                print("DEBUG: Loaded \(todaysGalleryEvents.count) gallery events for \(todaysTaskIds.count) tasks")
                for (index, event) in todaysGalleryEvents.enumerated() {
                    if case .taskResponse(let data) = event.eventData {
                        print("DEBUG: Event \(index): taskId=\(data.taskId ?? "nil"), title=\(data.taskTitle ?? "nil")")
                    }
                }
            }
        } catch {
            print("Error loading today's gallery events: \(error)")
        }
    }
    
    private func findGalleryEventForTask(_ task: Task) async -> GalleryHistoryEvent? {
        do {
            let authService = container.resolve(AuthenticationServiceProtocol.self)
            guard let userId = authService.currentUser?.uid else {
                return nil
            }
            
            // Get gallery events from database
            let databaseService = container.resolve(DatabaseServiceProtocol.self)
            let galleryEvents = try await databaseService.getGalleryHistoryEvents(for: userId)
            
            // Find the gallery event that corresponds to this task
            return galleryEvents.first { event in
                switch event.eventData {
                case .taskResponse(let data):
                    return data.taskId == task.id
                case .profileCreated(_):
                    return false
                }
            }
        } catch {
            print("Error finding gallery event for task: \(error)")
            return nil
        }
    }
    
    // MARK: - 🏠 Header Section
    /**
     * APP HEADER: Brand identity and account access
     * 
     * LAYOUT: Left-aligned logo, right-aligned profile button
     * TYPOGRAPHY: Custom Inter font with exact Figma specifications
     * PURPOSE: Establishes app identity and provides settings access
     */
    private var headerSection: some View {
        SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
    }
    
    
    
    // MARK: - ⏰ Upcoming Section
    /**
     * TODAY'S PENDING TASKS: What needs to be done today
     * 
     * CRITICAL FILTERING LOGIC:
     * - Only shows tasks for currently selected elderly profile
     * - Only shows today's tasks (not future days)
     * - Only shows pending tasks (not completed ones)
     * 
     * PURPOSE: Gives families clear visibility into what care tasks
     * are scheduled for today and still need completion
     * 
     * UI BEHAVIOR:
     * - No "view" buttons (tasks aren't completed yet)
     * - Each row shows profile photo, name, task title, and time
     * - Time format: 12-hour ("9AM", "2PM") for easy reading
     */
    private var upcomingSection: some View {
        /*
         * TASK LIST: Profile-filtered, today-only pending tasks
         * Data source: viewModel.todaysUpcomingTasks (automatically filtered)
         * White card background for clarity and grouping
         */
        VStack(spacing: 0) {
                // Section title inside card
                HStack {
                    Text("UPCOMING")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Task rows or Complete message
                if viewModel.todaysUpcomingTasks.isEmpty {
                    // Show Complete message when no tasks
                    HStack {
                        Spacer()
                        Text("Empty!")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(viewModel.todaysUpcomingTasks.enumerated()), id: \.offset) { index, task in
                        TaskRowView(
                            task: task.task,
                            profile: task.profile,
                            showViewButton: false, // No view button for pending tasks
                            onViewButtonTapped: nil
                        )
                        .padding(.horizontal, 12)  // Match card title alignment
                        .padding(.vertical, 12)
                        .background(Color.white) // Each task has white background
                        
                        if index < viewModel.todaysUpcomingTasks.count - 1 {
                            Divider()
                                .overlay(Color(hex: "f8f3f3"))
                                .padding(.horizontal, 24)  // Shorter lines aligned with tasks
                        }
                    }
                }
        }
        .background(Color.white) // Card background
        .cornerRadius(12) // Consistent rounded corners
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
    }
    
    // MARK: - ✅ Card Stack Section
    /**
     * INTERACTIVE CARD STACK: Playing card style display of completed tasks
     * 
     * REPLACES: Old completedTasksSection with detailed view system
     * 
     * FEATURES:
     * - Shows max 3 cards in random fan arrangement
     * - Each card displays either photo or SMS evidence (never both)
     * - Swipe left/right to cycle through completed tasks
     * - Task title displays under stack and changes with current card
     * - Placeholder card when no completed tasks exist
     * 
     * DATA TRANSFORMATION:
     * - Converts DashboardTask with SMSResponse into separate CardData
     * - Splits ResponseType.both into individual photo and SMS cards
     * - Maintains chronological order (most recent first)
     */
    private var cardStackSection: some View {
        // CARD STACK - Full width for proper centering
        CardStackView(events: completedTaskEvents)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity) // Allow full width for internal centering
    }
    
    // MARK: - Card Stack Data Conversion
    private var completedTaskEvents: [GalleryHistoryEvent] {
        let events: [GalleryHistoryEvent] = viewModel.todaysCompletedTasks.compactMap { task in
            guard let response = task.response, response.isCompleted else { return nil }
            return GalleryHistoryEvent.fromSMSResponse(response)
        }
        print("DEBUG: Completed tasks count: \(viewModel.todaysCompletedTasks.count)")
        print("DEBUG: Card events count: \(events.count)")
        return events
    }
    
    // MARK: - ✅ OLD Completed Tasks Section (REPLACED BY CARD STACK)
    /**
     * TODAY'S FINISHED TASKS: What has been accomplished today
     * 
     * CRITICAL FILTERING LOGIC:
     * - Only shows tasks for currently selected elderly profile447
     * - Only shows today's tasks (not previous days)
     * - Only shows completed tasks (with completion evidence)
     * 
     * PURPOSE: Provides families with reassurance that care tasks
     * have been completed and allows reviewing completion evidence
     * 
     * UI BEHAVIOR:
     * - Shows "view" buttons for reviewing completion details
     * - Buttons lead to photos/SMS responses from elderly person
     * - Same TaskRowView component as upcoming but with viewing enabled
     * 
     * COMPLETION EVIDENCE:
     * - Photos taken by elderly person showing task completion
     * - SMS responses confirming task completion
     * - Timestamp and location data (if available)
     */
    private var completedTasksSection: some View {
        /*
         * COMPLETED TASK LIST: Profile-filtered, today-only completed tasks
         * Data source: viewModel.todaysCompletedTasks (automatically filtered)
         * 
         * KEY DIFFERENCE FROM UPCOMING:
         * - showViewButton: true enables reviewing completion evidence
         * - Families can see photos, SMS responses, timestamps
         * - Provides peace of mind that care tasks were actually completed
         */
        VStack(spacing: 0) {
                // Section title inside card
                HStack {
                    Text("COMPLETED TASKS")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Task rows or Complete message
                if viewModel.todaysCompletedTasks.isEmpty {
                    // Show Complete message when no completed tasks
                    HStack {
                        Spacer()
                        Text("Empty!")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(viewModel.todaysCompletedTasks.enumerated()), id: \.element.task.id) { rowIndex, task in
                        TaskRowView(
                            task: task.task,
                            profile: task.profile,
                            showViewButton: true, // IMPORTANT: Enables viewing completion evidence
                            onViewButtonTapped: {
                                guard selectedTaskForGalleryDetail == nil else { return }
                                
                                let taskToFind = task.task
                                let taskIndex = rowIndex
                                print("DEBUG: ========================================")
                                print("DEBUG: View button \(taskIndex + 1) tapped")
                                print("DEBUG: Task ID: \(taskToFind.id)")
                                print("DEBUG: Task Title: \(taskToFind.title)")
                                print("DEBUG: ========================================")
                                
                                _Concurrency.Task {
                                    // Always reload today's gallery events to ensure we have all of them
                                    await loadTodaysGalleryEvents()
                                    
                                    print("DEBUG: After loading, we have \(todaysGalleryEvents.count) gallery events")
                                    print("DEBUG: Trying to open event at index \(taskIndex)")
                                    
                                    // The gallery events are now guaranteed to be in the same order as completed tasks
                                    if taskIndex < todaysGalleryEvents.count {
                                        await MainActor.run {
                                            let galleryEvent = todaysGalleryEvents[taskIndex]
                                            let totalEventsCount = todaysGalleryEvents.count
                                            print("DEBUG: Successfully setting currentGalleryIndex to \(taskIndex)")
                                            print("DEBUG: Gallery event ID: \(galleryEvent.id)")
                                            print("DEBUG: Will show next button: \(taskIndex < totalEventsCount - 1)")
                                            print("DEBUG: About to present with currentIndex=\(taskIndex), totalEvents=\(totalEventsCount)")
                                            
                                            // Set both values BEFORE presenting to ensure proper navigation state
                                            currentGalleryIndex = taskIndex
                                            currentTotalEvents = totalEventsCount
                                            
                                            // Disable animation when presenting
                                            var transaction = Transaction()
                                            transaction.disablesAnimations = true
                                            withTransaction(transaction) {
                                                selectedTaskForGalleryDetail = GalleryPresentationData(event: galleryEvent, index: taskIndex, total: totalEventsCount)
                                            }
                                        }
                                    } else {
                                        print("ERROR: Task index \(taskIndex) is out of bounds!")
                                        print("ERROR: We only have \(todaysGalleryEvents.count) gallery events")
                                    }
                                }
                            }
                        )
                        .id(task.task.id) // Force unique identity for each row
                        .padding(.horizontal, 12)  // Match card title alignment
                        .padding(.vertical, 12)
                        .background(Color.white) // Each task has white background
                        
                        if rowIndex < viewModel.todaysCompletedTasks.count - 1 {
                            Divider()
                                .overlay(Color(hex: "f8f3f3"))
                                .padding(.horizontal, 24)  // Shorter lines aligned with tasks
                        }
                    }
                }
        }
        .background(Color.white) // Card background for grouping
        .cornerRadius(12) // Consistent rounded appearance
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        // No bottom padding - this is the last content section
    }
    
    // MARK: - 🧭 Bottom Tab Navigation
    private var bottomTabNavigation: some View {
        FloatingPillNavigation(selectedTab: $selectedTab)
    }
    
    // MARK: - ✨ Unified Create Button
    /**
     * FLOATING UNIFIED CREATE BUTTON: Bottom center call-to-action
     * 
     * PURPOSE: Primary action button for creating new profiles or tasks
     * Positioned at bottom center for easy thumb access
     * Shows action sheet to choose between profile creation or task creation
     * Same size as profile circles for visual consistency
     */
    private var createHabitButton: some View {
        Button(action: {
            // Haptic feedback for create action
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            showingCreateActionSheet = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 45, height: 45) // Same size as profile circles
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .actionSheet(isPresented: $showingCreateActionSheet) {
            ActionSheet(
                title: Text("What would you like to create?"),
                buttons: [
                    .default(Text("Add Family Member")) {
                        // Create profile action
                        profileViewModel.startProfileOnboarding()
                        showingDirectOnboarding = true
                    },
                    .default(Text("Create Habit")) {
                        // Create task action
                        showingTaskCreation = true
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - 🔧 Helper Properties & Methods
    
    /**
     * SELECTED PROFILE ACCESSOR: Safe access to currently selected elderly profile
     * 
     * PURPOSE: Provides the ElderlyProfile object for the currently selected index
     * Used for preselecting profile in TaskCreationView and safety checks
     * 
     * SAFETY: Returns nil if selectedProfileIndex is out of bounds
     * This prevents crashes when profiles are loading or being modified
     */
    private var selectedProfile: ElderlyProfile? {
        guard selectedProfileIndex < viewModel.profiles.count else { return nil }
        return viewModel.profiles[selectedProfileIndex]
    }
    
    /**
     * DATA LOADING: Initialize dashboard data and set default profile selection
     * 
     * BUSINESS LOGIC:
     * 1. Load all dashboard data (profiles, tasks, etc.) from ViewModel
     * 2. Auto-select first profile (index 0) for immediate task filtering
     * 3. This ensures families see relevant tasks immediately upon app launch
     * 
     * CALLED: On view appearance (.onAppear)
     * TIMING: Critical to call selectProfile after profiles are loaded
     */
    private func loadData() {
        /*
         * Load dashboard data from ViewModel
         * This triggers network calls to fetch profiles, tasks, etc.
         * Auto-selection now happens in DashboardViewModel after profiles are loaded
         */
        viewModel.loadDashboardData()
    }
    
    /**
     * DEPRECATED: Task loading method no longer needed
     * 
     * LEGACY NOTE: This method previously handled manual task loading
     * Now handled automatically by profile tap gesture and ViewModel filtering
     * 
     * CURRENT APPROACH:
     * - Profile tap updates selectedProfileIndex
     * - Profile tap calls viewModel.selectProfile()
     * - ViewModel automatically filters @Published task properties
     * - UI updates reactively via @Published property changes
     */
    private func loadTasksForSelectedProfile() {
        // This method is now handled by profile tap gesture
        // ViewModel automatically filters tasks based on selectedProfileId
    }
}

// MARK: - ProfileImageView Components Moved to /Views/Components/ProfileImageView.swift
// This eliminates duplicate code and provides unified ProfileImageView component

// MARK: - Task Row View Component
struct TaskRowView: View {
    let task: Task
    let profile: ElderlyProfile?
    let showViewButton: Bool
    let onViewButtonTapped: (() -> Void)?
    
    init(
        task: Task,
        profile: ElderlyProfile?,
        showViewButton: Bool,
        onViewButtonTapped: (() -> Void)? = nil
    ) {
        self.task = task
        self.profile = profile
        self.showViewButton = showViewButton
        self.onViewButtonTapped = onViewButtonTapped
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image (smaller)
            AsyncImage(url: URL(string: profile?.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    // Use a light version based on profile ID hash
                    let colorIndex = abs((profile?.id ?? "").hashValue) % 4
                    let profileColor = [Color(hex: "B9E3FF"), Color.red, Color.green, Color.purple][colorIndex]
                    profileColor.opacity(0.2)
                    Text(String(profile?.name.prefix(1) ?? "").uppercased())
                        .font(.custom("Inter", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            // Task Details
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.name ?? "")
                    .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                    .tracking(-0.25)  // Half of original -0.5 offset
                    .foregroundColor(.black)
                
                HStack(spacing: 4) {
                    Text(task.title)
                        .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                        .fontWeight(.regular)
                        .tracking(-0.5)  // Less tight tracking
                        .foregroundColor(.black)
                    
                    Text("•")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))
                    
                    Text(formatTime(task.scheduledTime))
                        .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                        .fontWeight(.regular)
                        .tracking(-0.5)  // Less tight tracking
                        .foregroundColor(.black)
                }
            }
            
            Spacer()
            
            // View Button (only for completed tasks)
            if showViewButton {
                Button(action: {
                    onViewButtonTapped?()
                }) {
                    Text("view")
                        .font(.custom("Inter", size: 13))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "28ADFF"))  // Rich blue like continue buttons
                        .cornerRadius(8)
                }
                .frame(height: 28)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha" // This gives "5PM" or "8AM" format
        return formatter.string(from: date)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Views now in dedicated files
// ProfileCreationView -> ProfileViews.swift
// TaskCreationView -> TaskViews.swift

// MARK: - Preview Support
#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // SIMPLE FALLBACK PREVIEW (if comprehensive fails)
            VStack {
                Text("DashboardView Canvas Preview")
                    .font(.headline)
                Text("Canvas loading...")
                    .foregroundColor(.gray)
            }
            .previewDisplayName("📱 Simple Fallback")
            
            // COMPREHENSIVE DASHBOARD LAYOUT PREVIEW
            PreviewDashboardWrapper()
                .previewDisplayName("📱 Complete Dashboard Layout")
            
            // INDIVIDUAL SECTION PREVIEWS FOR EASY EDITING
            // Updated Header Section Preview - Uses shared component
            PreviewHeaderWrapper()
                .previewDisplayName("🏠 Header Section - UPDATED")
            
            PreviewProfilesSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("👥 Profiles Section")
            
            
            PreviewUpcomingSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("⏰ Upcoming Section")
            
            PreviewCompletedTasksSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("✅ Completed Tasks Section")
            
            PreviewBottomNavigation()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("🧭 Bottom Navigation")
        }
    }
}

// MARK: - Organized Preview Components

// SharedHeaderSection moved to /Views/Components/SharedHeaderSection.swift

struct PreviewProfilesSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockProfiles = [
        ("👴🏻", "Grandpa Joe", Color(hex: "B9E3FF"), true),   // Show all outlines
        ("👵🏽", "Grandma Maria", Color.red.opacity(0.6), true),  // Show all outlines
        ("👴🏿", "Uncle Robert", Color.green.opacity(0.6), true)   // Show all outlines
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // White Card with Profiles - title inside card
            VStack(alignment: .leading, spacing: 12) {
                // Section Title inside the card
                Text("PROFILES:")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(Color(hex: "9f9f9f"))
                
                // Profile circles
                HStack(spacing: 12) {
                    ForEach(Array(mockProfiles.enumerated()), id: \.offset) { index, profile in
                        ZStack {
                            profile.2.opacity(0.2)  // Use profile's color as background
                            Text(profile.0)
                                .font(.system(size: 20))
                        }
                        .frame(width: 44, height: 44) // ~44pt diameter
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(profile.2, lineWidth: profile.3 ? 2 : 2)  // All have 2px for preview
                        )
                    }
                    
                    // Add Profile Button - Figma specs
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "5f5f5f"))
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}


struct PreviewUpcomingSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockTasks = [
        ("👴🏻", "Grandpa Joe", "example task • Create Now!", "9AM"),
        ("👴🏻", "Grandpa Joe", "Walk in Garden", "2PM"),
        ("👴🏻", "Grandpa Joe", "Call Family", "6PM")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // White Card with title inside
            VStack(alignment: .leading, spacing: 0) {
                // Section Title inside the card
                HStack {
                    Text("UPCOMING")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Tasks list - seamless white
                ForEach(Array(mockTasks.enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 16) {
                        // Profile Image - 32pt diameter
                        ZStack {
                            // Consistent color mapping - Grandpa Joe always blue
                            let backgroundColor: Color = {
                                switch task.1 {
                                case "Grandpa Joe": return Color(hex: "B9E3FF")
                                case "Grandma Maria": return Color.red  
                                case "Uncle Robert": return Color.green
                                default: return Color.purple
                                }
                            }()
                            backgroundColor.opacity(0.2)
                            Text(task.0)
                                .font(.system(size: 16))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        // Task Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.1)
                                .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                                .tracking(-0.25)  // Half of original -0.5 offset
                                .foregroundColor(.black)
                            
                            HStack(spacing: 4) {
                                Text(task.2)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from secondary to black
                                
                                Text("•")
                                    .font(.custom("Inter", size: 14))
                                    .foregroundColor(.secondary)  // Keep bullet gray
                                
                                Text(task.3)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from secondary to black
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)  // Increased by 4px more for better left spacing
                    .padding(.vertical, 12)
                    .background(Color.white) // Each task has white background
                    
                    if index < mockTasks.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, 32)  // Even shorter lines
                    }
                }
            }
            .background(Color.white) // Overall white card background
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}

struct PreviewCompletedTasksSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockCompletedTasks = [
        ("👴🏻", "Grandpa Joe", "example task • Create Now!", "8AM"),
        ("👴🏻", "Grandpa Joe", "Breakfast", "8:30AM")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Tasks Card with title inside
            VStack(spacing: 0) {
                // Section Title - moved inside card
                HStack {
                    Text("COMPLETED TASKS")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                ForEach(Array(mockCompletedTasks.enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 16) {
                        // Profile Image - 32pt diameter
                        ZStack {
                            // Consistent color mapping - Grandpa Joe always blue
                            let backgroundColor: Color = {
                                switch task.1 {
                                case "Grandpa Joe": return Color(hex: "B9E3FF")
                                case "Grandma Maria": return Color.red  
                                case "Uncle Robert": return Color.green
                                default: return Color.purple
                                }
                            }()
                            backgroundColor.opacity(0.2)
                            Text(task.0)
                                .font(.system(size: 16))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        // Task Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.1)
                                .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                                .tracking(-0.25)  // Half of original -0.5 offset
                                .foregroundColor(.black)
                            
                            HStack(spacing: 4) {
                                Text(task.2)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from .secondary
                                
                                Text("•")
                                    .font(.custom("Inter", size: 14))
                                    .foregroundColor(.secondary)  // Match Upcoming
                                
                                Text(task.3)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from .secondary
                            }
                        }
                        
                        Spacer()
                        
                        // View Button - solid blue with black text
                        Button(action: {}) {
                            Text("view")
                                .font(.custom("Inter", size: 13))
                                .fontWeight(.medium)
                                .foregroundColor(.black)  // Changed to black
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "B9E3FF"))  // Solid blue from Figma
                                .cornerRadius(8)
                        }
                        .frame(height: 28)
                    }
                    .padding(.horizontal, 20)  // Increased by 4px more for better left spacing
                    .padding(.vertical, 12)
                    
                    if index < mockCompletedTasks.count - 1 {
                        Divider()
                            .padding(.horizontal, 32)  // Even shorter lines
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}

struct PreviewBottomNavigation: View {
    var body: some View {
        // Pill-shaped navigation - exact specs
        HStack(spacing: 20) {
            // Home Tab (Active)
            VStack(spacing: 4) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                
                Text("home")
                    .font(.custom("Inter", size: 10))
                    .foregroundColor(.black)
            }
            
            // Gallery Tab (Inactive)
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                
                Text("gallery")
                    .font(.custom("Inter", size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 94, height: 43.19)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 21.595)
                .stroke(Color(hex: "e0e0e0"), lineWidth: 1)
        )
        .padding(.trailing, 10)
        .padding(.bottom, 20)
    }
}

// MARK: - Universal Floating Pill Navigation Component
/**
 * UNIVERSAL FLOATING PILL NAVIGATION: Shared navigation component
 * 
 * DESIGN RATIONALE:
 * - Custom design instead of native TabView for exact Figma match
 * - Pill shape (94×43.19px) positioned precisely (10px right, 20px bottom)
 * - Only 2 visible tabs (home/gallery) for MVP simplicity
 * 
 * BUSINESS LOGIC:
 * - Home tab: Active state (black) - shows Dashboard screen
 * - Gallery tab: Inactive state (gray) - shows Gallery screen
 * - Navigation logic handled by parent ContentView via TabView
 * 
 * VISUAL STATES:
 * - Active tab: Black icons/text
 * - Inactive tab: Gray icons/text
 * - White background with light gray border for definition
 * 
 * USAGE: Can be used in any view that needs tab navigation
 */
struct FloatingPillNavigation: View {
    @Binding var selectedTab: Int
    
    // iPhone 13 base dimensions for scaling (390x844)
    private let iPhone13Width: CGFloat = 390
    private let basePillWidth: CGFloat = 160 // Reduced size for three tabs
    private let basePillHeight: CGFloat = 43
    
    // Calculate responsive dimensions based on screen width
    private var pillWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return (basePillWidth / iPhone13Width) * screenWidth
    }
    
    private var pillHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return (basePillHeight / iPhone13Width) * screenWidth
    }
    
    private var iconSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return (20 / iPhone13Width) * screenWidth
    }
    
    private var fontSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return (8 / iPhone13Width) * screenWidth // Smaller font for three tabs
    }
    
    var body: some View {
        HStack {
            Spacer() // Pushes navigation pill to right side
            
            /*
             * PILL-SHAPED NAVIGATION CONTAINER:
             * Responsive dimensions based on iPhone 13 proportions (43px height on 390px width)
             * Corner radius is exactly half the height for perfect pill shape
             */
            HStack(spacing: pillWidth * 0.08) { // Very tight spacing for three tabs
                
                /*
                 * HOME TAB: Dynamic active/inactive state
                 * Icon: house.fill when active, house when inactive
                 * Text: "home" in small Inter font with negative tracking
                 * Color: Changes based on selectedTab state
                 */
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        .font(.system(size: iconSize))
                        .foregroundColor(selectedTab == 0 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                    
                    Text("home")
                        .font(.custom("Inter", size: fontSize))
                        .tracking(-0.5) // Negative letter spacing to condense text
                        .foregroundColor(selectedTab == 0 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                }
                .onTapGesture {
                    selectedTab = 0 // Switch to Home tab
                }
                
                /*
                 * HABITS TAB: Dynamic active/inactive state
                 * Icon: bookmark.fill when active, bookmark when inactive
                 * Text: "habits" in small Inter font with negative tracking
                 * Color: Changes based on selectedTab state
                 * Action: Updates selectedTab to switch to Habits view
                 */
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 1 ? "bookmark.fill" : "bookmark")
                        .font(.system(size: iconSize))
                        .foregroundColor(selectedTab == 1 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                    
                    Text("habits")
                        .font(.custom("Inter", size: fontSize))
                        .tracking(-0.5) // Negative letter spacing to condense text
                        .foregroundColor(selectedTab == 1 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                }
                .onTapGesture {
                    selectedTab = 1 // Switch to Habits tab
                }
                
                /*
                 * GALLERY TAB: Dynamic active/inactive state
                 * Icon: photo.on.rectangle (photo archive representation)
                 * Text: "gallery" in small Inter font with negative tracking
                 * Color: Changes based on selectedTab state
                 * Action: Updates selectedTab to switch to Gallery view
                 */
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: iconSize))
                        .foregroundColor(selectedTab == 2 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                    
                    Text("gallery")
                        .font(.custom("Inter", size: fontSize))
                        .tracking(-0.5) // Negative letter spacing to condense text
                        .foregroundColor(selectedTab == 2 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                }
                .onTapGesture {
                    selectedTab = 2 // Switch to Gallery tab
                }
            }
            /*
             * PILL CONTAINER STYLING:
             * - Responsive sizing based on screen dimensions
             * - Corner radius is half height for perfect pill shape
             * - White pill-shaped background with matching stroke
             * - Positioned exactly 10px from right, 20px from bottom
             */
            .frame(width: pillWidth, height: pillHeight) // Responsive dimensions
            .background(
                RoundedRectangle(cornerRadius: pillHeight / 2) // Half of height = perfect pill
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: pillHeight / 2) // Same corner radius for stroke
                    .stroke(Color(hex: "e0e0e0"), lineWidth: 1)
            )
            .padding(.trailing, 10) // 10px from right edge (Figma spec)
            .padding(.bottom, 20)   // 20px from bottom edge (Figma spec)
        }
    }
}

// MARK: - Preview Wrapper Structs
private struct PreviewDashboardWrapper: View {
    @State private var selectedProfileIndex: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section - Use shared header component
                    SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
                    
                    // Profiles Section  
                    PreviewProfilesSection()
                        .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                        .padding(.top, 8)
                    
                    
                    // Upcoming Section
                    PreviewUpcomingSection()
                        .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                        .padding(.top, 20)
                    
                    // Completed Tasks Section
                    PreviewCompletedTasksSection()
                        .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                        .padding(.top, 20)
                    
                    // Bottom spacing for navigation
                    Spacer(minLength: 100)
                }
            }
            .background(Color(hex: "f9f9f9"))
            .overlay(
                // Bottom Navigation Overlay
                PreviewBottomNavigation()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            )
        }
        .inject(container: Container.makeForTesting())
    }
}

private struct PreviewHeaderWrapper: View {
    @State private var selectedProfileIndex: Int = 0
    
    var body: some View {
        SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
            .background(Color(hex: "f9f9f9"))
            .inject(container: Container.makeForTesting())
    }
}

#endif
