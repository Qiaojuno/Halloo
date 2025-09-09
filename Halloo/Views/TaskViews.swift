import SwiftUI

// MARK: - Task Views
// Component-based architecture for Task-related UI

// MARK: - Task Creation View (Multi-Step Flow)
struct TaskCreationView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    let preselectedProfileId: String? // Profile ID to preselect for task creation
    
    init(preselectedProfileId: String? = nil) {
        self.preselectedProfileId = preselectedProfileId
    }
    
    var body: some View {
        NavigationView {
            CustomHabitCreationFlow(
                viewModel: viewModel,
                onDismiss: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            // Set preselected profile when view appears
            if let profileId = preselectedProfileId {
                viewModel.preselectProfile(profileId: profileId)
            }
        }
    }
}

// MARK: - Multi-Step Custom Habit Creation Flow (UNIFIED NAVIGATION LIKE PROFILEVIEWS)
struct CustomHabitCreationFlow: View {
    @ObservedObject var viewModel: TaskViewModel
    let onDismiss: () -> Void
    
    @State private var currentStep = 1
    @State private var habitName = ""
    @State private var selectedDays: Set<Int> = []
    @State private var selectedTimes: [Date] = []
    @State private var confirmationMethod = ""
    @State private var buttonWidth: CGFloat = 0 // Store button width from Step 1
    @State private var showingTimePicker = false
    @State private var tempSelectedTime = Date()
    
    var body: some View {
        if currentStep == 1 {
            Step1_HabitForm(
                habitName: $habitName,
                selectedDays: $selectedDays,
                selectedTimes: $selectedTimes,
                showingTimePicker: $showingTimePicker,
                tempSelectedTime: $tempSelectedTime,
                onNext: { currentStep = 2 },
                onDismiss: onDismiss,
                onButtonWidthCapture: { width in
                    buttonWidth = width
                }
            )
        } else {
            Step2_ConfirmationMethod(
                habitName: habitName,
                confirmationMethod: $confirmationMethod,
                capturedButtonWidth: buttonWidth,
                onBack: { currentStep = 1 },
                onCreate: { createHabit() }
            )
        }
    }
    
