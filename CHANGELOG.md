# Changelog

## [Unreleased] - 2025-10-04

### Fixed - Authentication Flow Restructuring

#### Problem Summary
- **Logout not working**: Sign out button didn't navigate back to login screen
- **Double sign-in required**: Users had to sign in twice to authenticate
- **Login screen stuck**: After successful sign-in, UI remained on login screen despite debug showing "Sign-in succeeded"

#### Root Causes Identified
1. **Container creating new service instances**: Each `container.resolve()` call created a new `FirebaseAuthenticationService` instance, causing different auth listeners and publishers
2. **Auth listener not updating boolean publisher**: `setupAuthStateListener()` only updated `authStateSubject` but not `authBoolSubject` that ContentView subscribed to
3. **Competing state updates**: LoginView manually set `isAuthenticated = true` while auth listener also fired, creating race conditions
4. **Complex Combine subscriptions**: ContentView manually subscribed to `authBoolSubject` publisher with convoluted state management

#### Changes Made

**1. Container.swift - Singleton Pattern**
- Added `singletons` dictionary to store singleton instances
- Created `registerSingleton()` method for one-time service creation
- Modified `resolve()` to check singletons first before factory pattern
- Registered `AuthenticationServiceProtocol` and `DatabaseServiceProtocol` as singletons

```swift
// BEFORE: New instance on each resolve
register(AuthenticationServiceProtocol.self) {
    FirebaseAuthenticationService()
}

// AFTER: Single shared instance
registerSingleton(AuthenticationServiceProtocol.self) {
    FirebaseAuthenticationService()
}
```

**2. FirebaseAuthenticationService.swift - ObservableObject with @Published**
- Made service conform to `ObservableObject`
- Added `@Published var isAuthenticated: Bool = false`
- Updated `setupAuthStateListener()` to update both publishers AND @Published property

```swift
// BEFORE: Only updated publishers
self?.authBoolSubject.send(true)

// AFTER: Updates both publisher and @Published property
self?.authBoolSubject.send(true)
self?.isAuthenticated = true
```

**3. ContentView.swift - Direct State Reference**
- Changed from manual Combine subscription to direct `@State` reference
- Removed `@State private var isAuthenticated`
- Removed `@State private var authCancellable`
- Removed `subscribeToAuthState()` method entirely
- Uses `authService.isAuthenticated` directly in view

```swift
// BEFORE: Manual subscription
@State private var isAuthenticated = false
@State private var authCancellable: AnyCancellable?

private func subscribeToAuthState() {
    authCancellable = authService.authStatePublisher
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isAuth in
            self?.isAuthenticated = isAuth
        }
}

// AFTER: Direct property access
@State private var authService: FirebaseAuthenticationService?

if authService.isAuthenticated {
    authenticatedContent
} else {
    LoginView(...)
}
```

**4. LoginView Callback - Removed Manual State Update**
- Removed manual `isAuthenticated = true` from callback
- Auth listener is now single source of truth

```swift
// BEFORE: Manual state update + listener
LoginView(onAuthenticationSuccess: {
    isAuthenticated = true  // ❌ Race condition
    profileViewModel?.loadProfiles()
})

// AFTER: Listener only
LoginView(onAuthenticationSuccess: {
    // Auth state updated by listener automatically
    profileViewModel?.loadProfiles()
})
```

**5. SharedHeaderSection.swift - Logout Button**
- Added account settings button in header
- Created `AccountSettingsView` sheet with sign out functionality
- Used `_Concurrency.Task.detached` to avoid Task naming conflicts

#### Benefits
- **Single source of truth**: Firebase auth state → listener → @Published property → SwiftUI
- **No race conditions**: Eliminated competing manual state updates
- **Simplified code**: Removed complex Combine subscriptions
- **Scalable architecture**: ObservableObject pattern is standard SwiftUI best practice
- **Proper singleton usage**: Core services are now shared instances

### Added - Firebase Migration Infrastructure

#### Migration Script (migrate.js)
- Created comprehensive Node.js migration script using Firebase Admin SDK
- Migrates data from flat collections to nested subcollections structure
- Features:
  - Dry-run mode (default safe mode)
  - Validation and data integrity checks
  - Batch processing for large datasets
  - Detailed logging and progress tracking
  - Backup functionality

#### NPM Configuration
- Added `package.json` with migration scripts:
  - `npm run migrate:dry-run` - Preview migration without changes
  - `npm run migrate:commit` - Execute production migration
  - `npm run migrate:validate` - Verify migration results
  - `npm run migrate:backup` - Backup existing data

#### Documentation
- Created `MIGRATION-README.md` with step-by-step instructions
- Updated `.gitignore` to exclude service account keys and migration outputs

#### Firestore Setup
- Enabled Cloud Firestore API in Google Cloud Console
- Created Firestore database (Standard Edition, us-central1)

## Previous Work

See `TODO-1-COMPLETION-SUMMARY.md` for details on nested subcollections migration implementation.
