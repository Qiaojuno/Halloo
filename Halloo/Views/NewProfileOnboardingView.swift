import SwiftUI

// MARK: - Step-by-Step Profile Creation Flow (True Onboarding Style)
struct NewProfileOnboardingView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    let dismissAction: (() -> Void)?
    
    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }
    
    @State private var showingImagePicker = false
    @State private var showingImageOptions = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var currentStep: ProfileStep = .name
    @State private var showOptions = false
    
    enum ProfileStep {
        case name
        case relationship
        case picture
        case phone
        case confirmation
    }
    
    private let totalSteps = 4 // Don't count confirmation as a step
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button (only for steps 1-3)
                if currentStep != .confirmation {
                    HStack(spacing: 12) {
                        // Back button
                        Button(action: {
                            switch currentStep {
                            case .name:
                                // First step - clear form and dismiss entirely
                                profileViewModel.resetForm()
                                if let dismissAction = dismissAction {
                                    dismissAction()
                                } else {
                                    dismiss()
                                }
                            case .relationship:
                                currentStep = .name
                            case .picture:
                                currentStep = .relationship
                            case .phone:
                                currentStep = .picture
                            case .confirmation:
                                break // No back from confirmation
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        
                        // Progress bar
                        GeometryReader { progressGeometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: progressGeometry.size.width * progressPercentage, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                }
                
                // Step content
                Group {
                    switch currentStep {
                    case .name:
                        nameStep
                    case .relationship:
                        relationshipStep
                    case .picture:
                        pictureStep
                    case .phone:
                        phoneStep
                    case .confirmation:
                        confirmationStep
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color(hex: "f9f9f9")
                    
                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color(hex: "B3B3B3").opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                    }
                }
                .ignoresSafeArea(.all)
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            imagePickerSheet
        }
        .actionSheet(isPresented: $showingImageOptions) {
            imageOptionsActionSheet
        }
        .onChange(of: currentStep) { _, _ in
            // Reset and trigger animations when step changes
            resetAndStartAnimations()
        }
        .onAppear {
            // Clear form and trigger initial animations when view appears
            profileViewModel.resetForm()
            resetAndStartAnimations()
        }
    }
    
    private var progressPercentage: CGFloat {
        switch currentStep {
        case .name: return 1.0 / CGFloat(totalSteps)
        case .relationship: return 2.0 / CGFloat(totalSteps)
        case .picture: return 3.0 / CGFloat(totalSteps)
        case .phone: return 4.0 / CGFloat(totalSteps)
        case .confirmation: return 1.0 // Not shown
        }
    }
    
    // MARK: - Name Step
    private var nameStep: some View {
        VStack {
            // Question text as main title - left aligned, closer to top
            Text("What's their name?")
                .font(.system(size: 24, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Name input field
            VStack(spacing: 16) {
                TextField("", text: $profileViewModel.profileName, prompt: Text("Enter their full name").foregroundColor(.gray.opacity(0.6)))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(8) // Rounded rectangle
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Next button
            Button(action: {
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                currentStep = .relationship
            }) {
                Text("Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(nameIsValid ? Color.black : Color.gray.opacity(0.3))
                    .cornerRadius(8) // Rounded rectangle
            }
            .disabled(!nameIsValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    private var nameIsValid: Bool {
        !profileViewModel.profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Relationship Step
    private var relationshipStep: some View {
        VStack {
            // Question text as main title - left aligned, closer to top
            Text("What's your relationship to \(profileViewModel.profileName.isEmpty ? "them" : profileViewModel.profileName)?")
                .font(.system(size: 24, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Relationship options
            VStack(spacing: 12) {
                ForEach(Array(profileViewModel.relationshipOptions.enumerated()), id: \.element) { index, option in
                    Button(action: {
                        profileViewModel.relationship = option
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }) {
                        HStack(spacing: 12) {
                            // Light grey circle with numbers and checkmark animation
                            ZStack {
                                Circle()
                                    .fill(profileViewModel.relationship == option ? Color.black : Color.gray.opacity(0.3))
                                    .frame(width: 20, height: 20)
                                
                                if profileViewModel.relationship == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.leading, 16)
                            .animation(.easeInOut(duration: 0.3), value: profileViewModel.relationship == option)
                            
                            Text(option)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(profileViewModel.relationship == option ? .white : .black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 16)
                        }
                        .padding(.vertical, 16)
                        .background(profileViewModel.relationship == option ? Color.black : Color.white)
                        .cornerRadius(8) // Rounded rectangle
                    }
                    .opacity(showOptions ? 1 : 0)
                    .offset(y: showOptions ? 0 : 10)
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: showOptions)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Next button
            Button(action: {
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                currentStep = .picture
            }) {
                Text("Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(!profileViewModel.relationship.isEmpty ? Color.black : Color.gray.opacity(0.3))
                    .cornerRadius(8) // Rounded rectangle
            }
            .disabled(profileViewModel.relationship.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Picture Step
    private var pictureStep: some View {
        VStack {
            // Question text as main title - left aligned, closer to top
            Text("Add a photo of \(profileViewModel.profileName.isEmpty ? "them" : profileViewModel.profileName)")
                .font(.system(size: 24, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Profile photo section - matching onboarding style
            VStack(spacing: 16) {
                Button(action: {
                    // Add haptic feedback for photo selection
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    showingImageOptions = true
                }) {
                    ZStack {
                        // White background circle with shadow
                        Circle()
                            .fill(Color.white)
                            .frame(width: 160, height: 160)
                            .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 8, x: 0, y: 4)
                        
                        if let photoData = profileViewModel.selectedPhotoData,
                           let uiImage = UIImage(data: photoData) {
                            // Show selected image
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                        } else {
                            // Default icon when no image
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: "CCCCCC"))
                        }
                        
                        // Dotted circle outline when no image
                        if profileViewModel.selectedPhotoData == nil {
                            Circle()
                                .stroke(Color(hex: "E0E0E0"), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                .frame(width: 150, height: 150)
                        }
                        
                        // Black camera/edit button in bottom right
                        Circle()
                            .fill(Color.black)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: profileViewModel.selectedPhotoData == nil ? "camera.fill" : "pencil")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 55, y: 55)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                
                Text("Optional - Tap to add photo")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Next button
            Button(action: {
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                currentStep = .phone
            }) {
                Text("Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)  // Always enabled since photo is optional
                    .cornerRadius(8) // Rounded rectangle
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Phone Step
    private var phoneStep: some View {
        VStack {
            // Question text as main title - left aligned, closer to top
            Text("What's \(profileViewModel.profileName.isEmpty ? "their" : profileViewModel.profileName)'s phone number?")
                .font(.system(size: 24, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Phone input field
            VStack(spacing: 16) {
                TextField("", text: $profileViewModel.phoneNumber, prompt: Text("(555) 123-4567").foregroundColor(.gray.opacity(0.6)))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.black)
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(8) // Rounded rectangle
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                
                Text("We'll send them a text to confirm they want to receive reminders.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Create Profile button
            Button(action: {
                createProfile()
            }) {
                Text("Create Profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(phoneIsValid ? Color.black : Color.gray.opacity(0.3))
                    .cornerRadius(8) // Rounded rectangle
            }
            .disabled(!phoneIsValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    private var phoneIsValid: Bool {
        !profileViewModel.phoneNumber.isEmpty && profileViewModel.phoneNumber != "+1 "
    }
    
    // MARK: - Confirmation Step
    private var confirmationStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Success animation area
            VStack(spacing: 32) {
                // Clock icon for pending confirmation
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "clock")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                // Confirmation message
                VStack(spacing: 12) {
                    Text("Profile Created!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("\(profileViewModel.profileName) will appear on your dashboard but won't receive reminders until they confirm via text message.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            
            // Debug information
            if !profileViewModel.debugInfo.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🔍 Debug Info:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text(profileViewModel.debugInfo)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxHeight: 150)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            
            Spacer()
            
            // Done button
            Button(action: {
                // Reset the form when dismissing from confirmation
                profileViewModel.resetForm()
                if let dismissAction = dismissAction {
                    dismissAction()
                } else {
                    dismiss()
                }
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 47)
                    .background(Color.black)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
    }
    
    // MARK: - Helper Functions
    private func resetAndStartAnimations() {
        // Reset all animation states immediately without animation
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showOptions = false
        }
        
        // Start options animation after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showOptions = true
        }
    }
    
    private func createProfile() {
        profileViewModel.createProfile()
        
        // Monitor the profile creation process
        _Concurrency.Task {
            var attempts = 0
            let maxAttempts = 20 // 10 seconds max wait
            
            while attempts < maxAttempts {
                try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                attempts += 1
                
                await MainActor.run {
                    // Check if profile creation completed (either success or error)
                    if !profileViewModel.isLoading {
                        if profileViewModel.errorMessage == nil {
                            // Success - profile was created, clear form and show confirmation
                            profileViewModel.resetForm()
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentStep = .confirmation
                            }
                        } else {
                            // Error occurred - could show error UI
                            print("Profile creation failed: \(profileViewModel.errorMessage ?? "Unknown error")")
                        }
                        return
                    }
                }
                
                // Break out of loop if we found completion
                if !profileViewModel.isLoading {
                    break
                }
            }
        }
    }
}

// MARK: - Image Picker (Reused from existing profile creation)
extension NewProfileOnboardingView {
    private var imagePickerSheet: some View {
        ImagePicker(
            sourceType: imageSourceType,
            onImagePicked: { imageData in
                profileViewModel.selectedPhotoData = imageData
            }
        )
    }
    
    private var imageOptionsActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Add Photo"),
            buttons: [
                .default(Text("Camera")) {
                    imageSourceType = .camera
                    showingImagePicker = true
                },
                .default(Text("Photo Library")) {
                    imageSourceType = .photoLibrary
                    showingImagePicker = true
                },
                .cancel()
            ]
        )
    }
}

// MARK: - Previews
#if DEBUG
struct NewProfileOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        NewProfileOnboardingView()
            .environmentObject(Container.makeForTesting().makeProfileViewModelForCanvas())
    }
}
#endif