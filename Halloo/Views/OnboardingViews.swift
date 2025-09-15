import SwiftUI

// MARK: - Custom Shapes
struct TopRoundedRectangle: Shape {
    let topRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: topRadius, height: topRadius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showMessages = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // Remi Logo - EXACT same Y-axis as LoginView (100px from top)
                Text("Remi")
                    .font(.custom("Poppins-Medium", size: 73.93))
                    .tracking(-3.0)
                    .foregroundColor(.black)
                    .padding(.top, 100) // Exact match with LoginView position
                
                // Message bubbles conversation - positioned close to logo
                VStack(spacing: 16) {
                    if showMessages {
                        // Blue bubble (sender) - "Create Reminders"
                        HStack {
                            Spacer(minLength: UIScreen.main.bounds.width * 0.2)
                            SpeechBubbleView(
                                text: "Create Reminders",
                                isOutgoing: true,
                                backgroundColor: Color(hex: "007AFF"),
                                textColor: .white
                            )
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        // Grey bubble (receiver) - "for anyone you love"
                        HStack {
                            SpeechBubbleView(
                                text: "for anyone you love",
                                isOutgoing: false,
                                backgroundColor: Color(hex: "E5E5EA"),
                                textColor: .black
                            )
                            Spacer(minLength: UIScreen.main.bounds.width * 0.2)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 40) // Close spacing to logo
                
                Spacer() // Push everything to top
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
        .onAppear {
            // Show messages after a brief delay with bottom-up animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.2)) {
                    showMessages = true
                }
            }
            
            // Auto-advance to login flow after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                viewModel.nextStep()
            }
        }
    }
}

// MARK: - iOS-Style Speech Bubble View
/**
 * PROFESSIONAL SPEECH BUBBLE - Following iOS Messages design
 * 
 * Features:
 * - Dynamic sizing with min/max width constraints
 * - Proper triangle tail positioning
 * - Elderly-friendly font sizes and accessibility
 * - iOS-authentic colors and styling
 */
struct SpeechBubbleView: View {
    let text: String
    let isOutgoing: Bool
    let backgroundColor: Color
    let textColor: Color
    
    // Dynamic sizing constraints
    private let minWidth: CGFloat = 60
    private let maxWidthPercent: CGFloat = 0.8
    private let cornerRadius: CGFloat = 18
    private let padding: CGFloat = 16
    private let tailSize: CGFloat = 15 // Bigger triangles
    
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .regular)) // Elderly-friendly 18pt minimum
            .foregroundColor(textColor)
            .padding(.horizontal, padding)
            .padding(.vertical, 12)
            .background(
                BubbleWithTail(isOutgoing: isOutgoing, cornerRadius: cornerRadius, tailSize: tailSize)
                    .fill(backgroundColor)
            )
            .frame(minWidth: minWidth)
            .frame(maxWidth: UIScreen.main.bounds.width * maxWidthPercent, alignment: isOutgoing ? .trailing : .leading)
    }
}

// MARK: - Corrected Bubble Shape with Attached Tail
struct BubbleWithTail: Shape {
    let isOutgoing: Bool
    let cornerRadius: CGFloat
    let tailSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let tailInset: CGFloat = 20 // Triangle positioned closer to edges but avoiding rounded corners
        
