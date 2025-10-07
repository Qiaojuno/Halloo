# Hallo iOS App - Development Guidelines & Patterns
# Last Updated: 2025-10-03
# Critical patterns and fixes for future development

## RECENT LESSONS LEARNED (2025-10-03)

### Profile Creation & User Document Management

**Critical Pattern:** Always ensure user document exists before creating related entities

```swift
// ❌ WRONG - assumes user document exists
func createElderlyProfile(_ profile: ElderlyProfile) async throws {
    // ... save profile
    try await updateUserProfileCount(profile.userId) // FAILS if user doc missing
}

// ✅ CORRECT - create user document on sign-in
func signInWithGoogle() async throws -> AuthResult {
    let result = try await auth.signIn(with: credential)
    let isNewUser = result.additionalUserInfo?.isNewUser ?? false

    if isNewUser {
        // Create user document immediately
        let userData = [
            "id": user.id,
            "email": user.email,
            "profileCount": 0 // Critical for updateUserProfileCount
        ]
        try await db.collection("users").document(user.id).setData(userData)
    }
}
```

### SwiftUI ForEach ID Selection

**Critical Pattern:** Always use unique, stable identifiers for ForEach, never indices

```swift
// ❌ WRONG - using index/offset as ID
ForEach(Array(profiles.prefix(2).enumerated()), id: \.offset) { index, profile in
    ProfileView(profile: profile)
}
// Problem: SwiftUI can't track changes when array is modified

// ✅ CORRECT - using unique profile ID
ForEach(Array(profiles.prefix(2).enumerated()), id: \.element.id) { index, profile in
    ProfileView(profile: profile)
}
// SwiftUI properly tracks each profile by its unique ID
```

### ViewModel Initialization & Authentication

**Critical Pattern:** Reload data after authentication completes

```swift
// ❌ WRONG - load profiles in init (user not authenticated yet)
init(...) {
    loadProfiles() // Fails silently because user is nil
}

// ✅ CORRECT - reload after authentication
func handleSuccessfulLogin() {
    isAuthenticated = true
    profileViewModel.loadProfiles() // Now user is authenticated
}
```

### Async/Await in Profile Creation

**Critical Pattern:** Properly await async operations before dismissing views

```swift
// ❌ WRONG - dismisses before profile is saved
_Concurrency.Task {
    profileViewModel.createProfile() // Not awaited!
    try? await Task.sleep(nanoseconds: 500_000_000)
    onDismiss() // View closes before save completes
}

// ✅ CORRECT - await completion before dismiss
_Concurrency.Task {
    await profileViewModel.createProfileAsync() // Waits for completion
    onDismiss() // Only dismiss after save succeeds
}
```

## CRITICAL DEVELOPMENT PATTERNS

### Task Naming Conflicts
**Issue:** Swift naming conflicts between app Task model and Swift Concurrency Task
**Solution:** Always use `_Concurrency.Task` for Swift concurrency operations

```swift
// ❌ WRONG - causes naming conflict
Task { @MainActor in
    await someOperation()
}

// ✅ CORRECT - explicit Concurrency namespace  
_Concurrency.Task { @MainActor in
    await someOperation()
}
```

### UIKit Dependencies
**Rule:** This is a SwiftUI-only project - no UIKit imports allowed
**Alternative Patterns:**

```swift
// ❌ UIKit dependency
import UIKit
UIApplication.shared...
UIDevice.current...

// ✅ SwiftUI/Foundation alternatives
import SwiftUI
// Use SwiftUI's native components and Foundation APIs
```

### Asset Naming
**Critical:** Use exact case-sensitive names consistently

```swift
// Asset files in Xcode:
Character.imageset/Mascot.png
Bird1.imageset/Bird.png
Bird2.imageset/Bird.png

// Code references:
Image("Mascot")    // ✅ CORRECT
Image("Bird1")     // ✅ CORRECT
Image("mascot")    // ❌ WRONG - case mismatch
```

## KEY DESIGN PATTERNS

### Container Dependency Injection
```swift
// Service Factory Pattern
extension Container {
    func makeDashboardViewModel() -> DashboardViewModel {
        return DashboardViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            analyticsService: resolve(AnalyticsServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
}
```

