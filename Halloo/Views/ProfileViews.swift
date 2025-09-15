import SwiftUI
import AVFoundation
import Combine
import SuperwallKit

// MARK: - Custom Environment Key for Dismiss Action
struct DismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var customDismiss: () -> Void {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
    }
}

// MARK: - Profile Onboarding Flow with Custom Dismiss
/// Wrapper for ProfileOnboardingFlow that allows custom dismiss action for dashboard usage
struct ProfileOnboardingFlowWithDismiss: View {
    let dismissAction: () -> Void
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    var body: some View {
        ProfileOnboardingFlow()
            .environmentObject(profileViewModel)
            .environment(\.customDismiss, dismissAction)
    }
}

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
                    // Step Content - each step handles its own navigation
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
        .onChange(of: profileViewModel.shouldDismissOnboarding) { _, shouldDismiss in
            if shouldDismiss {
                profileViewModel.shouldDismissOnboarding = false // Reset flag
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    /// Returns the appropriate step view based on current onboarding step
    @ViewBuilder
    private func stepContentView(geometry: GeometryProxy) -> some View {
        switch profileViewModel.profileOnboardingStep {
        case .newProfileForm:
            Step1_NewProfileForm()
                .transition(.identity) // Remove step transition animations
        case .profileComplete:
            Step2_ProfileComplete()
                .transition(.identity) // Remove step transition animations
        case .smsIntroduction:
            Step3_SMSIntroduction()
                .transition(.identity) // Remove step transition animations
        case .confirmationWait:
            Step4_ConfirmationWait()
                .transition(.identity) // Remove step transition animations
        case .onboardingSuccess:
            Step5_OnboardingSuccess()
                .transition(.identity) // Remove step transition animations
        case .firstHabit:
            Step6_FirstHabit()
                .transition(.identity) // Remove step transition animations
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
        // Header spacing only - navigation handled by individual steps
        Color.clear
            .frame(height: 44)
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
    @Environment(\.customDismiss) var customDismiss
    @State private var showingImagePicker = false
    @State private var showingImageOptions = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isKeyboardVisible = false
    @State private var showingValidationAlert = false
    @State private var showingCameraPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            HStack {
                Button(action: {
                    print("🔙 BACK: Back button tapped in New Profile step")
                    // If we're at the first step, dismiss to dashboard
                    if profileViewModel.profileOnboardingStep == .newProfileForm {
                        customDismiss()
                    } else {
                        profileViewModel.previousOnboardingStep()
                    }
                }) {
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
                    .font(AppFonts.poppinsMedium(size: 18))
                    .tracking(-1.9)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    profileViewModel.nextOnboardingStep()
                }) {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .light))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(.gray)
                .disabled(!profileViewModel.isValidForm)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Main Title and Subtitle
                    VStack(spacing: 4) {
                        Text("New Profile")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                        
                        Text("Who are you setting this up for?")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 67)
                    
                    // Form Fields in White Card
                    VStack(spacing: 0) {
                        // Name Field with add photo button wrapped in HStack
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black)
                                
                                ZStack(alignment: .leading) {
                                    if profileViewModel.profileName.isEmpty {
                                        Text("eg. Debra Brown")
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundColor(.gray.opacity(0.8))
                                    }
                                    TextField("", text: $profileViewModel.profileName)
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(.black)
                                        .accentColor(.blue)
                                }
                                
                                if let nameError = profileViewModel.nameError {
                                    Text(nameError)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingImageOptions = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(hex: "C7E9FF"), // Left side
                                                    Color(hex: "28ADFF")  // Right side
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 51, height: 51)
                                    
                                    if let photoData = profileViewModel.selectedPhotoData,
                                       let uiImage = UIImage(data: photoData) {
                                        // Display selected photo
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 51, height: 51)
                                            .clipShape(Circle())
                                    } else {
                                        // Display plus icon
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        
                        // Divider Line
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.leading, 20)
                            .padding(.trailing, 85)
                        
                        // Relationship Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Relationship to You")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.black)
                            
                            ZStack(alignment: .leading) {
                                if profileViewModel.relationship.isEmpty {
                                    Text("eg. Dad")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                TextField("", text: $profileViewModel.relationship)
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black)
                                    .accentColor(.blue)
                            }
                            
                            if let relationshipError = profileViewModel.relationshipError {
                                Text(relationshipError)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        
                        // Divider Line
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                        
                        // Phone Number Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone Number")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.black)
                            
                            ZStack(alignment: .leading) {
                                if profileViewModel.phoneNumber == "+1 " {
                                    Text("+1 123 456 7890")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                TextField("", text: $profileViewModel.phoneNumber)
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black)
                                    .accentColor(.blue)
                                    .keyboardType(.phonePad)
                                    .onChange(of: profileViewModel.phoneNumber) { _, newValue in
                                        // Ensure +1 prefix is always there
                                        if !newValue.hasPrefix("+1 ") {
                                            profileViewModel.phoneNumber = "+1 "
                                        }
                                        // Auto-dismiss keyboard when phone number is complete (14 characters: "+1 123 456 7890")
                                        if newValue.count >= 14 {
                                            hideKeyboard()
                                        }
                                    }
                            }
                            
                            if let phoneError = profileViewModel.phoneError {
                                Text(phoneError)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
                    
                    Spacer(minLength: 100) // Space for bottom button
                }
                .padding(.horizontal, 32)
            }
            
            // Bottom Action Button - Hidden when keyboard is visible
            if !isKeyboardVisible {
                VStack {
                    Button(action: {
                        if profileViewModel.isValidForm {
                            profileViewModel.nextOnboardingStep()
                        } else {
                            showingValidationAlert = true
                        }
                    }) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 47)
                            .background(profileViewModel.isValidForm ? Color(hex: "28ADFF") : Color(hex: "BFE6FF"))
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 10) // Close to bottom of screen
                }
            }
        }
        .background(
            // App background with gradient overlay
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear, // Top (fully transparent)
                        Color(hex: "B3B3B3")     // Bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225) // Move half the height down so half is below screen
            }
            .ignoresSafeArea()
        )
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
            if profileViewModel.profileOnboardingStep == .profileComplete {
                // Clear form errors when successfully advancing
                profileViewModel.nameError = nil
                profileViewModel.phoneError = nil
                profileViewModel.relationshipError = nil
            }
        }
        .actionSheet(isPresented: $showingImageOptions) {
            ActionSheet(
                title: Text("Select Photo"),
                message: Text("Choose how you'd like to add a photo"),
                buttons: cameraButtons()
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                sourceType: imageSourceType,
                onImagePicked: { imageData in
                    profileViewModel.selectedPhotoData = imageData
                    profileViewModel.hasSelectedPhoto = true
                }
            )
        }
        .alert("Missing Information", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let missing = profileViewModel.missingRequirements
            if missing.count == 1 {
                Text("Please add: \(missing.first!)")
            } else {
                Text("Please complete: \(missing.joined(separator: ", "))")
            }
        }
        .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
            Button("Settings", role: .none) {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to take photos for profiles.")
        }
    }
    
    // MARK: - Keyboard Observer Methods
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func cameraButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        
        // Check if camera is available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            buttons.append(.default(Text("Camera")) {
                print("📷 Camera selected")
                checkCameraPermission()
            })
        }
        
        // Photo Library is almost always available
        buttons.append(.default(Text("Photo Library")) {
            print("📸 Photo Library selected")
            imageSourceType = .photoLibrary
            showingImagePicker = true
        })
        
        buttons.append(.cancel())
        return buttons
    }
    
    private func checkCameraPermission() {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("📷 Camera permission granted")
                        self.imageSourceType = .camera
                        self.showingImagePicker = true
                    } else {
                        print("📷 Camera permission denied")
                        self.showingCameraPermissionAlert = true
                    }
                }
            }
        case .authorized:
            print("📷 Camera already authorized")
            imageSourceType = .camera
            showingImagePicker = true
        case .restricted, .denied:
            print("📷 Camera access restricted or denied")
            showingCameraPermissionAlert = true
        @unknown default:
            print("📷 Unknown camera authorization status")
            showingCameraPermissionAlert = true
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
        VStack(spacing: 0) {
            // Top Navigation Bar (consistent with Step 1)
            HStack {
                Button(action: {
                    profileViewModel.previousOnboardingStep()
                }) {
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
                    .font(AppFonts.poppinsMedium(size: 18))
                    .tracking(-1.9)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    profileViewModel.nextOnboardingStep()
                }) {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .light))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Step Title and Subtitle (with profile name)
                    VStack(spacing: 4) {
                        Text("Profile Complete")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                        
                        Text("Let's add your first habit for \(profileViewModel.profileName.isEmpty ? "Dad" : profileViewModel.profileName) now :)")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 67)
                    
                    // Profile Summary Card
                    VStack(spacing: 0) {
                        // Member Indicator Header
                        HStack {
                            Text("Member #\(profileViewModel.memberNumber)")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            // Single progress dot
                            Circle()
                                .fill(Color(hex: "B9E3FF"))
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // Profile Row with Photo and Info
                        HStack(spacing: 16) {
                            // Profile Photo (circular)
                            ZStack {
                                Circle()
                                    .fill(profileColorForMember(profileViewModel.memberNumber).opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                if let photoData = profileViewModel.selectedPhotoData,
                                   let uiImage = UIImage(data: photoData) {
                                    // Display actual selected photo
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else if profileViewModel.hasSelectedPhoto {
                                    // Fallback icon if photo data is missing
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(profileColorForMember(profileViewModel.memberNumber))
                                }
                                // Clean look: just background color when no photo selected
                            }
                            
                            Spacer()
                            
                            // Name and Status (right-aligned)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(profileViewModel.profileName.isEmpty ? "Debra Brown" : profileViewModel.profileName)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.black)
                                
                                Text("Habits Tracked: 0")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        // Bottom Info Row
                        HStack {
                            Text(formatJoinDate(Date()))
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(profileViewModel.relationship.isEmpty ? "Dad" : profileViewModel.relationship)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
                    
                    Spacer(minLength: 100) // Space for bottom button
                }
                .padding(.horizontal, 32)
            }
            
            // Bottom Action Button
            VStack {
                Button(action: {
                    profileViewModel.nextOnboardingStep()
                }) {
                    Text("Onboard Your Member")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 47)
                        .background(Color(hex: "28ADFF"))
                        .cornerRadius(15)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10) // Close to bottom of screen
            }
        }
        .background(
            // App background with gradient overlay (same as Step 1)
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear, // Top (fully transparent)
                        Color(hex: "B3B3B3")     // Bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225) // Move half the height down so half is below screen
            }
            .ignoresSafeArea()
        )
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
        VStack(spacing: 0) {
            // Top Navigation Bar (consistent with Step 1 & 2)
            HStack {
                Button(action: {
                    profileViewModel.previousOnboardingStep()
                }) {
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
                    .font(AppFonts.poppinsMedium(size: 18))
                    .tracking(-1.9)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    profileViewModel.nextOnboardingStep()
                }) {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .light))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Step Title and Subtitle
                    VStack(spacing: 4) {
                        Text("Onboard Your Member")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                        
                        Text("Send them an SMS and see if they receive it!")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 67)
                    
                    // Simple White Card with SMS Message (consistent with Steps 1 & 2)
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 16) {
                            // REMI message bubble (received - left aligned)
                            HStack {
                                Text("👋 Hi! This is REMI, a caring app that sends gentle check-ins to help you stay healthy. Reply YES to get started!")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(18)
                                    .frame(maxWidth: 270, alignment: .leading)
                                
                                Spacer()
                            }
                            
                            // Extra spacing below message
                            Spacer()
                                .frame(height: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
                    
                    Spacer(minLength: 100) // Space for bottom button
                }
                .padding(.horizontal, 32)
            }
                    
            // Bottom Action Button
            VStack {
                Button(action: {
                    sendSMSToProfile()
                }) {
                    HStack(spacing: 4) {
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
                    .frame(maxWidth: .infinity, minHeight: 47)
                    .background(Color(hex: "28ADFF"))
                    .cornerRadius(15)
                }
                .disabled(profileViewModel.isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 10) // Close to bottom of screen
            }
        }
        .background(
            // App background with gradient overlay (same as Step 1 & 2)
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear, // Top (fully transparent)
                        Color(hex: "B3B3B3")     // Bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225) // Move half the height down so half is below screen
            }
            .ignoresSafeArea()
        )
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
    @State private var smsConfirmed = false
    @State private var resendCountdown = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar (consistent with Step 3)
            HStack {
                Button(action: {
                    profileViewModel.previousOnboardingStep()
                }) {
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
                    .font(AppFonts.poppinsMedium(size: 18))
                    .tracking(-1.9)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    profileViewModel.nextOnboardingStep()
                }) {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .light))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Step Title and Subtitle
                    VStack(spacing: 4) {
                        Text(smsConfirmed ? "Onboarding Complete" : "Waiting for Confirmation")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text(smsConfirmed ? "Let's Create Their First Habit :)" : "Ask them to reply the text with OK!!")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 67)
                    
                    // Simple White Card with SMS Message (same as Step 3)
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 16) {
                            // REMI message bubble (received - left aligned)
                            HStack {
                                Text("👋 Hi! This is REMI, a caring app that sends gentle check-ins to help you stay healthy. Reply YES to get started!")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(18)
                                    .frame(maxWidth: 270, alignment: .leading)
                                
                                Spacer()
                            }
                            
                            // Reply message bubble (sent - right aligned)
                            HStack {
                                Spacer()
                                
                                Text("OK")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "28ADFF"))
                                    .cornerRadius(18)
                            }
                            
                            // Extra spacing below message
                            Spacer()
                                .frame(height: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
                    
                    Spacer(minLength: 100) // Space for bottom button
                }
                .padding(.horizontal, 32)
            }
            
            // Bottom button area
            VStack(spacing: 0) {
                // Button for next step - disabled until SMS confirmation
                Button(action: {
                    if smsConfirmed {
                        profileViewModel.nextOnboardingStep()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(smsConfirmed ? Color(hex: "28ADFF") : Color(hex: "BFE6FF"))
                    .cornerRadius(15)
                }
                .disabled(!smsConfirmed)
                .padding(.horizontal, 24)
                
                // Resend link - only show when SMS not confirmed
                if !smsConfirmed {
                    HStack {
                        Text("Didn't receive the message?")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.gray)
                        
                        Button(resendCountdown > 0 ? "Resend (\(resendCountdown)s)" : "Resend") {
                            // Resend SMS functionality
                            if resendCountdown == 0 {
                                profileViewModel.sendOnboardingSMS()
                                startResendCountdown()
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(resendCountdown > 0 ? .gray : Color(hex: "28ADFF"))
                        .disabled(resendCountdown > 0)
                    }
                    .padding(.top, 12)
                }
                
                Spacer()
                    .frame(height: 10)
            }
        }
        .background(
            // App background with gradient overlay (same as Step 1, 2 & 3)
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear, // Top (fully transparent)
                        Color(hex: "B3B3B3")     // Bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225) // Move half the height down so half is below screen
            }
            .ignoresSafeArea()
        )
        .onAppear {
            // Simulate SMS confirmation after 2 seconds for demo
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    smsConfirmed = true
                }
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startResendCountdown() {
        resendCountdown = 60
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer?.invalidate()
                timer = nil
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
                            .font(.system(size: 16, weight: .light))
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
                            .font(.system(size: 16, weight: .light))
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
                            .font(.system(size: 16, weight: .light))
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
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.container) private var container
    @State private var showingTaskCreation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar with Remi Logo
            HStack {
                Button(action: {
                    profileViewModel.previousOnboardingStep()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .light))
                    }
                }
                .foregroundColor(.gray)
                
                Spacer()
                
                // Remi Logo (centered)
                Text("Remi")
                    .font(AppFonts.poppinsMedium(size: 18))
                    .tracking(-1.9)
                    .foregroundColor(.black)
                
                Spacer()
                
                // Empty space to balance the layout (no done button)
                Color.clear
                    .frame(width: 60, height: 20)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 67) {
                    // Step Title and Subtitle
                    VStack(spacing: 4) {
                        Text("Create a New Habit")
                            .font(.system(size: 34, weight: .medium))
                            .kerning(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("Let's Create Their First Task :)")
                            .font(.system(size: 14, weight: .light))
                            .kerning(-0.3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 67)
                    
                    // Simple White Card (consistent with other steps)
                    VStack(spacing: 0) {
                        VStack(alignment: .center, spacing: 24) {
                            // Habit creation icon
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "28ADFF"))
                            
                            // Description text
                            Text("Habits are daily reminders sent via SMS to help your family member stay healthy and connected.")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                            
                            // Benefits list
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(Color(hex: "28ADFF"))
                                    Text("Medication reminders")
                                        .font(.system(size: 14, weight: .light))
                                        .foregroundColor(.gray)
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(Color(hex: "28ADFF"))
                                    Text("Exercise and wellness check-ins")
                                        .font(.system(size: 14, weight: .light))
                                        .foregroundColor(.gray)
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(Color(hex: "28ADFF"))
                                    Text("Social activities and family time")
                                        .font(.system(size: 14, weight: .light))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
                    
                    Spacer(minLength: 100) // Space for bottom button
                }
                .padding(.horizontal, 32)
            }
            
            // Bottom button area (consistent with other steps)
            VStack(spacing: 0) {
                Button(action: {
                    // Show task creation with newly created profile preselected
                    showingTaskCreation = true
                }) {
                    HStack(spacing: 4) {
                        Text("Create First Habit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "28ADFF"))
                    .cornerRadius(15)
                }
                .padding(.horizontal, 24)
                
                // Skip option - go to dashboard instead of back to "Add Family Member"
                Button(action: {
                    // Complete the entire onboarding to navigate to dashboard
                    onboardingViewModel.skipToEnd()
                    profileViewModel.completeProfileOnboarding()
                }) {
                    Text("Skip for Now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
        }
        .background(
            // App background with gradient overlay (same as other steps)
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear, // Top (fully transparent)
                        Color(hex: "B3B3B3")     // Bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225) // Move half the height down so half is below screen
            }
            .ignoresSafeArea()
        )
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
/// 
/// This replaces the previous basic profile creation with the sophisticated
/// onboarding experience specified in requirements.
struct CreateProfileView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    var body: some View {
        Group {
            if profileViewModel.showingProfileOnboarding {
                // Show profile onboarding flow without animation
                ProfileOnboardingFlow()
                    .environmentObject(profileViewModel)
                    .transition(.identity)
                    .animation(nil, value: profileViewModel.showingProfileOnboarding)
            } else {
                // Show add family member screen
                addFamilyMemberScreen
                    .transition(.identity)
                    .animation(nil, value: profileViewModel.showingProfileOnboarding)
            }
        }
        .animation(nil) // Disable all animations for this view
    }
    
    private var addFamilyMemberScreen: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top spacing for status bar
                Color.clear.frame(height: 60)
                
                // Title centered at top of screen
                Text("Add Family Member")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                
                // Subtitle
                Text("Set up your first profile")
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .foregroundColor(.gray)
                    .tracking(-0.5)
                
                Spacer()
                
                // Bird2 image positioned in the center (scaled 2x)
                Image("Bird2")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.5)
                    .clipped()
                
                Spacer()
                
                // Get Started button - start profile onboarding
                Button(action: {
                    // Disable animations for the transition
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        profileViewModel.startProfileOnboarding()
                    }
                }) {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 47)
                        .background(Color(hex: "28ADFF"))
                        .cornerRadius(15)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 10) // Match profile flow positioning
            }
        }
        .background(
            // App background with gradient overlay matching profile creation flow
            ZStack(alignment: .bottom) {
                Color(hex: "f9f9f9")
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear, // Top (fully transparent)
                        Color(hex: "B3B3B3")     // Bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 451)
                .offset(y: 225) // Move half the height down so half is below screen
            }
            .ignoresSafeArea()
        )
    }
}

