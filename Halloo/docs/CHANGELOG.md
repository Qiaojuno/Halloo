# Changelog

## [Unreleased] - 2025-10-09

### Fixed - Gallery UI Polish & Data Loading

#### Problem Summary
- **Gallery empty state bug**: Gallery showed "Create your first remi" despite data existing in Firebase
- **Text message preview styling**: Speech bubble lines had visible gaps and broken appearance
- **Profile avatar missing**: Git revert lost previous profile emoji display work

#### Root Causes Identified
1. **Service injection failure**: `GalleryViewModel.updateServices()` was empty stub, services stayed as Mock
2. **Immutable services**: Services declared as `private let`, couldn't be updated after initialization
3. **Complex spacing logic**: Mixing spacing values into segment arrays, using Spacer() with ignored frame constraints
4. **Git revert side effects**: Full file revert lost unrelated profile avatar improvements

#### Changes Made

**1. GalleryViewModel.swift - Fixed Service Injection (lines 95-97, 174-178)**
```swift
// BEFORE: Immutable services
private let databaseService: DatabaseServiceProtocol
func updateServices(...) {
    print("🔄 GalleryViewModel services updated")  // No-op!
}

// AFTER: Mutable services with real injection
private var databaseService: DatabaseServiceProtocol
func updateServices(...) {
    self.databaseService = databaseService
    self.authService = authService
    self.errorCoordinator = errorCoordinator
}
```

**2. GalleryPhotoView.swift - Simplified Speech Bubble Rendering (lines 253-261)**
```swift
// Clean data structure: only text segments
textLines: [
    [(11, 1.5), (13, 1.5), (15, 1.5)],   // 3 segments = 2 gaps
    [(18, 1.5), (17, 1.5)],              // 2 segments = 1 gap
    [(10, 1.5), (14, 1.5), (12, 1.5)]    // 3 segments = 2 gaps
]

// Simple rendering with HStack spacing
HStack(spacing: 1) {
    ForEach(...) { wordIndex in
        Rectangle()
            .fill(Color.black)
            .frame(width: ..., height: ...)
    }
}
```

**3. GalleryPhotoView.swift - Restored Profile Avatar (lines 216-240)**
```swift
// Show profile emoji instead of blue circle
profileAvatarOverlay(for: event)

// Clean flat design (no shadow, no stroke)
Circle()
    .fill(Color.white)
    .overlay(Text(emoji).font(.system(size: 10)))
```

#### Result
- ✅ Gallery loads real data from Firebase (Mock → Firebase injection works)
- ✅ Text segments render cleanly with subtle 1px gaps
- ✅ Correct gap counts: Line 1 (2 gaps), Line 2 (1 gap), Line 3 (2 gaps)
- ✅ Profile emoji displays in bottom-right corner of text/photo squares
- ✅ No visible background bleeding through text bars

#### Files Changed
- `Halloo/ViewModels/GalleryViewModel.swift` - Service injection implementation
- `Halloo/Views/Components/GalleryPhotoView.swift` - Speech bubble rendering + profile avatar
- `Halloo/Views/GalleryView.swift` - Example message box updates

#### Documentation
- Created `docs/sessions/SESSION-2025-10-09-GalleryUIFixes.md` with full debugging walkthrough

---

## [Unreleased] - 2025-10-08

### Added - iOS-Native Habit Deletion Animation

#### Problem Summary
- **Deletion felt sluggish**: Habit deletion had no visual feedback during async database operation
- **Vertical scroll conflict**: Swipe-to-delete interfered with vertical scrolling in habits list
- **Animation conflicts**: Global `.animation(nil)` was blocking all deletion animations
- **No slide-away effect**: Missing the characteristic iOS deletion animation

#### Root Causes Identified
1. **Async blocking UI**: Waited for database deletion before updating UI, causing freeze
2. **Ambiguous gesture detection**: DragGesture didn't distinguish horizontal vs vertical movement
3. **Global animation disabler**: `.animation(nil)` on line 81 blocked all animations in view hierarchy
4. **Missing optimistic updates**: No immediate UI feedback while background operation completed

#### Changes Made

