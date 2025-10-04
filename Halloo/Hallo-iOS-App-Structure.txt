# Hallo iOS App - Project Structure & Status
# Last Updated: 2025-10-03
# Status: PROFILE CREATION BUG FIX - User Document + ForEach ID Issues Resolved

## PROJECT OVERVIEW
**App Name:** Hallo (iOS/SwiftUI)
**Purpose:** Elderly care task management via SMS workflow
**Architecture:** MVVM with Container Pattern (Dependency Injection)
**Target:** iOS 14+ minimum
**Current Status:** Onboarding flow complete with unified Remi branding

## XCODE PROJECT STRUCTURE

```
📁 Halloo/	
├── 📄 HalloApp.swift (App.swift renamed)
├── 📁 Core/
│   ├── 📄 App.swift ✅ COMPLETE
│   ├── 📄 AppFonts.swift ✅ COMPLETE - Poppins/Inter font system
│   ├── 📄 Container.swift ✅ IMPLEMENTED
│   ├── 📄 DataSyncCoordinator.swift ✅
│   ├── 📄 ErrorCoordinator.swift ✅
│   ├── 📄 NotificationCoordinator.swift ✅
│   └── 📄 String+Extensions.swift ✅
├── 📁 Models/
│   ├── 📄 AnalyticsTimeRange.swift ✅ NEW (2025-10-01) - 7 time range cases for analytics
│   ├── 📄 Container.swift ✅
│   ├── 📄 ElderlyProfile.swift ✅
│   ├── 📄 Task.swift ✅ RESOLVED - Uses _Concurrency.Task throughout to avoid naming conflicts
│   ├── 📄 User.swift ✅
│   ├── 📄 TaskCategory.swift ✅
│   ├── 📄 TaskFrequency.swift ✅
│   ├── 📄 TaskStatus.swift ✅
│   ├── 📄 ProfileStatus.swift ✅
│   ├── 📄 ResponseType.swift ✅
│   ├── 📄 SMSMessageType.swift ✅
│   ├── 📄 SMSResponse.swift ✅
│   ├── 📄 GalleryHistoryEvent.swift ✅
│   ├── 📄 SubscriptionStatus.swift ✅
│   └── 📄 VersionedModel.swift ✅
├── 📁 Services/
│   ├── 📄 FirebaseAuthenticationService.swift ✅ COMPLETE
│   ├── 📄 FirebaseDatabaseService.swift ✅ COMPLETE
│   ├── 📄 MockAnalyticsService.swift ✅ REFACTORED (2025-10-01) - Fully dynamic, no hardcoded data
│   ├── 📄 MockAuthenticationService.swift ✅ REFACTORED (2025-10-01) - Uses _Concurrency.Task
│   ├── 📄 MockDatabaseService.swift ✅ REFACTORED (2025-10-01) - 300+ lines of hardcoded data removed
│   ├── 📄 MockNotificationService.swift ✅ FIXED (2025-10-01) - Protocol conformance complete
│   ├── 📄 MockSMSService.swift ✅ REFACTORED (2025-10-01) - Fully dynamic
│   └── Protocol files...
├── 📁 ViewModels/
│   ├── 📄 DashboardViewModel.swift ✅
│   ├── 📄 OnboardingViewModel.swift ✅
│   ├── 📄 ProfileViewModel.swift ✅
│   └── 📄 TaskViewModel.swift ✅
├── 📁 Views/
│   ├── 📄 ContentView.swift ✅ COMPLETE
│   ├── 📄 DashboardView.swift ✅ COMPLETE
│   ├── 📄 GalleryView.swift ✅ COMPLETE
│   ├── 📄 GalleryDetailView.swift ✅ COMPLETE
│   ├── 📄 ProfileViews.swift ✅ COMPLETE - 6-step onboarding
│   ├── 📄 TaskViews.swift ✅ COMPLETE - 2-step habit creation
│   ├── 📄 LoginView.swift ✅ COMPLETE - Social authentication
│   ├── 📄 OnboardingViews.swift ✅ COMPLETE - Welcome/Quiz screens
│   └── 📁 Components/
│       ├── 📄 CardStackView.swift ✅ COMPLETE - Swipeable card stack with task details
│       ├── 📄 SharedHeaderSection.swift ✅ NEW - Reusable header component
│       ├── 📄 FloatingPillNavigation.swift ✅ UNIFIED - 3-tab navigation (140×48px)
│       ├── 📄 TaskRowView.swift ✅ - Reusable task row component
│       └── 📄 GalleryPhotoView.swift ✅ - Gallery photo thumbnail component
├── 🎨 Assets.xcassets/
│   ├── 🖼️ Character.imageset/Mascot.png ✅
│   ├── 🖼️ MascotSitting.imageset/ ✅
│   ├── 🖼️ Bird1.imageset/Bird.png ✅
│   ├── 🖼️ Bird2.imageset/Bird.png ✅
│   └── 🖼️ GoogleIcon.imageset/ ✅
├── 📁 Fonts/
│   ├── Poppins-Medium.ttf ✅
│   └── Inter-VariableFont.ttf ✅
└── 📁 Firebase Configuration/
    └── 📄 GoogleService-Info.plist ⚠️ REQUIRED
```

