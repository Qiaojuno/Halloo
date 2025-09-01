import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container
final class Container: ObservableObject {
    static let shared = Container()
    
    private var services: [String: Any] = [:]
    private let lock = NSLock()
    
    private init() {
        setupServices()
    }
    
    // MARK: - Service Registration
    private func setupServices() {
        // Core Services - Mock Implementation for UI Development
        register(AuthenticationServiceProtocol.self) { 
            MockAuthenticationService() 
        }
        
        register(DatabaseServiceProtocol.self) {
            MockDatabaseService()
        }
        
        register(SMSServiceProtocol.self) {
            MockSMSService() // Keep mock for now, implement Twilio later
        }
        
        register(NotificationServiceProtocol.self) {
            MockNotificationService() // Keep mock for now, implement later
        }
        
        register(AnalyticsServiceProtocol.self) {
            MockAnalyticsService()
        }
        
        register(SubscriptionServiceProtocol.self) {
            MockSubscriptionService() // Keep mock for now, implement StoreKit later
        }
        
        // Coordination Services
        register(NotificationCoordinator.self) {
            NotificationCoordinator()
        }
        
        register(DataSyncCoordinator.self) { [weak self] in
            DataSyncCoordinator(
                databaseService: self?.resolve(DatabaseServiceProtocol.self) ?? MockDatabaseService(),
                notificationCoordinator: self?.resolve(NotificationCoordinator.self) ?? NotificationCoordinator()
            )
        }
        
        register(ErrorCoordinator.self) {
            ErrorCoordinator()
        }
    }
    
    // MARK: - Generic Registration
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        services[key] = factory
    }
    
    func register<T>(_ type: T.Type, factory: @escaping (Container) -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        services[key] = { [weak self] in
            guard let self = self else { 
                fatalError("Container deallocated during service resolution") 
            }
            return factory(self)
        }
    }
    
    // MARK: - Service Resolution
    func resolve<T>(_ type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        
        guard let factory = services[key] else {
            fatalError("Service \(key) not registered")
        }
        
        if let directFactory = factory as? () -> T {
            return directFactory()
        } else if let containerFactory = factory as? (Container) -> T {
            return containerFactory(self)
        } else {
            fatalError("Invalid factory type for service \(key)")
        }
    }
    
    // MARK: - ViewModel Factories
    @MainActor
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            authService: resolve(AuthenticationServiceProtocol.self),
            databaseService: resolve(DatabaseServiceProtocol.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
    
    @MainActor
    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            smsService: resolve(SMSServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
    
    @MainActor
    func makeTaskViewModel() -> TaskViewModel {
        TaskViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            smsService: resolve(SMSServiceProtocol.self),
            notificationService: resolve(NotificationServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
    
    @MainActor
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            analyticsService: resolve(AnalyticsServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
    
    @MainActor
    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(
            analyticsService: resolve(AnalyticsServiceProtocol.self),
            databaseService: resolve(DatabaseServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
    
    @MainActor
    func makeSubscriptionViewModel() -> SubscriptionViewModel {
        SubscriptionViewModel(
            subscriptionService: resolve(SubscriptionServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
}

// MARK: - SwiftUI Environment Integration
struct ContainerKey: EnvironmentKey {
    static let defaultValue: Container = Container.shared
}

extension EnvironmentValues {
    var container: Container {
        get { self[ContainerKey.self] }
        set { self[ContainerKey.self] = newValue }
    }
}

// MARK: - SwiftUI ViewModifier for Dependency Injection
struct DependencyInjection: ViewModifier {
    let container: Container
    
    func body(content: Content) -> some View {
        content
            .environmentObject(container)
            .environment(\.container, container)
    }
}

extension View {
    func inject(container: Container = Container.shared) -> some View {
        modifier(DependencyInjection(container: container))
    }
}

// MARK: - Service Factory (Alternative Pattern)
class ServiceFactory {
    private let container: Container
    
    init(container: Container = Container.shared) {
        self.container = container
    }
    
    // Factory methods for services that need special configuration
    func makeAuthenticatedDatabaseService() async throws -> DatabaseServiceProtocol {
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        
        // Ensure user is authenticated before creating database service
        guard authService.isAuthenticated else {
            throw ServiceError.userNotAuthenticated
        }
        
        return container.resolve(DatabaseServiceProtocol.self)
    }
    
    func makeConfiguredSMSService() -> SMSServiceProtocol {
        let smsService = container.resolve(SMSServiceProtocol.self)
        
        // Configure SMS service with app-specific settings
        // This would be where we set Twilio credentials, templates, etc.
        
        return smsService
    }
}

// MARK: - Service Errors
enum ServiceError: LocalizedError {
    case userNotAuthenticated
    case serviceNotAvailable
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to access this service"
        case .serviceNotAvailable:
            return "Required service is not available"
        case .configurationError:
            return "Service configuration error"
        }
    }
}

// MARK: - Testing Support
#if DEBUG
extension Container {
    static func makeForTesting() -> Container {
        let container = Container()
        
        // Register mock services for testing
        container.register(AuthenticationServiceProtocol.self) {
            MockAuthenticationService()
        }
        
        container.register(DatabaseServiceProtocol.self) {
            MockDatabaseService()
        }
        
        container.register(SMSServiceProtocol.self) {
            MockSMSService()
        }
        
        return container
    }
    
    func registerMock<T>(_ type: T.Type, mock: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        services[key] = { mock }
    }
}
#endif