---
name: iOS Architecture Guardian
description: Enforce MVVM + AppState architecture patterns for the Halloo iOS app. Use when creating ViewModels, Views, Services, or modifying AppState. Apply when reviewing code that involves state management, Firebase operations, or UI-ViewModel interactions.
version: 1.0.0
---

# iOS Architecture Guardian for Halloo

This skill enforces the MVVM + AppState architecture pattern used in the Halloo elderly care iOS app.

## Core Architecture Rules

### AppState - Single Source of Truth

**Location:** `Core/AppState.swift`

AppState is the ONLY place where shared app state lives:

```swift
@MainActor
final class AppState: ObservableObject {
    // ✅ Correct - State lives here
    @Published var currentUser: AuthUser?
    @Published var profiles: [ElderlyProfile] = []
    @Published var tasks: [Task] = []
    @Published var galleryEvents: [GalleryHistoryEvent] = []
    @Published var isLoading: Bool = false
    @Published var globalError: AppError?
}
```

**AppState Must:**
- Be marked `@MainActor` and conform to `ObservableObject`
- Own ALL shared state (profiles, tasks, gallery events, user)
- Provide mutation methods: `addProfile()`, `updateTask()`, `deleteProfile()`, etc.
- Handle ALL Firebase operations
- Be created ONCE in `ContentView` and injected via `.environmentObject()`
- Use `DataSyncCoordinator` for real-time multi-device sync

**AppState Must NOT:**
- Be created in ViewModels
- Be duplicated across multiple instances
- Expose services publicly (keep them private)

---

## ViewModel Architecture

### ViewModel Requirements

**All ViewModels MUST:**

1. **Be marked with `@MainActor`**
```swift
@MainActor
final class ProfileViewModel: ObservableObject {
```

2. **Use computed properties when reading from AppState**
```swift
// ✅ Correct - Read from AppState
var profiles: [ElderlyProfile] {
    appState.profiles
}

// ❌ Wrong - Duplicating state
@Published var profiles: [ElderlyProfile] = []
```

3. **Write mutations through AppState methods**
```swift
// ✅ Correct
func addProfile(_ profile: ElderlyProfile) {
    appState.addProfile(profile)
}

// ❌ Wrong - Direct Firebase access
func addProfile(_ profile: ElderlyProfile) {
    databaseService.saveProfile(profile)
}
```

4. **Have `@Published var errorMessage: String?` for error handling**
```swift
@Published var errorMessage: String?

func handleError(_ error: Error) {
    errorMessage = error.localizedDescription
}
```

5. **Use dependency injection via Container**
```swift
init(container: Container = .shared) {
    self.appState = container.appState
    self.authService = container.authService
}
```

### ViewModel Responsibilities

| ViewModel Type | Reads From | Writes To | Purpose |
|---------------|-----------|-----------|---------|
| **ProfileViewModel** | `appState.profiles` | `appState.addProfile()` | Profile CRUD operations |
| **TaskViewModel** | `appState.tasks` | `appState.addTask()` | Task CRUD operations |
| **DashboardViewModel** | `appState.profiles`, `appState.tasks` | - | Display logic only (filtering, sorting) |
| **GalleryViewModel** | `appState.galleryEvents` | - | Display logic only |
| **OnboardingViewModel** | - | `appState.currentUser` | Onboarding flow coordination |

### Anti-patterns to Flag Immediately

**❌ WRONG - Duplicating State:**
```swift
@Published var profiles: [ElderlyProfile] = []

func loadProfiles() async {
    profiles = await databaseService.fetchProfiles()
}
```

**✅ CORRECT - Read from AppState:**
```swift
var profiles: [ElderlyProfile] {
    appState.profiles
}
// No loadProfiles() needed - AppState handles loading
```

**❌ WRONG - Direct Firebase Access:**
```swift
func deleteTask(_ taskId: String) {
    Task {
        try await databaseService.deleteTask(taskId)
    }
}
```

**✅ CORRECT - Delegate to AppState:**
```swift
func deleteTask(_ taskId: String) {
    appState.deleteTask(taskId)
}
```

---

## View Architecture

### View Requirements

**All Views MUST:**

1. **Inject AppState via `@EnvironmentObject`**
```swift
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: DashboardViewModel
```

2. **Never perform business logic or Firebase calls**
```swift
// ❌ Wrong - Business logic in View
Button("Delete") {
    Task {
        try await databaseService.deleteProfile(profile.id)
    }
}

// ✅ Correct - Delegate to ViewModel
Button("Delete") {
    viewModel.deleteProfile(profile.id)
}
```

