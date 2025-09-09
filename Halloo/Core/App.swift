import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@main
struct HalloApp: App {
    // MARK: - Dependencies
    private let container: Container
    
    // MARK: - App Lifecycle
    init() {
        // Skip heavy initialization during Canvas/Preview execution
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            // Configure Firebase FIRST, before Container initialization
            HalloApp.configureFirebase()
        }
        
        // Initialize Container AFTER Firebase is configured
        container = Container.shared
        
        // Configure other services after container is initialized
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            configureNotifications()
        }
        
        configureAppearance()
    }
    
    private static func configureFirebase() {
        var firebaseConfigured = false
        
        #if DEBUG
        // Development configuration - Skip if file missing
        if let path = Bundle.main.path(forResource: "GoogleService-Info-Dev", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
            firebaseConfigured = true
        } else if let _ = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            // Fall back to regular config file if dev version missing
            FirebaseApp.configure()
            firebaseConfigured = true
        } else {
            print("⚠️ Firebase config file missing - running with mock services")
            firebaseConfigured = false
        }
        #else
        // Production configuration
        FirebaseApp.configure()
        firebaseConfigured = true
        #endif
        
        // Only configure Firestore/Auth if Firebase was successfully configured
        if firebaseConfigured {
            let db = Firestore.firestore()
            let settings = FirestoreSettings()
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            db.settings = settings
            
            let auth = Auth.auth()
            auth.languageCode = "en"
        }
        
        print("🔥 Firebase configured: \(firebaseConfigured)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .inject(container: container)
                .onAppear {
                    // Skip app launch handling during Canvas/Preview execution
                    if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
                        handleAppLaunch()
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
        
        // Track app launch analytics
        trackAppLaunch()
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
        await authService.initializeAuthState()
        
        // Initialize notification service
        let notificationService = container.resolve(NotificationServiceProtocol.self)
        await notificationService.initialize()
        
        // Initialize data sync coordinator
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        await dataSyncCoordinator.initialize()
        
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
    
    // MARK: - Analytics
    private func trackAppLaunch() {
        let analyticsService = container.resolve(AnalyticsServiceProtocol.self)
        
        _Concurrency.Task {
            await analyticsService.trackEvent("app_launched", parameters: [
                "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                "ios_version": UIDevice.current.systemVersion,
                "device_model": UIDevice.current.model
            ])
        }
    }
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

