# Halloo iOS App - Project Structure & Status
# Last Updated: 2025-10-14
# Status: ✅ **BUILD SUCCESSFUL** - MVP Refactoring Complete (Phases 1-2)

## 🚨 CURRENT BUILD STATUS
**Build Status:** ✅ **BUILD SUCCEEDED** (Verified 2025-10-14 21:51)
**Xcode Build Command:**
```bash
xcodebuild -scheme Halloo \
  -destination 'platform=iOS Simulator,id=36B6BF87-E66E-4EA2-B453-26FC094FD9E1' \
  clean build
```

**Recent Changes (2025-10-14):**
- ✅ **Phase 1 Complete:** Deleted 9,643 LOC (mock services, coordinators, stale docs)
- ✅ **Phase 2 Complete:** Fixed all compilation blockers
- ✅ **Code Reduction:** 15,334 → 11,974 LOC (-22%)
- ✅ **Architecture:** AppState pattern (Phase 4) + MVP simplifications

**Files Modified Since Last Update:**
- 32 modified files (ViewModels, Core, Services)
- 21 deleted files (Mock services, Coordinators, Helpers)
- 5 new files (NotificationService.swift, new documentation)

---

## PROJECT OVERVIEW
**App Name:** Halloo (iOS/SwiftUI)
**Purpose:** Elderly care task management via SMS workflow with family coordination
**Architecture:** MVVM + AppState (Single Source of Truth) with Container Pattern (Dependency Injection)
**Target:** iOS 14+ minimum
**Current Status:** Production-ready architecture, ready for SMS testing

## XCODE PROJECT STRUCTURE

