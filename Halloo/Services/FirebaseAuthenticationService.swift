import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import Combine

// MARK: - Firebase Authentication Service
class FirebaseAuthenticationService: ObservableObject, AuthenticationServiceProtocol {

    // MARK: - Properties
    private lazy var auth: Auth = Auth.auth()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let authStateSubject = CurrentValueSubject<User?, Never>(nil)
    private let authBoolSubject = CurrentValueSubject<Bool, Never>(false)

    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false

    var currentUser: AuthUser? {
        guard let firebaseUser = auth.currentUser else { return nil }
        return AuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            isEmailVerified: firebaseUser.isEmailVerified,
            createdAt: firebaseUser.metadata.creationDate ?? Date(),
            lastSignInAt: firebaseUser.metadata.lastSignInDate ?? Date()
        )
    }
    
    var authStatePublisher: AnyPublisher<Bool, Never> {
        authBoolSubject.eraseToAnyPublisher()
    }
    
    var userStatePublisher: AnyPublisher<User?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        // Delay auth listener setup to avoid crash during initialization
        // Will be set up when initializeAuthState() is called
        print("🔥 FirebaseAuthenticationService: init() completed (listener not yet set up)")
    }

    deinit {
        removeAuthStateListener()
    }

    // MARK: - AuthenticationServiceProtocol Implementation
    
    func createAccount(email: String, password: String, fullName: String) async throws -> AuthResult {
        let result = try await auth.createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = fullName
        try await changeRequest.commitChanges()
        
        return AuthResult(
            uid: result.user.uid,
            email: result.user.email,
            displayName: fullName,
            isNewUser: true,
            idToken: try await result.user.getIDToken()
        )
    }
    
    func signIn(email: String, password: String) async throws -> AuthResult {
        let result = try await auth.signIn(withEmail: email, password: password)
        return AuthResult(
            uid: result.user.uid,
            email: result.user.email,
            displayName: result.user.displayName,
            isNewUser: false,
            idToken: try await result.user.getIDToken()
        )
    }
    
    func signInWithApple() async throws -> AuthResult {
        // Note: Apple Sign In integration would typically be handled at the UI level
        // with SignInWithAppleButton, which then passes the ASAuthorization result here
        // For now, we'll throw an error indicating this should be handled differently
        throw AuthenticationError.unknownError("Apple Sign In should be handled through SignInWithAppleButton in the UI layer")
    }
    
    /// Process Apple Sign In authorization result from UI layer
    func processAppleSignIn(authorization: ASAuthorization) async throws -> AuthResult {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthenticationError.unknownError("Invalid Apple ID credential")
        }

        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthenticationError.unknownError("Failed to get identity token from Apple")
        }

        // Create Firebase credential
        let credential = OAuthProvider.appleCredential(withIDToken: identityTokenString,
                                                      rawNonce: "",
                                                      fullName: appleIDCredential.fullName)

        // Sign in with Firebase
        let authResult = try await auth.signIn(with: credential)
        let firebaseUser = authResult.user
        let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

        // Update display name if provided by Apple
        if let fullName = appleIDCredential.fullName,
           let givenName = fullName.givenName,
           let familyName = fullName.familyName,
           firebaseUser.displayName == nil {
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = "\(givenName) \(familyName)"
            try await changeRequest.commitChanges()
        }

        // CRITICAL: Ensure user document exists in Firestore
        // This is required for profile creation (updateUserProfileCount needs it)
        if isNewUser {
            print("📝 Creating user document for new Apple user...")
            let newUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? appleIDCredential.email ?? "",
                fullName: firebaseUser.displayName ?? "",
                phoneNumber: "",
                createdAt: Date(),
                isOnboardingComplete: false,
                subscriptionStatus: .trial,
                trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                quizAnswers: nil,
                profileCount: 0,
                taskCount: 0,
                updatedAt: Date(),
                lastSyncTimestamp: nil
            )

            // ✅ Use centralized helper to ensure schema compliance
            try await createUserDocument(newUser)
        }

        return AuthResult(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? appleIDCredential.email,
            displayName: firebaseUser.displayName,
            isNewUser: isNewUser,
            idToken: try await firebaseUser.getIDToken()
        )
    }
    
    func signInWithGoogle() async throws -> AuthResult {
        print("🔐 Starting Google Sign-In flow...")

        // Get the app's root view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = await windowScene.windows.first?.rootViewController else {
            print("❌ Failed to get root view controller")
            throw AuthenticationError.unknownError("Unable to get root view controller")
        }
        print("✅ Got root view controller")

        do {
            print("📱 Presenting Google Sign-In...")
            // Start the Google Sign-In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            print("✅ Google Sign-In successful - User: \(user.profile?.email ?? "unknown")")

            // Get the ID token and access token
            guard let idToken = user.idToken?.tokenString else {
                print("❌ Failed to get ID token from Google")
                throw AuthenticationError.unknownError("Failed to get ID token from Google")
            }
            print("✅ Got ID token")

            let accessToken = user.accessToken.tokenString
            print("✅ Got access token")

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            print("✅ Created Firebase credential")

            print("🔥 Signing into Firebase...")
            // Sign in with Firebase
            let authResult = try await auth.signIn(with: credential)
            let firebaseUser = authResult.user
            let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
            print("✅ Firebase sign-in successful")
            print("   UID: \(firebaseUser.uid)")
            print("   Email: \(firebaseUser.email ?? "unknown")")
            print("   Is new user: \(isNewUser)")

            // CRITICAL: Ensure user document exists in Firestore
            // This is required for profile creation (updateUserProfileCount needs it)
            if isNewUser {
                print("📝 Creating user document for new Google user...")
                let newUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    fullName: firebaseUser.displayName ?? "",
                    phoneNumber: "",
                    createdAt: Date(),
                    isOnboardingComplete: false,
                    subscriptionStatus: .trial,
                    trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                    quizAnswers: nil,
                    profileCount: 0,
                    taskCount: 0,
                    updatedAt: Date(),
                    lastSyncTimestamp: nil
                )
                // ✅ Use centralized helper to ensure schema compliance
                try await createUserDocument(newUser)
            }

            print("🎉 Google Sign-In complete!")
            return AuthResult(
                uid: firebaseUser.uid,
                email: firebaseUser.email,
                displayName: firebaseUser.displayName,
                isNewUser: isNewUser,
                idToken: try await firebaseUser.getIDToken()
            )

        } catch {
            print("❌ Google Sign-In error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            throw AuthenticationError.unknownError("Google Sign In failed: \(error.localizedDescription)")
        }
    }
    
    func signOut() async throws {
        try auth.signOut()
        authStateSubject.send(nil)
        authBoolSubject.send(false)
    }
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        try await user.delete()
    }
    
    func updatePassword(_ newPassword: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        try await user.updatePassword(to: newPassword)
    }
    
    func sendPasswordReset(to email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    func updateDisplayName(_ name: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
    }
    
    func updateEmail(_ email: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        try await user.sendEmailVerification(beforeUpdatingEmail: email)
    }
    
    func refreshAuthToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        return try await user.getIDToken(forcingRefresh: true)
    }
    
    func getIdToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        return try await user.getIDToken()
    }
    
    func sendEmailVerification() async throws {
        guard let user = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        try await user.sendEmailVerification()
    }
    
    func isEmailVerified() -> Bool {
        return auth.currentUser?.isEmailVerified ?? false
    }
    
    func initializeAuthState() async {
        print("🔥 FirebaseAuthenticationService: Setting up auth state listener")
        // Set up the auth state listener first
        setupAuthStateListener()

        // Check if user is already signed in
        if let firebaseUser = auth.currentUser {
            do {
                let user = try await createUserFromFirebaseUser(firebaseUser)
                await MainActor.run {
                    authStateSubject.send(user)
                    authBoolSubject.send(true)
                }
            } catch {
                print("❌ Error creating user from Firebase user: \(error)")
                await MainActor.run {
                    authStateSubject.send(nil)
                    authBoolSubject.send(false)
                }
            }
        }
    }
    
    func getCurrentUser() async throws -> User? {
        guard let firebaseUser = auth.currentUser else {
            return nil
        }
        
        return try await createUserFromFirebaseUser(firebaseUser)
    }
    
    func signInWithEmail(_ email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return try await createUserFromFirebaseUser(result.user)
    }
    
    func signUpWithEmail(_ email: String, password: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        let user = try await createUserFromFirebaseUser(result.user)
        
        // Create user document in Firestore
        try await createUserDocument(user)
        
        return user
    }
    
    func signInWithApple(_ idToken: String, nonce: String) async throws -> User {
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
        
        let result = try await auth.signIn(with: credential)
        let user = try await createUserFromFirebaseUser(result.user)
        
        // Create user document if new user
        if result.additionalUserInfo?.isNewUser == true {
            try await createUserDocument(user)
        }
        
        return user
    }
    
    func signInWithGoogle(_ idToken: String, accessToken: String) async throws -> User {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let result = try await auth.signIn(with: credential)
        let user = try await createUserFromFirebaseUser(result.user)
        
        // Create user document if new user
        if result.additionalUserInfo?.isNewUser == true {
            try await createUserDocument(user)
        }
        
        return user
    }
    
    func reauthenticate(password: String) async throws {
        guard let firebaseUser = auth.currentUser,
              let email = firebaseUser.email else {
            throw AuthenticationError.userNotFound
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await firebaseUser.reauthenticate(with: credential)
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            _Concurrency.Task { [weak self] in
                guard let self = self else { return }

                if let firebaseUser = firebaseUser {
                    do {
                        let user = try await self.createUserFromFirebaseUser(firebaseUser)
                        await MainActor.run { [weak self] in
                            self?.authStateSubject.send(user)
                            self?.authBoolSubject.send(true)
                            self?.isAuthenticated = true  // ✅ Update @Published property
                            print("🔐 Auth listener: User logged in, isAuthenticated = true")
                        }
                    } catch {
                        print("❌ Error in auth state listener: \(error)")
                        await MainActor.run { [weak self] in
                            self?.authStateSubject.send(nil)
                            self?.authBoolSubject.send(false)
                            self?.isAuthenticated = false  // ✅ Update @Published property
                            print("🔐 Auth listener: Error, isAuthenticated = false")
                        }
                    }
                } else {
                    await MainActor.run { [weak self] in
                        self?.authStateSubject.send(nil)
                        self?.authBoolSubject.send(false)
                        self?.isAuthenticated = false  // ✅ Update @Published property
                        print("🔐 Auth listener: User logged out, isAuthenticated = false")
                    }
                }
            }
        }
    }
    
    private func removeAuthStateListener() {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
    
    private func createUserFromFirebaseUser(_ firebaseUser: FirebaseAuth.User) async throws -> User {
        // Fetch user document from Firestore
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(firebaseUser.uid).getDocument()
        
        if userDoc.exists, let data = userDoc.data() {
            // User document exists, create User from Firestore data
            return User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                fullName: data["fullName"] as? String ?? firebaseUser.displayName ?? "",
                phoneNumber: data["phoneNumber"] as? String ?? "",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                isOnboardingComplete: data["isOnboardingComplete"] as? Bool ?? false,
                subscriptionStatus: SubscriptionStatus(rawValue: data["subscriptionStatus"] as? String ?? "trial") ?? .trial,
                trialEndDate: (data["trialEndDate"] as? Timestamp)?.dateValue(),
                quizAnswers: data["quizAnswers"] as? [String: String],
                profileCount: data["profileCount"] as? Int ?? 0,
                taskCount: data["taskCount"] as? Int ?? 0,
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                lastSyncTimestamp: (data["lastSyncTimestamp"] as? Timestamp)?.dateValue()
            )
        } else {
            // User document doesn't exist, create User with basic info
            return User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                fullName: firebaseUser.displayName ?? "",
                phoneNumber: "",
                createdAt: Date(),
                isOnboardingComplete: false,
                subscriptionStatus: .trial,
                trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                quizAnswers: nil,
                profileCount: 0,
                taskCount: 0,
                updatedAt: Date(),
                lastSyncTimestamp: nil
            )
        }
    }
    
    private func createUserDocument(_ user: User) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.id)
        
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "fullName": user.fullName,
            "phoneNumber": user.phoneNumber,
            "createdAt": user.createdAt,
            "subscriptionStatus": user.subscriptionStatus.rawValue,
            "isOnboardingComplete": user.isOnboardingComplete,
            "trialEndDate": user.trialEndDate ?? Date(),
            "quizAnswers": user.quizAnswers ?? [:],
            "profileCount": user.profileCount,
            "taskCount": user.taskCount,
            "updatedAt": user.updatedAt,
            "lastSyncTimestamp": user.lastSyncTimestamp as Any
        ]
        
        try await userRef.setData(userData)
        print("✅ User document created in Firestore: \(user.id)")
    }
}

// Using AuthenticationError from AuthenticationServiceProtocol.swift

// MARK: - Firebase Auth Error Mapping Extension
extension FirebaseAuthenticationService {
    private func mapAuthError(_ error: Error) -> AuthenticationError {
        guard let authError = error as NSError?,
              let authErrorCode = AuthErrorCode(rawValue: authError.code) else {
            return .unknownError(error.localizedDescription)
        }
        
        switch authErrorCode {
        case .userNotFound, .invalidEmail:
            return .userNotFound
        case .wrongPassword, .invalidCredential:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError, .tooManyRequests:
            return .networkError
        default:
            return .unknownError(error.localizedDescription)
        }
    }
}
