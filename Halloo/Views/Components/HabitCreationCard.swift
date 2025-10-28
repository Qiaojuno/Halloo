import SwiftUI

// MARK: - Habit Creation Card Component
/**
 * HABIT CREATION CARD: Custom white card popup for creating new habits
 *
 * PURPOSE: Replaces multi-step wizard with single-screen form in card format
 * DESIGN: White rounded card with shadow, slides up from bottom
 * SECTIONS: Profile selector, habit name, days, times, confirmation method
 *
 * USAGE:
 * ```swift
 * .overlay(
 *     HabitCreationCard(
 *         isPresented: $showingHabitCreation,
 *         preselectedProfileId: selectedProfileId,
 *         onDismiss: { showingHabitCreation = false }
 *     )
 * )
 * ```
 */
struct HabitCreationCard: View {
    @Binding var isPresented: Bool
    let preselectedProfileId: String?
    let onDismiss: () -> Void

    // Environment
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel

    // Form state
    @State private var selectedProfileId: String?
    @State private var habitName: String = ""
    @State private var selectedDays: Set<Int> = []
    @State private var selectedTimes: [Date] = []
    @State private var confirmationMethod: String = "" // "photo" or "text"
    @State private var showingTimePicker: Bool = false
    @State private var tempSelectedTime = Date()

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background overlay (tap to dismiss)
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                            onDismiss()
                        }
                    }
                    .transition(.opacity)
            }

            // White card popup
            VStack {
                Spacer()

                if isPresented {
                    cardContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(
                selectedTime: $tempSelectedTime,
                selectedTimes: $selectedTimes,
                isPresented: $showingTimePicker
            )
        }
        .onAppear {
            // Set preselected profile if provided
            if let profileId = preselectedProfileId {
                selectedProfileId = profileId
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // White card with scrollable content + button inside
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Profile Selector
                        profileSelectorSection

                        // Habit Name
                        habitNameSection

                        // Days of Week
                        daysSection

                        // Times
                        timesSection

                        // Confirmation Method
                        confirmationMethodSection

                        // Button inside card (scrollable)
                        if !isTextFieldFocused {
                            createButtonInside
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
            .padding(.horizontal, 16) // Match CreateActionCard
            .padding(.bottom, 90) // Position right above tab bar (same as CreateActionCard)
        }
    }

    // MARK: - Profile Selector Section
    private var profileSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHO IS THIS FOR?")
                .font(.custom("Inter", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "8E8E93"))
                .tracking(0.5)

            Menu {
                ForEach(appState.profiles) { profile in
                    Button(action: {
                        selectedProfileId = profile.id
                    }) {
                        Text(profile.name)
                    }
                }
            } label: {
                HStack {
                    if let profileId = selectedProfileId,
                       let profile = appState.profiles.first(where: { $0.id == profileId }) {
                        Text(profile.name)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                    } else {
                        Text("Select a profile")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: "f0f0f0"))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Habit Name Section
    private var habitNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S THE HABIT?")
                .font(.custom("Inter", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "8E8E93"))
                .tracking(0.5)

            ZStack(alignment: .leading) {
                TextField("", text: $habitName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(hex: "f0f0f0"))
                    .cornerRadius(12)

                if habitName.isEmpty {
                    Text("e.g., take medication")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Days Section
    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHICH DAYS?")
                .font(.custom("Inter", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "8E8E93"))
                .tracking(0.5)

            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    Button(action: {
                        if selectedDays.contains(index) {
                            selectedDays.remove(index)
                        } else {
                            selectedDays.insert(index)
                        }
                    }) {
                        Text(["S", "M", "T", "W", "T", "F", "S"][index])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(selectedDays.contains(index) ? Color.black : Color(hex: "e0e0e0"))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Times Section
    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT TIMES?")
                .font(.custom("Inter", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "8E8E93"))
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(Array(selectedTimes.enumerated()), id: \.offset) { index, time in
                    HStack {
                        Text("•")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)

                        Text(formatTime(time))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)

                        Spacer()

                        Button(action: {
                            selectedTimes.remove(at: index)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "9f9f9f"))
                                .frame(width: 24, height: 24)
                        }
                    }
                    .frame(height: 44)
                }

                Button(action: {
                    showingTimePicker = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .regular))
                        Text("Add Time")
                            .font(.system(size: 16, weight: .regular))
                    }
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Confirmation Method Section
    private var confirmationMethodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW TO CONFIRM?")
                .font(.custom("Inter", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "8E8E93"))
                .tracking(0.5)

            HStack(spacing: 12) {
                // Photo Option
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    confirmationMethod = "photo"
                }) {
                    VStack(spacing: 12) {
                        Text("📷")
                            .font(.system(size: 40))
                        Text("Photo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .background(confirmationMethod == "photo" ? Color(hex: "B9E3FF") : Color(hex: "F5F5F5"))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(confirmationMethod == "photo" ? Color.black : Color.clear, lineWidth: 2)
                    )
                }

                // Text Option
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    confirmationMethod = "text"
                }) {
                    VStack(spacing: 12) {
                        Text("💬")
                            .font(.system(size: 40))
                        Text("Text")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .background(confirmationMethod == "text" ? Color(hex: "B9E3FF") : Color(hex: "F5F5F5"))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(confirmationMethod == "text" ? Color.black : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }

    // MARK: - Create Button (Inside Card)
    private var createButtonInside: some View {
        Button(action: handleCreateHabit) {
            Text("Create Habit")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canCreate ? Color.black : Color.gray.opacity(0.3))
                .cornerRadius(15)
        }
        .disabled(!canCreate)
        .padding(.bottom, 4) // Small bottom padding inside card
    }

    // MARK: - Validation
    private var canCreate: Bool {
        !habitName.isEmpty &&
        selectedProfileId != nil &&
        !selectedDays.isEmpty &&
        !selectedTimes.isEmpty &&
        !confirmationMethod.isEmpty
    }

    // MARK: - Actions
    private func handleCreateHabit() {
        guard canCreate else { return }
        guard let profileId = selectedProfileId else { return }
        guard let profile = appState.profiles.first(where: { $0.id == profileId }) else { return }

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Transfer data to TaskViewModel
        taskViewModel.selectedProfile = profile
        taskViewModel.taskTitle = habitName
        taskViewModel.taskCategory = .medication
        taskViewModel.frequency = .custom
        taskViewModel.scheduledTimes = selectedTimes
        taskViewModel.customDays = convertDaysToWeekdays(selectedDays)

        // Set confirmation method
        if confirmationMethod == "photo" {
            taskViewModel.requiresPhoto = true
            taskViewModel.requiresText = false
        } else {
            taskViewModel.requiresPhoto = false
            taskViewModel.requiresText = true
        }

        // Clear time error (debounced validation issue)
        if !taskViewModel.scheduledTimes.isEmpty {
            taskViewModel.timeError = nil
        }

        // Create task
        taskViewModel.createTask()

        // Dismiss card
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }

        // Call dismiss callback after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    // MARK: - Helper Functions
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func convertDaysToWeekdays(_ days: Set<Int>) -> Set<Weekday> {
        Set(days.compactMap { dayIndex in
            switch dayIndex {
            case 0: return .sunday
            case 1: return .monday
            case 2: return .tuesday
            case 3: return .wednesday
            case 4: return .thursday
            case 5: return .friday
            case 6: return .saturday
            default: return nil
            }
        })
    }
}

// MARK: - Preview
// Note: TimePickerSheet is defined in TaskViews.swift and reused here
#Preview {
    ZStack {
        Color(hex: "f9f9f9")
            .ignoresSafeArea()

        HabitCreationCard(
            isPresented: .constant(true),
            preselectedProfileId: nil,
            onDismiss: { print("Dismissed") }
        )
        .environmentObject(AppState(
            authService: Container.shared.resolve(AuthenticationServiceProtocol.self),
            databaseService: Container.shared.resolve(DatabaseServiceProtocol.self),
            dataSyncCoordinator: Container.shared.resolve(DataSyncCoordinator.self),
            imageCache: Container.shared.resolve(ImageCacheService.self)
        ))
        .environmentObject(ProfileViewModel(
            databaseService: Container.shared.resolve(DatabaseServiceProtocol.self),
            smsService: Container.shared.resolve(SMSServiceProtocol.self),
            authService: Container.shared.resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: Container.shared.resolve(DataSyncCoordinator.self)
        ))
        .environmentObject(Container.shared.makeTaskViewModel())
    }
}