        if isOutgoing {
            // OUTGOING BUBBLE (Right tail attached to bottom)
            
            // Start from top-left, create full rounded rectangle first
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            
            // Top edge
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            
            // Right edge
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            
            // Bottom edge with right-angle triangle tail pointing LEFT
            // Go to where triangle starts (30pt from right edge)
            path.addLine(to: CGPoint(x: width - tailInset, y: height))
            
            // Left-pointing triangle (outgoing messages point toward center/left)
            path.addLine(to: CGPoint(x: width - tailInset - tailSize, y: height))          // Left point of triangle
            path.addLine(to: CGPoint(x: width - tailInset, y: height + tailSize))          // Bottom corner
            path.addLine(to: CGPoint(x: width - tailInset, y: height))                     // Back to start
            
            // Continue bottom edge to left
            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            
            // Left edge
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            
        } else {
            // INCOMING BUBBLE (Left tail attached to bottom)
            
            // Start from top-left, create full rounded rectangle first
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            
            // Top edge
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            
            // Right edge
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            
            // Bottom edge with right-angle triangle tail pointing RIGHT
            // Go to where triangle starts (30pt from left edge)
            path.addLine(to: CGPoint(x: tailInset, y: height))
            
            // Right-pointing triangle (incoming messages point toward center/right)
            path.addLine(to: CGPoint(x: tailInset + tailSize, y: height))                      // Right point of triangle
            path.addLine(to: CGPoint(x: tailInset, y: height + tailSize))                     // Bottom corner
            path.addLine(to: CGPoint(x: tailInset, y: height))                               // Back to start
            
            // Continue bottom edge to left
            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            
            // Left edge
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Account Setup View
struct AccountSetupView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    Text("Create Your Account")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                        .padding(.top, 50)
                    
                    VStack(spacing: 15) {
                        TextField("Full Name", text: $viewModel.fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        SecureField("Confirm Password", text: $viewModel.confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        TextField("Phone Number", text: $viewModel.phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .keyboardType(.phonePad)
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.previousStep()
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.nextStep()
                        }) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.isValidSignUpForm ? Color.blue : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.isValidSignUpForm)
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
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Quiz View
struct QuizView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showOptions = false
    @State private var showBars = false
    @State private var showBarText = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button
                if !viewModel.isQuizComplete {
                    HStack(spacing: 12) {
                        // Back button - always shows, goes to login on first question
                        Button(action: {
                            if viewModel.currentQuestionIndex > 0 {
                                viewModel.previousStep()
                            } else {
                                // First question - go back to login screen
                                viewModel.currentStep = .signUp
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
                                    .fill(Color(hex: "1A5FBF"))
                                    .frame(width: progressGeometry.size.width * CGFloat(viewModel.currentQuestionIndex + 1) / CGFloat(viewModel.totalQuestions), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                }
                
                if let question = viewModel.currentQuestion {
                    VStack {
                        // Question text as main title - left aligned, closer to top
                        Group {
                            if question.id == "age_statistic_break" {
                                // Special title for statistic break with personalized age group
                                Text(generateStatisticTitle())
                                    .font(.system(size: 24, weight: .bold))
                                    .tracking(-1.0)
                                    .foregroundColor(.black)
                            } else if question.question.contains("#1 habit") {
                                // Special styling for question 2 with gradient on "#1 habit"
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("What's the ")
                                            .font(.system(size: 24, weight: .bold))
                                            .tracking(-1.0)
                                            .foregroundColor(.black)
                                        
                                        Text("#1 habit")
                                            .font(.system(size: 24, weight: .bold))
                                            .tracking(-1.0)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(hex: "28ADFF"),
                                                        Color(hex: "1A5FBF")
                                                    ]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        
                                        Text(" you'd")
                                            .font(.system(size: 24, weight: .bold))
                                            .tracking(-1.0)
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        Text("love them to build right now?")
                                            .font(.system(size: 24, weight: .bold))
                                            .tracking(-1.0)
                                            .foregroundColor(.black)
                                        Spacer()
                                    }
                                }
                            } else {
                                // Regular question styling
                                Text(question.question)
                                    .font(.system(size: 24, weight: .bold))
                                    .tracking(-1.0)
                                    .foregroundColor(.black)
                            }
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20) // Closer to top
                        
                        Spacer()
                            .frame(maxHeight: 60) // Limit spacer height to bring options up
                        
                        // Answer options positioned higher on screen
                        VStack(spacing: 12) {
                            if question.id == "age_statistic_break" {
                                // Special statistic break screen with comparison bars wrapped in styled card
                                VStack(spacing: 30) {
                                    // Horizontal comparison bars wrapped in styled card
                                    VStack(spacing: 24) {
                                        // With Remi bar (longer)
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("With Remi")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.black)
                                            
                                            // Progress bar with white background and gradient fill
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    // White background bar (full width)
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.white)
                                                        .frame(width: geometry.size.width, height: 60)
                                                    
                                                    // Gradient progress bar (75% width) with animation
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color(hex: "28ADFF"),
                                                                Color(hex: "1A5FBF")
                                                            ]),
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        ))
                                                        .frame(width: showBars ? geometry.size.width * 0.75 : 0, height: 60)
                                                        .animation(.easeInOut(duration: 0.8), value: showBars)
                                                    
                                                    HStack {
                                                        Text("2x")
                                                            .font(.system(size: 18, weight: .regular))
                                                            .foregroundColor(.white)
                                                            .padding(.leading, 20)
                                                            .opacity(showBarText ? 1 : 0)
                                                            .animation(.easeInOut(duration: 0.4), value: showBarText)
                                                        Spacer()
                                                    }
                                                    .frame(width: geometry.size.width * 0.75, height: 60)
                                                }
                                            }
                                            .frame(height: 60)
                                        }
                                        
                                        // Without Remi bar (much shorter)
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Without Remi")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.black)
                                            
                                            // Progress bar with white background and grey fill
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    // White background bar (full width)
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.white)
                                                        .frame(width: geometry.size.width, height: 60)
                                                    
