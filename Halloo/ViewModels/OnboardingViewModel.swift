//
//  OnboardingViewModel.swift
//  Hallo
//
//  Purpose: Guides families through first-time setup and elderly care education workflow
//  Key Features: 
//    • Multi-step account creation with elderly care context education
//    • Personalized quiz to understand family care needs and elderly preferences
//    • Onboarding completion tracking with trial subscription activation
//  Dependencies: AuthenticationService, DatabaseService, ErrorCoordinator
//  
//  Business Context: Critical first impression that shapes family understanding of elderly care coordination
//  Critical Paths: Welcome → Account creation → Care needs quiz → Setup completion → Profile creation readiness
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import SwiftUI
import Combine
import SuperwallKit


/// Guides families through comprehensive onboarding and elderly care education workflow
///
/// This ViewModel manages the critical first-time user experience that introduces families
/// to elderly care coordination concepts, collects essential user information, and prepares
/// them for successful elderly profile creation and SMS reminder management. It serves as
/// the foundation for building family confidence in digital elderly care coordination.
///
/// ## Key Responsibilities:
/// - **Educational Onboarding**: Introduce families to elderly care coordination concepts
/// - **Account Setup**: Secure authentication with email/password or social providers
/// - **Care Needs Assessment**: Personalized quiz to understand family's elderly care context
/// - **Preference Configuration**: Setup notification and communication preferences
/// - **Trial Activation**: Enable 3-day free trial for immediate elderly care access
///
/// ## Elderly Care Considerations:
/// - **Family Education**: Explains SMS confirmation process and elderly user respect
/// - **Realistic Expectations**: Sets appropriate expectations for elderly tech comfort levels
/// - **Care Priority Guidance**: Helps families identify most important reminder types
/// - **Gentle Introduction**: Avoids overwhelming families with complex care concepts
///
/// ## Usage Example:
/// ```swift
/// let onboardingViewModel = container.makeOnboardingViewModel()
/// // User progresses through: Welcome → SignUp → Quiz → Preferences → Complete
/// await onboardingViewModel.nextStep() // Advances through onboarding flow
/// ```
///
/// - Important: Onboarding completion enables elderly profile creation and SMS reminders
/// - Note: Quiz answers inform care recommendations and default reminder configurations
/// - Warning: Incomplete onboarding prevents access to elderly care coordination features
@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Onboarding Flow State Properties
    
    /// Current step in the elderly care onboarding workflow
    /// 
    /// Tracks progression through the educational and setup process:
    /// - .welcome: Introduction to elderly care coordination concepts
    /// - .signUp: Account creation with family context
    /// - .quiz: Care needs assessment and elderly preference gathering
    /// - .preferences: Notification and communication setup
    /// - .complete: Onboarding finished, ready for elderly profile creation
    @Published var currentStep: OnboardingStep = .signUp
    
    /// Family's responses to elderly care assessment questions
    /// 
    /// Stores quiz answers that inform:
    /// - Recommended reminder types (medication, exercise, social)
    /// - Communication style based on elderly tech comfort
    /// - Family relationship context for appropriate messaging
    /// - Default notification preferences for care coordination
    ///
    /// Used to personalize elderly care recommendations and SMS templates.
    @Published var userAnswers: [String: String] = [:]
    
    /// Loading state for onboarding operations (account creation, data saving)
    /// 
    /// Shows loading during:
    /// - Firebase authentication account creation
    /// - User profile database creation
    /// - Onboarding completion and preference saving
    ///
    /// Used by families to understand when onboarding steps are processing.
    @Published var isLoading = false
    
    /// User-friendly error messages for onboarding failures
    /// 
    /// Displays context-aware error messages for:
    /// - Account creation failures (email conflicts, weak passwords)
    /// - Authentication provider issues (Apple/Google sign-in)
    /// - Network connectivity problems during setup
    ///
    /// Used by families to understand and resolve onboarding obstacles.
    @Published var errorMessage: String?
    
    /// Whether onboarding workflow has been successfully completed
    /// 
    /// Determines if family can proceed to elderly profile creation.
    /// Updated when all onboarding steps are finished and user preferences saved.
    @Published var isComplete = false
    
    /// Visual progress indicator for onboarding workflow completion
    /// 
    /// Shows families how much of the setup process remains.
    /// Updates smoothly as users progress through onboarding steps.
    @Published var progress: Double = 0.0
    
    // MARK: - Family Account Creation Properties
    
    /// Email address for family member's Hallo account
    /// 
    /// Used for:
    /// - Firebase authentication and account recovery
    /// - Important notifications about elderly care adherence
    /// - Weekly care summary reports and analytics
    /// - Emergency alerts when elderly tasks are severely overdue
    @Published var email = ""
    
    /// Secure password for family member's account
    /// 
    /// Must meet security requirements for protecting elderly care data:
    /// - Minimum 8 characters with uppercase, lowercase, and numbers
    /// - Protects access to elderly profiles and SMS response history
    /// - Secures family coordination and care adherence information
    @Published var password = ""
    
    /// Password confirmation to prevent account creation errors
    @Published var confirmPassword = ""
    
    /// Full name of family member creating the account
    /// 
    /// Used for:
    /// - Personalizing family care coordination interface
    /// - SMS attribution when family members mark tasks complete
    /// - Care team identification for multi-family coordination
    @Published var fullName = ""
    
    /// Phone number for family member (optional but recommended)
    /// 
    /// Used for:
    /// - Emergency contact when elderly care issues arise
    /// - Two-factor authentication for enhanced account security
    /// - Family coordination when multiple members manage care
    @Published var phoneNumber = ""
    
    // MARK: - Elderly Care Assessment Properties
    
    /// Current position in the elderly care needs assessment quiz
    /// 
    /// Tracks progress through personalized questions about:
    /// - Family relationship to elderly members (parent, grandparent)
    /// - Elderly person's technology comfort level for SMS communication
    /// - Priority care areas (medication, exercise, social activities)
    ///
    /// Used to provide contextual help and appropriate care recommendations.
    @Published var currentQuestionIndex = 7  // TEMPORARY: Start at last question for faster paywall testing
    
    /// Array of family responses to elderly care assessment questions
    /// 
    /// Parallel array to quiz questions containing family's answers.
    /// Combined with userAnswers dictionary for flexible access patterns.
    /// Used for analytics and care pattern recommendations.
    @Published var quizAnswers: [String] = []
    
    
    
    // MARK: - Account Creation Validation Properties
    
    /// Validation error for email address field
    /// 
    /// Shows when email format is invalid or already in use.
    /// Critical for ensuring families can receive elderly care notifications
    /// and account recovery communications.
    @Published var emailError: String?
    
    /// Validation error for password security requirements
    /// 
    /// Shows when password doesn't meet security standards for protecting
    /// elderly care data and family coordination information.
    /// Ensures account security for sensitive care information.
    @Published var passwordError: String?
    
    /// Validation error for phone number format
    /// 
    /// Shows when phone number format is invalid for emergency contact
    /// and two-factor authentication purposes.
    @Published var phoneError: String?
    
    // MARK: - Service Dependencies
    
    /// Authentication service for family account creation and social sign-in
    private let authService: AuthenticationServiceProtocol
    
    /// Database service for user profile creation and onboarding data persistence
    private let databaseService: DatabaseServiceProtocol
    
    /// Coordinator for onboarding-specific error handling and family communication
    private let errorCoordinator: ErrorCoordinator
    
    // MARK: - Internal Onboarding Coordination Properties
    
    /// Combine cancellables for reactive onboarding form validation
    private var cancellables = Set<AnyCancellable>()
    
    /// Elderly care assessment questions for family personalization
    /// 
    /// Static questions designed to understand:
    /// - Family's relationship context with elderly members
    /// - Elderly person's technology comfort and SMS preferences
    /// - Priority care areas for focused reminder recommendations
    ///
    /// Used to customize onboarding experience and care suggestions.
    private let quizQuestions = OnboardingQuiz.questions
    
    /// Total number of quiz questions for progress tracking
    var totalQuestions: Int {
        return quizQuestions.count
    }
    
    // MARK: - Onboarding Flow Validation Properties
    
    /// Whether family can proceed to the next onboarding step
    /// 
    /// Validates step-specific requirements:
    /// - .welcome: Always ready to proceed (introduction step)
    /// - .signUp: Requires valid account creation form completion
    /// - .quiz: Requires completion of all elderly care assessment questions
    /// - .preferences: Always ready (optional configuration step)
    /// - .complete: Cannot proceed further (terminal step)
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .signUp:
            return isValidSignUpForm
        case .quiz:
            return currentQuestionIndex >= quizQuestions.count
        case .profileSetupConfirmation:
            return true
        case .preferences:
            return true
        case .complete:
            return false
        }
    }
    
    /// Whether family account creation form meets all requirements
    /// 
    /// Validates that:
    /// - Email is properly formatted and available
    /// - Password meets security requirements for elderly care data protection
    /// - Phone number is valid for emergency contact and 2FA
    /// - All required fields are completed without validation errors
    /// - Password confirmation matches for account security
    var isValidSignUpForm: Bool {
        return !email.isEmpty && 
               !password.isEmpty && 
               !confirmPassword.isEmpty &&
               !fullName.isEmpty &&
               !phoneNumber.isEmpty &&
               emailError == nil && 
               passwordError == nil && 
               phoneError == nil &&
               password == confirmPassword
    }
    
    /// Current elderly care assessment question for family personalization
    /// 
    /// Returns the question object for the current quiz position, or nil
    /// if all questions have been completed. Used to display appropriate
    /// elderly care context and answer options.
    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < quizQuestions.count else { return nil }
        var question = quizQuestions[currentQuestionIndex]
        
        // Generate dynamic content for age statistic break
        if question.id == "age_statistic_break" {
            question.question = generateAgeStatisticText()
        }
        return question
    }
    
    /// Whether the quiz has been completed (all questions answered)
    var isQuizComplete: Bool {
        return currentQuestionIndex >= quizQuestions.count
    }
    
    /// Generate age-specific statistic text based on previous age answer
    private func generateAgeStatisticText() -> String {
        // Find the age answer from userAnswers
        let ageAnswer = userAnswers["loved_one_age"] ?? "seniors"
        
        // Map age ranges to appropriate text
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
        
        return "\(ageGroup) who receive text-based reminders are 2x more likely to stick to healthy routines compared to app-based reminders."
    }
    
    /// Calculated progress percentage for onboarding workflow visualization
    /// 
    /// Shows families how much of the setup process remains.
    /// Excludes the complete step from calculation as it's a terminal state.
    /// Used for progress bars and completion indicators.
    var progressPercentage: Double {
        let totalSteps = Double(OnboardingStep.allCases.count - 1) // Exclude complete step
        let currentStepIndex = Double(OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0)
        return currentStepIndex / totalSteps
    }
    
    // MARK: - Family Onboarding Setup
    
    /// Initializes onboarding workflow with elderly-care-focused education and validation
    /// 
    /// Sets up the complete infrastructure for guiding families through their first
    /// experience with elderly care coordination. Configures form validation, progress
    /// tracking, and educational workflow to build family confidence in digital care.
    ///
    /// ## Setup Process:
    /// 1. **Service Integration**: Connects authentication and database services
    /// 2. **Form Validation**: Configures real-time validation for account creation
    /// 3. **Progress Tracking**: Sets up visual progress indicators for family feedback
    /// 4. **Educational Flow**: Prepares quiz and preference collection workflows
    /// 5. **Error Handling**: Establishes family-friendly error communication
    ///
    /// - Parameter authService: Handles account creation and social authentication
    /// - Parameter databaseService: Manages user profile creation and quiz data persistence
    /// - Parameter errorCoordinator: Provides onboarding-specific error handling and recovery
    init(
        authService: AuthenticationServiceProtocol,
        databaseService: DatabaseServiceProtocol,
        errorCoordinator: ErrorCoordinator
    ) {
        self.authService = authService
        self.databaseService = databaseService
        self.errorCoordinator = errorCoordinator
        
        // Configure real-time form validation for account security
        setupValidation()
        
        // Enable visual progress feedback for family confidence
        setupProgressTracking()
    }
    
    // MARK: - Setup Methods
    private func setupValidation() {
        // Email validation
        $email
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] email in
                self?.validateEmail(email)
            }
            .store(in: &cancellables)
        
        // Password validation
        $password
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] password in
                self?.validatePassword(password)
            }
            .store(in: &cancellables)
        
        // Phone validation
        $phoneNumber
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] phone in
                self?.validatePhoneNumber(phone)
            }
            .store(in: &cancellables)
    }
    
    private func setupProgressTracking() {
        $currentStep
            .sink { [weak self] step in
                self?.updateProgress()
            }
            .store(in: &cancellables)
        
        $currentQuestionIndex
            .sink { [weak self] _ in
                self?.updateProgress()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Onboarding Flow Navigation
    
    /// Advances family through the next step of elderly care onboarding workflow
    ///
    /// This method orchestrates the progression through onboarding steps, handling
    /// step-specific logic and validation requirements. Each step transition is
    /// designed to build family understanding and confidence in elderly care coordination.
    ///
    /// ## Step Progression:
    /// - **Welcome → SignUp**: Transition from introduction to account creation
    /// - **SignUp → Quiz**: Account creation triggers elderly care assessment
    /// - **Quiz → Preferences**: Completed assessment leads to preference setup
    /// - **Preferences → Complete**: Final setup completion and trial activation
    ///
    /// - Important: Validates step requirements before allowing progression
    /// - Note: Some steps trigger async operations (account creation, completion)
    /// - Warning: Incomplete steps prevent progression to maintain data integrity
    func nextStep() {
        guard canProceed else { return }
        
        switch currentStep {
        case .welcome:
            // Go to signup/login page
            currentStep = .signUp
            print("🧪 nextStep: Advanced from welcome to signup/login")
        case .signUp:
            // User should authenticate via LoginView before proceeding
            // nextStep will be called by LoginView after successful authentication
            print("🧪 nextStep: Waiting for user authentication in LoginView")
        case .quiz:
            if currentQuestionIndex >= quizQuestions.count {
                currentStep = .profileSetupConfirmation
                print("🧪 nextStep: Advanced from quiz to profile setup confirmation")
            } else {
                print("🧪 nextStep: Quiz not complete yet (index: \(currentQuestionIndex), total: \(quizQuestions.count))")
            }
        case .profileSetupConfirmation:
            currentStep = .preferences
            print("🧪 nextStep: Advanced from profile setup confirmation to preferences")
        case .preferences:
            // Show CreateProfileView - don't auto-complete
            print("🧪 nextStep: Reached preferences step - should show CreateProfileView")
            break
        case .complete:
            break
        }
    }
    
    
    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .signUp:
            currentStep = .welcome
        case .quiz:
            if currentQuestionIndex > 0 {
                currentQuestionIndex -= 1
            } else {
                currentStep = .signUp
            }
        case .profileSetupConfirmation:
            currentStep = .quiz
        case .preferences:
            currentStep = .profileSetupConfirmation
        case .complete:
            currentStep = .preferences
        }
    }
    
    func skipToEnd() {
        currentStep = .complete
        isComplete = true
    }
    
    func skipToQuiz() {
        currentStep = .quiz
        print("✅ Authentication successful - proceeding to quiz")
    }
    
    /// Handle successful authentication and navigation logic
    func handleSuccessfulAuthentication(authResult: AuthResult) async {
        do {
            // Check if user needs onboarding
            let existingUser = try await databaseService.getUser(authResult.uid)
            
            if let user = existingUser, user.isOnboardingComplete {
                // User already onboarded, skip to complete
                await MainActor.run {
                    // Disable animations during transition
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isComplete = true
                    }
                }
            } else {
                // New user or incomplete onboarding, continue with quiz
                await MainActor.run {
                    // Disable animations during transition
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        currentStep = .quiz
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                errorCoordinator.handle(error, context: "Post-authentication user check")
            }
        }
    }
    
    // MARK: - Elderly Care Assessment Actions
    
    /// Records family's response to current elderly care assessment question
    ///
    /// This method captures family input about their elderly care context, storing
    /// responses for personalized recommendations and care coordination setup.
    /// Each answer helps customize the app experience for the family's specific
    /// elderly care needs and technology comfort levels.
    ///
    /// ## Answer Processing:
    /// 1. **Answer Storage**: Store response in both array and dictionary formats
    /// 2. **Progress Tracking**: Advance to next question in assessment sequence
    /// 3. **Personalization**: Use answers to inform care recommendations
    /// 4. **Validation**: Ensure answer is recorded for current question context
    ///
    /// - Parameter answer: Family's selected response to elderly care assessment question
    /// Navigate to profile setup after quiz completion
    func proceedToProfileSetup() {
        // Move to preferences step (CreateProfileView)
        currentStep = .preferences
    }
    
    /// Skip profile setup and go to main app
    func skipProfileSetup() {
        // Mark onboarding as complete and go to main app
        currentStep = .complete
    }
    
    /// - Important: Answers inform SMS templates and care recommendation algorithms
    /// - Note: Supports both array indexing and dictionary key-based access patterns
    func answerQuestion(_ answer: String) {
        print("🧪 answerQuestion called with: \(answer)")
        guard let question = currentQuestion else { 
            print("❌ No current question available")
            return 
        }
        
        print("🧪 Current question index: \(currentQuestionIndex), Total questions: \(quizQuestions.count)")
        
        // Store answer in indexed array for sequential access
        if currentQuestionIndex < quizAnswers.count {
            quizAnswers[currentQuestionIndex] = answer
        } else {
            quizAnswers.append(answer)
        }
        
        // Store in user answers dictionary for easier thematic access
        userAnswers[question.id] = answer
        
        // Always advance question index after answering
        currentQuestionIndex += 1
        print("🧪 Advanced question index to \(currentQuestionIndex)")
        
        // Check if quiz is complete
        if currentQuestionIndex >= quizQuestions.count {
            print("🧪 Quiz complete!")
            
            // Regular quiz completion - trigger paywall
            print("🧪 Regular quiz complete! Triggering paywall...")
            
            // Trigger Superwall paywall BEFORE profile creation
            Superwall.shared.register(placement: "campaign_trigger")
            
            // DO NOT call nextStep() - wait for paywall completion
            print("🧪 Paywall triggered - waiting for completion...")
        } else {
            print("🧪 More questions remaining")
            // Force UI update for next question
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func selectQuizOption(_ option: String) {
        answerQuestion(option)
    }
    
    // MARK: - Family Account Creation & Trial Activation
    
    /*
    BUSINESS LOGIC: Family Account Creation with Elderly Care Trial Access
    
    CONTEXT: Families need immediate access to elderly care coordination features
    to evaluate the app's value. The 3-day trial provides enough time to create
    elderly profiles, send SMS confirmations, and experience care coordination.
    
    DESIGN DECISION: Automatic trial activation upon account creation
    - Alternative 1: Require payment upfront (rejected - prevents evaluation)
    - Alternative 2: Limited free tier (rejected - insufficient for proper trial)  
    - Chosen Solution: Full-featured 3-day trial for comprehensive evaluation
    
    FAMILY ONBOARDING: Account creation immediately enables elderly profile
    creation and SMS confirmation workflow, allowing families to start
    coordinating care within minutes of signing up.
    
    TRIAL STRATEGY: 3 days provides enough time for families to create profiles,
    experience SMS confirmation, set up daily reminders, and see elderly
    response patterns - sufficient for informed subscription decision.
    */
    private func createAccount() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create secure Firebase authentication account
            let authResult = try await authService.createAccount(
                email: email,
                password: password,
                fullName: fullName
            )
            
            // Create family user profile with trial access to elderly care features
            let user = User(
                id: authResult.uid,
                email: email,
                fullName: fullName,
                phoneNumber: phoneNumber,
                createdAt: Date(),
                isOnboardingComplete: false, // Requires quiz completion
                subscriptionStatus: .trial, // Full feature access for evaluation
                trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())
            )
            
            // Persist family profile for elderly care coordination
            try await databaseService.createUser(user)
            
            // Advance to elderly care needs assessment
            currentStep = .quiz
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Creating family account for elderly care coordination")
        }
        
        isLoading = false
    }
    
    // MARK: - Elderly Care Onboarding Completion
    
    /*
    BUSINESS LOGIC: Onboarding Completion with Elderly Care Personalization
    
    CONTEXT: Families have provided their care context through the assessment quiz.
    This information must be permanently stored to inform all future care
    recommendations, SMS templates, and family coordination features.
    
    DESIGN DECISION: Store quiz answers with user profile for persistent personalization
    - Alternative 1: Separate quiz results table (rejected - adds complexity)
    - Alternative 2: Recalculate preferences each time (rejected - poor performance)  
    - Chosen Solution: Embed quiz answers in user profile for fast access
    
    FAMILY READINESS: Onboarding completion unlocks elderly profile creation,
    SMS confirmation workflow, and care task scheduling. Families are now
    prepared to begin coordinating elderly care with proper context.
    
    PERSONALIZATION: Quiz answers inform default reminder types, SMS language
    style, and care priority recommendations throughout the app experience.
    */
    private func completeOnboarding() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let currentUser = authService.currentUser else {
                throw OnboardingError.userNotFound
            }
            
            // Update user profile with completed onboarding and elderly care personalization
            let updatedUser = User(
                id: currentUser.uid,
                email: email,
                fullName: fullName,
                phoneNumber: phoneNumber,
                createdAt: Date(),
                isOnboardingComplete: true, // Unlocks elderly profile creation
                subscriptionStatus: .trial, // Maintains trial access
                trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                quizAnswers: userAnswers // Permanent personalization data
            )
            
            // Persist family profile with elderly care context
            try await databaseService.updateUser(updatedUser)
            
            // Complete onboarding workflow - ready for elderly care coordination
            currentStep = .complete
            isComplete = true
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Completing elderly care onboarding setup")
        }
        
        isLoading = false
    }
    
    /// Proceed to profile creation after successful paywall interaction
    func proceedAfterPaywall() {
        print("🧪 Proceeding to profile creation after paywall")
        
        // Show the thank you message first, then proceed to profile setup
        currentStep = .profileSetupConfirmation
        print("🎉 Paywall completed successfully - showing thank you confirmation")
    }
    
    // MARK: - Validation Methods
    private func validateEmail(_ email: String) {
        if email.isEmpty {
            emailError = nil
        } else if !email.isValidEmail {
            emailError = "Please enter a valid email address"
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword(_ password: String) {
        if password.isEmpty {
            passwordError = nil
        } else if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
        } else if !password.hasUppercaseLetter || !password.hasLowercaseLetter || !password.hasNumber {
            passwordError = "Password must contain uppercase, lowercase, and number"
        } else {
            passwordError = nil
        }
    }
    
    private func validatePhoneNumber(_ phone: String) {
        if phone.isEmpty {
            phoneError = nil
        } else if !phone.isValidPhoneNumber {
            phoneError = "Please enter a valid phone number"
        } else {
            phoneError = nil
        }
    }
    
    private func updateProgress() {
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = progressPercentage
        }
    }
    
    // MARK: - Sign In Alternative
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await authService.signInWithApple()
            
            // Check if user needs onboarding
            let existingUser = try await databaseService.getUser(authResult.uid)
            
            if let user = existingUser, user.isOnboardingComplete {
                // User already onboarded, skip to complete
                isComplete = true
            } else {
                // New user or incomplete onboarding, continue with quiz
                currentStep = .quiz
            }
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Apple Sign In")
        }
        
        isLoading = false
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await authService.signInWithGoogle()
            
            // Check if user needs onboarding
            let existingUser = try await databaseService.getUser(authResult.uid)
            
            if let user = existingUser, user.isOnboardingComplete {
                // User already onboarded, skip to complete
                isComplete = true
            } else {
                // New user or incomplete onboarding, continue with quiz
                currentStep = .quiz
            }
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Google Sign In")
        }
        
        isLoading = false
    }
}

