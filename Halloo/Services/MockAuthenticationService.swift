import Foundation
import Combine

// MARK: - Mock Authentication Service
class MockAuthenticationService: AuthenticationServiceProtocol {
    
    // MARK: - Properties
    @Published var isAuthenticated: Bool = false
    private let authStateSubject = CurrentValueSubject<Bool, Never>(false)
    
    var currentUser: AuthUser? {
        return isAuthenticated ? AuthUser(
            uid: "mock-user-id",
            email: "test@example.com",
            displayName: "Mock User",
            isEmailVerified: true,
            createdAt: Date(),
            lastSignInAt: Date()
        ) : nil
    }
    
    var authStatePublisher: AnyPublisher<Bool, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - AuthenticationServiceProtocol Implementation
    
    func createAccount(email: String, password: String, fullName: String) async throws -> AuthResult {
        // Simulate account creation
        try await _Concurrency.Task.sleep(for: .milliseconds(500))
        
        isAuthenticated = true
        authStateSubject.send(true)
        
        return AuthResult(
            uid: "mock-user-\(UUID().uuidString)",
            email: email,
            displayName: fullName,
            isNewUser: true,
            idToken: "mock-id-token"
        )
    }
    
    func signIn(email: String, password: String) async throws -> AuthResult {
        // Simulate sign in
        try await _Concurrency.Task.sleep(for: .milliseconds(500))
        
        isAuthenticated = true
        authStateSubject.send(true)
        
        return AuthResult(
            uid: "mock-user-existing",
            email: email,
            displayName: "Mock User",
            isNewUser: false,
            idToken: "mock-id-token"
        )
    }
    
    func signInWithApple() async throws -> AuthResult {
        // Simulate Apple sign in
        try await _Concurrency.Task.sleep(for: .milliseconds(1000))
        
        isAuthenticated = true
        authStateSubject.send(true)
        
        return AuthResult(
            uid: "mock-apple-user",
            email: "apple@example.com",
            displayName: "Apple User",
            isNewUser: false,
            idToken: "mock-apple-token"
        )
    }
    
    func signInWithGoogle() async throws -> AuthResult {
        // Simulate Google sign in
        try await _Concurrency.Task.sleep(for: .milliseconds(1000))
        
        isAuthenticated = true
        authStateSubject.send(true)
        
        return AuthResult(
            uid: "mock-google-user",
            email: "google@example.com",
            displayName: "Google User",
            isNewUser: false,
            idToken: "mock-google-token"
        )
    }
    
    func signOut() async throws {
        isAuthenticated = false
        authStateSubject.send(false)
        print("🔐 Mock user signed out")
    }
    
    func deleteAccount() async throws {
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
        return "mock-refreshed-token"
    }
    
    func getIdToken() async throws -> String {
        return "mock-current-token"
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