import SwiftUI
import Combine
import SuperwallKit
import Firebase

struct ContentView: View {
    // MARK: - Environment
    @Environment(\.container) private var container

    // MARK: - State Management
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var profileViewModel: ProfileViewModel?
    @State private var dashboardViewModel: DashboardViewModel?
    @State private var galleryViewModel: GalleryViewModel?
    @State private var authService: FirebaseAuthenticationService?
    @State private var isAuthenticated = false
    @State private var selectedTab = 0
    @State private var authCancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        // ViewModels will be created in initializeViewModels to avoid crashes during init
    }

    var body: some View {
        navigationContent
            .onAppear {
                initializeViewModels()
            }
            .onChange(of: onboardingViewModel?.isComplete) { oldValue, newValue in
                if let newValue = newValue {
                    handleOnboardingCompletion(newValue)
                }
            }
    }
    
    // MARK: - Navigation Content
    @ViewBuilder
    private var navigationContent: some View {
        if onboardingViewModel != nil {
            if isAuthenticated {
                authenticatedContent
                    .onAppear {
                        print("✅ Showing authenticated content (dashboard)")
                    }
            } else {
                LoginView(onAuthenticationSuccess: {
                    // Auth state will be updated by the listener automatically
                    // Just reload profiles when ready
                    profileViewModel?.loadProfiles()
                })
                .environmentObject(onboardingViewModel!)
                .onAppear {
                    print("📱 Showing login screen")
                }
            }
        } else {
            LoadingView()
        }
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        mainAppFlow
    }
    
    
    // MARK: - Main App Flow
    private var mainAppFlow: some View {
        // Custom navigation without TabView to eliminate black box completely
        ZStack {
            Color(hex: "f9f9f9") // Consistent app background

            // Conditional view switching based on selectedTab
            if let dashboardVM = dashboardViewModel,
               let profileVM = profileViewModel,
               let galleryVM = galleryViewModel {
                if selectedTab == 0 {
                    // Dashboard Tab - Home screen
                    DashboardView(selectedTab: $selectedTab)
                        .environmentObject(dashboardVM)
                        .environmentObject(profileVM)
                } else if selectedTab == 1 {
                    // Habits Tab - Habit management screen
                    HabitsView(selectedTab: $selectedTab)
                        .environmentObject(dashboardVM) // Share same instance for real-time data sync
                        .environmentObject(profileVM)
                } else {
                    // Gallery Tab - Archive of completed habits with photos
                    GalleryView(selectedTab: $selectedTab)
                        .environmentObject(galleryVM) // Use real Firebase services!
                        .environmentObject(profileVM)
                }
            } else {
                // Loading state while ViewModel is being created
                LoadingView()
            }
        }
        // No longer need onAppear since we're not using TabView
    }
    
    // MARK: - Initialization Methods
    @MainActor
    private func initializeViewModels() {
        print("🔥 initializeViewModels called - creating ViewModels")

        // Create ViewModels using Container (all factory methods are @MainActor)
        print("📝 Creating OnboardingViewModel...")
        onboardingViewModel = container.makeOnboardingViewModel()
        print("✅ OnboardingViewModel created")

        print("📝 Creating ProfileViewModel...")
        profileViewModel = container.makeProfileViewModel()
        print("✅ ProfileViewModel created")

        // Load profiles after ViewModel is fully initialized
        profileViewModel?.loadProfiles()
        print("✅ ProfileViewModel.loadProfiles() called")

        print("📝 Creating DashboardViewModel...")
        dashboardViewModel = container.makeDashboardViewModel()
        print("✅ DashboardViewModel created")

        print("📝 Creating GalleryViewModel...")
        galleryViewModel = container.makeGalleryViewModel()
        print("✅ GalleryViewModel created")

        // Store auth service reference (singleton)
        print("📝 Resolving AuthService...")
        authService = container.resolve(AuthenticationServiceProtocol.self) as? FirebaseAuthenticationService
        print("✅ AuthService resolved")

        print("✅ All ViewModels created successfully (including GalleryViewModel)")

        // Subscribe to auth state changes
        setupAuthStateObserver()

        // Check if user is already authenticated on app launch
        _Concurrency.Task {
            // Small delay to ensure Firebase Auth is ready
            try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            await MainActor.run {
                if authService?.isAuthenticated == true {
                    print("✅ User already authenticated on app launch, going to dashboard")
                    isAuthenticated = true
                    // Reload profiles now that user is authenticated
                    profileViewModel?.loadProfiles()
                } else {
                    print("ℹ️ User not authenticated, showing login")
                    isAuthenticated = false
                }
            }
        }
    }

    private func setupAuthStateObserver() {
        guard let authService = authService else { return }

        // Subscribe to auth state publisher
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak authService] newAuthState in
                print("🔐 Auth state changed: \(newAuthState)")
                self.isAuthenticated = newAuthState

                if newAuthState {
                    print("✅ User authenticated, navigating to dashboard")
                    self.profileViewModel?.loadProfiles()
                } else {
                    print("🔓 User logged out, showing login screen")
                }
            }
            .store(in: &authCancellables)
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
            // Remi logo with animation
            Text("Remi")
                .font(.system(size: 60, weight: .medium))
                .tracking(-3.0)
                .foregroundColor(.black)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("Make sure your loved one never misses another reminder")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "7A7A7A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .tracking(-0.3)

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "f9f9f9")) // Same background as app to prevent black flash
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

