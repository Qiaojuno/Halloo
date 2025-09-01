import SwiftUI
import Combine

// MARK: - Profile Onboarding Flow (6-Step Process)
/// Complete profile onboarding experience replacing basic CreateProfileView
/// 
/// This view orchestrates the sophisticated 6-step profile creation and SMS confirmation
/// workflow as specified in requirements. It provides a guided, educational experience
/// that builds user confidence in SMS communication with elderly family members.
///
/// ## Onboarding Steps:
/// 1. **NewProfileForm**: Basic profile information with photo upload
/// 2. **ProfileComplete**: Summary with member counting and habit counter
/// 3. **SMSIntroduction**: Educational SMS test introduction
/// 4. **ConfirmationWait**: Real-time SMS confirmation waiting
/// 5. **OnboardingSuccess**: Confirmation success celebration
/// 6. **FirstHabit**: Transition to habit creation workflow
struct ProfileOnboardingFlow: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Progress Header with Navigation
                    ProfileOnboardingHeader(
                        step: profileViewModel.profileOnboardingStep,
                        onBack: {
                            if profileViewModel.profileOnboardingStep.canGoBack {
                                profileViewModel.previousOnboardingStep()
                            } else {
                                // Cancel entire flow from first step
                                profileViewModel.cancelProfileOnboarding()
                            }
                        },
                        onClose: {
                            profileViewModel.cancelProfileOnboarding()
                        }
                    )
                    
                    // Step Content
                    stepContentView(geometry: geometry)
                }
                .background(Color(hex: "f9f9f9"))
            }
            .navigationBarHidden(true)
        }
        .onDisappear {
            // Reset onboarding state if view disappears unexpectedly
            if profileViewModel.showingProfileOnboarding {
                profileViewModel.cancelProfileOnboarding()
            }
        }
    }
    
    /// Returns the appropriate step view based on current onboarding step
    @ViewBuilder
    private func stepContentView(geometry: GeometryProxy) -> some View {
        switch profileViewModel.profileOnboardingStep {
        case .newProfileForm:
            Step1_NewProfileForm()
        case .profileComplete:
            Step2_ProfileComplete()
        case .smsIntroduction:
            Step3_SMSIntroduction()
        case .confirmationWait:
            Step4_ConfirmationWait()
        case .onboardingSuccess:
            Step5_OnboardingSuccess()
        case .firstHabit:
            Step6_FirstHabit()
        }
    }
}

// MARK: - Profile Onboarding Header
/// Header component with progress indicators and navigation controls
/// 
/// Provides consistent navigation experience across all onboarding steps
/// with progress dots, back button, and close option.
struct ProfileOnboardingHeader: View {
    let step: ProfileOnboardingStep
    let onBack: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            // Back Navigation Button
            if step.canGoBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
            } else {
                // Close button for first step
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            
            Spacer()
            
            // Progress Indicator Dots
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < Int(step.progress * 6) ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
            
            // Next Button (placeholder - will be handled by individual step views)
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: "f9f9f9"))
    }
}