**1. HabitsView.swift - Optimistic UI Updates (lines 45-49, 252-266)**
```swift
// NEW: Track locally deleted habits for instant UI updates
@State private var locallyDeletedHabitIds: Set<String> = []

// Filter out locally deleted habits immediately
private var filteredHabits: [Task] {
    return allTasks.filter { habit in
        guard !locallyDeletedHabitIds.contains(habit.id) else { return false }
        // ... rest of filtering
    }
}

// Immediate deletion with animation
withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
    locallyDeletedHabitIds.insert(habit.id)
}
// Database deletion happens in background
```

**2. HabitsView.swift - Horizontal Gesture Detection (lines 412-455)**
```swift
// BEFORE: All drags triggered swipe-to-delete
DragGesture()
    .onChanged { value in
        if value.translation.width < 0 {
            dragOffset = max(value.translation.width, -deleteButtonWidth)
        }
    }

// AFTER: Only horizontal swipes trigger delete
@State private var isDraggingHorizontally: Bool? = nil

DragGesture()
    .onChanged { value in
        // Detect direction on first movement
        if isDraggingHorizontally == nil {
            let horizontalAmount = abs(value.translation.width)
            let verticalAmount = abs(value.translation.height)
            isDraggingHorizontally = horizontalAmount > verticalAmount && horizontalAmount > 10
        }

        // Only respond to horizontal drags
        if isDraggingHorizontally == true && value.translation.width < 0 {
            dragOffset = max(value.translation.width, -deleteButtonWidth)
        }
    }
```

**3. HabitsView.swift - Removed Animation Blocker (line 81)**
```swift
// BEFORE: Blocked ALL animations
.animation(nil) // Disable all animations

// AFTER: Removed entirely
// Specific .animation(nil, value:) modifiers still prevent unwanted nav animations
```

**4. HabitsView.swift - iOS-Native Transitions (lines 229-235)**
```swift
.transition(.asymmetric(
    insertion: .identity,
    removal: .move(edge: .leading).combined(with: .opacity)
))
```

**5. DatabaseServiceProtocol.swift & Implementations - Fixed Delete Signature (lines 247-252)**
```swift
// BEFORE: Required collection group query
func deleteTask(_ taskId: String) async throws

// AFTER: Direct path construction
func deleteTask(_ taskId: String, userId: String, profileId: String) async throws
```

**6. FirebaseDatabaseService.swift - Removed Collection Group Query (lines 391-425)**
```swift
// BEFORE: Used collection group query (required index, caused permission errors)
let snapshot = try await db.collectionGroup("habits")
    .whereField("id", isEqualTo: taskId)
    .getDocuments()

// AFTER: Direct path deletion
let taskPath = "users/\(userId)/profiles/\(profileId)/habits/\(taskId)"
try await db.document(taskPath).delete()
```

#### Diagnostic Logging Evidence
```
🗑️ Deleting habit 'Take vitamins' (ID: B6437C28-689E-49D5-84B5-E6C9887AADC5)
🔍 [FirebaseDatabaseService] deleteTask called
   taskId: B6437C28-689E-49D5-84B5-E6C9887AADC5
   userId: IJue7FhdmbbIzR3WG6Tzhhf2ykD2
   profileId: +17788143739
🗑️ [FirebaseDatabaseService] Deleting habit at: users/IJue7FhdmbbIzR3WG6Tzhhf2ykD2/profiles/+17788143739/habits/B6437C28-689E-49D5-84B5-E6C9887AADC5
✅ [FirebaseDatabaseService] Habit deleted successfully
```

#### Benefits
- **Instant feedback**: Habit slides away immediately (no freeze or delay)
- **Smooth animations**: iOS-native spring animation (response: 0.35s, damping: 0.8)
- **Proper gesture handling**: Vertical scroll works, horizontal swipe deletes
- **Error recovery**: If deletion fails, habit slides back in with animation
- **No index requirements**: Direct path deletion eliminates Firestore composite index needs
- **Production-safe**: Optimistic UI pattern used by iOS Mail, Messages, Reminders

#### Files Changed
- `Halloo/Views/HabitsView.swift` - Optimistic updates, gesture detection, animation fixes
- `Halloo/Services/DatabaseServiceProtocol.swift` - Updated deleteTask signature
- `Halloo/Services/FirebaseDatabaseService.swift` - Direct path deletion
- `Halloo/Services/MockDatabaseService.swift` - Updated mock implementation
- `Halloo/ViewModels/TaskViewModel.swift` - Updated deleteTask call

---

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