3. **Use ViewModels for complex interactions**
```swift
// ✅ Simple display - No ViewModel needed
Text(appState.currentUser?.displayName ?? "Unknown")

// ✅ Complex interaction - Use ViewModel
@StateObject private var taskViewModel = TaskViewModel()
```

4. **Keep presentation logic only**
- UI layout and styling
- Navigation state
- Animation triggers
- User input handling (delegate to ViewModel for processing)

### View Anti-patterns

**❌ WRONG - Creating AppState in View:**
```swift
struct DashboardView: View {
    @StateObject private var appState = AppState()  // NO!
}
```

**✅ CORRECT - Inject from parent:**
```swift
struct ContentView: View {
    @StateObject private var appState: AppState

    init() {
        let container = Container.shared
        _appState = StateObject(wrappedValue: container.appState)
    }

    var body: some View {
        DashboardView()
            .environmentObject(appState)
    }
}
```

---

## SwiftUI & Swift Concurrency Patterns

### Critical Pattern 1: Task Naming (Prevents Build Errors)

**Issue:** Swift naming conflict between app's `Task` model and `Swift.Concurrency.Task`

```swift
// ❌ WRONG - causes naming conflict with app Task model
Task { @MainActor in
    await someOperation()
}

// ✅ CORRECT - explicit Concurrency namespace
_Concurrency.Task { @MainActor in
    await someOperation()
}
```

**Always use `_Concurrency.Task` for async operations** to avoid naming conflicts.

### Critical Pattern 2: ForEach ID Selection (Prevents State Bugs)

**Issue:** Using unstable IDs breaks SwiftUI state tracking

```swift
// ❌ WRONG - using index as ID breaks state tracking
ForEach(Array(profiles.enumerated()), id: \.offset) { index, profile in
    ProfileView(profile: profile)
}

// ✅ CORRECT - using unique stable ID
ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
    ProfileView(profile: profile)
}
```

**Always use the element's unique ID** (`.element.id`), never indices or offsets.

### Critical Pattern 3: User Document Creation (Prevents Firebase Errors)

**Issue:** Creating profiles before user document exists causes silent failures

```swift
// ✅ CORRECT - Always create user document on sign-in BEFORE related entities
func signInWithGoogle() async throws -> AuthResult {
    let result = try await auth.signIn(with: credential)
    let isNewUser = result.additionalUserInfo?.isNewUser ?? false

    if isNewUser {
        // Create user document IMMEDIATELY
        let userData = [
            "id": user.id,
            "email": user.email,
            "profileCount": 0  // Critical for validation
        ]
        try await db.collection("users").document(user.id).setData(userData)
    }
    return result
}
```

**Ensure user document exists before creating profiles or tasks.**

### Critical Pattern 4: No UIKit Imports (Architecture Rule)

**Rule:** This is a SwiftUI-only project - UIKit is not allowed

```swift
// ❌ WRONG - UIKit import
import UIKit
UIApplication.shared...
UIDevice.current...

// ✅ CORRECT - SwiftUI/Foundation only
import SwiftUI
import Foundation
// Use SwiftUI's native components
```

**Never import UIKit.** Use SwiftUI and Foundation alternatives.

### Critical Pattern 5: Async/Await Before Dismiss (Prevents Race Conditions)

**Issue:** Dismissing views before async operations complete loses data

```swift
// ❌ WRONG - dismisses before save completes
_Concurrency.Task {
    viewModel.createProfile()  // Not awaited!
    try? await Task.sleep(nanoseconds: 500_000_000)
    onDismiss()  // View closes before Firebase save finishes
}

// ✅ CORRECT - await completion before dismiss
_Concurrency.Task {
    await viewModel.createProfileAsync()  // Wait for completion
    onDismiss()  // Only dismiss after save succeeds
}
```

**Always await async operations** before dismissing views or navigating away.

---

## Service Architecture

### Service Requirements

**All Services MUST:**

1. **Have a protocol definition**
```swift
protocol DatabaseServiceProtocol {
    func fetchProfiles(userId: String) async throws -> [ElderlyProfile]
    func saveProfile(_ profile: ElderlyProfile, userId: String) async throws
}
```

2. **Be registered in Container**
```swift
final class Container {
    static let shared = Container()

    lazy var databaseService: DatabaseServiceProtocol = {
        FirebaseDatabaseService()
    }()
}
```

3. **Use nested Firestore collections**
```swift
// ✅ Correct - Nested under user
db.collection("users/\(userId)/profiles")

// ❌ Wrong - Top-level collection
db.collection("profiles")
```