## BUILD STATUS (Updated 2025-10-01)
✅ **BUILD SUCCEEDED** - All previous compilation errors resolved
- Task naming conflicts fixed (using _Concurrency.Task throughout)
- AnalyticsTimeRange model created and integrated
- MockNotificationService protocol conformance complete
- All mock services refactored to be fully dynamic (no hardcoded values)
- Only minor warnings remain (deprecated APIs, unused variables)

## COMPLETED VIEWS & FEATURES

### Authentication & Onboarding ✅ FULLY REBUILT (2025-10-01)
**NEW 9-STEP EMOTIONAL JOURNEY ONBOARDING:**
1. **WelcomeView** - Entry point with speech bubble animation
2. **LoginView** - Apple Sign-In & Google Sign-In (detects new vs returning users)
3. **Step 1** - Who are you downloading Remi for? (Family/Friend/Other)
4. **Step 2** - Connection frequency assessment
5. **Step 3** - Name & relationship input with validation
6. **Step 4** - Memory vision selection (checkboxes for moment types)
7. **Step 5** - Emotional value proposition with memory grid
8. **Step 6** - Paywall with Superwall integration (API: pk_1FZVcGgpr1JMD5XJ4d0Cb)
9. **Step 7** - Profile photo upload (camera/library/skip)
10. **Step 8** - Phone number input with auto-formatting (+1 555 123-4567)
11. **Step 9** - Custom first message with relationship-based templates

### Profile Management ✅
1. **ProfileOnboardingFlow** - 6-step guided profile creation
2. **Step 1** - Profile form (name, relationship, phone)
3. **Step 2** - Profile complete summary
4. **Step 3** - SMS test introduction
5. **Step 4** - SMS confirmation wait
6. **Step 5** - Success state
7. **Step 6** - First habit creation

### Task Management ✅
1. **TaskCreationView** - 2-step habit creation flow
2. **HabitFormView** - Name, days, times selection
3. **ConfirmationMethodView** - Photo vs text selection

### Dashboard & Gallery ✅
1. **DashboardView** - Profile-specific task display with card stack
   - CardStackView integration with swipeable task responses
   - Task details section below card stack (uses TaskRowView)
   - Profile circles connected to actual profile data
   - Black gradient overlay (120px, 0%-15%-25% opacity)
2. **GalleryView** - Photo archive with filter system
3. **GalleryDetailView** - Full-screen photo with navigation
4. **HabitsView** - All scheduled habits management page

## FIREBASE INTEGRATION

### Required Services
- **Authentication** - Email/Password, Apple Sign-In, Google Sign-In
- **Firestore** - Users, Profiles, Tasks, Responses collections
- **Storage** - Photo uploads for responses

### Data Structure
```
/users/{userId}
  - email, displayName, subscriptionStatus, profileCount...

/profiles/{profileId}
  - userId, name, phoneNumber, status, relationship...

/tasks/{taskId}
  - userId, profileId, title, frequency, responseType...

/responses/{responseId}
  - userId, taskId, textResponse, photoURL, isCompleted...

/gallery_events/{eventId}
  - userId, eventType, eventData, timestamp...
```

## CURRENT NAVIGATION FLOW

