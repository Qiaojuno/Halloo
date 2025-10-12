import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SuperwallKit
import GoogleSignIn

// MARK: - App Delegate for Orientation Control
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

@main
struct HalloApp: App {
    // MARK: - App Delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - Dependencies
    private let container: Container
    
    // MARK: - App Lifecycle
    init() {
        // Skip heavy initialization during Canvas/Preview execution
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            // Configure Firebase FIRST, before Container initialization
            do {
                HalloApp.configureFirebase()
                print("✅ Firebase configuration completed successfully")
            } catch {
                print("❌ Firebase configuration failed: \(error)")
            }
        }

        // Initialize Container AFTER Firebase is configured
        container = Container.shared
        print("✅ Container initialized successfully")

        // Configure other services after container is initialized
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            configureNotifications()
            configureSuperwall()
            configureGoogleSignIn()
        }

        configureAppearance()
        print("✅ App initialization completed")
    }
    
    private static func configureFirebase() {
        print("🔥 Starting Firebase configuration...")

        // Simple Firebase configuration
        FirebaseApp.configure()
        print("✅ Firebase configured")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .inject(container: container)
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    // Skip app launch handling during Canvas/Preview execution
                    if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
                        handleAppLaunch()
                    }

                    // Force portrait orientation and lock it
                    AppDelegate.orientationLock = .portrait
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleAppDidEnterBackground()
                }
        }
    }
    
    // MARK: - Configuration
    
    private func configureNotifications() {
        _Concurrency.Task {
            await requestNotificationPermissions()
        }
    }
    
    private func configureSuperwall() {
        // Superwall API key from dashboard
        let SUPERWALL_API_KEY = "pk_1FZVcGgpr1JMD5XJ4d0Cb"
        
        Superwall.configure(apiKey: SUPERWALL_API_KEY)
        print("✅ Superwall configuration initiated")
        
        // Optional: Set user attributes for targeting
        // Superwall.shared.setUserAttributes([
        //     "plan": "free",
        //     "profiles_created": 0
        // ])
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ Failed to configure Google Sign-In: Missing CLIENT_ID")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign-In configured successfully")
    }
    
    private func configureAppearance() {
        // Register custom fonts (Poppins & Inter available when needed)
        AppFonts.registerFonts()

        #if DEBUG
        AppFonts.printAvailableFonts()
        #endif

        // Configure global app appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        // Configure tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray

        // Senior-friendly settings
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()
        }
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppLaunch() {
        print("📱 Hallo app launched")
        
        // Initialize critical services
        _Concurrency.Task {
            await initializeCriticalServices()
        }
        
        // Analytics removed - no longer tracking app launch
    }
    
    private func handleAppWillEnterForeground() {
        print("🔄 App entering foreground")
        
        // Refresh data when app comes to foreground
        _Concurrency.Task {
            await refreshAppData()
        }
        
        // Check for pending notifications
        checkPendingNotifications()
    }
    
    private func handleAppDidEnterBackground() {
        print("⏸️ App entering background")
        
        // Save any pending changes
        savePendingChanges()
        
        // Schedule background notifications if needed
        scheduleBackgroundNotifications()
    }
    
    // MARK: - Service Initialization
    private func initializeCriticalServices() async {
        // Initialize authentication state
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        print("🔍 [App] BEFORE initializeAuthState - currentUser: \(authService.currentUser?.uid ?? "nil")")
        await authService.initializeAuthState()
        print("🔍 [App] AFTER initializeAuthState - currentUser: \(authService.currentUser?.uid ?? "nil")")

        // Initialize notification service
        let notificationService = container.resolve(NotificationServiceProtocol.self)
        await notificationService.initialize()

        // Initialize data sync coordinator
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        await dataSyncCoordinator.initialize()

        // Setup incoming SMS listener if user is authenticated
        if let userId = authService.currentUser?.uid {
            print("✅ [App] User authenticated - setting up SMS listener for: \(userId)")
            setupSMSListener(userId: userId, dataSyncCoordinator: dataSyncCoordinator)
        } else {
            print("⚠️ [App] User NOT authenticated - skipping SMS listener setup")
        }

        print("✅ Critical services initialized successfully")
    }
    
    private func requestNotificationPermissions() async {
        let notificationService = container.resolve(NotificationServiceProtocol.self)
        
        do {
            let granted = try await notificationService.requestPermission()
            print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }
    
    // MARK: - Data Management
    private func refreshAppData() async {
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        
        await dataSyncCoordinator.syncAllData()
        print("✅ App data refreshed")
    }
    
    private func savePendingChanges() {
        // Save any unsaved changes before app goes to background
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        
        _Concurrency.Task {
            await dataSyncCoordinator.saveUnsavedChanges()
        }
    }
    
    /// Sets up Firestore listener for incoming SMS messages
    private func setupSMSListener(userId: String, dataSyncCoordinator: DataSyncCoordinator) {
        print("📱 [App] Setting up SMS listener for user: \(userId)")

        guard let databaseService = container.resolve(DatabaseServiceProtocol.self) as? FirebaseDatabaseService else {
            print("❌ [App] Failed to cast DatabaseService to FirebaseDatabaseService")
            return
        }

        // Subscribe to incoming SMS messages
        databaseService.observeIncomingSMSMessages(userId)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ [App] SMS listener completed")
                    case .failure(let error):
                        print("❌ [App] SMS listener error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { smsResponse in
                    print("📩 [App] Received SMS response - broadcasting to DataSyncCoordinator")
                    print("   - Profile ID: \(smsResponse.profileId ?? "unknown")")
                    print("   - Message: \(smsResponse.textResponse ?? "no text")")
                    print("   - Is Confirmation: \(smsResponse.isConfirmationResponse)")

                    // Broadcast to all ViewModels via DataSyncCoordinator
                    dataSyncCoordinator.broadcastSMSResponse(smsResponse)
                }
            )
            .store(in: &container.cancellables) // Store in Container's cancellables

        print("✅ [App] SMS listener registered successfully")
    }

    private func checkPendingNotifications() {
        let notificationService = container.resolve(NotificationServiceProtocol.self)

        _Concurrency.Task {
            await notificationService.checkPendingNotifications()
        }
    }
    
    private func scheduleBackgroundNotifications() {
        let notificationCoordinator = container.resolve(NotificationCoordinator.self)
        
        _Concurrency.Task {
            await notificationCoordinator.scheduleBackgroundReminders()
        }
    }
    
    // Analytics removed - no longer tracking app events
}

// MARK: - App Configuration Extensions
extension HalloApp {
    // MARK: - Environment Setup
    private var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - Error Handling
extension HalloApp {
    private func handleCriticalError(_ error: Error) {
        print("🚨 Critical app error: \(error)")
        
        // Log to crash reporting service
        // CrashlyticsService.shared.recordError(error)
        
        // Show user-friendly error if needed
        _Concurrency.Task { @MainActor in
            let errorCoordinator = container.resolve(ErrorCoordinator.self)
            errorCoordinator.handleCriticalError(error, context: "Critical app error")
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct HalloApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .inject(container: Container.makeForTesting())
    }
}
#endif

