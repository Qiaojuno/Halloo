import SwiftUI
import UIKit

/**
 * HABITS VIEW - Habit Management Screen
 *
 * PURPOSE: Allows users to view and manage all scheduled habits across all profiles.
 * Provides filtering by days of the week and swipe-to-delete functionality.
 *
 * KEY FEATURES:
 * - Reuses profile selection from Dashboard for consistency
 * - Week selector for filtering habits by scheduled days
 * - Swipe-to-delete with day-specific deletion capability
 * - Maintains same design language as rest of app
 *
 * NAVIGATION: Accessed via middle tab (bookmark icon) in floating pill navigation
 */
struct HabitsView: View {

    // MARK: - Environment & Dependencies
    @Environment(\.container) private var container
    @Environment(\.isScrollDisabled) private var isScrollDisabled
    @Environment(\.isDragging) private var isDragging

    // PHASE 3: Single source of truth for all shared state
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    // MARK: - Navigation State
    @Binding var selectedTab: Int

    /// Controls whether to show header (false when rendered in ContentView's layered architecture)
    var showHeader: Bool = true

    /// Controls whether to show bottom navigation (false when rendered in ContentView's layered architecture)
    var showNav: Bool = true
    
    // MARK: - UI State Management
    @State private var selectedProfileIndex: Int = 0
    @State private var selectedDays: Set<Int> = Set(0...6) // Default to all days selected
    
    /// Controls TaskCreationView conditional presentation with profile preselection
    @State private var showingTaskCreation = false
    
    /// Controls direct ProfileOnboardingFlow presentation
    @State private var showingDirectOnboarding = false
    
    /// Controls action sheet for unified create button
    @State private var showingCreateActionSheet = false

    /// Controls delete confirmation alert for habits
    @State private var showingDeleteConfirmation = false
    @State private var habitToDelete: Task?

    /// Controls delete confirmation alert for profiles
    @State private var showingProfileDeleteConfirmation = false

    /// Track habits pending deletion (waiting for user confirmation)
    @State private var habitsPendingDeletion: Set<String> = []

    /// Track locally deleted habit IDs for optimistic UI updates
    @State private var locallyDeletedHabitIds: Set<String> = []

    /// Tab transition state (for BottomGradientNavigation)
    @State private var previousTab: Int = 0
    @State private var transitionDirection: Int = 1
    @State private var isTransitioning: Bool = false

    /// Delete button cooldown to prevent accidental taps
    @State private var isDeleteButtonCoolingDown = false

    /// Persistent TaskViewModel instance (prevents recreation on re-render)
    @State private var taskViewModel: TaskViewModel?

    /// Force view refresh when tasks change
    @State private var refreshID = UUID()