### Mock Service Pattern
```swift
class MockAnalyticsService: AnalyticsServiceProtocol {
    // Return realistic mock data with proper types
    func getWeeklyAnalytics(for userId: String) async throws -> WeeklyAnalytics {
        return WeeklyAnalytics(
            userId: userId,                    // PRESERVE INPUT
            completionRate: 0.8,              // REALISTIC DATA
            dailyCompletion: [0.8, 0.9, 0.7], // MOCK ARRAY
            generatedAt: Date()               // CURRENT TIME
        )
    }
}
```

### Canvas Preview Safety
```swift
// ProfileViewModel Canvas-safe initialization
init(skipAutoLoad: Bool = false) {
    if !skipAutoLoad {
        loadProfiles() // Production behavior
    }
    // Canvas skips auto-loading
}

// Container Canvas-specific factory
func makeProfileViewModelForCanvas() -> ProfileViewModel {
    return ProfileViewModel(skipAutoLoad: true)
}
```

## COMMON VARIABLE NAMING PATTERNS

### ID Relationships
- `userId`: Links to User.id (owner of data)
- `profileId`: Links to ElderlyProfile.id (elderly person)  
- `taskId`: Links to Task.id (specific care task)
- `responseId`: Links to SMSResponse.id (SMS reply)

### Status Enums Pattern
- `ProfileStatus`: .pendingConfirmation → .confirmed → .inactive
- `TaskStatus`: .active → .paused → .completed  
- `ErrorSeverity`: .low → .medium → .high → .critical

### Date Variables
- `createdAt`: Initial creation timestamp
- `lastActiveAt`: Most recent activity
- `confirmedAt`: SMS confirmation timestamp  
- `receivedAt`: SMS response timestamp
- `scheduledTime`: When to send SMS reminder

## COMPONENT REUSABILITY PATTERNS

### Shared Components (NEW 2025-09-29)
**Rule:** Always reuse components when possible to maintain consistency

```swift
// SharedHeaderSection - Used in all main views
SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)

// FloatingPillNavigation - Unified 3-tab design
FloatingPillNavigation(selectedTab: $selectedTab, onTabTapped: nil)

// TaskRowView - Reusable task display component
TaskRowView(task: task, profile: profile, showViewButton: false, onViewButtonTapped: nil)
```

### Animation Handling
**Rule:** Disable animations for instant transitions

```swift
// Remove animations from view transitions
.animation(nil)
.transition(.identity)

// Use Transaction for navigation without animation
var transaction = Transaction()
transaction.disablesAnimations = true
withTransaction(transaction) {
    // Navigation code
}
```

### Gradient Implementation
**Pattern:** Bottom gradient for navigation visibility

```swift
LinearGradient(
    gradient: Gradient(colors: [
        Color.black.opacity(0),
        Color.black.opacity(0.15),
        Color.black.opacity(0.25)
    ]),
    startPoint: .top,
    endPoint: .bottom
)
.frame(height: 120)
.allowsHitTesting(false)
```

## FIREBASE INTEGRATION PATTERNS

### Authentication Flow
```swift
func signInWithGoogle() async throws -> AuthResult {
    // Modern iOS window management
    guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let presentingViewController = await windowScene.windows.first?.rootViewController else {
        throw AuthenticationError.unknownError("Unable to get root view controller")
    }
    
    // GIDSignIn.sharedInstance.signIn() with proper token handling
    // Firebase credential creation with GoogleAuthProvider
}
```

### Firestore Data Models
```swift
// Always include these fields
struct DatabaseModel: Codable {
    let id: String          // PRIMARY KEY
    let userId: String      // OWNER REFERENCE
    let createdAt: Date     // TIMESTAMP
    var updatedAt: Date     // LAST MODIFIED
}
```

## UI IMPLEMENTATION PATTERNS

### Consistent Button Styling
```swift
// Standard button implementation
Button(action: { /* action */ }) {
    Text("Button Text")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 47)
        .background(Color(hex: "B9E3FF"))
        .cornerRadius(23.5) // Half of height for pill shape
}
```