```
App Launch
    ↓
ContentView (Router)
    ↓
Unauthenticated → WelcomeView → LoginView → Quiz → Profile
    ↓
Authenticated → TabView (3 tabs visible)
    ├── DashboardView (Home) - with + button
    ├── HabitsView (Habits) - no + button
    └── GalleryView (Gallery) - no + button
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

## DEVELOPMENT STATUS

### ✅ Complete (Updated 2025-10-01)
- **ONBOARDING FLOW COMPLETELY REBUILT** - 9-step emotional journey
  - New user detection via Firestore (`isOnboardingComplete` flag)
  - Paywall integration with Superwall SDK (API: pk_1FZVcGgpr1JMD5XJ4d0Cb)
  - Phone number auto-formatting (+1 555 123-4567)
  - Relationship-based message templates
  - Profile photo upload with camera/library support
- **LOGIN FLOW FIXED** - Detects new vs returning users automatically
  - New users → Start 9-step onboarding
  - Returning users → Go straight to Dashboard
  - Incomplete onboarding → Resume at correct step
- **3-TAB NAVIGATION COMPLETE**:
  - Dashboard (home) with CardStackView ✅
  - HabitsView (habits management with week filtering) ✅
  - GalleryView (photo timeline) ✅
- Profile creation with SMS confirmation
- Task creation flow (2-step: habit form + confirmation method)
- Dashboard with profile filtering
- Gallery with photo archive
- Firebase authentication integration
- **Mock Services for Development** (Fully Refactored 2025-10-01):
  - ALL mock services now fully dynamic (no hardcoded data)
  - MockDatabaseService: 300+ lines of hardcoded test data removed
  - MockNotificationService: Complete protocol conformance
  - MockAuthenticationService, MockSMSService, MockAnalyticsService: All use _Concurrency.Task
  - Services generate data dynamically at runtime for realistic testing
- **CardStackView Component** - Swipeable card stack with:
  - Smooth horizontal drag with subtle rotation arc (0.02 multiplier)
  - Fast swipe-away animation (0.15s duration)
  - Linear card rearrangement animation (0.3s duration)
  - Proper card stacking with fan effect and z-index layering
  - SMS bubble layout for task responses
  - Empty state with paper airplane design
- **Task Naming Resolution** (2025-10-01):
  - All Task type conflicts resolved by using _Concurrency.Task for async operations
  - Applied consistently across 15+ files (ViewModels, Services, Core)
- **Analytics Infrastructure** (2025-10-01):
  - AnalyticsTimeRange model with 7 time range cases (today, thisWeek, thisMonth, last7Days, last30Days, thisYear, allTime)
  - Complete date range calculations and UI display properties

### 🚧 In Progress
- SMS integration with Twilio
- Real-time data sync
- Push notifications

### 📋 Planned
- Analytics dashboard
- Settings screen
- Subscription management
- Family member sharing

## REQUIRED DEPENDENCIES

### Swift Packages
- Firebase iOS SDK (Auth, Firestore, Storage)
- Google Sign-In SDK

### Configuration Files
- GoogleService-Info.plist (from Firebase Console)
- Bundle ID: com.yourcompany.hallo

## TESTING APPROACH

### Development
- Mock services via Container.makeForTesting()
- SwiftUI Canvas previews for all views
- Firebase emulators for local testing

### Production
- Real Firebase services
- Twilio SMS integration
- Device testing for accessibility

## RECENT CRITICAL FIXES (2025-10-03)

### 🔴 PROFILE CREATION BUG - ROOT CAUSE & RESOLUTION

**Problem**: Profiles were not being created or displayed after Google/Apple Sign-In
**Confidence**: 9/10

#### Root Causes Identified:

1. **Missing User Document in Firestore**
   - When user signed in with Google/Apple, NO user document was created in Firestore
   - `createElderlyProfile()` calls `updateUserProfileCount()` which tries to update user document
   - If user document doesn't exist, `updateData()` throws error
   - Profile creation failed silently with error caught but not displayed

2. **SwiftUI ForEach ID Bug in SharedHeaderSection**
   - `ForEach` was using `.offset` (index) as ID instead of `.element.id` (profile ID)
   - SwiftUI couldn't track which profile was which when array changed
   - New profiles inserted at index 0 didn't trigger UI update

3. **ProfileViewModel Loading Before Authentication**
   - ProfileViewModel calls `loadProfiles()` on init
   - But user not authenticated yet, so `loadProfilesAsync()` fails
   - Profiles array stays empty even after successful login

#### Files Changed:

**FirebaseAuthenticationService.swift**
- Added `import FirebaseFirestore`
- Lines 173-206: Restored user document creation for Google Sign-In (new users only)
- Lines 120-153: Added user document creation for Apple Sign-In (new users only)
- Creates user with: id, email, fullName, createdAt, subscriptionStatus, profileCount: 0

**SharedHeaderSection.swift**
- Line 45: Changed ForEach ID from `.offset` to `.element.id`
- Lines 30-33: Added debug overlay showing profile count (temporary)

**ContentView.swift**
- Line 120: Added `profileViewModel?.loadProfiles()` after app launch auth check
- Line 47: Added `profileViewModel?.loadProfiles()` after successful login

**ProfileViewModel.swift**
- Line 525: Changed `private func createProfileAsync()` to `func createProfileAsync()`

**ProfileViews.swift**
- Lines 402-418: Changed to properly `await profileViewModel.createProfileAsync()`
- Added detailed logging throughout creation flow

**LoginView.swift**
- Added debug status overlay to show login progress without console

#### Testing Checklist:
- [ ] Sign out and sign in with Google
- [ ] Create a profile
- [ ] Verify "Profiles: 1" appears at top of dashboard
- [ ] Verify profile circle appears next to "Remi" logo
- [ ] Check console for "✅ Profile creation complete! Total profiles: 1"
- [ ] Create second profile, verify both show
- [ ] Restart app, verify profiles persist

#### Known Issues/Questions:
- Should we use `DatabaseService.createUser()` instead of manual Firestore calls?
- What if existing user returns but document doesn't exist? (edge case)
- Debug overlay should be removed before production

## NEXT STEPS

1. **Immediate**: Test profile creation flow with fixes
2. **Short-term**: Remove debug overlays and clean up logging
3. **Medium-term**: Integrate Twilio for SMS functionality
4. **Long-term**: Multi-device sync and family sharing

---

**For detailed UI specifications**: See `Hallo-UI-Integration-Plan.txt`
**For development patterns**: See `Hallo-Development-Guidelines.txt`