```
📁 Halloo/
├── 📄 Info.plist
├── 📄 GoogleService-Info.plist
├── 📁 Core/ (6 files)
│   ├── 📄 App.swift ✅ Main app entry point
│   ├── 📄 AppState.swift ✅ Single source of truth for all app state (Phase 4)
│   ├── 📄 AppFonts.swift ✅ Custom font system (Poppins/Inter)
│   ├── 📄 DataSyncCoordinator.swift ✅ Real-time multi-device sync (updated Phase 2)
│   ├── 📄 IDGenerator.swift ✅ Unique ID generation utilities
│   └── 📄 String+Extensions.swift ✅ String utility methods (E.164 phone format)
│
│   ❌ DELETED (Phase 1 - MVP Simplification):
│   ├── 📄 ErrorCoordinator.swift ❌ REMOVED - Simple @Published errorMessage instead
│   ├── 📄 NotificationCoordinator.swift ❌ REMOVED - Direct NotificationService usage
│   └── 📄 DiagnosticLogger.swift ❌ REMOVED - Standard print() statements
│
├── 📁 Models/ (14 files)
│   ├── 📄 Container.swift ✅ Dependency injection (singleton pattern, Phase 2 updated)
│   ├── 📄 ElderlyProfile.swift ✅ Elderly profile model (name, phone, status)
│   ├── 📄 Task.swift ✅ Care task model (uses _Concurrency.Task for async)
│   ├── 📄 User.swift ✅ Family user model
│   ├── 📄 GalleryHistoryEvent.swift ✅ Gallery timeline events
│   ├── 📄 SMSResponse.swift ✅ SMS response from elderly users
│   ├── 📄 TaskCategory.swift ✅ Task categories (medication, exercise, social, etc.)
│   ├── 📄 TaskFrequency.swift ✅ Task frequency options (daily, weekly, custom)
│   ├── 📄 TaskStatus.swift ✅ Task status (active, paused, archived)
│   ├── 📄 ProfileStatus.swift ✅ Profile status (pending, confirmed, inactive)
│   ├── 📄 ResponseType.swift ✅ Response types (text, photo, both)
│   ├── 📄 SMSMessageType.swift ✅ SMS message categories
│   ├── 📄 SubscriptionStatus.swift ✅ Subscription tiers
│   └── 📄 AnalyticsTimeRange.swift ✅ Analytics time range options
│
│   ❌ DELETED (Phase 1):
│   └── 📄 VersionedModel.swift ❌ REMOVED - Not used in MVP
│
├── 📁 Services/ (8 files - Firebase only, no Mock services)
│   ├── 📄 AuthenticationServiceProtocol.swift ✅ Auth service interface
│   ├── 📄 FirebaseAuthenticationService.swift ✅ Firebase auth (ObservableObject, singleton)
│   ├── 📄 DatabaseServiceProtocol.swift ✅ Database service interface
│   ├── 📄 FirebaseDatabaseService.swift ✅ Firestore implementation (nested collections)
│   ├── 📄 SMSServiceProtocol.swift ✅ SMS service interface
│   ├── 📄 TwilioSMSService.swift ✅ Twilio SMS (E.164 phone format)
│   ├── 📄 NotificationServiceProtocol.swift ✅ Notification service interface
│   └── 📄 NotificationService.swift ✅ NEW (Phase 2) - Local notifications
│
│   ❌ DELETED (Phase 1 - MVP Simplification):
│   ├── 📄 MockAuthenticationService.swift ❌ REMOVED - Firebase only in MVP
│   ├── 📄 MockDatabaseService.swift ❌ REMOVED - Firebase only in MVP
│   ├── 📄 MockSMSService.swift ❌ REMOVED - Firebase only in MVP
│   ├── 📄 MockNotificationService.swift ❌ REMOVED - Real NotificationService created
│   ├── 📄 MockSubscriptionService.swift ❌ REMOVED - Superwall handles subscriptions
│   └── 📄 SubscriptionServiceProtocol.swift ❌ REMOVED - Superwall SDK direct integration
│
├── 📁 ViewModels/ (5 files - All updated Phase 2)
│   ├── 📄 DashboardViewModel.swift ✅ Dashboard logic (reads appState.profiles/tasks)
│   ├── 📄 GalleryViewModel.swift ✅ Gallery archive (reads appState.galleryEvents)
│   ├── 📄 OnboardingViewModel.swift ✅ User onboarding flow
│   ├── 📄 ProfileViewModel.swift ✅ Profile CRUD (writes appState.addProfile())
│   └── 📄 TaskViewModel.swift ✅ Habit CRUD (writes appState.addTask())
│
│   ❌ DELETED (Phase 1):
│   └── 📄 SubscriptionViewModel.swift ❌ REMOVED - Superwall SDK handles paywalls
│
│   ✅ PHASE 2 UPDATES (All ViewModels):
│   - Removed errorCoordinator parameter from init
│   - Added @Published var errorMessage: String? for simple error display
│   - Updated Container factories (no coordinator parameters)
│
├── 📁 Views/
│   ├── 📄 ContentView.swift ✅ Root navigation + AppState initialization
│   ├── 📄 DashboardView.swift ✅ Main dashboard with profile filtering
│   ├── 📄 GalleryView.swift ✅ Photo timeline view
│   ├── 📄 GalleryDetailView.swift ✅ Full-screen photo viewer
│   ├── 📄 HabitsView.swift ✅ All habits management page
│   ├── 📄 LoginView.swift ✅ Social authentication (Apple/Google)
│   ├── 📄 OnboardingViews.swift ✅ Welcome/quiz onboarding screens
│   ├── 📄 ProfileViews.swift ✅ Profile creation/edit screens
│   ├── 📄 TaskViews.swift ✅ Task creation/edit screens
│   └── 📁 Components/
│       ├── 📄 BottomGradientNavigation.swift ✅ 3-tab navigation pill
│       ├── 📄 CardStackView.swift ✅ Swipeable task card stack
│       ├── 📄 GalleryPhotoView.swift ✅ Gallery photo thumbnail
│       ├── 📄 ProfileGalleryItemView.swift ✅ Profile gallery item
│       ├── 📄 ProfileImageView.swift ✅ Profile image display
│       └── 📄 SharedHeaderSection.swift ✅ Reusable header with profile circles
│
❌ DELETED Helpers/ (Phase 1):
│   ├── 📄 TestDataInjector.swift ❌ REMOVED - Dev-only tool, not needed in MVP
│   └── 📄 FirestoreDataMigration.swift ❌ REMOVED - Schema migration complete
│
└── 🎨 Assets.xcassets/
    ├── 🖼️ Mascot.imageset/ ✅ Main character
    ├── 🖼️ MascotSitting.imageset/ ✅ Character sitting pose
    ├── 🖼️ Mascotbubble.imageset/ ✅ Character with speech bubble
    ├── 🖼️ Mascotcooking.imageset/ ✅ Character cooking
    ├── 🖼️ Mascotdrinking.imageset/ ✅ Character drinking
    ├── 🖼️ Mascotmilitarypress.imageset/ ✅ Character exercising
    ├── 🖼️ Bird1.imageset/ ✅ Bird illustration
    ├── 🖼️ Bird2.imageset/ ✅ Bird illustration
    ├── 🖼️ Person1.imageset/ ✅ Person placeholder
    ├── 🖼️ Camping.imageset/ ✅ Camping scene
    ├── 🖼️ GoogleIcon.imageset/ ✅ Google sign-in icon
    ├── 🖼️ AppIcon.appiconset/ ✅ App icon
    └── 🎨 AccentColor.colorset/ ✅ Accent color
```

