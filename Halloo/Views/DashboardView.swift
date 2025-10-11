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

    /// Scroll lock state from ContentView (disables vertical scroll during horizontal swipe)
    @Environment(\.isScrollDisabled) private var isScrollDisabled

    /// Reactive data source for dashboard content (profiles, tasks, filtering logic)
    /// Uses @Published properties to automatically update UI when data changes
    @EnvironmentObject private var viewModel: DashboardViewModel

    /// Profile management for onboarding flow - shared across Dashboard and ProfileCreation
    /// Fixes ViewModel instance isolation by using same instance for profile creation
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    // MARK: - Navigation State
    /// Tab selection binding from parent ContentView for floating pill navigation
    @Binding var selectedTab: Int

    /// Controls whether to show header (false when rendered in ContentView's layered architecture)
    var showHeader: Bool = true

    /// Controls whether to show bottom navigation (false when rendered in ContentView's layered architecture)
    var showNav: Bool = true
    
    // MARK: - UI State Management
    /// Tracks which elderly profile is currently selected (0-3 max)
    /// IMPORTANT: This drives task filtering - only selected profile's tasks show
    @State private var selectedProfileIndex: Int = 0
    
    /// Controls upcoming section expand/collapse state
    /// When collapsed: shows summary message, when expanded: shows task list or confirmation
    @State private var isUpcomingExpanded: Bool = false
    
    
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
    
    /// Tracks the current top card in the card stack to show its task details
    @State private var currentTopCardEvent: GalleryHistoryEvent?
    
    /// Current index in the gallery events array
    @State private var currentGalleryIndex: Int = 0
    
    /// Current total events count for navigation
    @State private var currentTotalEvents: Int = 0

    /// Tab transition state (for GalleryDetailView)
    @State private var previousTab: Int = 0
    @State private var transitionDirection: Int = 1
    @State private var isTransitioning: Bool = false
    
    var body: some View {
        if showingDirectOnboarding {
            // ✅ NEW: Simplified single-card profile creation
            SimplifiedProfileCreationView(onDismiss: {
                showingDirectOnboarding = false
            })
            .environmentObject(profileViewModel)
            .transition(.identity)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        } else if showingTaskCreation {
            // Show task creation flow
            TaskCreationView(
                preselectedProfileId: selectedProfile?.id,
                dismissAction: {
                    showingTaskCreation = false
                }
            )
            .environmentObject(container.makeTaskViewModel())
            .transition(.identity)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        } else {
            // Show dashboard - NO .transition() here, let parent control it
            dashboardContent
        }
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

                        // 🏠 HEADER: App branding + account access (conditionally rendered)
                        if showHeader {
                            headerSection
                                .padding(.bottom, 3.33) // Increase spacing by 1/3 (10 → 13.33)
                        }

                        // ✅ COMPLETED: Interactive card stack showing task evidence
                        // Replaces detailed view system with swipeable playing card stack
                        VStack(spacing: 18) {  // VStack spacing between card and task details (30pt total with TaskRowView padding)
                            cardStackSection

                            // 📋 TASK DETAILS: Shows current top card's habit information
                            // Only visible when there are cards in the stack
                            if currentTopCardEvent != nil {
                                taskDetailsSection
                                    .padding(.bottom, 8)  // Bottom padding to match top (total 20pt each side)
                            }
                        }
                        .padding(.bottom, -8.33) // Half the spacing to upcoming (3.33 - 6.67 = -3.33, halved from -6.67)
                        .padding(.top, showHeader ? 0 : 100) // Add top padding when header is hidden (static header height)

                        // ⏰ UPCOMING: Today's pending tasks for selected profile only
                        // Shows tasks that still need to be completed today
                        upcomingSection
                            .padding(.top, currentTopCardEvent == nil ? 18 : 0) // Add spacing when card stack is empty

                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // Match GalleryView (96% width)
                }
                .scrollDisabled(isScrollDisabled)
                .background(Color(hex: "f9f9f9")) // Light gray app background

                // Reusable bottom gradient navigation with create button (conditionally rendered)
                if showNav {
                    BottomGradientNavigation(selectedTab: $selectedTab, previousTab: $previousTab, transitionDirection: $transitionDirection, isTransitioning: $isTransitioning) {
                        createHabitButton
                    }
                }
            }
        }
        .onAppear {
            /*
             * DATA LOADING & PROFILE SELECTION:
             * 1. Connect DashboardViewModel to ProfileViewModel (single source of truth)
             * 2. Load dashboard data and auto-select first profile for task filtering
             * 3. Sync UI selection state with ViewModel selection state
             */
            viewModel.setProfileViewModel(profileViewModel)

            // Sync selectedProfileIndex with ViewModel's selectedProfileId
            if let selectedId = viewModel.selectedProfileId,
               let index = profileViewModel.profiles.firstIndex(where: { $0.id == selectedId }) {
                selectedProfileIndex = index
            } else {
                print("⚠️ [DashboardView] Could not sync profile selection - profiles may not be loaded yet")
            }

            loadData()
        }
        .onChange(of: viewModel.selectedProfileId) { newProfileId in
            // Sync selectedProfileIndex when ViewModel auto-selects a profile
            if let newId = newProfileId,
               let index = profileViewModel.profiles.firstIndex(where: { $0.id == newId }) {
                selectedProfileIndex = index
            }
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
                previousTab: $previousTab,
                transitionDirection: $transitionDirection,
                isTransitioning: $isTransitioning,
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
        guard currentGalleryIndex > 0 else {
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
    }

    private func navigateToNextTask() {
        guard currentGalleryIndex < todaysGalleryEvents.count - 1 else {
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

            // Create a map of task ID to gallery event
            var taskEventMap: [String: GalleryHistoryEvent] = [:]
            for event in allEvents {
                switch event.eventData {
                case .taskResponse(let data):
                    if let taskId = data.taskId {
                        if todaysTaskIds.contains(taskId) {
                            // Only keep the first event for each task (avoid duplicates)
                            if taskEventMap[taskId] == nil {
                                taskEventMap[taskId] = event
                            }
                        }
                    }
                case .profileCreated(_):
                    break // Skip profile events
                }
            }

            // Build the gallery events array in the same order as completed tasks
            var orderedEvents: [GalleryHistoryEvent] = []
            for task in todaysTasks {
                if let event = taskEventMap[task.task.id] {
                    orderedEvents.append(event)
                }
            }

            await MainActor.run {
                todaysGalleryEvents = orderedEvents
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
    
    /// Dynamic header text based on task count and selected profile
    private func getUpcomingHeaderText() -> String {
        let taskCount = viewModel.todaysUpcomingTasks.count
        
        if taskCount == 0 {
            return "All steps completed today!"
        } else {
            // Get selected profile name
            let profileName = selectedProfile?.name ?? "Profile"
            let checkInText = taskCount == 1 ? "check-in" : "check-ins"
            return "\(profileName) has \(taskCount) \(checkInText) left!"
        }
    }
    
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
    // MARK: - 👥 Profiles Section
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Title
            Text("PROFILES")
                .font(.system(size: 15, weight: .bold))
                .tracking(-1)
                .foregroundColor(Color(hex: "9f9f9f"))
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)

            // Profile circles - NOW USING ProfileViewModel (single source of truth)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(profileViewModel.profiles.enumerated()), id: \.element.id) { index, profile in
                        Button(action: {
                            selectedProfileIndex = index
                            // Update DashboardViewModel's selected profile to trigger task filtering
                            viewModel.selectProfile(profileId: profile.id)
                        }) {
                            ProfileImageView.custom(
                                profile: profile,
                                profileSlot: index,
                                isSelected: selectedProfile?.id == profile.id,
                                size: 44
                            )
                        }
                    }

                    // Add Profile Button
                    Button(action: {
                        showingDirectOnboarding = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "5f5f5f"))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var upcomingSection: some View {
        /*
         * TASK LIST: Profile-filtered, today-only pending tasks
         * Data source: viewModel.todaysUpcomingTasks (automatically filtered)
         * White card background for clarity and grouping
         */
        VStack(spacing: 0) {
                // Collapsible header with dynamic message and chevron
                HStack {
                    Text(getUpcomingHeaderText())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .rotationEffect(.degrees(isUpcomingExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle()) // Make entire header tappable
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                        isUpcomingExpanded.toggle()
                    }
                }

                // Expandable content with animation
                VStack(spacing: 0) {
                    if viewModel.todaysUpcomingTasks.isEmpty {
                        // Show confirmation message when no tasks and expanded
                        HStack {
                            Spacer()
                            Text("All tasks completed today!")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(hex: "9f9f9f"))
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        // Show task list when tasks exist and expanded
                        VStack(spacing: 0) {
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
                }
                .opacity(isUpcomingExpanded ? 1.0 : 0.0)
                .frame(maxHeight: isUpcomingExpanded ? .infinity : 0)
                .clipped()
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
        CardStackView(events: completedTaskEvents, currentTopEvent: $currentTopCardEvent)
            .padding(.top, 20)  // Only top padding to avoid double padding with task details
            .offset(y: 8)  // Move down slightly
            .frame(maxWidth: .infinity) // Allow full width for internal centering
    }
    
    // MARK: - 📋 Task Details Section
    /**
     * CURRENT CARD DETAILS: Shows the habit information for the top card
     * 
     * PURPOSE: Displays the task details corresponding to the currently 
     * visible card in the stack, providing context about what the card represents
     * 
     * UI BEHAVIOR:
     * - Shows profile image, name, task title, and scheduled time
     * - Uses standard TaskRowView without view button
     * - Only appears when there are cards in the stack
     * - Updates dynamically as user swipes through cards
     */
    private var taskDetailsSection: some View {
        VStack(spacing: 0) {
            // Find the matching completed task for the current top card event
            if let topEvent = currentTopCardEvent {
                if let matchingTask = viewModel.todaysCompletedTasks.first(where: { task in
                    task.response?.id == topEvent.id ||
                    (task.response != nil && GalleryHistoryEvent.fromSMSResponse(task.response!).id == topEvent.id)
                }) {
                    // Real task data
                    TaskRowView(
                        task: matchingTask.task,
                        profile: matchingTask.profile,
                        showViewButton: false,
                        onViewButtonTapped: nil
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                } else {
                    // Mock data fallback - show basic info without full Task creation
                    HStack(spacing: 16) {
                        // Connected profile circle - find profile by profileId
                        let profile = profileViewModel.profiles.first(where: { $0.id == topEvent.profileId })
                        
                        AsyncImage(url: URL(string: profile?.photoURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ZStack {
                                // Use profile-specific color based on profile ID hash
                                let colorIndex = abs((profile?.id ?? topEvent.profileId).hashValue) % 4
                                let profileColor = [Color(hex: "B9E3FF"), Color.red, Color.green, Color.purple][colorIndex]
                                profileColor // Full opacity background
                                Text(String((profile?.name ?? "G").prefix(1)).uppercased())
                                    .font(.custom("Inter", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        // Task details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile?.name ?? "Grandma Smith")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 4) {
                                Text(topEvent.title)
                                    .font(.custom("Inter", size: 13))
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)
                                
                                Text("•")
                                    .font(.custom("Inter", size: 14))
                                    .foregroundColor(Color(hex: "9f9f9f"))
                                
                                Text("10AM")
                                    .font(.custom("Inter", size: 13))
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Card Stack Data Conversion
    private var completedTaskEvents: [GalleryHistoryEvent] {
        let events: [GalleryHistoryEvent] = viewModel.todaysCompletedTasks.compactMap { task in
            guard let response = task.response, response.isCompleted else { return nil }
            return GalleryHistoryEvent.fromSMSResponse(response)
        }
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

                                let taskIndex = rowIndex

                                _Concurrency.Task {
                                    // Always reload today's gallery events to ensure we have all of them
                                    await loadTodaysGalleryEvents()

                                    // The gallery events are now guaranteed to be in the same order as completed tasks
                                    if taskIndex < todaysGalleryEvents.count {
                                        await MainActor.run {
                                            let galleryEvent = todaysGalleryEvents[taskIndex]
                                            let totalEventsCount = todaysGalleryEvents.count

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
                                        print("❌ [DashboardView] Gallery event index out of bounds")
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
                    .frame(width: 57.25, height: 57.25) // 61.56 × 0.93 = 57.25 (matches navigation pill height)
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)

                Image(systemName: "plus")
                    .font(.system(size: 26.11, weight: .medium)) // 28.08 × 0.93 = 26.11 (7% smaller)
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
        // Use ProfileViewModel as single source of truth
        guard selectedProfileIndex < profileViewModel.profiles.count else { return nil }
        return profileViewModel.profiles[selectedProfileIndex]
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

    @EnvironmentObject private var profileViewModel: ProfileViewModel

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

    // Calculate profile slot index based on position in ProfileViewModel
    private var profileSlot: Int {
        guard let profile = profile else { return 0 }
        return profileViewModel.profiles.firstIndex(where: { $0.id == profile.id }) ?? 0
    }

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image - Use unified ProfileImageView component
            if let profile = profile {
                ProfileImageView.custom(
                    profile: profile,
                    profileSlot: profileSlot,
                    isSelected: false, // Tasks don't have selection state
                    size: 32
                )
            }
            
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
    @EnvironmentObject var dashboardViewModel: DashboardViewModel

    var upcomingTasks: [DashboardTask] {
        dashboardViewModel.todaysTasks.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
        }
        .padding(.horizontal, 23)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tasksList
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var header: some View {
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
    }

    @ViewBuilder
    private var tasksList: some View {
        if upcomingTasks.isEmpty {
            VStack(spacing: 8) {
                Text("No upcoming tasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Text("Create a habit to get started")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ForEach(Array(upcomingTasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 16) {
                            // Profile Image - 32pt diameter
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                )

                            // Task Details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.profile.name)
                                    .font(.system(size: 16, weight: .heavy))
                                    .tracking(-0.25)
                                    .foregroundColor(.black)

                                HStack(spacing: 4) {
                                    Text(task.task.title)
                                        .font(.custom("Inter", size: 13))
                                        .fontWeight(.regular)
                                        .foregroundColor(.black)

                                    Text("•")
                                        .font(.custom("Inter", size: 14))
                                        .foregroundColor(.secondary)

                                    Text(formatTime(task.scheduledTime))
                                        .font(.custom("Inter", size: 13))
                                        .fontWeight(.regular)
                                        .foregroundColor(.black)
                                }
                            }

                            Spacer()

                            // Checkmark Button
                            Button(action: {
                                // Mark task as complete
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.black)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)

                        if index < upcomingTasks.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                                .padding(.horizontal, 32)
                        }
                    }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
}

struct PreviewCompletedTasksSection: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel

    var completedTasks: [DashboardTask] {
        dashboardViewModel.todaysTasks.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            cardContent
        }
        .padding(.horizontal, 23)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            header
            tasksList
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var header: some View {
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
    }

    @ViewBuilder
    private var tasksList: some View {
        if completedTasks.isEmpty {
            // Empty state
            VStack(spacing: 8) {
                Text("No completed tasks yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Text("Complete a task to see it here")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ForEach(Array(completedTasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 16) {
                    // Profile Image - 32pt diameter
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        )

                    // Task Details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.profile.name)
                            .font(.system(size: 16, weight: .heavy))
                            .tracking(-0.25)
                            .foregroundColor(.black)

                        HStack(spacing: 4) {
                            Text(task.task.title)
                                .font(.custom("Inter", size: 13))
                                .fontWeight(.regular)
                                .foregroundColor(.black)

                            Text("•")
                                .font(.custom("Inter", size: 14))
                                .foregroundColor(.secondary)

                            Text(formatTime(task.scheduledTime))
                                .font(.custom("Inter", size: 13))
                                .fontWeight(.regular)
                                .foregroundColor(.black)
                        }
                    }

                    Spacer()

                    // View Button
                    Button(action: {}) {
                        Text("view")
                            .font(.custom("Inter", size: 13))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "B9E3FF"))
                            .cornerRadius(8)
                    }
                    .frame(height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if index < completedTasks.count - 1 {
                    Divider()
                        .padding(.horizontal, 32)
                        .background(Color.gray.opacity(0.2))
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
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
 * - Custom design to match original Remi app layout
 * - Pill shape (140×47px) positioned LEFT-aligned (20px left, 35px bottom)  
 * - Three tabs (home/habits/gallery) restored from original design
 * - UPDATED 2025-09-29: Unified component with optional dismiss callback
 * - UPDATED 2025-09-29: Changed from right to left alignment per Remi app photo
 * 
 * BUSINESS LOGIC:
 * - Home tab: Dashboard screen
 * - Habits tab: Habits management screen  
 * - Gallery tab: Photo gallery screen
 * - Navigation logic handled by parent ContentView via TabView
 * - Optional dismiss callback for detail views (GalleryDetailView)
 * 
 * VISUAL STATES:
 * - Active tab: Black icons/text
 * - Inactive tab: Gray icons/text
 * - White background with light gray border for definition
 * 
 * USAGE:
 * - Regular views: FloatingPillNavigation(selectedTab: $tab, previousTab: $previousTab, transitionDirection: $transitionDirection, onTabTapped: nil)
 * - Detail views: FloatingPillNavigation(selectedTab: $tab, previousTab: $previousTab, transitionDirection: $transitionDirection, onTabTapped: { dismiss() })
 */
struct FloatingPillNavigation: View {
    @Binding var selectedTab: Int
    @Binding var previousTab: Int  // Add binding to previousTab
    @Binding var transitionDirection: Int  // Add binding to transition direction
    @Binding var isTransitioning: Bool  // Lock to prevent animation overlap
    let onTabTapped: (() -> Void)? // Optional dismiss callback
    
    // iPhone 13 base dimensions for scaling (390x844)
    private let iPhone13Width: CGFloat = 390
    private let basePillWidth: CGFloat = 168.74 // 181.44 × 0.93 = 168.74 (7% smaller)
    private let basePillHeight: CGFloat = 57.25 // 61.56 × 0.93 = 57.25 (matches create button)
    
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
        return (21.2 / iPhone13Width) * screenWidth // 22.8 × 0.93 = 21.2 (7% smaller)
    }

    private var fontSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return (8.84 / iPhone13Width) * screenWidth // 9.5 × 0.93 = 8.84 (7% smaller)
    }
    
    var body: some View {
        HStack {
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
                VStack(spacing: 2) { // Reduced from 4 to 2
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        .font(.system(size: iconSize))
                        .foregroundColor(selectedTab == 0 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state

                    Text("home")
                        .font(.custom("Inter", size: fontSize))
                        .tracking(-0.5) // Negative letter spacing to condense text
                        .foregroundColor(selectedTab == 0 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                }
                .onTapGesture {
                    // Prevent rapid tab switches during animation
                    guard !isTransitioning else {
                        print("⚠️ Tab tap blocked - transition in progress")
                        return
                    }

                    if let onTabTapped = onTabTapped {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            selectedTab = 0
                            onTabTapped()
                        }
                    } else {
                        // Update previousTab for Habits transition (Dashboard/Gallery use fixed positions)
                        previousTab = selectedTab
                        selectedTab = 0
                    }
                }
                
                /*
                 * HABITS TAB: Dynamic active/inactive state
                 * Icon: bookmark.fill when active, bookmark when inactive
                 * Text: "habits" in small Inter font with negative tracking
                 * Color: Changes based on selectedTab state
                 * Action: Updates selectedTab to switch to Habits view
                 */
                VStack(spacing: 2) { // Reduced from 4 to 2
                    Image(systemName: selectedTab == 1 ? "bookmark.fill" : "bookmark")
                        .font(.system(size: iconSize))
                        .foregroundColor(selectedTab == 1 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state

                    Text("habits")
                        .font(.custom("Inter", size: fontSize))
                        .tracking(-0.5) // Negative letter spacing to condense text
                        .foregroundColor(selectedTab == 1 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                }
                .onTapGesture {
                    // Prevent rapid tab switches during animation
                    guard !isTransitioning else {
                        print("⚠️ Tab tap blocked - transition in progress")
                        return
                    }

                    if let onTabTapped = onTabTapped {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            selectedTab = 1
                            onTabTapped()
                        }
                    } else {
                        // Update previousTab for Habits transition
                        previousTab = selectedTab
                        selectedTab = 1
                    }
                }
                
                /*
                 * GALLERY TAB: Dynamic active/inactive state
                 * Icon: photo.fill when active, photo when inactive (single photo representation)
                 * Text: "gallery" in small Inter font with negative tracking
                 * Color: Changes based on selectedTab state
                 * Action: Updates selectedTab to switch to Gallery view
                 */
                VStack(spacing: 2) { // Reduced from 4 to 2
                    Image(systemName: selectedTab == 2 ? "photo.fill" : "photo")
                        .font(.system(size: iconSize))
                        .foregroundColor(selectedTab == 2 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state

                    Text("gallery")
                        .font(.custom("Inter", size: fontSize))
                        .tracking(-0.5) // Negative letter spacing to condense text
                        .foregroundColor(selectedTab == 2 ? .black : Color(hex: "9f9f9f")) // Active/Inactive state
                }
                .onTapGesture {
                    // Prevent rapid tab switches during animation
                    guard !isTransitioning else {
                        print("⚠️ Tab tap blocked - transition in progress")
                        return
                    }

                    if let onTabTapped = onTabTapped {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            selectedTab = 2
                            onTabTapped()
                        }
                    } else {
                        // Update previousTab for Habits transition (Dashboard/Gallery use fixed positions)
                        previousTab = selectedTab
                        selectedTab = 2
                    }
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
            // No padding - positioned by parent HStack
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