    // MARK: - Step 1: Habit Form (COPIED FROM PROFILEVIEWS STRUCTURE)
struct Step1_HabitForm: View {
    @Binding var habitName: String
    @Binding var selectedDays: Set<Int>
    @Binding var selectedTimes: [Date]
    @Binding var showingTimePicker: Bool
    @Binding var tempSelectedTime: Date
    let onNext: () -> Void
    let onDismiss: () -> Void
    let onButtonWidthCapture: (CGFloat) -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar - FIXED WIDTH to ignore card constraints
            HStack {
                Spacer()
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .light))
                        }
                    }
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Remi Logo (centered between functional buttons)
                    Text("Remi")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-1.9)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: {
                        if !habitName.isEmpty && !selectedDays.isEmpty && !selectedTimes.isEmpty {
                            onNext()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Next")
                                .font(.system(size: 16, weight: .light))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor(.gray)
                    .disabled(habitName.isEmpty || selectedDays.isEmpty || selectedTimes.isEmpty)
                }
                .frame(width: 347) // Match Step 2's exact effective width (393-46)
                Spacer()
            }
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Main Title and Subtitle
                    VStack(spacing: 4) {
                        Text("Create Custom Habit")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("Let's Create Their First Habit")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 67)
                    
                    // White Card - EXACT ProfileViews Pattern
                    VStack(spacing: 0) {
                        // Habit Name Input (FIGMA SPEC: EXACT ProfileViews Structure)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("HABIT NAME")
                                        .font(.system(size: 16, weight: .medium)) // Match flow titles pattern
                                        .kerning(-0.3) // Consistent with other titles
                                        .foregroundColor(.gray) // Grey title
                                    
                                    ZStack(alignment: .leading) {
                                        TextField("", text: $habitName)
                                            .font(.system(size: 16, weight: .light))
                                            .focused($isTextFieldFocused)
                                            .foregroundColor(.black) // Black text so user can see what they're typing
                                            .accentColor(.blue)
                                        
                                        if habitName.isEmpty {
                                            Text("eg. take medication")
                                                .font(.system(size: 14, weight: .light))
                                                .foregroundColor(.gray.opacity(0.8))
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    .onTapGesture {
                                        isTextFieldFocused = true
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 18) // Reduced internal padding to fix visual conflict with Step 2
                        .padding(.vertical, 24) // More top/bottom padding
                        .background(Color.white)
                        
                        // Days Selection (FIGMA SPEC: NO TITLE, CENTERED)
                        VStack(alignment: .center, spacing: 8) {
                            DaySelectionView(selectedDays: $selectedDays)
                                .simultaneousGesture(
                                    TapGesture().onEnded { _ in
                                        isTextFieldFocused = false
                                    }
                                )
                        }
                        .padding(.horizontal, 18) // Reduced internal padding to fix visual conflict with Step 2
                        .padding(.vertical, 24) // More top/bottom padding
                        .background(Color.white)
                        
                        // Time Selection (FIGMA SPEC: NO TITLE)
                        VStack(alignment: .leading, spacing: 8) {
                            TimeSelectionView(selectedTimes: $selectedTimes, showingTimePicker: $showingTimePicker)
                                .simultaneousGesture(
                                    TapGesture().onEnded { _ in
                                        isTextFieldFocused = false
                                    }
                                )
                        }
                        .padding(.horizontal, 18) // Reduced internal padding to fix visual conflict with Step 2
                        .padding(.vertical, 24) // More top/bottom padding
                        .background(Color.white)
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 23) // Calculated for 348px button width
                }
            }
            
            // Bottom Action Button - CAPTURE WIDTH for Step 2
            if !isTextFieldFocused {
                GeometryReader { geometry in
                    VStack {
                        Button(action: {
                            if !habitName.isEmpty && !selectedDays.isEmpty && !selectedTimes.isEmpty {
                                onButtonWidthCapture(geometry.size.width - 46) // CAPTURE the actual width
                                onNext()
                            }
                        }) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: geometry.size.width - 46, height: 47) // Exact calculation: screen width - (23px × 2)
                                .background(habitName.isEmpty || selectedDays.isEmpty || selectedTimes.isEmpty ? Color(hex: "BFE6FF") : Color(hex: "28ADFF"))
                                .cornerRadius(15)
                        }
                        .disabled(habitName.isEmpty || selectedDays.isEmpty || selectedTimes.isEmpty)
                        .frame(maxWidth: .infinity) // Center the button
                        .padding(.bottom, 10) // Close to bottom of screen
                    }
                }
                .frame(height: 57) // Fixed height for the GeometryReader
            }
        }
        .background(
            // ProfileViews Background Pattern
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")  // App background
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,           // Top (transparent)
                        Color(hex: "B3B3B3")   // Bottom (light grey)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225)  // Half extends below screen
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(
                selectedTime: $tempSelectedTime,
                selectedTimes: $selectedTimes,
                isPresented: $showingTimePicker
            )
        }
    }
}