### Profile Color System
```swift
// Fixed colors assigned to profile slots
private let profileColors: [Color] = [
    Color.blue.opacity(0.6),
    Color.red.opacity(0.6),
    Color.green.opacity(0.6),
    Color.purple.opacity(0.6)
]

// Profile gets color based on slot, not random
let profileColor = profileColors[profileIndex % 4]
```

### Bottom Gradient Effect
```swift
.background(
    ZStack(alignment: .bottom) {
        Color(hex: "f9f9f9")
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color(hex: "B3B3B3")
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 451)
        .offset(y: 225)
    }
    .ignoresSafeArea()
)
```

## TESTING PATTERNS

### Mock Data Consistency
```swift
// Use consistent IDs across mock services
let mockUserId = "mock-user-1"
let mockProfileId = "mock-profile-1"
let mockTaskId = "mock-task-1"
```

### Canvas Preview Pattern
```swift
#Preview("View Name") {
    MyView()
        .inject(container: Container.makeForTesting())
        .environmentObject(mockViewModel)
}
```

## ERROR HANDLING PATTERNS

### Comprehensive Error Types
```swift
enum ServiceError: LocalizedError {
    case networkError(String)
    case authenticationRequired
    case insufficientPermissions
    case dataNotFound
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        // ... other cases
        }
    }
}
```

### Error Coordination
```swift
// Always use ErrorCoordinator for user-facing errors
errorCoordinator.handleError(error, context: "Loading profiles")
```

## PERFORMANCE OPTIMIZATIONS

### Image Loading
- Use `.resizable().scaledToFit()` for dynamic image sizing
- Lazy load images in lists with `LazyVStack`/`LazyVGrid`
- Cache profile images in memory when possible

### Data Fetching
- Use `@Published` properties for reactive updates
- Implement pagination for large data sets
- Cache frequently accessed data locally

## ACCESSIBILITY REQUIREMENTS

### Text Sizing
- Support Dynamic Type for all text
- Minimum touch target: 44x44 points
- High contrast mode support

### VoiceOver
- Add `.accessibilityLabel()` to all interactive elements
- Group related elements with `.accessibilityElement(children: .combine)`
- Provide hints for complex interactions

## BUILD ERROR RESOLUTION CHECKLIST

When encountering build errors:

1. **Check Task conflicts**: Replace `Task` with `_Concurrency.Task`
2. **Remove UIKit imports**: Use SwiftUI/Foundation alternatives
3. **Verify asset names**: Ensure exact case-sensitive matching
4. **Check protocol conformance**: Implement all required methods
5. **Verify Codable conformance**: All stored properties must be Codable
6. **Check type definitions**: Look for duplicates in protocol files
7. **Verify service dependencies**: Ensure Container can resolve all services

## DEPLOYMENT CHECKLIST

Before deploying:

1. ✅ Add GoogleService-Info.plist from Firebase Console
2. ✅ Configure bundle ID to match Firebase project
3. ✅ Install Firebase SDK via Swift Package Manager
4. ✅ Set up Twilio credentials in environment
5. ✅ Test on physical device for:
   - Camera/photo access
   - SMS functionality
   - Push notifications
   - Accessibility features
6. ✅ Deploy Firebase security rules
7. ✅ Configure Firebase indexes for queries
8. ✅ Set up Firebase Storage rules

## COMMON PITFALLS TO AVOID

1. **Don't use `Task` without namespace** - Always use `_Concurrency.Task`
2. **Don't import UIKit** - This is a pure SwiftUI project
3. **Don't hardcode colors** - Use the design system colors
4. **Don't skip protocol methods** - Implement all required protocol methods
5. **Don't use random profile colors** - Use slot-based color assignment
6. **Don't forget Canvas safety** - Use skipAutoLoad for ViewModels in previews
7. **Don't mix asset name cases** - Use exact case-sensitive names

## CONFIDENCE SCORING

When implementing features, rate confidence 1-10:
- 10/10: Feature complete, tested, follows all patterns
- 8-9/10: Feature works, minor polish needed
- 6-7/10: Basic functionality, needs refinement
- Below 6/10: Needs significant work, seek clarification

Always include confidence score with "YARRR!" when confident (8+/10).

---

**For project structure**: See `Hallo-iOS-App-Structure.txt`
**For UI specifications**: See `Hallo-UI-Integration-Plan.txt`