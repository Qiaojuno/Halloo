import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - Environment
    @Environment(\.container) private var container
    
    // MARK: - State Management
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var isLoading = true
    @State private var selectedTab = 0
    
    // MARK: - Initialization
    init() {
        // Initialize with placeholder - will be properly set in onAppear
        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(
            authService: MockAuthenticationService(),
            databaseService: MockDatabaseService(),
            errorCoordinator: ErrorCoordinator()
        ))
        
        // Initialize ProfileViewModel with mock services for consistency
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(
            databaseService: MockDatabaseService(),
            smsService: MockSMSService(),
            authService: MockAuthenticationService(),
            dataSyncCoordinator: DataSyncCoordinator(
                databaseService: MockDatabaseService(),
                notificationCoordinator: NotificationCoordinator(),
                errorCoordinator: ErrorCoordinator()
            ),
            errorCoordinator: ErrorCoordinator()
        ))
    }
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
                    .onAppear {
                        print("🔥 LoadingView appeared - isLoading = true")
                        // Failsafe: If still loading after 2 seconds, force continue
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if isLoading {
                                print("⚠️ Loading timeout - forcing app start")
                                isLoading = false
                            }
                        }
                    }
            } else {
                navigationContent
                    .onAppear {
                        print("🔥 navigationContent appeared - isLoading = false")
                    }
            }
        }
        .onAppear {
            initializeViewModels()
            // DEVELOPMENT: Skip onboarding for faster testing
            #if DEBUG
            if !onboardingViewModel.isComplete {
                print("🚀 DEVELOPMENT MODE: Skipping onboarding flow")
                onboardingViewModel.skipToEnd()
            }
            #endif
        }
        .onChange(of: onboardingViewModel.isComplete) { oldValue, newValue in
            handleOnboardingCompletion(newValue)
        }
    }
    
    // MARK: - Navigation Content
    @ViewBuilder
    private var navigationContent: some View {
        // RESTORED: Proper app flow with onboarding check
        if !onboardingViewModel.isComplete {
            onboardingFlow
        } else {
            authenticatedContent
        }
        
        // DEBUG: Firebase Test Button temporarily removed
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        mainAppFlow
    }
    
    @ViewBuilder
    private var onboardingFlow: some View {
        switch onboardingViewModel.currentStep {
        case .welcome:
            WelcomeView()
                .environmentObject(onboardingViewModel)
            
        case .signUp:
            AccountSetupView()
                .environmentObject(onboardingViewModel)
            
        case .quiz:
            QuizView()
                .environmentObject(onboardingViewModel)
            
        case .preferences:
            CreateProfileView()
                .environmentObject(profileViewModel)
            
        case .complete:
            OnboardingCompleteView()
                .environmentObject(onboardingViewModel)
        }
    }
    
    // MARK: - Main App Flow
    private var mainAppFlow: some View {
        // Custom navigation without TabView to eliminate black box completely
        ZStack {
            Color(hex: "f9f9f9") // Consistent app background
            
            // Conditional view switching based on selectedTab
            if selectedTab == 0 {
                // Dashboard Tab - Home screen
                DashboardView(selectedTab: $selectedTab)
                    .environmentObject(container.makeDashboardViewModel())
                    .environmentObject(profileViewModel)
            } else {
                // Gallery Tab - Archive of completed habits with photos
                GalleryView(selectedTab: $selectedTab)
            }
        }
        // No longer need onAppear since we're not using TabView
    }
    
    // MARK: - Initialization Methods
    private func initializeViewModels() {
        // ViewModels are initialized through Container dependency injection
        print("🔥 initializeViewModels called - setting isLoading = false")
        
        // Debug: Check which services are being used
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let dbService = container.resolve(DatabaseServiceProtocol.self)
        
        print("🔥 Auth Service: \(type(of: authService))")
        print("🔥 Database Service: \(type(of: dbService))")
        
        isLoading = false
        print("🔥 isLoading is now: \(isLoading)")
    }
    
    // TEMPORARY: Safe TaskViewModel creation with detailed debugging
    private func safeTaskViewModel() -> TaskViewModel? {
        print("🔥 Attempting to create TaskViewModel...")
        
        print("🔥 Step 1: Resolving DatabaseService...")
        let dbService = container.resolve(DatabaseServiceProtocol.self)
        print("🔥 Step 1: DatabaseService resolved = \(type(of: dbService))")
        
        print("🔥 Step 2: Resolving SMSService...")
        let smsService = container.resolve(SMSServiceProtocol.self)
        print("🔥 Step 2: SMSService resolved = \(type(of: smsService))")
        
        print("🔥 Step 3: Resolving NotificationService...")
        let notificationService = container.resolve(NotificationServiceProtocol.self)
        print("🔥 Step 3: NotificationService resolved = \(type(of: notificationService))")
        
        print("🔥 Step 4: Resolving AuthService...")
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        print("🔥 Step 4: AuthService resolved = \(type(of: authService))")
        
        print("🔥 Step 5: Resolving DataSyncCoordinator...")
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        print("🔥 Step 5: DataSyncCoordinator resolved = \(type(of: dataSyncCoordinator))")
        
        print("🔥 Step 6: Resolving ErrorCoordinator...")
        let errorCoordinator = container.resolve(ErrorCoordinator.self)
        print("🔥 Step 6: ErrorCoordinator resolved = \(type(of: errorCoordinator))")
        
        print("🔥 Step 7: Creating TaskViewModel with all dependencies...")
        let viewModel = TaskViewModel(
            databaseService: dbService,
            smsService: smsService,
            notificationService: notificationService,
            authService: authService,
            dataSyncCoordinator: dataSyncCoordinator,
            errorCoordinator: errorCoordinator
        )
        print("🔥 Step 7: TaskViewModel created successfully!")
        
        return viewModel
    }
    
    // MARK: - Event Handlers
    private func handleOnboardingCompletion(_ isComplete: Bool) {
        print("🔐 Onboarding completion changed to: \(isComplete)")
        
        if isComplete {
            // User completed onboarding, reset tab selection
            selectedTab = 0
        }
    }
    
    // MARK: - Firebase Testing (DEBUG ONLY)
    #if DEBUG
    private func testFirebaseIntegration() {
        print("🧪 FIREBASE INTEGRATION TEST STARTING...")
        
        // Test 1: Check which services are loaded
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let dbService = container.resolve(DatabaseServiceProtocol.self)
        
        print("🔥 Auth Service: \(type(of: authService))")
        print("🔥 Database Service: \(type(of: dbService))")
        
        // Test 2: Try creating a test account
        DispatchQueue.main.async {
            _Concurrency.Task {
                do {
                    print("🧪 Attempting to create test Firebase account...")
                    let result = try await authService.createAccount(
                        email: "test@firebase.remi.com", 
                        password: "TestPassword123",
                        fullName: "Firebase Test User"
                    )
                    print("✅ Firebase account created! UID: \(result.uid)")
                    
                    // Test 3: Try signing out
                    try await authService.signOut()
                    print("✅ Firebase sign out successful!")
                    
                } catch {
                    print("❌ Firebase test failed: \(error)")
                }
            }
        }
    }
    #endif
    
    // MARK: - UI Configuration
    // TabBar hiding functions no longer needed since we removed TabView completely
    // Keeping empty functions to avoid breaking any remaining references
    private func hideTabBarCompletely() {
        // No longer needed - TabView removed
    }
    
    private func configureTabBarAppearance() {
        // No longer needed - TabView removed
    }
}

