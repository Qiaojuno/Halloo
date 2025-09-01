import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - Environment
    @Environment(\.container) private var container
    
    // MARK: - State Management
    @StateObject private var onboardingViewModel: OnboardingViewModel
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
    }
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else {
                navigationContent
            }
        }
        .onAppear {
            initializeViewModels()
        }
        .onChange(of: onboardingViewModel.isComplete) { oldValue, newValue in
            handleOnboardingCompletion(newValue)
        }
    }
    
    // MARK: - Navigation Content
    @ViewBuilder
    private var navigationContent: some View {
        if !onboardingViewModel.isComplete {
            onboardingFlow
        } else {
            authenticatedContent
        }
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .environmentObject(container.makeDashboardViewModel())
                .environmentObject(container.makeProfileViewModel())
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            Text("Tasks View") // Placeholder
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tasks")  
                }
                .tag(1)
                
            Text("Profiles View") // Placeholder
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Profiles")
                }
                .tag(2)
        }
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
                .environmentObject(container.makeProfileViewModel())
            
        case .complete:
            OnboardingCompleteView()
                .environmentObject(onboardingViewModel)
        }
    }
    
    // MARK: - Main App Flow
    private var mainAppFlow: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab - Home screen
            NavigationView {
                DashboardView()
                    .environmentObject(container.makeDashboardViewModel())
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                Text("Home")
            }
            .tag(0)
            
            // Gallery Tab - MVP: Archive of completed habits with photos
            NavigationView {
                GalleryView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: selectedTab == 1 ? "photo.on.rectangle" : "photo")
                Text("Gallery")
            }
            .tag(1)
        }
        .accentColor(.blue)
        .onAppear {
            configureTabBarAppearance()
        }
    }
    
    // MARK: - Initialization Methods
    private func initializeViewModels() {
        // ViewModels are initialized through Container dependency injection
        isLoading = false
    }
    
    // MARK: - Event Handlers
    private func handleOnboardingCompletion(_ isComplete: Bool) {
        print("🔐 Onboarding completion changed to: \(isComplete)")
        
        if isComplete {
            // User completed onboarding, reset tab selection
            selectedTab = 0
        }
    }
    
    // MARK: - UI Configuration
    private func configureTabBarAppearance() {
        // Senior-friendly tab bar configuration
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Larger icons and text for seniors
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Increase tab bar item font size
        UITabBarItem.appearance().setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ], for: .normal)
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