4. **Handle errors properly**
```swift
do {
    try await db.collection("users/\(userId)/tasks")
        .document(taskId)
        .setData(taskData)
} catch {
    print("❌ Firebase Error: \(error.localizedDescription)")
    throw DatabaseError.writeFailed(error)
}
```

### Service Anti-patterns

**❌ NO Mock Services in MVP**
The Halloo app uses Firebase only. Mock services were removed in Phase 1 refactor.

**❌ NO Public Service Exposure**
Services should be private in AppState, accessed only through AppState methods.

---

## Data Flow Pattern

```
User Action (View)
    ↓
ViewModel Method Call
    ↓
AppState Mutation Method
    ↓
Firebase Service (via AppState)
    ↓
AppState @Published Property Updates
    ↓
All Views Auto-Update (via @EnvironmentObject)
```

### Example: Adding a Task

```swift
// 1. User taps button in TaskViews.swift
Button("Save Task") {
    viewModel.addTask(newTask)
}

// 2. ViewModel delegates to AppState
func addTask(_ task: Task) {
    appState.addTask(task)
}

// 3. AppState handles Firebase + updates state
func addTask(_ task: Task) {
    Task {
        do {
            try await databaseService.saveTask(task, userId: currentUser!.uid)
            await MainActor.run {
                tasks.append(task)  // ✅ @Published triggers updates
            }
        } catch {
            globalError = AppError.from(error)
        }
    }
}

// 4. All views reading appState.tasks auto-update
```

---

## Business Rules

### Hard Limits
- **Maximum 4 profiles** per user
- **Maximum 10 tasks** per profile
- **90-day data retention** for gallery events

### Validation Rules
```swift
// ✅ Always validate before mutations
func addProfile(_ profile: ElderlyProfile) {
    guard profiles.count < 4 else {
        errorMessage = "Maximum 4 profiles allowed"
        return
    }
    appState.addProfile(profile)
}
```

---

## Testing Patterns

### ViewModel Testing
```swift
@MainActor
final class TaskViewModelTests: XCTestCase {
    var sut: TaskViewModel!
    var mockContainer: Container!

    override func setUp() async throws {
        mockContainer = Container.makeForTesting()
        sut = TaskViewModel(container: mockContainer)
    }

    func testAddTask_UpdatesAppState() async {
        // Given
        let task = Task(...)

        // When
        sut.addTask(task)

        // Then
        XCTAssertTrue(sut.appState.tasks.contains(where: { $0.id == task.id }))
    }
}
```

---

## Code Review Checklist

When reviewing code, verify:

- [ ] ViewModels use `@MainActor` and `ObservableObject`
- [ ] State is read from AppState via computed properties
- [ ] Mutations go through AppState methods
- [ ] Views inject AppState via `@EnvironmentObject`
- [ ] No duplicate state across ViewModels
- [ ] No direct Firebase calls from ViewModels or Views
- [ ] Services use protocol-based abstraction
- [ ] Error handling uses `@Published var errorMessage`
- [ ] Business rules (max 4 profiles, max 10 tasks) are enforced
- [ ] Firebase collections are nested under users

---

## Common Refactoring Patterns

### Converting ViewModel to Use AppState

**Before:**
```swift
@Published var profiles: [ElderlyProfile] = []

func loadProfiles() async {
    do {
        profiles = try await databaseService.fetchProfiles(userId: userId)
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**After:**
```swift
var profiles: [ElderlyProfile] {
    appState.profiles
}
// No loadProfiles() needed - AppState.loadUserData() handles it
```

### Moving Firebase Logic to AppState

**Before (in ViewModel):**
```swift
func deleteTask(_ taskId: String) {
    Task {
        try await databaseService.deleteTask(taskId, userId: userId)
        tasks.removeAll { $0.id == taskId }
    }
}
```

**After (in AppState):**
```swift
func deleteTask(_ taskId: String) {
    Task {
        do {
            try await databaseService.deleteTask(taskId, userId: currentUser!.uid)
            await MainActor.run {
                tasks.removeAll { $0.id == taskId }
            }
        } catch {
            globalError = AppError.from(error)
        }
    }
}
```

---

## When to Apply This Skill

This skill should be invoked when:
- Creating new ViewModels or Views
- Modifying AppState
- Adding Firebase operations
- Reviewing state management code
- Refactoring existing code to follow architecture
- Writing unit tests for ViewModels
- Debugging state synchronization issues
- Onboarding new team members to codebase patterns