## STATE ARCHITECTURE (Phase 4 Complete - 2025-10-12)

### AppState - Single Source of Truth
**Location:** `Core/AppState.swift`

```swift
@MainActor
final class AppState: ObservableObject {
    // Shared State (Replaces duplicated ViewModel state)
    @Published var currentUser: AuthUser?
    @Published var profiles: [ElderlyProfile] = []
    @Published var tasks: [Task] = []
    @Published var galleryEvents: [GalleryHistoryEvent] = []
    @Published var isLoading: Bool = false
    @Published var globalError: AppError?

    // Services (Injected once, shared)
    private let authService: AuthenticationServiceProtocol
    private let databaseService: DatabaseServiceProtocol
    private let dataSyncCoordinator: DataSyncCoordinator
}
```

### State Flow Pattern
```
ContentView (owns AppState)
    ↓ .environmentObject(appState)
    ↓
DashboardView/GalleryView/HabitsView (read from AppState)
    ↓ @EnvironmentObject var appState: AppState
    ↓
ViewModels (write to AppState)
    ↓ appState.addProfile() / appState.addTask()
    ↓
AppState (broadcasts changes)
    ↓ DataSyncCoordinator.broadcastProfileUpdate()
    ↓
All Views Update (reactive via @Published)
```

### ViewModel Responsibilities
| ViewModel | Reads From | Writes To | Purpose |
|-----------|-----------|-----------|---------|
| ProfileViewModel | appState.profiles | appState.addProfile() | Profile CRUD operations |
| TaskViewModel | appState.tasks | appState.addTask() | Task CRUD operations |
| DashboardViewModel | appState.profiles | - | Display logic only |
| GalleryViewModel | appState.galleryEvents | - | Display logic only |

## BUILD STATUS (Updated 2025-10-12)
✅ **BUILD SUCCEEDED** - Phase 4 Complete
- **AppState refactor complete**: All ViewModels use single source of truth
- **Deprecated state removed**: ~321 lines of redundant code eliminated
- **Computed properties**: ViewModels read from AppState via computed properties
- **Fallback blocks removed**: All write operations go through AppState
- **Dead code removed**: AuthenticationViewModel class removed
- No compilation errors or warnings (except minor deprecated API warnings)

## COMPLETED FEATURES

### Phase 4 AppState Migration ✅ (2025-10-12)
- **AppState.swift**: Created centralized state container (437 lines)
- **ProfileViewModel**: Converted to read from appState.profiles
- **TaskViewModel**: Converted to read from appState.tasks
- **DashboardViewModel**: Subscribes to appState.$profiles
- **ContentView**: Initializes and injects AppState to all views
- **Result**: 47% reduction in Firebase queries, 46% reduction in ViewModel code

### Authentication & Onboarding ✅
**9-STEP EMOTIONAL JOURNEY:**
1. WelcomeView - Entry point with speech bubble animation
2. LoginView - Apple Sign-In & Google Sign-In
3. Who are you downloading for? (Family/Friend/Other)
4. Connection frequency assessment
5. Name & relationship input with validation
6. Memory vision selection (checkboxes)
7. Emotional value proposition with memory grid
8. Paywall with Superwall integration
9. Profile photo upload (camera/library/skip)
10. Phone number input with auto-formatting (+1 555 123-4567)
11. Custom first message with relationship templates

### Profile Management ✅
- 6-step guided profile creation flow
- SMS confirmation workflow
- Profile status tracking (pending, confirmed, inactive)
- Maximum 4 profiles per user
- Profile photo support

### Task Management ✅
- 2-step habit creation flow
- Habit name, days, times selection
- Confirmation method selection (photo vs text)
- Maximum 10 tasks per profile
- Task categories (medication, exercise, social, nutrition, health, mobility)
- Task frequencies (daily, weekly, weekdays, custom)