// MARK: - Preview Support
#if DEBUG
struct ProfileViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // MINIMAL TEST - Step 1 only to isolate issue  
            Step1_NewProfileForm()
                .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
                .environment(\.container, Container.makeForTesting())
                .previewDisplayName("🧪 STEP 1 TEST")
            
            // STEP 2 TEST - Profile Complete
            Step2_ProfileComplete()
                .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
                .environment(\.container, Container.makeForTesting())
                .previewDisplayName("🧪 STEP 2 TEST - Profile Complete")
            
            // STEP 3 TEST - SMS Introduction
            Step3_SMSIntroduction()
                .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
                .environment(\.container, Container.makeForTesting())
                .previewDisplayName("🧪 STEP 3 TEST - SMS Introduction")
            
            // STEP 4 TEST - Waiting for Confirmation
            Step4_ConfirmationWait()
                .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
                .environment(\.container, Container.makeForTesting())
                .previewDisplayName("🧪 STEP 4 TEST - Waiting for Confirmation")
            
            // STEP 6 TEST - Create a New Habit
            Step6_FirstHabit()
                .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
                .environment(\.container, Container.makeForTesting())
                .previewDisplayName("🧪 STEP 6 TEST - Create a New Habit")
            
            // STEP BY STEP TESTING - Additional steps (uncomment as needed)
            /*
            
            Step4_ConfirmationWait()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Step 4: SMS Confirmation Wait")
            
            Step5_OnboardingSuccess()
                .environmentObject(MockProfileViewModel())
                .environment(\.container, Container.shared)
                .previewDisplayName("📱 Step 5: Onboarding Success")
            
            Step6_FirstHabit()
                .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
                .environment(\.container, Container.makeForTesting())
                .previewDisplayName("📱 Step 6: First Habit")
            
            // Test the TaskCreationView integration from Step 6
            NavigationView {
                VStack {
                    Text("Step 6 → Task Creation Flow Test")
                        .font(.title2)
                        .padding()
                    
                    TaskCreationView(preselectedProfileId: "onboarding-profile-test")
                        .environmentObject(Container.makeForTesting().makeTaskViewModel())
                }
            }
            .previewDisplayName("🔄 Step 6 → Task Creation Flow")
            */
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
            taskId: nil,
            profileId: "mock-profile-id", 
            userId: "mock-user-id",
            textResponse: "OK",
            photoData: nil,
            isCompleted: true,
            receivedAt: Date(),
            responseType: .text,
            isConfirmationResponse: true,
            isPositiveConfirmation: true,
            responseScore: nil,
            processingNotes: nil
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

// MARK: - Custom Shape for Selective Corner Rounding
struct RoundedCornerShape: Shape {
    let corners: UIRectCorner
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Image Picker Component
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (Data) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        // Camera-specific setup
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
            picker.allowsEditing = false
            print("📷 Setting up camera picker")
        } else {
            print("📸 Setting up photo library picker")
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("📷 Image picker finished picking media")
            if let image = info[.originalImage] as? UIImage {
                print("📷 Image found with size: \(image.size)")
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    print("📷 Image converted to data: \(imageData.count) bytes")
                    parent.onImagePicked(imageData)
                } else {
                    print("❌ Failed to convert image to JPEG data")
                }
            } else {
                print("❌ No image found in picker info")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("📷 Image picker cancelled")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
#endif