    // Days of the week for display
    private let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
    private let weekDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
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
        } else if showingTaskCreation, let taskVM = taskViewModel {
            // Show task creation flow with persistent ViewModel
            TaskCreationView(
                preselectedProfileId: selectedProfile?.id,
                dismissAction: {
                    showingTaskCreation = false
                }
            )
            .environmentObject(taskVM)
            .transition(.identity)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        } else {
            // Show habits view - NO .transition() here, let parent control it
            habitsContent
                .onAppear {
                    // Initialize TaskViewModel once
                    if taskViewModel == nil {
                        print("🔴 [HabitsView] Creating TaskViewModel instance")
                        taskViewModel = container.makeTaskViewModel()
                        // Load all tasks for the authenticated user
                        taskViewModel?.loadTasks()
                    }
                }
                .onChange(of: taskViewModel?.tasks.count) { newCount in
                    print("🔄 [HabitsView] Tasks count changed to: \(newCount ?? 0)")
                    // Force view refresh by updating a local state
                    refreshID = UUID()
                }
                .id(refreshID) // Force refresh when refreshID changes
        }
    }
    
    private var habitsContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 10) { // Match DashboardView spacing

                        // 🏠 HEADER: App branding + account access (conditionally rendered)
                        if showHeader {
                            headerSection
                        }

                        // 📋 HABITS MANAGEMENT: All scheduled tasks with filtering and deletion
                        allScheduledTasksSection
                            .padding(.top, showHeader ? 0 : 100) // Add top padding when header is hidden (static header height)

                        // 🗑️ DELETE PROFILE BUTTON: Remove profile and all associated habits
                        deleteProfileButton

                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // Match DashboardView
                }
                .scrollDisabled(isScrollDisabled)
                .background(Color(hex: "f9f9f9")) // Light gray app background

                // Reusable bottom gradient navigation (no create button) (conditionally rendered)
                if showNav {
                    BottomGradientNavigation(selectedTab: $selectedTab, previousTab: $previousTab, transitionDirection: $transitionDirection, isTransitioning: $isTransitioning)
                }
            }
        }
        .onAppear {
            // PHASE 3: Sync selectedProfileIndex with ViewModel's selectedProfileId when view appears
            if let selectedId = viewModel.selectedProfileId,
               let index = appState.profiles.firstIndex(where: { $0.id == selectedId }) {
                selectedProfileIndex = index
            } else {
                print("⚠️ [HabitsView] Could not sync selectedProfileIndex - profile selection may be out of sync")
            }

            // Trigger initial cooldown if user is already on Habits tab
            if selectedTab == 2 {
                withAnimation {
                    isDeleteButtonCoolingDown = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isDeleteButtonCoolingDown = false
                    }
                }
            }

            loadData()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Start delete button cooldown when switching TO Habits tab (index 2)
            if newValue == 2 {
                withAnimation {
                    isDeleteButtonCoolingDown = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isDeleteButtonCoolingDown = false
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedProfileId) { newProfileId in
            // PHASE 3: Sync selectedProfileIndex when ViewModel auto-selects a profile
            if let newId = newProfileId,
               let index = appState.profiles.firstIndex(where: { $0.id == newId }) {
                selectedProfileIndex = index
            }
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation, presenting: habitToDelete) { habit in
            Button("Cancel", role: .cancel) {
                // Remove from pending deletion if user cancels
                habitsPendingDeletion.remove(habit.id)
                habitToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteHabit()
            }
        } message: { habit in
            Text("Are you sure you want to delete '\(habit.title)' scheduled \(formatHabitSchedule(habit: habit))?")
        }
    }
    
    // MARK: - 🏠 Header Section
    private var headerSection: some View {
        SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
    }
    
    
    // MARK: - 📋 All Scheduled Tasks Section
    private var allScheduledTasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section title inside card
            HStack {
                Text("All Scheduled Tasks")
                    .font(AppFonts.poppinsMedium(size: 15))
                    .tracking(-1)
                    .foregroundColor(Color(hex: "9f9f9f"))
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                Spacer()
            }
            
            // Week selector
            weekSelectorSection
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            
            // Divider line
            Divider()
                .overlay(Color(hex: "f8f3f3"))
                .padding(.horizontal, 12)
            
            // Habits list
            habitsListSection
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Week Selector Component (Matches Create Habit View)
    private var weekSelectorSection: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    Text(weekDays[dayIndex])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "0D0C0C")) // Dark text for both states
                        .frame(width: (geometry.size.width / 7), height: 39) // Responsive width, fixed height
                        .background(
                            Circle()
                                .fill(Color.clear) // Always clear background
                                .frame(width: 39, height: 39) // Keep circle size consistent
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedDays.contains(dayIndex) ? Color.black : Color(hex: "D5D5D5"), lineWidth: 1) // Black stroke when selected, gray stroke when not
                                .frame(width: 39, height: 39) // Keep circle size consistent
                        )
                        .contentShape(Circle())
                        .onTapGesture {
                            if selectedDays.contains(dayIndex) {
                                selectedDays.remove(dayIndex)
                            } else {
                                selectedDays.insert(dayIndex)
                            }
                        }
                }
            }
        }
        .frame(height: 39)
    }
    
    // MARK: - Habits List Section
    private var habitsListSection: some View {
        Group {
            if filteredHabits.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    Text("No habits scheduled for selected days")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredHabits, id: \.id) { habit in
                        HabitRowViewSimple(
                            habit: habit,
                            profile: getProfileForHabit(habit),
                            selectedDays: selectedDays
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.white)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteHabitFromSelectedDays(habit: habit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .overlay(
                            VStack {
                                Spacer()
                                if habit.id != filteredHabits.last?.id {
                                    Divider()
                                        .overlay(Color(hex: "f8f3f3"))
                                        .padding(.horizontal, 4)
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(filteredHabits.count) * 90) // Increased for multi-line titles
                .animation(.easeInOut(duration: 0.3), value: selectedDays)
            }
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Computed Properties

    /// PHASE 3: Selected profile accessor - Use AppState as single source of truth
    private var selectedProfile: ElderlyProfile? {
        guard selectedProfileIndex < appState.profiles.count else { return nil }
        return appState.profiles[selectedProfileIndex]
    }
    
    /// Filtered habits based on selected profile and days
    private var filteredHabits: [Task] {
        // Get all tasks from TaskViewModel (not just today's tasks)
        guard let taskVM = taskViewModel else { return [] }
        let allTasks = taskVM.tasks

        return allTasks.filter { habit in
            // Exclude locally deleted habits for optimistic UI
            guard !locallyDeletedHabitIds.contains(habit.id) else { return false }

            // Filter by selected profile (match DashboardView behavior)
            guard let selectedProfileId = viewModel.selectedProfileId else { return false }
            guard habit.profileId == selectedProfileId else { return false }

            // Check if habit is scheduled for any of the selected days
            return selectedDays.contains { dayIndex in
                let weekday = Weekday.fromIndex(dayIndex)
                return habit.frequency == .daily || habit.customDays.contains(weekday)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() {
        viewModel.loadDashboardData()
    }
    
    private func getProfileForHabit(_ habit: Task) -> ElderlyProfile? {
        // PHASE 3: Use AppState as single source of truth
        return appState.profiles.first { $0.id == habit.profileId }
    }
    
    private func deleteHabitFromSelectedDays(habit: Task) {
        // Mark as pending deletion (prevents List from auto-animating)
        habitsPendingDeletion.insert(habit.id)

        // Store habit and show confirmation alert
        habitToDelete = habit
        showingDeleteConfirmation = true
    }

    private func confirmDeleteHabit() {
        guard let habit = habitToDelete else { return }

        print("🗑️ Deleting habit '\(habit.title)' (ID: \(habit.id))")

        // Remove from pending deletion
        habitsPendingDeletion.remove(habit.id)

        // Optimistic UI update: immediately remove from local state with iOS-native spring animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            locallyDeletedHabitIds.insert(habit.id)
        }

        // Trigger haptic feedback immediately for responsiveness
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Perform database deletion in background
        _Concurrency.Task {
            do {
                // Delete habit from database with userId and profileId
                try await container.resolve(DatabaseServiceProtocol.self)
                    .deleteTask(habit.id, userId: habit.userId, profileId: habit.profileId)

                print("✅ Habit deleted successfully")

                // Reload data to sync with server (without animation since UI already updated)
                await MainActor.run {
                    viewModel.loadDashboardData()
                }

            } catch {
                print("❌ Failed to delete habit: \(error.localizedDescription)")

                // Revert optimistic update on error with spring animation
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        locallyDeletedHabitIds.remove(habit.id)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }

        // Clear state
        habitToDelete = nil
    }

    private func formatHabitSchedule(habit: Task) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let time = timeFormatter.string(from: habit.scheduledTime)

        let days: String
        switch habit.frequency {
        case .daily:
            days = "Every day"
        case .weekdays:
            days = "Weekdays (Mon-Fri)"
        case .weekly:
            let weekday = Calendar.current.component(.weekday, from: habit.scheduledTime)
            let dayName = weekDayNames[weekday - 1]
            days = "Every \(dayName)"
        case .custom:
            if habit.customDays.isEmpty {
                days = "No days selected"
            } else {
                let dayNames = habit.customDays.map { $0.displayName }
                days = dayNames.joined(separator: ", ")
            }
        case .once:
            days = "One time"
        }

        return "at \(time) on \(days)"
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
    private var unifiedCreateButton: some View {
        Button(action: {
            // Haptic feedback for create action
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            showingCreateActionSheet = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 61, height: 61) // Updated to match user requirements
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
    
    // MARK: - 🗑️ Delete Profile Button
    /**
     * DELETE PROFILE BUTTON: Removes selected profile and all habits
     *
     * PURPOSE: Allow users to delete profiles to test Twilio SMS integration
     * Displays at bottom of habits list
     * Shows profile name and habit count in confirmation dialog
     */
    private var deleteProfileButton: some View {
        Button(action: {
            guard !isDeleteButtonCoolingDown else {
                return
            }

            // Haptic feedback for delete action
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            showingProfileDeleteConfirmation = true
        }) {
            HStack {
                if isDeleteButtonCoolingDown {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "9f9f9f")))
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }

                Text("Delete Profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDeleteButtonCoolingDown ? Color(hex: "9f9f9f") : .red)

                Spacer()  // Push content to the left
            }
            .frame(maxWidth: .infinity, minHeight: 47)
            .padding(.horizontal, 16)  // Add horizontal padding for left alignment
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            .opacity(isDeleteButtonCoolingDown ? 0.6 : 1.0)
        }
        .disabled(isDeleteButtonCoolingDown)
        .alert("Delete Profile", isPresented: $showingProfileDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                confirmDeleteProfile()
            }
        } message: {
            if let profile = selectedProfile {
                let habitCount = filteredHabits.count
                Text("Are you sure you want to delete '\(profile.name)' and all \(habitCount) associated habit\(habitCount == 1 ? "" : "s")? This action cannot be undone.")
            } else {
                Text("No profile selected.")
            }
        }
    }

    // MARK: - Profile Deletion Logic
    private func confirmDeleteProfile() {
        guard let profile = selectedProfile else {
            return
        }

        // Trigger haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Call ProfileViewModel to delete profile (recursive deletion of habits)
        profileViewModel.deleteProfile(profile)

        // Reset selected profile index to 0 after deletion
        selectedProfileIndex = 0
    }

    // MARK: - Helper Properties
    // selectedProfile is already defined earlier in the file
}

// MARK: - Habit Row With Custom Swipe
struct HabitRowWithCustomSwipe: View {
    let habit: Task
    let profile: ElderlyProfile?
    let selectedDays: Set<Int>
    let isLastItem: Bool
    let onDelete: () -> Void

    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed: Bool = false

    private let deleteButtonWidth: CGFloat = 80
    private let swipeThreshold: CGFloat = 50

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background (always present, revealed by drag)
            HStack {
                Spacer()
                Button(action: {
                    // Don't animate here - just trigger delete confirmation
                    onDelete()
                    // Keep button revealed until user confirms/cancels
                }) {
                    ZStack {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: deleteButtonWidth)

                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxHeight: .infinity)
            }

            // Main content that slides
            VStack(spacing: 0) {
                HabitRowViewSimple(
                    habit: habit,
                    profile: profile,
                    selectedDays: selectedDays
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Divider
                if !isLastItem {
                    Divider()
                        .overlay(Color(hex: "f8f3f3"))
                        .padding(.horizontal, 4)
                }
            }
            .background(Color.white)
            .offset(x: dragOffset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let translation = value.translation.width
                        let verticalTranslation = abs(value.translation.height)
                        let horizontalTranslation = abs(translation)

                        // Require swipe to be STRONGLY horizontal (3x more horizontal than vertical)
                        // This prevents accidental tab switching while allowing scroll
                        guard horizontalTranslation > verticalTranslation * 3 else { return }

                        // Only allow left swipe
                        if translation < 0 {
                            dragOffset = max(translation, -deleteButtonWidth)
                        } else if isRevealed {
                            // Allow closing if already revealed
                            dragOffset = min(0, -deleteButtonWidth + translation)
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let verticalTranslation = abs(value.translation.height)
                        let horizontalTranslation = abs(translation)

                        // Require swipe to be STRONGLY horizontal
                        guard horizontalTranslation > verticalTranslation * 3 else { return }

                        withAnimation(.easeOut(duration: 0.25)) {
                            if translation < -swipeThreshold {
                                // Reveal delete button
                                dragOffset = -deleteButtonWidth
                                isRevealed = true
                            } else {
                                // Close
                                dragOffset = 0
                                isRevealed = false
                            }
                        }
                    }
            )
        }
    }
}

// MARK: - Simplified Habit Row View Component
struct HabitRowViewSimple: View {
    let habit: Task
    let profile: ElderlyProfile?
    let selectedDays: Set<Int>

    // PHASE 3: Need appState for profile slot calculation
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            if let profile = profile {
                ProfileImageView.custom(
                    profile: profile,
                    profileSlot: profileSlot,
                    isSelected: false,
                    size: 32
                )
            }

            // Task Details with mini week strip
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.name ?? "")
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(-0.25)
                    .foregroundColor(.black)

                // Habit title and time on same row with dot separator
                HStack(spacing: 4) {
                    Text(habit.title)
                        .font(.custom("Inter", size: 13))
                        .fontWeight(.regular)
                        .tracking(-0.5)
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Text("•")
                        .font(.custom("Inter", size: 13))
                        .foregroundColor(.black)

                    Text(formatTime(habit.scheduledTime))
                        .font(.custom("Inter", size: 13))
                        .fontWeight(.regular)
                        .tracking(-0.5)
                        .foregroundColor(.black)
                }

                // Mini week strip - only show scheduled days
                miniWeekStrip
            }

            Spacer()
        }
    }

    // MARK: - Mini Week Strip (Only Scheduled Days)
    private var miniWeekStrip: some View {
        let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
        let scheduledDays = getScheduledDays()

        return HStack(spacing: 4) {
            ForEach(scheduledDays, id: \.self) { dayIndex in
                Text(weekDays[dayIndex])
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9f9f9f"))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(Color.clear)
                    )
            }
        }
    }

    /// Returns array of day indices (0-6) that the habit is scheduled for
    private func getScheduledDays() -> [Int] {
        switch habit.frequency {
        case .daily:
            return [0, 1, 2, 3, 4, 5, 6] // All days
        case .weekdays:
            return [1, 2, 3, 4, 5] // Mon-Fri
        case .weekly:
            let taskWeekday = Calendar.current.component(.weekday, from: habit.scheduledTime)
            return [taskWeekday - 1] // Single day
        case .custom:
            return habit.customDays.map { $0.toIndex() }.sorted()
        case .once:
            return [] // No recurring days
        }
    }

    private var profileSlot: Int {
        guard let profile = profile else { return 0 }
        // PHASE 3: Use AppState for profile slot calculation
        return appState.profiles.firstIndex(where: { $0.id == profile.id }) ?? 0
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Weekday Helper Extensions
extension Weekday {
    static func fromIndex(_ index: Int) -> Weekday {
        switch index {
        case 0: return .sunday
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        default: return .sunday
        }
    }
    
    func toIndex() -> Int {
        switch self {
        case .sunday: return 0
        case .monday: return 1
        case .tuesday: return 2
        case .wednesday: return 3
        case .thursday: return 4
        case .friday: return 5
        case .saturday: return 6
        }
    }
}