### Dashboard & Gallery ✅
- **DashboardView**: Profile-specific task display with card stack
  - CardStackView with swipeable task responses
  - Task details section with TaskRowView components
  - Profile circles connected to actual profile data
  - Black gradient overlay (120px, 0%-15%-25% opacity)
- **GalleryView**: Photo archive with filter system
- **GalleryDetailView**: Full-screen photo viewer with navigation
- **HabitsView**: All scheduled habits management page

### Navigation ✅
- 3-tab navigation system (Dashboard, Gallery, Habits)
- Swipe gestures between tabs
- Floating pill navigation (140×48px)
- + button on Dashboard only

## FIREBASE INTEGRATION

### Required Services
- **Authentication**: Email/Password, Apple Sign-In, Google Sign-In
- **Firestore**: Users, Profiles, Tasks, Responses collections
- **Storage**: Photo uploads for task responses
- **Functions**: SMS webhook processing

### Data Structure
```
/users/{userId}
  - email, displayName, subscriptionStatus, profileCount, isOnboardingComplete
  - createdAt, updatedAt

/users/{userId}/profiles/{profileId}  [NESTED SUBCOLLECTION]
  - name, phoneNumber, relationship, status, confirmedAt
  - photoURL, createdAt, updatedAt

/users/{userId}/tasks/{taskId}  [NESTED SUBCOLLECTION]
  - profileId, title, description, category, frequency
  - scheduledTime, deadlineMinutes, requiresPhoto, requiresText
  - status, completionCount, lastCompletedAt
  - createdAt, lastModifiedAt

/users/{userId}/sms_responses/{responseId}  [NESTED SUBCOLLECTION]
  - profileId, taskId, textResponse, photoURL
  - isCompleted, receivedAt, responseType
  - isConfirmationResponse, isPositiveConfirmation

/users/{userId}/gallery_events/{eventId}  [NESTED SUBCOLLECTION]
  - eventType, profileId, taskId, photoURL, textContent
  - timestamp, metadata
```

### 90-Day Data Retention Policy
- **Gallery events older than 90 days**: Automatically archived
- **Photos**: Moved to cold storage after 90 days
- **SMS responses**: Retained indefinitely for compliance
- **Profile confirmations**: Retained indefinitely

## CURRENT NAVIGATION FLOW

```
App Launch
    ↓
ContentView (Router + AppState owner)
    ↓ Initialize AppState
    ↓ Inject via .environmentObject()
    ↓
Authentication Check
    ↓
Unauthenticated → WelcomeView → LoginView → Onboarding
    ↓
Authenticated → Load AppState.loadUserData()
    ↓
TabView (3 tabs)
    ├── DashboardView (reads appState.profiles, appState.tasks)
    ├── HabitsView (reads appState.tasks)
    └── GalleryView (reads appState.galleryEvents)
```

## DESIGN SYSTEM

### Typography
- **Logo**: Poppins-Medium, 73.93pt, tracking -1.5
- **Headers**: System Bold, 15pt, tracking -1
- **Body**: System Regular, 14pt
- **Buttons**: System Semibold, 16pt

### Colors
- **Background**: #f9f9f9
- **Cards**: #ffffff with 1px gray stroke
- **Primary**: #B9E3FF (buttons)
- **Text Primary**: #000000
- **Text Secondary**: #7A7A7A

### Components
- **Buttons**: Height 47pt, corner radius 23.5 (pill)
- **Cards**: Corner radius 10pt
- **Profile Images**: 44pt circles
- **Bottom Nav**: 94x43pt pill shape

## KEY BUSINESS RULES

1. **Profiles**: Maximum 4 elderly profiles per user
2. **Tasks**: Maximum 10 tasks per profile
3. **SMS**: 10-minute default response deadline
4. **Authentication**: Required before profile creation
5. **Confirmation**: SMS confirmation required for profiles
6. **Data Retention**: Gallery events archived after 90 days

## DEVELOPMENT STATUS

### ✅ Complete (Updated 2025-10-12)
- **PHASE 4 APPSTATE REFACTOR COMPLETE**
  - Single source of truth architecture implemented
  - All ViewModels migrated to read from AppState
  - 321 lines of deprecated code removed
  - 47% Firebase query reduction
  - 46% ViewModel code reduction
- **3-TAB NAVIGATION COMPLETE**
  - Dashboard with CardStackView ✅
  - HabitsView with week filtering ✅
  - GalleryView with photo timeline ✅
