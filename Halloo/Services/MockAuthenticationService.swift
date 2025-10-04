import Foundation
import Combine

// MARK: - Mock Authentication Service
class MockAuthenticationService: AuthenticationServiceProtocol {

    // MARK: - Properties
    @Published var isAuthenticated: Bool = true
    private let authStateSubject = CurrentValueSubject<Bool, Never>(true)
    // Initialize with default mock user for testing without onboarding
    private var mockUserData: (uid: String, email: String, displayName: String)? = (
        uid: "mock-user-123",
        email: "test@remi.com",
        displayName: "Test User"
    )

    var currentUser: AuthUser? {
        guard isAuthenticated, let userData = mockUserData else { return nil }
        return AuthUser(
            uid: userData.uid,
            email: userData.email,
            displayName: userData.displayName,
            isEmailVerified: true,
            createdAt: Date(),
            lastSignInAt: Date()
        )
    }
    
    var authStatePublisher: AnyPublisher<Bool, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - AuthenticationServiceProtocol Implementation
    
    func createAccount(email: String, password: String, fullName: String) async throws -> AuthResult {
        // Simulate account creation
        try await _Concurrency.Task.sleep(for: .milliseconds(500))

        let uid = UUID().uuidString
        mockUserData = (uid: uid, email: email, displayName: fullName)
        isAuthenticated = true
        authStateSubject.send(true)

        return AuthResult(
            uid: uid,
            email: email,
            displayName: fullName,
            isNewUser: true,
            idToken: UUID().uuidString
        )
    }
    
    func signIn(email: String, password: String) async throws -> AuthResult {
        // Simulate sign in
        try await _Concurrency.Task.sleep(for: .milliseconds(500))

        let uid = UUID().uuidString
        let displayName = email.components(separatedBy: "@").first ?? "User"
        mockUserData = (uid: uid, email: email, displayName: displayName)
        isAuthenticated = true
        authStateSubject.send(true)

        return AuthResult(
            uid: uid,
            email: email,
            displayName: displayName,
            isNewUser: false,
            idToken: UUID().uuidString
        )
    }
    
    func signInWithApple() async throws -> AuthResult {
        // Simulate Apple sign in
        try await _Concurrency.Task.sleep(for: .milliseconds(1000))

        let uid = UUID().uuidString
        let email = "\(UUID().uuidString.prefix(8))@privaterelay.appleid.com"
        let displayName = "Apple User"
        mockUserData = (uid: uid, email: email, displayName: displayName)
        isAuthenticated = true
        authStateSubject.send(true)

        return AuthResult(
            uid: uid,
            email: email,
            displayName: displayName,
            isNewUser: false,
            idToken: UUID().uuidString
        )
    }
    
    func signInWithGoogle() async throws -> AuthResult {
        // Simulate Google sign in
        try await _Concurrency.Task.sleep(for: .milliseconds(1000))

        let uid = UUID().uuidString
        let email = "\(UUID().uuidString.prefix(8))@gmail.com"
        let displayName = "Google User"
        mockUserData = (uid: uid, email: email, displayName: displayName)
        isAuthenticated = true
        authStateSubject.send(true)

        return AuthResult(
            uid: uid,
            email: email,
            displayName: displayName,
            isNewUser: false,
            idToken: UUID().uuidString
        )
    }
    
    func signOut() async throws {
        mockUserData = nil
        isAuthenticated = false
        authStateSubject.send(false)
        print("🔐 Mock user signed out")
    }

    func deleteAccount() async throws {
        mockUserData = nil
        isAuthenticated = false
        authStateSubject.send(false)
        print("🔐 Mock account deleted")
    }
    
    func updatePassword(_ newPassword: String) async throws {
        print("🔐 Mock password updated")
    }
    
    func sendPasswordReset(to email: String) async throws {
        print("🔐 Mock password reset sent to: \(email)")
    }
    
    func updateDisplayName(_ name: String) async throws {
        print("🔐 Mock display name updated to: \(name)")
    }
    
    func updateEmail(_ email: String) async throws {
        print("🔐 Mock email updated to: \(email)")
    }
    
    func refreshAuthToken() async throws -> String {
        return UUID().uuidString
    }

    func getIdToken() async throws -> String {
        return UUID().uuidString
    }
    
    func sendEmailVerification() async throws {
        print("🔐 Mock email verification sent")
    }
    
    func isEmailVerified() -> Bool {
        return true // Always verified in mock
    }
    
    func initializeAuthState() async {
        print("🔐 Mock: Auth state initialized")
    }
}