// MARK: - Step 2: Confirmation Method (COPIED FROM PROFILEVIEWS STRUCTURE)
struct Step2_ConfirmationMethod: View {
    let habitName: String
    @Binding var confirmationMethod: String
    let capturedButtonWidth: CGFloat
    let onBack: () -> Void
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar - COPIED FROM STEP 1 with invisible Next button
            HStack {
                Spacer()
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .light))
                        }
                    }
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Remi Logo (centered between functional buttons)
                    Text("Remi")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-1.9)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Invisible Next button for perfect Remi centering
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Text("Next")
                                .font(.system(size: 16, weight: .light))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor(.clear) // Invisible but maintains layout
                    .disabled(true)
                }
                .frame(width: 347) // Match Step 1's exact width
                Spacer()
            }
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Main Title and Subtitle
                    VStack(spacing: 4) {
                        Text("Confirmation Method")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("How should \(habitName) be confirmed?")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 67)
                    
                    // White Card - EXACT ProfileViews Pattern
                    VStack(spacing: 0) {
                        VStack(spacing: 16) {
                            ConfirmationOption(
                                title: "Photo Confirmation",
                                description: "Take a photo to confirm completion",
                                isSelected: confirmationMethod == "photo",
                                onTap: { confirmationMethod = "photo" }
                            )
                            
                            ConfirmationOption(
                                title: "Text Response",
                                description: "Send a simple 'Done' message",
                                isSelected: confirmationMethod == "text",
                                onTap: { confirmationMethod = "text" }
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 23) // Match Step 1's padding for consistent button geometry
                }
            }
            
            // Bottom Action Button - USE CAPTURED WIDTH from Step 1
            VStack {
                Button(action: {
                    if !confirmationMethod.isEmpty {
                        onCreate()
                    }
                }) {
                    Text("Complete")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: capturedButtonWidth > 0 ? capturedButtonWidth : nil, height: 47) // Use captured width or fallback
                        .frame(maxWidth: capturedButtonWidth > 0 ? nil : .infinity) // Dynamic fallback
                        .background(confirmationMethod.isEmpty ? Color(hex: "BFE6FF") : Color(hex: "28ADFF"))
                        .cornerRadius(15)
                }
                .disabled(confirmationMethod.isEmpty)
                .frame(maxWidth: .infinity) // Center the button
                .padding(.horizontal, 23) // RESTORE the horizontal padding like Step 1
                .padding(.bottom, 10) // Close to bottom of screen
            }
        }
        .background(
            // ProfileViews Background Pattern
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")  // App background
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,           // Top (transparent)
                        Color(hex: "B3B3B3")   // Bottom (light grey)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225)  // Half extends below screen
            }
            .ignoresSafeArea()
        )
    }
}

    // MARK: - OLD CONTENT TO REMOVE
    private var step1Content: some View {
        VStack(spacing: 24) {
            // Title and Subtitle - EXACT ProfileViews Pattern
            VStack(spacing: 4) {
                Text("Create Custom Habit")
                    .font(.system(size: 34, weight: .medium))
                    .kerning(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                Text("Let's Create Their First Habit")
                    .font(.system(size: 14, weight: .light))
                    .kerning(-0.3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 67) // RESTORE for Step 1
            
            // White Card - EXACT ProfileViews Pattern
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Habit Name")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.black)
                        
                        TextField("Enter habit name...", text: $habitName)
                            .font(.system(size: 16, weight: .light))
                            .padding(.bottom, 8)
                    }
                    
                    // Day Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.black)
                        
                        DaySelectionView(selectedDays: $selectedDays)
                    }
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Times")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.black)
                        
                        TimeSelectionView(
                            selectedTimes: $selectedTimes,
                            showingTimePicker: $showingTimePicker
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            // .padding(.horizontal, 32) // COMMENTED OUT FOR DEBUGGING
            
            // Bottom Button - EXACT ProfileViews Pattern
            Button(action: {
                if !habitName.isEmpty && !selectedDays.isEmpty && !selectedTimes.isEmpty {
                    currentStep = 2
                }
            }) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 47)
                    .background(habitName.isEmpty || selectedDays.isEmpty || selectedTimes.isEmpty ? Color(hex: "BFE6FF") : Color(hex: "B9E3FF"))
                    .cornerRadius(15)
            }
            .disabled(habitName.isEmpty || selectedDays.isEmpty || selectedTimes.isEmpty)
            // .padding(.horizontal, 32) // COMMENTED OUT FOR DEBUGGING
        }
    }
    
    private var step2Content: some View {
        VStack(spacing: 8) { // REDUCE spacing for Step 2
            // Title and Subtitle - EXACT ProfileViews Pattern
            VStack(spacing: 4) {
                Text("Confirmation Method")
                    .font(.system(size: 34, weight: .medium))
                    .kerning(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                Text("How should \(habitName) be confirmed?")
                    .font(.system(size: 14, weight: .light))
                    .kerning(-0.3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8) // MINIMAL for Step 2 to prevent nav bar sliding
            
            // White Card - EXACT ProfileViews Pattern
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    ConfirmationOption(
                        title: "Photo Confirmation",
                        description: "Take a photo to confirm completion",
                        isSelected: confirmationMethod == "photo",
                        onTap: { confirmationMethod = "photo" }
                    )
                    
                    ConfirmationOption(
                        title: "Text Response",
                        description: "Send a simple 'Done' message",
                        isSelected: confirmationMethod == "text",
                        onTap: { confirmationMethod = "text" }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16) // REDUCE Step 2 card padding
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            // .padding(.horizontal, 32) // COMMENTED OUT FOR DEBUGGING
            
            // Bottom Button - EXACT ProfileViews Pattern
            Button(action: {
                if !confirmationMethod.isEmpty {
                    // Transfer form data to TaskViewModel and create task
                    createHabit()
                }
            }) {
                Text("Complete")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 47)
                    .background(confirmationMethod.isEmpty ? Color(hex: "BFE6FF") : Color(hex: "B9E3FF"))
                    .cornerRadius(15)
            }
            .disabled(confirmationMethod.isEmpty)
            // .padding(.horizontal, 32) // COMMENTED OUT FOR DEBUGGING
        }
    }
    
    // MARK: - Helper Functions
    private func createHabit() {
        // Transfer form data to TaskViewModel
        viewModel.taskTitle = habitName
        viewModel.taskCategory = .medication // Default as requested
        viewModel.frequency = .custom // Since we have specific days selected
        viewModel.scheduledTimes = selectedTimes
        viewModel.customDays = convertDaysToWeekdays(selectedDays)
        
        // Set confirmation method requirements
        if confirmationMethod == "photo" {
            viewModel.requiresPhoto = true
            viewModel.requiresText = false
        } else {
            viewModel.requiresPhoto = false  
            viewModel.requiresText = true
        }
        
        // Create the task and dismiss on success
        viewModel.createTask()
        onDismiss()
    }
    
    private func convertDaysToWeekdays(_ days: Set<Int>) -> Set<Weekday> {
        Set(days.compactMap { dayIndex in
            // DaySelectionView uses 0=Sunday, 1=Monday... 6=Saturday
            // Weekday.from expects 1=Sunday, 2=Monday... 7=Saturday
            return Weekday.from(weekday: dayIndex + 1)
        })
    }
}

