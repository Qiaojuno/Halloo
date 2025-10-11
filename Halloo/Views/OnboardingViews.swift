import SwiftUI
import SuperwallKit

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
    var maxWidth: CGFloat? = nil  // Optional override for custom layouts (e.g., cards)
    var scale: CGFloat = 1.0  // Optional scale factor for proportional sizing

    // Dynamic sizing constraints (scaled proportionally)
    private var minWidth: CGFloat { 60 * scale }
    private let maxWidthPercent: CGFloat = 0.8
    private var cornerRadius: CGFloat { 12 * scale }  // Increased from 9 to 12
    private var padding: CGFloat { 16 * scale }
    private var tailSize: CGFloat { 15 * scale }
    private var fontSize: CGFloat { 18 * scale }
    private var verticalPadding: CGFloat { 9 * scale }  // Reduced from 12 to 9 (3pt reduction per side)

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(textColor)
            .padding(.horizontal, padding)
            .padding(.vertical, verticalPadding)
            .background(
                BubbleWithTail(isOutgoing: isOutgoing, cornerRadius: cornerRadius, tailSize: tailSize)
                    .fill(backgroundColor)
            )
            .frame(minWidth: minWidth)
            .frame(maxWidth: maxWidth ?? (UIScreen.main.bounds.width * maxWidthPercent), alignment: isOutgoing ? .trailing : .leading)
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
                                .foregroundColor(.black)
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
                                .background(viewModel.isValidSignUpForm ? Color.black : Color.gray)
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

// MARK: - Step 1: Who For View
struct Step1View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showOptions = false

    let options = [
        "My parent",
        "My grandparent",
        "My partner",
        "Someone else I care about"
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            Rectangle()
                                .fill(Color.black)
                                .frame(width: progressGeometry.size.width * (1.0 / 9.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Header
                Text("Who are you downloading Remi for?")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Spacer()
                    .frame(maxHeight: 60)

                // Options
                VStack(spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.element) { index, option in
                        Button(action: {
                            selectedOption = option
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(spacing: 12) {
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
                            .background(selectedOption == option ? Color.black : Color.white)
                            .cornerRadius(25)
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
                    if let selected = selectedOption {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        viewModel.userAnswers["who_for"] = selected
                        viewModel.nextStep()
                    }
                }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedOption != nil ? Color.black : Color.gray.opacity(0.3))
                        .cornerRadius(25)
                }
                .disabled(selectedOption == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showOptions = true
                }
            }
        }
    }
}

// MARK: - Step 2: Connection View
struct Step2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showOptions = false

    let options = [
        "Every day",
        "A few times a week",
        "Once a week",
        "Not as often as I'd like"
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            Rectangle()
                                .fill(Color.black)
                                .frame(width: progressGeometry.size.width * (2.0 / 9.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Header
                Text("How often do you think about them?")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Spacer()
                    .frame(maxHeight: 60)

                // Options
                VStack(spacing: 12) {
                    ForEach(Array(options.enumerated()), id: \.element) { index, option in
                        Button(action: {
                            selectedOption = option
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(spacing: 12) {
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
                            .background(selectedOption == option ? Color.black : Color.white)
                            .cornerRadius(25)
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
                    if let selected = selectedOption {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        viewModel.userAnswers["connection_frequency"] = selected
                        viewModel.nextStep()
                    }
                }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedOption != nil ? Color.black : Color.gray.opacity(0.3))
                        .cornerRadius(25)
                }
                .disabled(selectedOption == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showOptions = true
                }
            }
        }
    }
}

// MARK: - Step 3: Name & Relationship View
struct Step3View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var lovedOneName: String = ""
    @State private var selectedRelationship: String? = nil
    @State private var showContent = false

    let relationshipOptions = [
        "Mom",
        "Dad",
        "Grandma",
        "Grandpa",
        "Partner",
        "Other"
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            Rectangle()
                                .fill(Color.black)
                                .frame(width: progressGeometry.size.width * (3.0 / 9.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Header
                Text("Tell us about them")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: showContent)

                Spacer()
                    .frame(maxHeight: 40)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Their name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)

                    TextField("Enter their name", text: $lovedOneName)
                        .font(.system(size: 18, weight: .regular))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.1), value: showContent)

                // Relationship selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your relationship")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    VStack(spacing: 8) {
                        ForEach(Array(relationshipOptions.enumerated()), id: \.element) { index, option in
                            Button(action: {
                                selectedRelationship = option
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(selectedRelationship == option ? .white : .black)

                                    Spacer()

                                    if selectedRelationship == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(selectedRelationship == option ? Color.black : Color.white)
                                .cornerRadius(12)
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.3).delay(0.2 + Double(index) * 0.05), value: showContent)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Next button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    viewModel.userAnswers["loved_one_name"] = lovedOneName
                    viewModel.userAnswers["relationship"] = selectedRelationship ?? ""
                    viewModel.nextStep()
                }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((lovedOneName.isEmpty || selectedRelationship == nil) ? Color.gray.opacity(0.3) : Color.black)
                        .cornerRadius(25)
                }
                .disabled(lovedOneName.isEmpty || selectedRelationship == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.4), value: showContent)
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
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere on screen
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
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
                        .background(Color.black)
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