// MARK: - Authentication States
enum AuthenticationState {
    case loading
    case authenticated
    case unauthenticated
}

// MARK: - Authentication ViewModel
class AuthenticationViewModel: ObservableObject {
    @Published var authenticationState: AuthenticationState = .loading
    @Published var currentUser: User?
    
    private var authService: AuthenticationServiceProtocol
    private var errorCoordinator: ErrorCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthenticationServiceProtocol, errorCoordinator: ErrorCoordinator) {
        self.authService = authService
        self.errorCoordinator = errorCoordinator
        observeAuthenticationChanges()
    }
    
    func updateServices(authService: AuthenticationServiceProtocol, errorCoordinator: ErrorCoordinator) {
        self.authService = authService
        self.errorCoordinator = errorCoordinator
        observeAuthenticationChanges()
    }
    
    private func observeAuthenticationChanges() {
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.authenticationState = isAuthenticated ? .authenticated : .unauthenticated
                if isAuthenticated {
                    _Concurrency.Task { [weak self] in
                        if self?.authService.currentUser != nil {
                            await MainActor.run { [weak self] in
                                // Convert AuthUser to User if needed, or use authUser directly
                                self?.currentUser = nil // For now, since we don't have a direct conversion
                            }
                        }
                    }
                } else {
                    self?.currentUser = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func checkAuthenticationState() async {
        await MainActor.run {
            let isAuthenticated = authService.isAuthenticated
            self.authenticationState = isAuthenticated ? .authenticated : .unauthenticated
            if isAuthenticated {
                // For now, we'll use the currentUser property directly
                // since getCurrentUser() isn't in the protocol
                self.currentUser = nil // Placeholder - would need proper User conversion
            } else {
                self.currentUser = nil
            }
        }
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            await MainActor.run {
                self.authenticationState = .unauthenticated
                self.currentUser = nil
            }
        } catch {
            errorCoordinator.handle(error, context: "User sign out")
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // App logo or icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("Hallo")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Caring for your loved ones")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // ISOLATED CANVAS TESTS - NO SERVICES OR DEPENDENCIES
            
            // Test LoadingView independently
            LoadingView()
                .previewDisplayName("Loading View")
            
            // Test simple tab structure without ViewModels
            TabView {
                Text("Home Tab - Canvas Test")
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                Text("Gallery Tab - Canvas Test") 
                    .tabItem {
                        Image(systemName: "photo.on.rectangle")
                        Text("Gallery")
                    }
                    .tag(1)
            }
            .previewDisplayName("Tab Structure Test")
            
            // Test basic UI elements
            VStack(spacing: 20) {
                Text("Hallo")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Text("Canvas UI Test")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Test Button") {
                    // No action needed for Canvas
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .previewDisplayName("Basic UI Elements")
        }
    }
}
#endif