                                                    // Grey progress bar (25% width - much smaller) with animation
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: showBars ? geometry.size.width * 0.25 : 0, height: 60)
                                                        .animation(.easeInOut(duration: 0.8), value: showBars)
                                                    
                                                    HStack {
                                                        Text("20%")
                                                            .font(.system(size: 18, weight: .regular))
                                                            .foregroundColor(.black)
                                                            .padding(.leading, 20)
                                                            .opacity(showBarText ? 1 : 0)
                                                            .animation(.easeInOut(duration: 0.4), value: showBarText)
                                                        Spacer()
                                                    }
                                                    .frame(width: geometry.size.width * 0.25, height: 60)
                                                }
                                            }
                                            .frame(height: 60)
                                        }
                                    }
                                    
                                    // Description text inside card
                                    Text("Remi makes consistency easy")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 16)
                                }
                                .padding(.all, 24)
                                .background(cardBackground)
                                .padding(.horizontal, 12)
                                .onAppear {
                                    // Auto-select so Next button is enabled
                                    selectedOption = "continue"
                                    
                                    // Start bar animations
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showBars = true
                                    }
                                    
                                    // Start text fade-in after bars finish
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        showBarText = true
                                    }
                                }
                            } else if question.id == "post_paywall_thanks" {
                                // Post-paywall thank you screen
                                VStack(spacing: 30) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(Color(hex: "1A5FBF"))
                                    
                                    Text("We're excited to help you and your loved one stay connected!")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                                .onAppear {
                                    selectedOption = "Let's get started"
                                }
                            } else {
                                ForEach(Array(question.options.enumerated()), id: \.element) { index, option in
                                Button(action: {
                                    selectedOption = option
                                    // Add haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }) {
                                    HStack(spacing: 12) {
                                        // Light grey circle with numbers and checkmark animation
                                        ZStack {
                                            Circle()
                                                .fill(selectedOption == option ? Color(hex: "228B22") : Color.gray.opacity(0.3))
                                                .frame(width: 20, height: 20)
                                            
                                            if selectedOption == option {
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
                                        .animation(.easeInOut(duration: 0.3), value: selectedOption == option)
                                        
                                        Text(option)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(selectedOption == option ? .white : .black)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.trailing, 16)
                                    }
                                    .padding(.vertical, 16)
                                    .background(selectedOption == option ? Color(hex: "1A5FBF") : Color.white)
                                    .cornerRadius(25) // Pill shape
                                }
                                .opacity(showOptions ? 1 : 0)
                                .offset(y: showOptions ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: showOptions)
                            }
                            } // Close the else block
                        }
                        .padding(.horizontal, 24)
                        .opacity(question.id == "age_statistic_break" ? 1 : 1)
                        .animation(question.id == "age_statistic_break" ? .none : .none, value: showOptions)
                        
                        Spacer()
                        
                        // Next button
                        Button(action: {
                            if let selected = selectedOption {
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                viewModel.answerQuestion(selected)
                                selectedOption = nil // Reset for next question
                            }
                        }) {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedOption != nil ? Color(hex: "28ADFF") : Color(hex: "B9E3FF"))
                                .cornerRadius(25) // Pill shape
                        }
                        .disabled(selectedOption == nil)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20) // Closer to bottom
                    }
                    .id("question-\(viewModel.currentQuestionIndex)") // Unique ID for each question
                    .transition(.identity) // No transition animation between questions
                } else if viewModel.isQuizComplete {
                    VStack(spacing: 20) {
                        Text("Quiz Complete!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.top, 80)
                        
                        Text("Thank you for completing the assessment. Setting up your profile...")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Spacer()
                    }
                    .onAppear {
                        print("🧪 Quiz complete screen appeared - forcing navigation")
                        DispatchQueue.main.async {
                            viewModel.nextStep()
                        }
                    }
                }
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
            .onChange(of: viewModel.currentQuestionIndex) { _, _ in
                // Reset selection when question changes
                selectedOption = nil
                // Reset and trigger sequential animations
                resetAndStartAnimations()
            }
            .onAppear {
                // Trigger initial animations when view appears
                resetAndStartAnimations()
            }
        }
    }
    
    // Card background with subtle gradient wash
    private var cardBackground: some View {
        ZStack {
            // Linear gradient base
            RoundedRectangle(cornerRadius: 16)
                .fill(cardLinearGradient)
            
            // Radial gradient overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(cardRadialGradient)
        }
    }
    
    // Linear gradient for card background
    private var cardLinearGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.gray.opacity(0.06), location: 0.0),
                .init(color: Color(hex: "40E0D0").opacity(0.04), location: 0.3),
                .init(color: Color(hex: "28ADFF").opacity(0.05), location: 0.6),
                .init(color: Color.gray.opacity(0.08), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Radial gradient overlay for card background
    private var cardRadialGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "28ADFF").opacity(0.02), location: 0.2),
                .init(color: Color(hex: "40E0D0").opacity(0.015), location: 0.5),
                .init(color: Color.clear, location: 0.8)
            ]),
            center: .center,
            startRadius: 50,
            endRadius: 200
        )
    }
    
    // Generate personalized title based on age selection
    private func generateStatisticTitle() -> String {
        let ageAnswer = viewModel.userAnswers["loved_one_age"] ?? "Seniors"
        
        let ageGroup: String
        switch ageAnswer {
        case "Under 65":
            ageGroup = "Adults Under 65"
        case "65-74":
            ageGroup = "Seniors 65-74"
        case "75-84":
            ageGroup = "Seniors 75-84"
        case "85+":
            ageGroup = "Seniors 85+"
        default:
            ageGroup = "Seniors"
        }
        
        return "Text Reminders Work Better with \(ageGroup)"
    }
    
    // Generate personalized description based on age selection
    private func generateComparisonDescription() -> String {
        let ageAnswer = viewModel.userAnswers["loved_one_age"] ?? "Seniors"
        
        let ageGroup: String
        switch ageAnswer {
        case "Under 65":
            ageGroup = "Adults under 65"
        case "65-74":
            ageGroup = "Seniors 65-74"
        case "75-84":
            ageGroup = "Seniors 75-84"
        case "85+":
            ageGroup = "Seniors 85+"
        default:
            ageGroup = "Seniors"
        }
        
        return "Remi makes consistency easy"
    }
    
    private func resetAndStartAnimations() {
        // Reset all animation states immediately without animation
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showOptions = false
            showBars = false
            showBarText = false
        }
        
        // Start options animation after brief delay (for non-statistic questions)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showOptions = true
        }
    }
}

// MARK: - Profile Setup Confirmation View
struct ProfileSetupConfirmationView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top spacing
                Color.clear.frame(height: 80)
                
                // Thank you message
                Text("Thank you for trusting us")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // Subtitle
                Text("Do you want to set up your first profile and habit?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                
                Spacer()
                    .frame(maxHeight: 100)
                
                // Yes button - large and prominent
                Button(action: {
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Navigate to profile creation
                    onboardingViewModel.proceedToProfileSetup()
                }) {
                    Text("Yes")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(hex: "1A5FBF"))
                        .cornerRadius(25)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Skip button - smaller and less prominent
                Button(action: {
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Skip to main app
                    onboardingViewModel.skipProfileSetup()
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .underline()
                }
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Create Profile View moved to ProfileViews.swift

// MARK: - Onboarding Complete View
struct OnboardingCompleteView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("You're All Set!")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                    
                    Text("You can now start creating daily reminders for your elderly loved ones")
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                        .tracking(-0.5)
                    
                    Spacer()
                    
                    Button(action: {
                        // This will trigger the main app flow
                        viewModel.isComplete = true
                    }) {
                        Text("Start Using halloo")
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
    }
}

// LoadingView is defined in ContentView.swift