// MARK: - Onboarding Models
enum OnboardingStep: String, CaseIterable {
    case welcome = "welcome"
    case signUp = "signUp"
    case quiz = "quiz"
    case profileSetupConfirmation = "profileSetupConfirmation"
    case preferences = "preferences"
    case complete = "complete"
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Hallo"
        case .signUp:
            return "Create Account"
        case .quiz:
            return "Quick Setup"
        case .profileSetupConfirmation:
            return "Profile Setup"
        case .preferences:
            return "Preferences"
        case .complete:
            return "You're all set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "Help your elderly loved ones stay on track with their daily habits"
        case .signUp:
            return "Create your account to get started"
        case .quiz:
            return "Help us personalize your experience"
        case .profileSetupConfirmation:
            return "Ready to create your first profile?"
        case .preferences:
            return "Customize your notification settings"
        case .complete:
            return "Start creating profiles for your elderly family members"
        }
    }
}

struct QuizQuestion {
    let id: String
    var question: String
    let options: [String]
    let helpText: String?
    
    init(id: String, question: String, options: [String], helpText: String? = nil) {
        self.id = id
        self.question = question
        self.options = options
        self.helpText = helpText
    }
}

struct OnboardingQuiz {
    static let questions = [
        QuizQuestion(
            id: "care_recipient",
            question: "Who are you setting reminders for?",
            options: [
                "My parent(s)",
                "My grandparent(s)",
                "Both",
                "Other"
            ],
            helpText: nil
        ),
        QuizQuestion(
            id: "loved_one_age",
            question: "How old is your loved one?",
            options: [
                "Under 65",
                "65-74",
                "75-84",
                "85+"
            ],
            helpText: nil
        ),
        QuizQuestion(
            id: "age_statistic_break",
            question: "", // Will be dynamically generated
            options: [], // No options - this is a break screen
            helpText: nil
        ),
        QuizQuestion(
            id: "reminder_motivation",
            question: "Why do you want to set reminders for them?",
            options: [
                "For their health",
                "For their independence",
                "To stay connected",
                "To reduce stress for myself"
            ],
            helpText: nil
        ),
        QuizQuestion(
            id: "primary_habit",
            question: "What's the #1 habit you'd love them to build right now?",
            options: [
                "Taking medications on time",
                "Drinking enough water",
                "Staying active",
                "Daily check-ins / routines",
                "Other"
            ],
            helpText: nil
        ),
        QuizQuestion(
            id: "personality_type",
            question: "What's their personality type when it comes to reminders?",
            options: [
                "Gentle encouragement works best",
                "Straightforward and to the point",
                "Funny and lighthearted",
                "Haven't figured that out yet"
            ],
            helpText: nil
        ),
        QuizQuestion(
            id: "reminder_frequency",
            question: "How often should we send reminders?",
            options: [
                "Daily",
                "A few times a week",
                "Weekly"
            ],
            helpText: nil
        ),
        QuizQuestion(
            id: "primary_motivation",
            question: "What matters most to you in helping them?",
            options: [
                "Their health",
                "Their happiness",
                "Their independence",
                "Staying connected with them"
            ],
            helpText: nil
        )
    ]
}

// MARK: - Onboarding Errors
enum OnboardingError: LocalizedError {
    case userNotFound
    case incompleteData
    case quizNotCompleted
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User session not found. Please try signing in again."
        case .incompleteData:
            return "Please complete all required fields."
        case .quizNotCompleted:
            return "Please complete the setup quiz before proceeding."
        }
    }
}