// MARK: - Supporting Components

// Day Selection Component (FIGMA SPEC: 39x39 CIRCLES)
struct DaySelectionView: View {
    @Binding var selectedDays: Set<Int>
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNumbers = [0, 1, 2, 3, 4, 5, 6]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7) { index in
                Button(action: {
                    if selectedDays.contains(index) {
                        selectedDays.remove(index)
                    } else {
                        selectedDays.insert(index)
                    }
                }) {
                    Text(dayLabels[index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "0D0C0C")) // Always dark color
                        .frame(width: 39, height: 39) // FIGMA SPEC: 39x39
                        .background(Color.clear) // No background fill
                        .overlay(
                            Circle()
                                .stroke(selectedDays.contains(index) ? Color(hex: "0D0C0C") : Color(hex: "D5D5D5"), lineWidth: 1) // Specific hex colors
                        )
                }
            }
        }
    }
}

// Time Selection Component (FIGMA SPEC: MULTI-ROW, MIDDLE ALIGNED)
struct TimeSelectionView: View {
    @Binding var selectedTimes: [Date]
    @Binding var showingTimePicker: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Create rows of times with max 3 per row, plus button always at end
            let timesWithButton = selectedTimes + [Date.distantFuture] // Add placeholder for button
            let chunked = timesWithButton.chunked(into: 3)
            
