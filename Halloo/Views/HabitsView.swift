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
    @EnvironmentObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    // MARK: - Navigation State
    @Binding var selectedTab: Int
    
    // MARK: - UI State Management
    @State private var selectedProfileIndex: Int = 0
    @State private var selectedDays: Set<Int> = Set(0...6) // Default to all days selected
    
    /// Controls TaskCreationView conditional presentation with profile preselection
    @State private var showingTaskCreation = false
    
    /// Controls direct ProfileOnboardingFlow presentation
    @State private var showingDirectOnboarding = false
    
    /// Controls action sheet for unified create button
    @State private var showingCreateActionSheet = false

    /// Controls delete confirmation alert
    @State private var showingDeleteConfirmation = false
    @State private var habitToDelete: Task?

    /// Track locally deleted habit IDs for optimistic UI updates
    @State private var locallyDeletedHabitIds: Set<String> = []

    // Days of the week for display
    private let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
    private let weekDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        Group {
            if showingDirectOnboarding {
                // ✅ NEW: Simplified single-card profile creation
                SimplifiedProfileCreationView(onDismiss: {
                    showingDirectOnboarding = false
                })
                .environmentObject(profileViewModel)
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
                // Show habits view
                habitsContent
                    .transition(.identity)
                    .animation(nil, value: showingDirectOnboarding)
                    .animation(nil, value: showingTaskCreation)
            }
        }
    }
    
    private var habitsContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 10) { // Match DashboardView spacing

                        // 🏠 HEADER: App branding + account access
                        headerSection

                        // 📋 HABITS MANAGEMENT: All scheduled tasks with filtering and deletion
                        allScheduledTasksSection

                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // Match DashboardView
                }
                .background(Color(hex: "f9f9f9")) // Light gray app background

                // Reusable bottom gradient navigation (no create button)
                BottomGradientNavigation(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            loadData()
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation, presenting: habitToDelete) { habit in
            Button("Cancel", role: .cancel) {
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
                Text("ALL SCHEDULED TASKS")
                    .font(.system(size: 15, weight: .bold))
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
                    Button(action: {
                        if selectedDays.contains(dayIndex) {
                            selectedDays.remove(dayIndex)
                        } else {
                            selectedDays.insert(dayIndex)
                        }
                    }) {
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
                    }
                }
            }
        }
        .frame(height: 39)
    }
    
    // MARK: - Habits List Section
    private var habitsListSection: some View {
        VStack(spacing: 0) {
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
                ForEach(filteredHabits, id: \.id) { habit in
                    HabitRowViewSimple(
                        habit: habit,
                        profile: getProfileForHabit(habit),
                        selectedDays: selectedDays,
                        onDelete: {
                            deleteHabitFromSelectedDays(habit: habit)
                        }
                    )
                    .padding(.horizontal, 20) // Match dashboard completed tasks padding exactly
                    .padding(.vertical, 12) // Match dashboard completed tasks padding exactly
                    .background(Color.white) // Each habit has white background like dashboard
                    .overlay(
                        // Divider at bottom if not last item
                        VStack {
                            Spacer()
                            if habit.id != filteredHabits.last?.id {
                                Divider()
                                    .overlay(Color(hex: "f8f3f3"))
                                    .padding(.horizontal, 4) // Relative padding since we're inside the padded view
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Computed Properties
    
    /// Selected profile accessor
    private var selectedProfile: ElderlyProfile? {
        guard selectedProfileIndex < viewModel.profiles.count else { return nil }
        return viewModel.profiles[selectedProfileIndex]
    }
    
    /// Filtered habits based on selected profile and days
    private var filteredHabits: [Task] {
        // Get all unique tasks from the ViewModel (today's tasks contain all active tasks)
        let allTasks = viewModel.todaysTasks.map { $0.task }

        return allTasks.filter { habit in
            // Exclude locally deleted habits for optimistic UI
            guard !locallyDeletedHabitIds.contains(habit.id) else { return false }

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
        return viewModel.profiles.first { $0.id == habit.profileId }
    }
    
    private func deleteHabitFromSelectedDays(habit: Task) {
        // Store habit and show confirmation alert
        habitToDelete = habit
        showingDeleteConfirmation = true
    }

    private func confirmDeleteHabit() {
        guard let habit = habitToDelete else { return }

        print("🗑️ Deleting habit '\(habit.title)' (ID: \(habit.id))")

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
    
    // MARK: - Helper Properties
    // selectedProfile is already defined earlier in the file
}

// MARK: - Simplified Habit Row View Component
struct HabitRowViewSimple: View {
    let habit: Task
    let profile: ElderlyProfile?
    let selectedDays: Set<Int>
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally: Bool? = nil
    private let deleteButtonWidth: CGFloat = 80

    var body: some View {
        ZStack {
            // Delete button background (red) - Single delete button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: deleteButtonWidth)
                        .frame(maxHeight: .infinity) // This will match the TaskRowView height exactly
                        .background(Color.red)
                }
            }

            // Reuse TaskRowView from Dashboard
            TaskRowView(
                task: habit,
                profile: profile,
                showViewButton: false,
                onViewButtonTapped: nil
            )
            .background(Color.white)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Determine drag direction on first movement
                        if isDraggingHorizontally == nil {
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)

                            // Only treat as horizontal if horizontal movement is significantly larger
                            isDraggingHorizontally = horizontalAmount > verticalAmount && horizontalAmount > 10
                        }

                        // Only respond to horizontal drags
                        if isDraggingHorizontally == true && value.translation.width < 0 {
                            dragOffset = max(value.translation.width, -deleteButtonWidth)
                        }
                    }
                    .onEnded { value in
                        // Only process if it was a horizontal drag
                        if isDraggingHorizontally == true {
                            withAnimation(.spring()) {
                                if value.translation.width < -50 {
                                    dragOffset = -deleteButtonWidth
                                } else {
                                    dragOffset = 0
                                }
                            }
                        }

                        // Reset drag direction state
                        isDraggingHorizontally = nil
                    }
            )
        }
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