// MARK: - Step 4: Memory Vision View
struct Step4View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedMoments: Set<String> = []
    @State private var showOptions = false

    let momentOptions = [
        ("Morning coffee rituals", "☕"),
        ("Medication taken successfully", "💊"),
        ("Photos from their day", "📸"),
        ("Simple check-ins", "💬"),
        ("Meals they're proud of", "🍽️"),
        ("Walks and activities", "🚶")
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            Rectangle()
                                .fill(Color.black)
                                .frame(width: progressGeometry.size.width * (4.0 / 9.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("What kind of daily moments would you love to capture with \(viewModel.userAnswers["loved_one_name"] ?? "your loved one")?")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Select all that matter to you")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()
                    .frame(maxHeight: 40)

                // Multi-select checkboxes
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(momentOptions.enumerated()), id: \.offset) { index, moment in
                            CheckboxCard(
                                text: moment.0,
                                emoji: moment.1,
                                isSelected: selectedMoments.contains(moment.0),
                                onTap: {
                                    if selectedMoments.contains(moment.0) {
                                        selectedMoments.remove(moment.0)
                                    } else {
                                        selectedMoments.insert(moment.0)
                                    }
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            )
                            .opacity(showOptions ? 1 : 0)
                            .offset(y: showOptions ? 0 : 10)
                            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: showOptions)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Next button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    // Store selected moments
                    viewModel.selectedMoments = selectedMoments
                    viewModel.nextStep()
                }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedMoments.isEmpty ? Color.gray.opacity(0.3) : Color.black)
                        .cornerRadius(25)
                }
                .disabled(selectedMoments.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showOptions = true
                }
            }
        }
    }
}

// MARK: - Step 5: Emotional Hook View
struct Step5View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedValue: String? = nil
    @State private var showGrid = false
    @State private var showOptions = false

    let emotionalValues = [
        "A priceless family treasure",
        "Daily peace of mind",
        "Staying close despite distance",
        "Creating lasting memories"
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Progress bar at the top with back button
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            Rectangle()
                                .fill(Color.black)
                                .frame(width: progressGeometry.size.width * (5.0 / 9.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Header
                VStack(spacing: 12) {
                    Text("Imagine a year with \(viewModel.userAnswers["loved_one_name"] ?? "your loved one")...")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("What would that collection mean to you?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Memory grid mockup
                        VStack(spacing: 0) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(0..<12, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            Image(systemName: index % 3 == 0 ? "photo" : index % 3 == 1 ? "message" : "heart.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.gray.opacity(0.4))
                                        )
                                        .opacity(showGrid ? 1 : 0)
                                        .scaleEffect(showGrid ? 1 : 0.8)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05), value: showGrid)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Options
                        VStack(spacing: 12) {
                            ForEach(Array(emotionalValues.enumerated()), id: \.element) { index, value in
                                Button(action: {
                                    selectedValue = value
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedValue == value ? Color(hex: "228B22") : Color.gray.opacity(0.3))
                                                .frame(width: 20, height: 20)

                                            if selectedValue == value {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                        .padding(.leading, 16)
                                        .animation(.easeInOut(duration: 0.3), value: selectedValue == value)

                                        Text(value)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(selectedValue == value ? .white : .black)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.trailing, 16)
                                    }
                                    .padding(.vertical, 16)
                                    .background(selectedValue == value ? Color.black : Color.white)
                                    .cornerRadius(25)
                                }
                                .opacity(showOptions ? 1 : 0)
                                .offset(y: showOptions ? 0 : 10)
                                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: showOptions)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }

                Spacer()
                    .frame(height: 16)

                // Next button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    // Store emotional value
                    if let value = selectedValue {
                        viewModel.emotionalValue = value
                    }
                    viewModel.nextStep()
                }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedValue != nil ? Color.black : Color.gray.opacity(0.3))
                        .cornerRadius(25)
                }
                .disabled(selectedValue == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showGrid = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showOptions = true
                }
            }
        }
    }
}

// MARK: - Step 6: Paywall View
struct Step6View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var paywallDismissed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Progress bar overlay at the top
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.previousStep()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(Circle())
                        }

                        GeometryReader { progressGeometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: progressGeometry.size.width * (6.0 / 9.0), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)

                    Spacer()
                }
                .zIndex(1)

                // Superwall Paywall - automatically shows campaign
                PaywallView()
                    .onAppear {
                        configureSuperwallHandlers()
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "f9f9f9").ignoresSafeArea(.all))
        }
    }

    // MARK: - Superwall Integration

    /// Configure Superwall event handlers for paywall lifecycle
    private func configureSuperwallHandlers() {
        // Set user attributes for paywall personalization
        Superwall.shared.setUserAttributes([
            "loved_one_name": viewModel.userAnswers["loved_one_name"] ?? "your loved one",
            "relationship": viewModel.userAnswers["relationship"] ?? "",
            "selected_moments": Array(viewModel.selectedMoments).joined(separator: ", "),
            "emotional_value": viewModel.emotionalValue,
            "onboarding_step": "paywall"
        ])

        print("✅ Superwall user attributes configured for Step 6 paywall")
    }
}

/// Superwall Paywall View Wrapper
struct PaywallView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()

        // Trigger Superwall paywall placement when view controller is created
        DispatchQueue.main.async {
            // Register the paywall placement - Superwall will show the configured campaign
            Superwall.shared.register(placement: "onboarding_paywall")
            print("🎯 Superwall 'onboarding_paywall' placement triggered")
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Reusable Components

// Checkbox Card Component
struct CheckboxCard: View {
    let text: String
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.black : Color.white)
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.leading, 16)
                .animation(.easeInOut(duration: 0.2), value: isSelected)

                // Text and emoji
                HStack(spacing: 8) {
                    Text(text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)

                    Text(emoji)
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

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
                            .background(Color.black)
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