// MARK: - Step 1: New Profile Form
/// Step 1: Basic profile information collection with photo upload
/// 
/// Collects essential profile information needed for SMS communication:
/// - Profile name (as elderly person recognizes it)
/// - Relationship to user for context
/// - Phone number for SMS delivery
/// - Optional photo upload (placeholder for future implementation)
struct Step1_NewProfileForm: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Step Title and Subtitle
                    VStack(spacing: 8) {
                        Text(ProfileOnboardingStep.newProfileForm.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text(ProfileOnboardingStep.newProfileForm.subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                    }
                    .padding(.top, 30)
                    
                    // Profile Form Fields
                    VStack(spacing: 20) {
                        // Name Input with Photo Upload Button
                        HStack(spacing: 16) {
                            VStack(spacing: 8) {
                                TextField("Name", text: $profileViewModel.profileName)
                                    .font(.system(size: 16, weight: .regular))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                if let nameError = profileViewModel.nameError {
                                    Text(nameError)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Photo Upload Button (Circular with + icon)
                            Button(action: {
                                // TODO: Implement photo upload functionality
                                profileViewModel.hasSelectedPhoto.toggle()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                    
                                    if profileViewModel.hasSelectedPhoto {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                        
                        // Relationship Input
                        VStack(spacing: 8) {
                            Picker("Relationship", selection: $profileViewModel.relationship) {
                                ForEach(profileViewModel.relationshipOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            if let relationshipError = profileViewModel.relationshipError {
                                Text(relationshipError)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Phone Number Input
                        VStack(spacing: 8) {
                            TextField("Phone Number", text: $profileViewModel.phoneNumber)
                                .font(.system(size: 16, weight: .regular))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                            
                            if let phoneError = profileViewModel.phoneError {
                                Text(phoneError)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    // Next Button
                    Button(action: {
                        profileViewModel.nextOnboardingStep()
                    }) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(profileViewModel.isValidForm ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!profileViewModel.isValidForm)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
        }
    }
}

// MARK: - Step 2: Profile Complete Summary
/// Step 2: Profile completion summary with member counting and habit counter
/// 
/// Displays a summary card showing:
/// - Member number (dynamic based on existing profiles)
/// - Profile information with photo
/// - Habits tracked counter (starts at 0)
/// - Join date (formatted MM.DD.YYYY)
/// - Relationship label
struct Step2_ProfileComplete: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Step Title and Subtitle (with profile name)
                    VStack(spacing: 8) {
                        Text(ProfileOnboardingStep.profileComplete.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text("Let's add your first habit for \(profileViewModel.profileName) now :)")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                    }
                    .padding(.top, 30)
                    
                    // Profile Summary Card
                    VStack(spacing: 20) {
                        // Member Indicator
                        HStack {
                            HStack(spacing: 8) {
                                Text("Member #\(profileViewModel.memberNumber)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                // Progress dots showing member position
                                HStack(spacing: 4) {
                                    ForEach(1...4, id: \.self) { index in
                                        Circle()
                                            .fill(index <= profileViewModel.memberNumber ? Color.blue : Color.gray.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Profile Photo (Large circular)
                        ZStack {
                            Circle()
                                .fill(profileColorForMember(profileViewModel.memberNumber).opacity(0.6))
                                .frame(width: 100, height: 100)
                            
                            if profileViewModel.hasSelectedPhoto {
                                // TODO: Display actual selected photo
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white)
                            } else {
                                // Default emoji based on member number and relationship
                                Text(defaultEmojiForProfile(
                                    memberNumber: profileViewModel.memberNumber,
                                    relationship: profileViewModel.relationship
                                ))
                                .font(.system(size: 50))
                            }
                            
                            // Colored border
                            Circle()
                                .stroke(profileColorForMember(profileViewModel.memberNumber), lineWidth: 3)
                                .frame(width: 100, height: 100)
                        }
                        
                        // Profile Name
                        Text(profileViewModel.profileName)
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        // Stats Row
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("Habits Tracked: 0")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Join Date")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(formatJoinDate(Date()))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        // Relationship Label
                        Text(profileViewModel.relationship)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.gray.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    // Onboard Button
                    Button(action: {
                        profileViewModel.nextOnboardingStep()
                    }) {
                        Text("Onboard Your Member")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
        }
    }
    
    /// Formats date in MM.DD.YYYY format for join date display
    private func formatJoinDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd.yyyy"
        return formatter.string(from: date)
    }
    
    /// Returns appropriate color for member number (cycling through blue, red, green, purple)
    private func profileColorForMember(_ memberNumber: Int) -> Color {
        let colors: [Color] = [.blue, .red, .green, .purple]
        let index = (memberNumber - 1) % colors.count
        return colors[index]
    }
    
    /// Returns default emoji for profile based on member number and relationship
    private func defaultEmojiForProfile(memberNumber: Int, relationship: String) -> String {
        let emojis = ["👴🏻", "👵🏽", "👴🏿", "👵🏻", "👴🏽", "👵🏿"]
        
        // Use relationship to influence emoji selection
        if relationship.lowercased().contains("grand") {
            return memberNumber % 2 == 1 ? "👴🏻" : "👵🏽"
        } else if relationship.lowercased().contains("parent") {
            return memberNumber % 2 == 1 ? "👴🏽" : "👵🏻"
        } else {
            let index = (memberNumber - 1) % emojis.count
            return emojis[index]
        }
    }
}

// MARK: - Step 3: SMS Test Introduction
/// Step 3: SMS test introduction with phone mockup and "Send Hello" trigger
/// 
/// Educational step that introduces SMS confirmation process:
/// - Tilted phone mockup showing SMS preparation
/// - Preview of confirmation message that will be sent
/// - "Send Hello 👋" button that triggers actual SMS delivery
/// - Clean illustration style matching app design
struct Step3_SMSIntroduction: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var smsSendingFailed = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Step Title and Subtitle
                    VStack(spacing: 8) {
                        Text(ProfileOnboardingStep.smsIntroduction.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text(ProfileOnboardingStep.smsIntroduction.subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                    }
                    .padding(.top, 30)
                    
                    // Phone Mockup with SMS Preview
                    VStack(spacing: 20) {
                        // Tilted Phone Illustration
                        ZStack {
                            // Phone Frame
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.black)
                                .frame(width: 200, height: 350)
                                .rotationEffect(.degrees(-5))
                            
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 180, height: 330)
                                .rotationEffect(.degrees(-5))
                            
                            // SMS Interface Mockup
                            VStack(spacing: 12) {
                                // Header
                                HStack {
                                    Text("Messages")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                
                                // Contact
                                HStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.6))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text("H")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(profileViewModel.profileName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                
                                // Message Preview
                                VStack(alignment: .trailing, spacing: 8) {
                                    HStack {
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("Hello \(profileViewModel.profileName)! Your family member wants to send you helpful daily reminders...")
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 6)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                                .multilineTextAlignment(.trailing)
                                            
                                            Text("Reply YES or STOP")
                                                .font(.system(size: 8, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                
                                Spacer()
                            }
                            .frame(width: 180, height: 330)
                            .rotationEffect(.degrees(-5))
                        }
                        .padding(.vertical, 20)
                        
                        // Message Preview Text
                        VStack(spacing: 8) {
                            Text("Preview of message to be sent:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("Hello \(profileViewModel.profileName)! Your family member wants to send you helpful daily reminders via text message. Reply YES to confirm and start receiving reminders, or STOP to decline. - Hallo Family Care")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    Spacer()
                    
                    // SMS Sending Buttons
                    VStack(spacing: 12) {
                        // Send Hello Button
                        Button(action: {
                            sendSMSToProfile()
                        }) {
                            HStack(spacing: 8) {
                                if profileViewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Text("Send Hello")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("👋")
                                        .font(.system(size: 16))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(profileViewModel.isLoading)
                        
                        // Resend Button (shown only when SMS sending failed)
                        if smsSendingFailed {
                            Button(action: {
                                smsSendingFailed = false
                                sendSMSToProfile()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text("Resend SMS")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                                .cornerRadius(12)
                            }
                            .disabled(profileViewModel.isLoading)
                        }
                        
                        // Error Message
                        if let errorMessage = profileViewModel.errorMessage, smsSendingFailed {
                            Text("Failed to send SMS: \(errorMessage)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
        }
    }
    
    /// Handles SMS sending with error detection and failure state management
    private func sendSMSToProfile() {
        guard let profileId = profileViewModel.onboardingProfile?.id else { return }
        
        // Clear any previous error state
        smsSendingFailed = false
        
        // Trigger SMS sending
        profileViewModel.sendOnboardingSMS()
        
        // Monitor for SMS sending failure
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let status = profileViewModel.confirmationStatus[profileId],
               status == .failed {
                smsSendingFailed = true
            }
        }
    }
}

// MARK: - Step 4: SMS Confirmation Wait
/// Step 4: Real-time SMS confirmation waiting with conversation display
/// 
/// Shows an SMS conversation interface with:
/// - Sent confirmation message display
/// - Waiting state animation for response
/// - "OK" reply visualization when received
/// - Continue button (disabled until confirmation)
struct Step4_ConfirmationWait: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var showingResponse = false
    @State private var responseReceived = false
    @State private var actualResponseText = "OK"
    
    var body: some View {
        Step4ContentView(
            profileViewModel: profileViewModel,
            showingResponse: $showingResponse,
            responseReceived: $responseReceived,
            actualResponseText: $actualResponseText
        )
        .onAppear {
            initializeStep()
        }
        .onReceive(
            profileViewModel.dataSyncPublisher.smsResponses
                .filter { response in
                    guard let profile = profileViewModel.onboardingProfile,
                          response.profileId == profile.id,
                          response.isConfirmationResponse else {
                        return false
                    }
                    return true
                }
        ) { response in
            handleRealTimeResponse(response)
        }
    }
    
    private func initializeStep() {
        withAnimation {
            showingResponse = true
        }
        checkForExistingResponse()
    }
    
    private func handleRealTimeResponse(_ response: SMSResponse) {
        withAnimation(.easeInOut(duration: 0.5)) {
            responseReceived = true
            showingResponse = true
            actualResponseText = response.textResponse ?? (response.isPositiveConfirmation ? "YES" : "STOP")
        }
    }
    
    /// Checks if SMS confirmation response has already been received
    /// 
    /// Handles cases where user navigates back to Step 4 after response
    /// or when response was received while on different step.
    private func checkForExistingResponse() {
        guard let profile = profileViewModel.onboardingProfile,
              let status = profileViewModel.confirmationStatus[profile.id] else {
            return
        }
        
        if status == .confirmed {
            withAnimation {
                responseReceived = true
                showingResponse = true
                // Use confirmed status message or default to "YES"
                actualResponseText = profileViewModel.confirmationMessages[profile.id]?.contains("Confirmed") == true ? "YES" : "OK"
            }
        } else if status == .declined {
            withAnimation {
                responseReceived = true
                showingResponse = true
                actualResponseText = "STOP"
            }
        }
    }
}

// MARK: - Step 4 Content View
struct Step4ContentView: View {
    let profileViewModel: ProfileViewModel
    @Binding var showingResponse: Bool
    @Binding var responseReceived: Bool
    @Binding var actualResponseText: String
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Step Title and Subtitle
                    VStack(spacing: 8) {
                        Text(ProfileOnboardingStep.confirmationWait.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text(ProfileOnboardingStep.confirmationWait.subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                    }
                    .padding(.top, 30)
                    
                    // SMS Conversation Display
                    SMSConversationView(
                        profileViewModel: profileViewModel,
                        showingResponse: showingResponse,
                        responseReceived: responseReceived,
                        actualResponseText: actualResponseText
                    )
                    
                    // Status Message
                    StatusMessageView(responseReceived: responseReceived, actualResponseText: actualResponseText)
                    
                    Spacer()
                    
                    // Continue/Retry Buttons
                    ActionButtonsView(
                        profileViewModel: profileViewModel,
                        actualResponseText: actualResponseText,
                        showingResponse: $showingResponse,
                        responseReceived: $responseReceived
                    )
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
        }
    }
}

// MARK: - SMS Conversation View
struct SMSConversationView: View {
    let profileViewModel: ProfileViewModel
    let showingResponse: Bool
    let responseReceived: Bool
    let actualResponseText: String
    
    private var confirmationMessage: String {
        "Hello \(profileViewModel.profileName)! Your family member wants to send you helpful daily reminders via text message. Reply YES to confirm and start receiving reminders, or STOP to decline.\n\n- Hallo Family Care"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            messagesView
        }
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(profileViewModel.profileName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(profileViewModel.phoneNumber)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
    }
    
    private var messagesView: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 16) {
                sentMessageView
                responseMessageView
                waitingIndicatorView
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var sentMessageView: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(confirmationMessage)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .multilineTextAlignment(.leading)
                
                Text("Delivered")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var responseMessageView: some View {
        if showingResponse && responseReceived {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(actualResponseText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(responseBackgroundColor)
                        .cornerRadius(16)
                    
                    Text("Read")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var responseBackgroundColor: Color {
        actualResponseText.uppercased().contains("STOP") ? 
            Color.red.opacity(0.2) : Color.gray.opacity(0.2)
    }
    
    @ViewBuilder  
    private var waitingIndicatorView: some View {
        if !responseReceived {
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(showingResponse ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: showingResponse
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Status Message View
struct StatusMessageView: View {
    let responseReceived: Bool
    let actualResponseText: String
    
    var body: some View {
        VStack(spacing: 8) {
            if !responseReceived {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Waiting for confirmation...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                let isPositive = !actualResponseText.uppercased().contains("STOP")
                HStack(spacing: 8) {
                    Image(systemName: isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isPositive ? .green : .red)
                    Text(isPositive ? "Confirmation received!" : "Declined - no reminders will be sent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isPositive ? .green : .red)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Action Buttons View
struct ActionButtonsView: View {
    let profileViewModel: ProfileViewModel
    let actualResponseText: String
    @Binding var showingResponse: Bool
    @Binding var responseReceived: Bool
    
    var body: some View {
        if responseReceived {
            let isPositive = !actualResponseText.uppercased().contains("STOP")
            
            if isPositive {
                // Positive confirmation
                Button(action: {
                    profileViewModel.nextOnboardingStep()
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            } else {
                // Negative response
                VStack(spacing: 12) {
                    Button(action: {
                        responseReceived = false
                        showingResponse = false
                        profileViewModel.sendOnboardingSMS()
                    }) {
                        Text("Try Again")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        profileViewModel.cancelProfileOnboarding()
                    }) {
                        Text("Cancel Setup")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            }
        } else {
            // No response yet
            Button(action: {}) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gray)
                    .cornerRadius(12)
            }
            .disabled(true)
            .padding(.horizontal, 12)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Step 5: Onboarding Success
/// Step 5: Confirmation success celebration screen
/// 
/// Displays:
/// - Success animation or icon
/// - Confirmation message
/// - Profile ready status
/// - Transition to habit creation
struct Step5_OnboardingSuccess: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var showCheckmark = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Step Title and Subtitle
                    VStack(spacing: 8) {
                        Text(ProfileOnboardingStep.onboardingSuccess.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text(ProfileOnboardingStep.onboardingSuccess.subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                    }
                    .padding(.top, 30)
                    
                    Spacer()
                    
                    // Success Animation
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 150, height: 150)
                            .scaleEffect(showCheckmark ? 1.0 : 0.5)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                        
                        // Checkmark icon
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.green)
                            .scaleEffect(showCheckmark ? 1.0 : 0.0)
                            .rotationEffect(.degrees(showCheckmark ? 0 : -180))
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showCheckmark)
                    }
                    
                    // Success Message
                    VStack(spacing: 16) {
                        Text("Successfully Onboarded!")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text("\(profileViewModel.profileName) is now ready to receive helpful daily reminders")
                            .font(.system(size: 16, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                            .padding(.horizontal, 20)
                    }
                    
                    // Status Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Profile Active")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Image(systemName: "message.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("SMS Confirmed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Image(systemName: "bell.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Ready for Habits")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            Spacer()
                            Text("0 habits")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    // Continue Button
                    Button(action: {
                        profileViewModel.nextOnboardingStep()
                    }) {
                        Text("Create First Habit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Step 6: First Habit Creation
/// Step 6: Transition to habit creation workflow
/// 
/// Shows:
/// - Preview of main dashboard with new profile
/// - Introduction to habit creation
/// - Button to start creating first habit
/// - Option to finish and go to dashboard
struct Step6_FirstHabit: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.container) private var container
    @State private var showingTaskCreation = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Step Title and Subtitle
                    VStack(spacing: 8) {
                        Text(ProfileOnboardingStep.firstHabit.displayName)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(.black)
                        
                        Text(ProfileOnboardingStep.firstHabit.subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .tracking(-0.5)
                    }
                    .padding(.top, 30)
                    
                    // Dashboard Preview
                    VStack(spacing: 16) {
                        HStack {
                            Text("Your Dashboard")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // Mini Dashboard Preview
                        VStack(spacing: 12) {
                            // Profile Section Preview
                            HStack(spacing: 12) {
                                // Profile circles
                                ForEach(0..<min(profileViewModel.profiles.count, 4), id: \.self) { index in
                                    if index < profileViewModel.profiles.count {
                                        let profile = profileViewModel.profiles[index]
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Circle()
                                                    .fill(profileColorForIndex(index).opacity(0.2))
                                                    .frame(width: 44, height: 44)
                                                
                                                Text(defaultEmojiForIndex(index))
                                                    .font(.system(size: 20))
                                                
                                                Circle()
                                                    .stroke(profileColorForIndex(index), lineWidth: 2)
                                                    .frame(width: 44, height: 44)
                                            }
                                            
                                            Text(profile.name)
                                                .font(.system(size: 10, weight: .medium))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            
                            Divider()
                            
                            // Empty Habits Section
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No habits created yet")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("Create your first habit for \(profileViewModel.profileName)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                        }
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    
                    // Habit Creation Benefits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What are habits?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Daily reminders sent via SMS to \(profileViewModel.profileName)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Track medication, exercise, social activities")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Get photo confirmations when tasks are completed")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Show task creation with newly created profile preselected
                            showingTaskCreation = true
                        }) {
                            Text("Create First Habit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            profileViewModel.completeProfileOnboarding()
                        }) {
                            Text("Skip for Now")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
        }
        .sheet(isPresented: $showingTaskCreation) {
            TaskCreationView(preselectedProfileId: profileViewModel.onboardingProfile?.id)
                .environmentObject(container.makeTaskViewModel())
        }
        .onDisappear {
            // Complete onboarding when task creation sheet is dismissed
            if showingTaskCreation {
                profileViewModel.completeProfileOnboarding()
            }
        }
    }
    
    /// Returns color for profile based on index
    private func profileColorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .red, .green, .purple]
        return colors[index % colors.count]
    }
    
    /// Returns emoji for profile based on index
    private func defaultEmojiForIndex(_ index: Int) -> String {
        let emojis = ["👴🏻", "👵🏽", "👴🏿", "👵🏻"]
        return emojis[index % emojis.count]
    }
}

// MARK: - Legacy ProfileViews (for backward compatibility)

// MARK: - Profile Creation View (simplified, now replaced by onboarding flow)
struct ProfileCreationView: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        // Redirect to new onboarding flow
        VStack {
            Text("Profile creation has been upgraded!")
                .font(.title2)
                .padding()
            
            Button("Start Profile Onboarding") {
                presentationMode.wrappedValue.dismiss()
                viewModel.startProfileOnboarding()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

// MARK: - Profile Form Component (legacy support)
struct ProfileCreationForm: View {
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var relationship = "Parent"
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Phone Number", text: $phoneNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.phonePad)
            
            Picker("Relationship", selection: $relationship) {
                Text("Parent").tag("Parent")
                Text("Grandparent").tag("Grandparent")
                Text("Other Family").tag("Other")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}

// MARK: - Profile Card Component (reused from existing implementation)
struct ProfileCard: View {
    let profile: ElderlyProfile
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: profile.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Text(String(profile.name.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.semibold)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            
            Text(profile.name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

// MARK: - Main CreateProfileView (now triggers onboarding flow)
/// Updated CreateProfileView that launches the comprehensive 6-step onboarding flow
/// 
/// This replaces the previous basic profile creation with the sophisticated
/// onboarding experience specified in requirements.
struct CreateProfileView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Add Family Member")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                    
                    Text("Start the guided setup process to add an elderly family member to your care coordination network")
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                        .tracking(-0.5)
                    
                    Spacer()
                    
                    Button(action: {
                        profileViewModel.startProfileOnboarding()
                    }) {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
        .fullScreenCover(isPresented: $profileViewModel.showingProfileOnboarding) {
            ProfileOnboardingFlow()
                .environmentObject(profileViewModel)
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct ProfileViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // MINIMAL TEST - Step 1 only to isolate issue
            Step1_NewProfileForm()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("🧪 STEP 1 TEST")
            
            // STEP BY STEP TESTING - Uncomment to test specific steps
            /*
            CreateProfileView()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 New Create Profile (Onboarding Trigger)")
            
            ProfileOnboardingFlow()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Complete Onboarding Flow")
            
            Step2_ProfileComplete()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Step 2: Profile Complete")
            
            Step3_SMSIntroduction()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Step 3: SMS Introduction")
            
            Step4_ConfirmationWait()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Step 4: SMS Confirmation Wait")
            
            Step5_OnboardingSuccess()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Step 5: Onboarding Success")
            */
            
            // ISOLATE STEP 6 - The suspected problematic step
            Step6_FirstHabit()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("🧪 STEP 6 TEST - ISOLATED")
        }
    }
}


// MARK: - Mock ProfileViewModel for Previews
class MockProfileViewModel: ObservableObject {
    @Published var profiles: [ElderlyProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateProfile = false
    @Published var showingEditProfile = false
    @Published var selectedProfile: ElderlyProfile?
    @Published var profileName = "Grandpa Joe"
    @Published var phoneNumber = "+1 (555) 123-4567"
    @Published var relationship = "Grandparent"
    @Published var isEmergencyContact = false
    @Published var timeZone = TimeZone.current
    @Published var notes = ""
    @Published var nameError: String?
    @Published var phoneError: String?
    @Published var relationshipError: String?
    @Published var confirmationStatus: [String: ConfirmationStatus] = ["mock-profile-id": .sent]
    @Published var confirmationMessages: [String: String] = ["mock-profile-id": "Confirmed - ready for habits"]
    @Published var profileOnboardingStep: ProfileOnboardingStep = .newProfileForm
    @Published var showingProfileOnboarding = false
    @Published var hasSelectedPhoto = false
    @Published var selectedPhotoData: Data?
    
    var memberNumber: Int { 1 }
    var isValidForm: Bool { !profileName.isEmpty && !phoneNumber.isEmpty && !relationship.isEmpty }
    var relationshipOptions: [String] { ["Parent", "Grandparent", "Aunt", "Uncle", "Other Family Member"] }
    
    // Mock onboarding profile for preview
    var onboardingProfile: ElderlyProfile? {
        ElderlyProfile(
            id: "mock-profile-id",
            userId: "mock-user-id",
            name: profileName,
            phoneNumber: phoneNumber,
            relationship: relationship,
            isEmergencyContact: false,
            timeZone: "America/New_York",
            notes: "",
            status: .pendingConfirmation,
            createdAt: Date(),
            lastActiveAt: Date()
        )
    }
    
    // Mock DataSync coordinator access
    var dataSyncPublisher: MockDataSyncCoordinator { MockDataSyncCoordinator() }
    
    func startProfileOnboarding() {
        showingProfileOnboarding = true
    }
    
    func nextOnboardingStep() {}
    func previousOnboardingStep() {}
    func cancelProfileOnboarding() {}
    func sendOnboardingSMS() {}
    func createProfileForOnboarding() {}
    func completeProfileOnboarding() {}
}

// MARK: - Mock DataSyncCoordinator for Previews
class MockDataSyncCoordinator: ObservableObject {
    var smsResponses: AnyPublisher<SMSResponse, Never> {
        Just(SMSResponse(
            id: "mock-response",
            profileId: "mock-profile-id", 
            userId: "mock-user-id",
            textResponse: "OK",
            receivedAt: Date(),
            responseType: .text,
            isConfirmationResponse: true,
            isPositiveConfirmation: true
        ))
        .eraseToAnyPublisher()
    }
}

// MARK: - Mock TaskViewModel for Canvas Previews
class MockTaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedProfileId: String?
    @Published var taskTitle = ""
    @Published var taskDescription = ""
    @Published var frequency = TaskFrequency.daily
    @Published var category = TaskCategory.medication
    @Published var scheduledTime = Date()
    
    func createTask() {}
    func updateTask(_ task: Task) {}
    func deleteTask(_ task: Task) {}
    func markTaskComplete(_ task: Task) {}
}

// MARK: - Mock Container for Canvas Previews  
class MockContainer: ObservableObject {
    static let shared = MockContainer()
    
    private init() {}
    
    @MainActor
    func makeTaskViewModel() -> MockTaskViewModel {
        MockTaskViewModel()
    }
    
    @MainActor
    func makeProfileViewModel() -> MockProfileViewModel {
        MockProfileViewModel()
    }
}

// MARK: - Mock Container Environment Key
struct MockContainerKey: EnvironmentKey {
    static let defaultValue: MockContainer = MockContainer.shared
}

extension EnvironmentValues {
    var mockContainer: MockContainer {
        get { self[MockContainerKey.self] }
        set { self[MockContainerKey.self] = newValue }
    }
}
#endif
