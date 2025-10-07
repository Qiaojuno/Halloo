# Changelog

## [Unreleased] - 2025-10-07

### Fixed - Profile Creation Failure

#### Problem Summary
- **Profile creation button appeared broken**: Users could tap "Create Profile" but nothing happened
- **Silent validation failures**: No error messages shown when validation failed
- **User document missing**: Returning users (isNewUser=false) didn't have Firestore user documents
- **updateData() on non-existent document**: Tried to update user's profileCount but document didn't exist

#### Root Causes Identified
1. **Validation mismatch**: `isValidForm` required `relationship` and `hasSelectedPhoto`, but SimplifiedProfileCreationView UI didn't collect them
2. **Silent failures**: Validation failure returned early with no user feedback
3. **Missing user document**: Sign-in only created user document for new users (`isNewUser=true`), but some returning users had no document
4. **Wrong Firestore method**: Used `.updateData()` which fails if document doesn't exist, instead of `.setData(merge: true)`

#### Changes Made

**1. ProfileViewModel.swift - Simplified Validation (lines 247-256)**
```swift
// BEFORE: Required relationship and photo
var isValidForm: Bool {
    return !profileName.isEmpty &&
           !phoneNumber.isEmpty &&
           !relationship.isEmpty &&  // ❌ UI doesn't collect this
           hasSelectedPhoto &&       // ❌ UI says "optional"
           // ...
}

// AFTER: Only require name and phone
var isValidForm: Bool {
    return !profileName.isEmpty &&
           !phoneNumber.isEmpty &&
           phoneNumber != "+1 " &&
           nameError == nil &&
           phoneError == nil
}
```

**2. ProfileViews.swift - Default Relationship (lines 411-415)**
```swift
// Set default relationship if not collected by UI
if profileViewModel.relationship.isEmpty {
    profileViewModel.relationship = "Family Member"
}
```

**3. ProfileViewModel.swift - Show Validation Errors (lines 618-631)**
```swift
// BEFORE: Silent failure
guard isValidForm else {
    return  // ❌ No feedback
}

// AFTER: Show error to user
guard isValidForm else {
    await MainActor.run {
        self.errorMessage = "Missing: \(missingRequirements.joined(separator: ", "))"
    }
    return
}
```

**4. FirebaseDatabaseService.swift - Defensive Document Creation (lines 805, 820)**
```swift
// BEFORE: Fails if document doesn't exist
.updateData(["profileCount": count])

// AFTER: Creates document if missing
.setData(["profileCount": count], merge: true)
```

Applied to:
- `updateUserProfileCount()` (line 805)
- `updateUserTaskCount()` (line 820)

**5. Added Comprehensive Diagnostic Logging**
- ProfileViewModel.swift (lines 601-636): Logs all validation state
- ProfileViews.swift (lines 389-443): Logs complete button → creation flow

#### Diagnostic Logging Evidence
```
🔨 ========== handleCreateProfile() CALLED ==========
✅ canProceed is TRUE
🔨 Setting default relationship: 'Family Member'
🔍 ==================== PROFILE CREATION DEBUG ====================
🔍 isValidForm: true
✅ VALIDATION PASSED - Proceeding with profile creation
✅ Profile created in Firestore
✅ User document created/updated with profileCount: 1
✅ Profile appears in dashboard
```

#### Benefits
- **Works for all users**: Both new and returning users can create profiles
- **Clear error messages**: Users see exactly what's missing if validation fails
- **Defensive programming**: User document created automatically if missing
- **Better UX**: Photo and relationship truly optional as UI suggests
- **Debuggable**: Comprehensive logging at every critical step

---

### Fixed - Authentication Navigation Issue

#### Problem Summary
- **Login screen stuck after sign-in**: After successful Google Sign-In, app remained on login screen despite authentication succeeding (isAuthenticated=true in logs)
- **Firestore security rules blocking**: Initial issue was Firestore permission errors blocking auth flow
- **ContentView not reacting to auth changes**: Auth state changes weren't triggering SwiftUI re-renders

#### Root Causes Identified
1. **Firestore security rules too restrictive**: Rules were blocking authenticated users from reading/writing their own data
2. **ContentView not observing auth state**: `authService` was `@State` variable, not `@StateObject` or observed, so `isAuthenticated` changes didn't trigger re-renders
3. **No Combine subscription**: ContentView wasn't subscribed to `authService.authStatePublisher` to react to auth state changes

#### Changes Made

**1. Firestore Security Rules - Fixed Permissions**
Updated Firebase Console rules to allow authenticated users to access their own data:
```javascript
match /users/{userId} {
  allow read, write: if isAuthenticated() && isOwner(userId);

  match /profiles/{profileId} {
    allow read, write: if isAuthenticated() && isOwner(userId);
    // ... nested collections
  }
}
```

**2. ContentView.swift - Added Auth State Observer**
- Added `@State private var isAuthenticated = false` to track auth state locally
- Added `@State private var authCancellables` to store Combine subscriptions
- Created `setupAuthStateObserver()` that subscribes to `authService.authStatePublisher`
- Changed navigation logic to check `isAuthenticated` instead of `authService.isAuthenticated`
- Updates `isAuthenticated` on auth state changes, triggering SwiftUI re-render

```swift
// BEFORE: Direct property check (no observation)
if authService.isAuthenticated {
    authenticatedContent
}

// AFTER: Observed local state
@State private var isAuthenticated = false

private func setupAuthStateObserver() {
    authService.authStatePublisher
        .receive(on: DispatchQueue.main)
        .sink { newAuthState in
            self.isAuthenticated = newAuthState
            if newAuthState {
                self.profileViewModel?.loadProfiles()
            }
        }
        .store(in: &authCancellables)
}

if isAuthenticated {
    authenticatedContent
}
```

#### Diagnostic Logging Evidence
```
✅ Firebase sign-in successful
   UID: IJue7FhdmbbIzR3WG6Tzhhf2ykD2
🔴 [📥 VM-LOAD] Checking authentication {isAuthenticated=true, userId=IJue7FhdmbbIzR3WG6Tzhhf2ykD2}
✅ [💾 DATABASE] Fetch profiles COMPLETED {count=0}
```

After fix, auth state changes properly trigger navigation to dashboard.

#### Benefits
- **Reactive navigation**: SwiftUI automatically re-renders when auth state changes
- **Single source of truth**: Auth state publisher drives UI updates
- **Proper Combine usage**: Standard pattern for observing state changes in SwiftUI
- **Diagnostic logging intact**: All logs from previous session still working

---

## [2025-10-04]

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