            ForEach(Array(chunked.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 12) {
                    Spacer() // Left spacer for centering
                    
                    ForEach(Array(row.enumerated()), id: \.offset) { index, time in
                        if time == Date.distantFuture {
                            // Add Time Button - FIGMA SPEC: Smaller, middle aligned
                            Button(action: {
                                showingTimePicker = true
                            }) {
                                Circle()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1) // Light grey stroke
                                    .frame(width: 28, height: 28) // Smaller size
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray) // Dark grey plus sign
                                    )
                            }
                        } else {
                            // Time slot button
                            let actualIndex = selectedTimes.firstIndex(of: time) ?? 0
                            Button(action: {
                                if let realIndex = selectedTimes.firstIndex(of: time) {
                                    selectedTimes.remove(at: realIndex)
                                }
                            }) {
                                Text(timeString(from: time))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray) // Dark grey instead of black
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "F8F3F3")) // FIGMA SPEC: F8F3F3 color
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Spacer() // Right spacer for centering
                }
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Extension to chunk arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// Time Picker Sheet - COMPACT BUT STILL SLIDER
struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @Binding var selectedTimes: [Date]
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.gray)
                
                Spacer()
                
                Text("Select Time")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button("Done") {
                    // Check for duplicates
                    let calendar = Calendar.current
                    let newHour = calendar.component(.hour, from: selectedTime)
                    let newMinute = calendar.component(.minute, from: selectedTime)
                    
                    let isDuplicate = selectedTimes.contains { existingTime in
                        let existingHour = calendar.component(.hour, from: existingTime)
                        let existingMinute = calendar.component(.minute, from: existingTime)
                        return existingHour == newHour && existingMinute == newMinute
                    }
                    
                    if !isDuplicate {
                        selectedTimes.append(selectedTime)
                    }
                    isPresented = false
                }
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Time Picker - Keep as wheel but limit space
            DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .presentationDetents([.fraction(0.4)]) // Only pop up 40% of screen
        .presentationDragIndicator(.visible)
    }
}

// Confirmation Option Component
struct ConfirmationOption: View {
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .stroke(isSelected ? Color(hex: "28ADFF") : Color.gray.opacity(0.3), lineWidth: 2)
                    .fill(isSelected ? Color(hex: "28ADFF") : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text(description)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(16)
            .background(isSelected ? Color.black.opacity(0.05) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.1), value: isSelected) // Fast, smooth animation
    }
}

// MARK: - Task Row Component
struct TaskRow: View {
    let task: Task
    let profile: ElderlyProfile?
    let showViewButton: Bool
    let onViewTapped: (() -> Void)?
    
    init(task: Task, profile: ElderlyProfile? = nil, showViewButton: Bool = false, onViewTapped: (() -> Void)? = nil) {
        self.task = task
        self.profile = profile
        self.showViewButton = showViewButton
        self.onViewTapped = onViewTapped
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image if provided
            if let profile = profile {
                ProfileImageSmall(profile: profile)
            }
            
            // Task details
            VStack(alignment: .leading, spacing: 4) {
                if let profile = profile {
                    Text(profile.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    Text(formatTime(task.scheduledTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showViewButton {
                        Spacer()
                        Button("View") {
                            onViewTapped?()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Small Profile Image Component
struct ProfileImageSmall: View {
    let profile: ElderlyProfile
    
    var body: some View {
        AsyncImage(url: URL(string: profile.photoURL ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                )
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

// MARK: - Task Card Component
struct TaskCard: View {
    let task: Task
    let onTap: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text(formatTime(task.scheduledTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(task.title)
                .font(.headline)
                .lineLimit(2)
            
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap?()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview Support
#if DEBUG
struct TaskViews_Previews: PreviewProvider {
    static var previews: some View {
        // Ultra-minimal preview to test if anything works
        Text("TaskViews Preview")
            .padding()
            .previewDisplayName("Basic Test")
    }
}

#endif
