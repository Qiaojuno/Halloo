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
    
    // Days of the week for display
    private let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
    private let weekDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 10) { // Match DashboardView spacing
                        
                        // 🏠 HEADER: App branding + account access
                        headerSection
                        
                        // 👥 PROFILES: Elderly family member selection (reused from Dashboard)
                        profilesSection
                        
                        // 📋 HABITS MANAGEMENT: All scheduled tasks with filtering and deletion
                        allScheduledTasksSection
                        
                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // Match DashboardView
                }
                .background(Color(hex: "f9f9f9")) // Light gray app background
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    bottomTabNavigation
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - 🧭 Bottom Tab Navigation
    private var bottomTabNavigation: some View {
        FloatingPillNavigation(selectedTab: $selectedTab)
    }
    
    // MARK: - 🏠 Header Section
    private var headerSection: some View {
        SharedHeaderSection()
    }
    
    // MARK: - 👥 Profiles Section (Reused from Dashboard)
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROFILES:")
                .font(.system(size: 15, weight: .bold))
                .tracking(-1)
                .foregroundColor(Color(hex: "9f9f9f"))
            
            HStack(spacing: 12) {
                ForEach(Array(viewModel.profiles.enumerated()), id: \.offset) { index, profile in
                    ProfileImageView(
                        profile: profile,
                        profileSlot: index,
                        isSelected: selectedProfileIndex == index
                    )
                    .onTapGesture {
                        selectedProfileIndex = index
                        if index < viewModel.profiles.count {
                            viewModel.selectProfile(profileId: viewModel.profiles[index].id)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
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
        HStack(spacing: 8) {
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
                        .foregroundColor(selectedDays.contains(dayIndex) ? .white : Color(hex: "0D0C0C")) // White text when selected, dark when not
                        .frame(width: 39, height: 39) // FIGMA SPEC: 39x39
                        .background(
                            Circle()
                                .fill(selectedDays.contains(dayIndex) ? Color(hex: "28ADFF") : Color.clear) // Blue fill when selected, clear when not
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedDays.contains(dayIndex) ? Color.clear : Color(hex: "D5D5D5"), lineWidth: 1) // No stroke when selected, gray stroke when not
                        )
                }
            }
            Spacer()
        }
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
                ForEach(Array(filteredHabits.enumerated()), id: \.offset) { index, habit in
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
                    
                    if index < filteredHabits.count - 1 {
                        Divider()
                            .overlay(Color(hex: "f8f3f3"))
                            .padding(.horizontal, 24) // Match dashboard spacing exactly
                    }
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
        return sampleHabits.filter { habit in
            // Check if habit is scheduled for any of the selected days
            return selectedDays.contains { dayIndex in
                let weekday = Weekday.fromIndex(dayIndex)
                return habit.frequency == .daily || habit.customDays.contains(weekday)
            }
        }
    }
    
    /// Sample habits for development (TODO: Replace with real data)
    private var sampleHabits: [Task] {
        return [
            Task(
                id: "habit1",
                userId: "demo-user",
                profileId: selectedProfile?.id ?? "",
                title: "Take Morning Medication",
                description: "Daily pills after breakfast",
                category: .medication,
                frequency: .custom,
                scheduledTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
                deadlineMinutes: 30,
                requiresPhoto: true,
                requiresText: false,
                customDays: [.monday, .wednesday, .friday],
                startDate: Date(),
                endDate: nil,
                status: .active,
                notes: "",
                createdAt: Date(),
                lastModifiedAt: Date(),
                completionCount: 0,
                lastCompletedAt: nil,
                nextScheduledDate: Date()
            ),
            Task(
                id: "habit2",
                userId: "demo-user",
                profileId: selectedProfile?.id ?? "",
                title: "Evening Walk",
                description: "30-minute walk around the neighborhood",
                category: .exercise,
                frequency: .daily,
                scheduledTime: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date(),
                deadlineMinutes: 60,
                requiresPhoto: true,
                requiresText: false,
                customDays: [],
                startDate: Date(),
                endDate: nil,
                status: .active,
                notes: "",
                createdAt: Date(),
                lastModifiedAt: Date(),
                completionCount: 0,
                lastCompletedAt: nil,
                nextScheduledDate: Date()
            ),
            Task(
                id: "habit3",
                userId: "demo-user",
                profileId: selectedProfile?.id ?? "",
                title: "Water Plants",
                description: "Water the garden plants",
                category: .other,
                frequency: .custom,
                scheduledTime: Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date()) ?? Date(),
                deadlineMinutes: 15,
                requiresPhoto: false,
                requiresText: true,
                customDays: [.monday, .thursday],
                startDate: Date(),
                endDate: nil,
                status: .active,
                notes: "",
                createdAt: Date(),
                lastModifiedAt: Date(),
                completionCount: 0,
                lastCompletedAt: nil,
                nextScheduledDate: Date()
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func loadData() {
        viewModel.loadDashboardData()
    }
    
    private func getProfileForHabit(_ habit: Task) -> ElderlyProfile? {
        return viewModel.profiles.first { $0.id == habit.profileId }
    }
    
    private func deleteHabitFromSelectedDays(habit: Task) {
        let selectedDayNames = selectedDays.map { weekDayNames[$0] }.joined(separator: ", ")
        print("🗑️ Deleting habit '\(habit.title)' from selected days: \(selectedDayNames)")
        
        // TODO: Implement real day-specific deletion logic
        // This would require updating the TaskViewModel to support:
        // 1. Removing selected weekdays from habit.customDays
        // 2. If no days left, delete entire habit
        // 3. Update database through ViewModel
        // 4. Refresh UI automatically through @Published properties
        
        // For now, just show feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Simplified Habit Row View Component  
struct HabitRowViewSimple: View {
    let habit: Task
    let profile: ElderlyProfile?
    let selectedDays: Set<Int>
    let onDelete: () -> Void
    
    @State private var dragOffset: CGFloat = 0
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
                        if value.translation.width < 0 { // Only allow left swipe
                            dragOffset = max(value.translation.width, -deleteButtonWidth)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -50 {
                                dragOffset = -deleteButtonWidth
                            } else {
                                dragOffset = 0
                            }
                        }
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