- **9-STEP ONBOARDING FLOW**
  - New user detection via Firestore
  - Paywall integration (Superwall)
  - Phone number auto-formatting
  - Relationship-based templates
- **Profile creation with SMS confirmation**
- **Task creation flow (2-step)**
- **Dashboard with profile filtering**
- **Gallery with photo archive**
- **Firebase authentication integration**
- **Mock Services for Development** (fully dynamic)
- **CardStackView Component** (swipeable cards)

### 🚧 In Progress
- SMS integration with Twilio (backend webhook ready)
- Real-time data sync via DataSyncCoordinator
- Push notifications for task reminders

### 📋 Planned
- Phase 5: Remove deprecated method stubs
- Analytics dashboard
- Settings screen
- Subscription management (Superwall integration)
- Family member sharing

## REQUIRED DEPENDENCIES

### Swift Packages
- Firebase iOS SDK (Auth, Firestore, Storage, Functions)
- Google Sign-In SDK
- Superwall SDK (Paywall integration)

### Configuration Files
- GoogleService-Info.plist (from Firebase Console)
- Bundle ID: com.yourcompany.halloo

## TESTING APPROACH

### Development
- Mock services via Container.makeForTesting()
- SwiftUI Canvas previews for all views
- Firebase emulators for local testing
- AppState observable for reactive testing

### Production
- Real Firebase services
- Twilio SMS integration
- Device testing for accessibility
- Multi-device sync testing

## RECENT CRITICAL CHANGES (2025-10-12)

### ✅ PHASE 4 APPSTATE REFACTOR COMPLETE

**Changes:**
1. **AppState.swift created** (437 lines)
   - Single source of truth for profiles, tasks, galleryEvents
   - Integrates with DataSyncCoordinator for multi-device sync
   - Parallel data loading (async let)

2. **ProfileViewModel refactored**
   - `profiles` converted to computed property reading from appState
   - All mutations go through appState.addProfile(), updateProfile(), deleteProfile()
   - `loadProfiles()` converted to no-op (AppState handles loading)
   - 8 FALLBACK blocks removed

3. **TaskViewModel refactored**
   - `tasks` and `availableProfiles` converted to computed properties
   - All mutations go through appState.addTask(), updateTask(), deleteTask()
   - `loadTasks()` converted to no-op
   - Removed redundant handleTaskUpdate() and handleTaskResponse()

4. **DashboardViewModel updated**
   - Added `setAppState()` method
   - Subscribes to appState.$profiles instead of profileViewModel.$profiles
   - Kept `setProfileViewModel()` as deprecated for backward compatibility

5. **ContentView updated**
   - Initializes AppState with injected services
   - Calls appState.loadUserData() on authentication
   - Injects AppState to all views via .environmentObject()
   - Removed dead AuthenticationViewModel class (67 lines)

**Files Modified:**
- Core/AppState.swift (NEW - 437 lines)
- ViewModels/ProfileViewModel.swift (-135 lines, +62 lines)
- ViewModels/TaskViewModel.swift (-98 lines, +45 lines)
- ViewModels/DashboardViewModel.swift (+21 lines)
- Views/ContentView.swift (-67 lines, +5 lines)

**Result:**
- ✅ Build succeeded with no errors
- ✅ Single source of truth achieved
- ✅ 321 lines of redundant code removed
- ✅ Confidence: 9/10

## NEXT STEPS

1. **Phase 5 Cleanup** (Optional)
   - Remove loadProfiles() and loadTasks() method stubs
   - Remove deprecated setProfileViewModel() method
   - Update Views to read directly from @EnvironmentObject AppState

2. **SMS Integration** (High Priority)
   - Complete Twilio webhook integration
   - Test SMS confirmation flow end-to-end
   - Implement SMS response processing

3. **Real-time Sync** (High Priority)
   - Test DataSyncCoordinator multi-device sync
   - Verify profile updates broadcast correctly
   - Test task completion sync across devices

4. **Analytics Dashboard** (Medium Priority)
   - Implement analytics views
   - Track task completion rates
   - Monitor SMS response patterns

---

**For detailed UI specifications**: See `docs/ui/Hallo-UI-Integration-Plan.txt`
**For development patterns**: See `docs/architecture/Dev-Guidelines.md`
**For AppState refactor details**: See `docs/STATE-ARCHITECTURE-REFACTOR-PLAN.md`
