# Halloo Technical Documentation

*Comprehensive guide covering data architecture, migrations, and feature implementations*

---

## Table of Contents

1. [Phone Number Format - E.164 Compliance](#phone-number-format---e164-compliance)
2. [Data Migration - Fix Task ProfileIds](#data-migration---fix-task-profileids)
3. [Archived Photos Feature - 90-Day Retention](#archived-photos-feature---90-day-retention)
4. [Real-Time Gallery Updates Fix](#real-time-gallery-updates-fix)

---

# Phone Number Format - E.164 Compliance

## Issue
Twilio SMS was failing with error `21211: Invalid 'To' Phone Number` because phone numbers were stored in display format (e.g., "+1 (778) 814-3739") instead of E.164 format required by Twilio.

## Root Cause
The `formattedPhoneNumber` extension in `String+Extensions.swift` was designed for UI display, adding parentheses, spaces, and dashes. When ProfileViewModel used this for creating profiles, the formatted phone numbers were incompatible with Twilio's E.164 requirement.

**E.164 Format Requirements:**
- Start with `+` and country code
- Only digits after `+` (no spaces, dashes, parentheses)
- Example: `+17788143739`

## Solution
Created new `e164PhoneNumber` extension property specifically for Twilio SMS compatibility.

### Files Changed

#### 1. `/Halloo/Core/String+Extensions.swift`
**Added:** New `e164PhoneNumber` computed property (lines 67-96)

```swift
/// E.164 format phone number for Twilio SMS (e.g., +17788143739)
///
/// Converts any phone number format to E.164 standard required by Twilio.
/// This format has no spaces, dashes, or parentheses - just + and digits.
var e164PhoneNumber: String {
    let cleaned = phoneNumberDigitsOnly

    // Handle different phone number lengths
    switch cleaned.count {
    case 10:
        // US/Canada 10-digit number → add +1 country code
        return "+1\(cleaned)"

    case 11 where cleaned.hasPrefix("1"):
        // Already has country code 1 → just add +
        return "+\(cleaned)"

    default:
        // International or other format → just add + if needed
        if cleaned.count > 10 {
            return "+\(cleaned)"
        } else if cleaned.count == 10 {
            // Assume US/Canada if exactly 10 digits
            return "+1\(cleaned)"
        } else {
            // Invalid or too short
            return "+\(cleaned)"
        }
    }
}
```

**Purpose:**
- `formattedPhoneNumber`: Display format for UI (e.g., "+1 (778) 814-3739")
- `e164PhoneNumber`: SMS-compatible format for Twilio (e.g., "+17788143739")

#### 2. `/Halloo/ViewModels/ProfileViewModel.swift`
**Changed:** All phone number processing to use `.e164PhoneNumber`

**Line 672:** `createProfileAsync()` - Profile creation
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 810:** `updateProfileAsync()` - Profile updates
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 1535:** `createTemporaryProfileForSMS()` - Onboarding flow
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 1293:** `validatePhoneNumber()` - Duplicate phone check
```swift
// Before
else if profiles.contains(where: { $0.phoneNumber == phone.formattedPhoneNumber && $0.id != selectedProfile?.id }) {

// After
else if profiles.contains(where: { $0.phoneNumber == phone.e164PhoneNumber && $0.id != selectedProfile?.id }) {
```

## Testing
1. Create a new elderly profile with phone number (e.g., "778-814-3739")
2. Verify profile.phoneNumber is stored as "+17788143739" (E.164)
3. Send SMS confirmation - should succeed without Twilio error 21211
4. Check Twilio logs - should show valid "To" phone number

## Impact
- **Fixes:** Twilio SMS delivery failures
- **Ensures:** All phone numbers stored consistently in E.164 format
- **Maintains:** Display formatting for UI using `formattedPhoneNumber`
- **Backward Compatible:** Existing profiles will be converted to E.164 on next update

## Related Files
- `Halloo/Core/String+Extensions.swift` - Phone number formatting utilities
- `Halloo/ViewModels/ProfileViewModel.swift` - Profile management and SMS
- `Halloo/Views/ProfileViews.swift` - Profile creation UI (uses formatted display)
- `functions/index.js` - Twilio SMS Cloud Function (validates E.164)

## References
- [Twilio E.164 Documentation](https://www.twilio.com/docs/glossary/what-e164)
- [E.164 Wikipedia](https://en.wikipedia.org/wiki/E.164)
- Twilio Error 21211: Invalid 'To' Phone Number

---

# Data Migration - Fix Task ProfileIds

## Problem

Your existing Firestore tasks have **phone numbers as `profileId`** (old schema) but the current code expects **UUID profile IDs** (new schema).

**Symptoms:**
- DashboardView shows 0 profiles
- HabitsView shows no habits
- GalleryView shows no profile info
- Console logs show:
  ```
  ❌ FILTERED: No profile found with id=+17788143739
  Available profile IDs: []
  ```

## Root Cause

Old schema (before ID standardization):
```swift
Task(profileId: "+17788143739")  // Phone number
```

New schema (after ID standardization):
```swift
Task(profileId: "A1B2C3D4-E5F6-...")  // UUID
Profile(id: "A1B2C3D4-E5F6-...", phoneNumber: "+17788143739")
```

## Solution Options

### Option 1: Clean Slate (Recommended for Testing)

**Delete all old habits and recreate them:**

1. Open Firebase Console → Firestore Database
2. Navigate to `users/{userId}/profiles/{profileId}/habits`
3. Delete all habits manually
4. Create new habits in the app (they will use correct UUID profileIds)

**Pros:** Clean, simple, no code needed
**Cons:** Loses existing habit data

---

### Option 2: Automatic Migration (Preserve Data)

**Use the migration helper to update existing tasks:**

1. Add this code to your `DashboardView.onAppear`:

```swift
.onAppear {
    viewModel.setProfileViewModel(profileViewModel)
    loadData()

    // ONE-TIME MIGRATION: Run this once to fix old data
    #if DEBUG
    Task {
        do {
            guard let userId = container.authService.currentUser?.uid else { return }
            let migration = FirestoreDataMigration()
            let count = try await migration.migrateTaskProfileIds(userId: userId)
            print("✅ Migrated \(count) tasks")
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    #endif
}
```

2. Run the app once in DEBUG mode
3. Check console for migration success
4. Remove the migration code block

**Pros:** Preserves existing data
**Cons:** Requires code change

---

### Option 3: Delete Orphaned Habits via Code

**Quick cleanup without manual Firestore console work:**

```swift
.onAppear {
    viewModel.setProfileViewModel(profileViewModel)
    loadData()

    // ONE-TIME CLEANUP: Delete old habits with phone-number profileIds
    #if DEBUG
    Task {
        do {
            guard let userId = container.authService.currentUser?.uid else { return }
            let migration = FirestoreDataMigration()
            let count = try await migration.deleteOrphanedHabits(userId: userId)
            print("✅ Deleted \(count) orphaned habits")
        } catch {
            print("❌ Cleanup failed: \(error)")
        }
    }
    #endif
}
```

**Pros:** Automated cleanup
**Cons:** Deletes all old habits (need to recreate)

---

## Verification

After migration/cleanup, verify:

1. **DashboardView** shows profiles and tasks
2. **HabitsView** displays habits correctly
3. **Console logs** show:
   ```
   ✅ Profile matched! Checking if scheduled for 2025-10-09
   ✅ Task IS scheduled for today - creating DashboardTask
   ```

## Prevention

The new schema is now enforced:
- `ElderlyProfile.id` = UUID (stored in Firestore document ID)
- `Task.profileId` = UUID (matches profile.id)
- `ElderlyProfile.phoneNumber` = E.164 phone (+1234567890)

Future task creation automatically uses correct UUIDs (line 621 in TaskViewModel.swift).

---

## Quick Reference

**Check current data structure in Firestore:**
```
users/{userId}/
  └── profiles/{UUID}/       ← Profile ID is UUID
      ├── phoneNumber: "+17788143739"
      └── habits/{habitId}/
          └── profileId: ???  ← Should match parent UUID, not phone
```

**Expected behavior:**
```swift
Task(
  profileId: "45DD3B0E-D983-4917-AE79-2BC001BFBA38"  // UUID
)

Profile(
  id: "45DD3B0E-D983-4917-AE79-2BC001BFBA38",        // Same UUID
  phoneNumber: "+17788143739"                        // Phone stored separately
)
```

---

# ⚠️ DEPRECATED: Archived Photos Feature - 90-Day Retention

> **Status:** REMOVED in 2025-10-21
> **Reason:** Simplified to store all photos in Firebase Storage indefinitely
> **Impact:** 150 lines of code removed from GalleryViewModel

## Overview (Historical)
Previously implemented automated data retention policy that archived photos to Cloud Storage and deleted text data after 90 days. This feature has been removed in favor of a simpler approach.

## Business Requirements

### Privacy
- Delete sensitive SMS text messages after 90 days
- Remove task response metadata (titles, timestamps, etc.)
- Keep only photos for long-term memory preservation

### Cost Optimization
- **Before:** ~$2/user/year (3,000+ Firestore documents)
- **After:** ~$0.50/user/year (270 docs + Cloud Storage)
- **Savings:** 75% reduction in Firestore read costs (~$1.50/user/year)

### Memory Preservation
- Photos archived forever in Cloud Storage
- Organized by user/profile/year/month for easy browsing
- Original creation dates preserved in metadata

## Architecture

### Data Flow
```
Day 0-89: Gallery Event in Firestore (text + photo base64)
    ↓
Day 90: Cloud Function triggers cleanup
    ↓
1. Extract photo from gallery event
2. Upload to Cloud Storage with metadata
3. Delete Firestore event (text data removed)
    ↓
Forever: Archived photo accessible in Gallery "Archived Memories" section
```

### Storage Organization
```
Cloud Storage: gallery-archive/
├── {userId}/
│   ├── {profileId}/
│   │   ├── {year}/
│   │   │   ├── {month}/
│   │   │   │   ├── {eventId}.jpg (with metadata)
```

**Example:**
```
gallery-archive/
├── user123/
│   ├── profile456/
│   │   ├── 2025/
│   │   │   ├── 01/
│   │   │   │   ├── event789.jpg
│   │   │   │   ├── event790.jpg
│   │   │   ├── 02/
│   │   │   │   ├── event791.jpg
```

## Implementation

### 1. Cloud Function - Automated Cleanup

**File:** `/functions/index.js` (lines 240-446)

#### `cleanupOldGalleryEvents` (Scheduled Function)
- **Trigger:** Runs daily at midnight PST
- **Schedule:** `every 24 hours`
- **Batch Size:** 500 events per run (prevents timeout)

**Process:**
1. Query events older than 90 days using `collectionGroup('galleryEvents')`
2. For each event with photo:
   - Extract base64 photo data
   - Create organized file path: `{userId}/{profileId}/{year}/{month}/{eventId}.jpg`
   - Upload to Cloud Storage with metadata
   - Track: `userId`, `profileId`, `eventId`, `originalCreatedAt`, `archivedAt`, `taskTitle`
3. Delete Firestore event (text data permanently removed)
4. Log summary: photos archived, events deleted, errors

**Code:**
```javascript
exports.cleanupOldGalleryEvents = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    // Calculate 90 days ago
    const threeMonthsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
    );

    // Query old events across all users
    const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
      .where('createdAt', '<', threeMonthsAgo)
      .limit(500)
      .get();

    // Archive photos and delete events
    // ... (see implementation)
  });
```

#### `manualCleanup` (HTTP Endpoint)
- **Trigger:** Manual HTTP POST request
- **Purpose:** Testing and debugging
- **Parameters:** `daysOld` (default: 90)

**Usage:**
```bash
curl -X POST https://us-central1-remi-91351.cloudfunctions.net/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

**Testing locally:**
```bash
curl -X POST http://localhost:5001/remi-91351/us-central1/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

### 2. Storage Security Rules

**File:** `/storage.rules` (lines 51-60)

```javascript
// Gallery archive - archived photos older than 90 days
// Read-only for users (photos archived by Cloud Function)
match /gallery-archive/{userId}/{profileId}/{year}/{month}/{photoId} {
  // Users can only read their own archived photos
  allow read: if isAuthenticated() && isOwner(userId);

  // Only Cloud Functions can write (via service account)
  // Users cannot upload/delete archived photos
  allow write: if false;
}
```

**Security:**
- Users can read only their own archived photos
- Cloud Functions write via Firebase Admin SDK (bypasses rules)
- Users cannot manually upload/delete archived photos
- Prevents unauthorized access to archived memories

### 3. iOS - GalleryViewModel

**File:** `/Halloo/ViewModels/GalleryViewModel.swift` (lines 95-335)

#### New Properties
```swift
/// Archived photos from Cloud Storage (older than 90 days)
@Published var archivedPhotos: [ArchivedPhoto] = []

/// Loading state for archived photos from Cloud Storage
@Published var isLoadingArchive = false
```

#### `loadArchivedPhotos()` Method (lines 235-316)
**Process:**
1. Get authenticated user ID
2. List all files under `gallery-archive/{userId}` in Cloud Storage
3. For each photo:
   - Get download URL
   - Extract metadata: `archivedAt`, `originalCreatedAt`, `profileId`
   - Create `ArchivedPhoto` object
4. Sort by `originalCreatedAt` (newest first)
5. Update `@Published` array for UI display

**Error Handling:**
- Gracefully handles individual photo failures
- Continues loading remaining photos if one fails
- Sets error message for user feedback

#### `ArchivedPhoto` Model (lines 322-335)
```swift
struct ArchivedPhoto: Identifiable, Codable {
    let id: String
    let url: URL
    let archivedAt: Date
    let originalCreatedAt: Date?
    let profileId: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: originalCreatedAt ?? archivedAt)
    }
}
```

### 4. iOS - GalleryView UI

**File:** `/Halloo/Views/GalleryView.swift` (lines 340-409, 72-74)

#### Archived Memories Section (lines 340-409)
**Features:**
- Section header: "Archived Memories (90+ days)" in gray
- Loading state with circular progress indicator
- Empty state: "No archived photos yet"
- 3-column grid matching recent gallery layout
- AsyncImage for efficient Cloud Storage loading
- Loading placeholders and error states

**Code:**
```swift
// Archived Memories Section (photos older than 90 days)
if !viewModel.archivedPhotos.isEmpty || viewModel.isLoadingArchive {
    VStack(alignment: .leading, spacing: 8) {
        // Section header
        HStack {
            Text("Archived Memories (90+ days)")
                .tracking(-1)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "9f9f9f"))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)

        if viewModel.isLoadingArchive {
            // Loading indicator
            ProgressView()
        } else if viewModel.archivedPhotos.isEmpty {
            // Empty state
            Text("No archived photos yet")
        } else {
            // Archived photo grid
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(viewModel.archivedPhotos) { photo in
                    AsyncImage(url: photo.url) { phase in
                        // Loading/success/failure states
                    }
                }
            }
        }
    }
}
```

#### Load on View Appear (lines 72-74)
```swift
.task {
    await viewModel.loadGalleryData()
    await viewModel.loadArchivedPhotos()
}
```

## Deployment

### 1. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

**Deployed Functions:**
- `cleanupOldGalleryEvents` - Scheduled cleanup (runs daily)
- `manualCleanup` - Manual testing endpoint

### 2. Deploy Storage Rules
```bash
firebase deploy --only storage
```

### 3. iOS App Update
- Build and deploy new version with archived photos UI
- Users will see "Archived Memories" section after 90 days

## Testing

### Local Testing (Emulator)
```bash
# Start emulators
firebase emulators:start

# Test manual cleanup with 7-day threshold
curl -X POST http://localhost:5001/remi-91351/us-central1/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

### Production Testing
1. Create test gallery events with old timestamps (backdated 91 days)
2. Trigger manual cleanup endpoint
3. Verify:
   - Photos uploaded to Cloud Storage
   - Metadata preserved (dates, profile IDs)
   - Firestore events deleted
   - iOS app displays archived photos

### Monitoring
```bash
# View Cloud Function logs
firebase functions:log --only cleanupOldGalleryEvents

# Check Cloud Storage bucket
gsutil ls -r gs://remi-91351.appspot.com/gallery-archive/
```

## Migration Plan

### Phase 1: Deploy (Immediate)
1. Deploy Cloud Function (scheduled but won't run immediately)
2. Deploy Storage rules
3. Deploy iOS app with archived photos UI

### Phase 2: Initial Cleanup (Day 1)
1. Cloud Function runs at midnight PST
2. Archives all photos older than 90 days
3. Monitor logs for errors

### Phase 3: Steady State (Ongoing)
- Daily cleanup runs automatically
- Processes 500 events per day (adjustable if needed)
- Users see archived photos in Gallery view

### Rollback Plan
If issues occur:
1. Disable scheduled function: `firebase functions:delete cleanupOldGalleryEvents`
2. Photos remain in Cloud Storage (safe)
3. Fix issues and redeploy

## Performance

### Cloud Function
- **Execution Time:** ~5-10 seconds per 100 events
- **Batch Size:** 500 events per run
- **Frequency:** Daily (midnight PST)
- **Cost:** Minimal (~$0.01/month for typical usage)

### iOS App
- **Initial Load:** ~1-2 seconds for 100 archived photos
- **Memory:** Efficient with AsyncImage lazy loading
- **Network:** Downloads photos on-demand as user scrolls

## Cost Analysis

### Firestore (Before)
- 10 events/day × 365 days × 3 years = 10,950 documents
- 10,950 reads/month × $0.06/100K = ~$0.66/month
- **Annual:** ~$7.92/user

### Firestore (After)
- 10 events/day × 90 days = 900 documents
- 900 reads/month × $0.06/100K = ~$0.05/month
- **Annual:** ~$0.60/user

### Cloud Storage
- 10 photos/day × 3 years × 500KB = ~5.5 GB
- 5.5 GB × $0.026/GB = ~$0.14/month
- **Annual:** ~$1.68/user

### Total Savings
- **Before:** $7.92/user/year
- **After:** $2.28/user/year
- **Savings:** $5.64/user/year (71% reduction)

## Future Enhancements

### Potential Features
1. **Download Archive:** Allow users to download all archived photos as ZIP
2. **Share Memories:** Share archived photos via social media
3. **Search:** Search archived photos by date, profile, or event type
4. **Filters:** Filter archived photos by profile or time period
5. **Pagination:** Lazy load archived photos in batches (for large archives)

### Monitoring & Alerts
1. Set up Cloud Function error alerts
2. Monitor Cloud Storage usage
3. Track cleanup success rate
4. Alert on archival failures

## Related Files

### Backend
- `/functions/index.js` - Cloud Functions implementation
- `/functions/README.md` - Deployment documentation
- `/storage.rules` - Cloud Storage security rules

### iOS
- `/Halloo/ViewModels/GalleryViewModel.swift` - Archived photos logic
- `/Halloo/Views/GalleryView.swift` - Archived photos UI

---

# Real-Time Gallery Updates Fix

## Issue
Gallery UI was not updating in real-time when SMS responses created gallery events, despite successful data flow through Firestore → Real-time listener → AppState chain.

## Root Causes

### 1. SwiftUI Property Wrapper Bug
**File:** `ContentView.swift:33`

AppState was declared as `@State` instead of `@StateObject`:
- `@State` only watches variable reassignment, doesn't subscribe to `@Published` properties
- `@StateObject` subscribes to all `@Published` properties in ObservableObject
- Result: Data reached AppState but SwiftUI wasn't watching it

### 2. Event Type Rendering Bug
**File:** `GalleryView.swift:360`

Gallery hardcoded to only render `taskResponse` events:
- Ignored `profileCreated` events entirely
- Needed switch statement to handle multiple event types
- Added `galleryEventView(for:)` helper function

### 3. Listener Crash on Malformed Data
**File:** `FirebaseDatabaseService.swift:735`

Listener crashed on single bad event, blocking all new events:
- Old events had `photoData: "<null>"` (JS null) causing decode failure
- Changed from `map { try }` to `compactMap { try? }` for fault tolerance
- Skip bad events instead of crashing entire listener

### 4. Duplicate Profile Creation Events
**File:** `ProfileViewModel.swift:1068`

Gallery events duplicated 20+ times on app launch:
- SMS listener replays all historical messages on launch
- Time-based deduplication insufficient (old timestamps bypass check)
- Implemented Set-based tracking: `profilesWithGalleryEvents = Set<String>()`

## Solution

### ContentView.swift
```swift
// Changed from @State to @StateObject with inline initialization
@StateObject private var appState: AppState = {
    let container = Container.shared
    return AppState(
        authService: container.resolve(AuthenticationServiceProtocol.self),
        databaseService: container.resolve(DatabaseServiceProtocol.self),
        dataSyncCoordinator: container.resolve(DataSyncCoordinator.self)
    )
}()
```

### GalleryView.swift
```swift
@ViewBuilder
private func galleryEventView(for event: GalleryHistoryEvent) -> some View {
    switch event.eventData {
    case .taskResponse:
        GalleryPhotoView.taskResponse(...)
    case .profileCreated:
        GalleryPhotoView.profilePhoto(...)
    }
}
```

### FirebaseDatabaseService.swift
```swift
// Fault-tolerant listener - skip bad events instead of crashing
let events = documents.compactMap { document -> GalleryHistoryEvent? in
    do {
        return try self.decodeFromFirestore(document.data(), as: GalleryHistoryEvent.self)
    } catch {
        print("❌ Failed to decode gallery event \(document.documentID) - SKIPPING")
        return nil
    }
}
subject.send(events)
```

### ProfileViewModel.swift
```swift
// Set-based deduplication
private var profilesWithGalleryEvents = Set<String>()

private func createGalleryEventForProfile(_ profile: ElderlyProfile, profileSlot: Int) {
    guard !profilesWithGalleryEvents.contains(profile.id) else { return }

    // Create event...

    await MainActor.run {
        self.profilesWithGalleryEvents.insert(profile.id)
    }
}
```

## Related Files

### iOS
- `/Halloo/Views/ContentView.swift` - @StateObject fix
- `/Halloo/Views/GalleryView.swift` - Event type rendering
- `/Halloo/Services/FirebaseDatabaseService.swift` - Fault-tolerant listener
- `/Halloo/ViewModels/ProfileViewModel.swift` - Set-based deduplication

### Documentation
- `/Halloo/docs/sessions/SESSION-2025-10-20-RealTimeGalleryFix.md` - Detailed session notes

### Cleanup Scripts (Temporary)
- `/cleanup-gallery-duplicates.js` - Remove duplicate events from Firestore
- `/UI-UPDATE-FIX.md` - UI update debugging notes

## Key Learnings

1. **@State vs @StateObject:** Using wrong property wrapper silently breaks reactive updates
2. **Fault tolerance:** Use `compactMap` for real-time listeners with legacy data
3. **Set-based deduplication:** More robust than time-based checks for replayed events
4. **Type-specific rendering:** Don't hardcode single type when data model supports multiple

---

# Image Caching System

## Issue
Profile photos and gallery images were reloading from Firebase Storage every time users switched tabs, causing:
- AsyncImage placeholder flicker (empty → loading → image)
- Unnecessary network requests
- Poor user experience with loading spinners

## Solution - NSCache-Based Image Service

**File:** `/Halloo/Services/ImageCacheService.swift` (NEW - 160 lines)

### Architecture
```swift
final class ImageCacheService: ObservableObject {
    private let cache = NSCache<NSString, UIImage>()
    @Published private(set) var loadedImages: Set<String> = []

    init() {
        cache.countLimit = 20           // Max 20 images
        cache.totalCostLimit = 50_000_000  // 50MB limit
    }
}
```

### Features

**1. Memory Cache with Automatic Eviction**
- Uses Apple's `NSCache` for automatic memory management
- Evicts least-recently-used images under memory pressure
- Thread-safe for concurrent access

**2. Parallel Preloading on App Launch**
```swift
// In AppState.loadUserData()
async let profilePhotosTask: Void = imageCache.preloadProfileImages(profiles)
async let galleryPhotosTask: Void = imageCache.preloadGalleryPhotos(galleryEvents)

_ = await profilePhotosTask
_ = await galleryPhotosTask
```

**3. Cache-First Lookup in UI**
```swift
// ProfileImageView.swift
if let cachedUIImage = appState.imageCache.getCachedImage(for: profile.photoURL) {
    // Use cached image directly - synchronous, no placeholder
    Image(uiImage: cachedUIImage)
        .resizable()
        .aspectRatio(contentMode: .fill)
} else {
    // Fallback to AsyncImage (first load or cache miss)
    AsyncImage(url: URL(string: profile.photoURL ?? "")) { /* ... */ }
}
```

### Integration Points

**Files Modified:**
- `AppState.swift` - Added imageCache parameter, parallel preloading
- `Container.swift` - Registered ImageCacheService singleton
- `ProfileImageView.swift` - Cache-first lookup
- `GalleryPhotoView.swift` - Cache-first for profile creation photos
- `GalleryDetailView.swift` - Cache-first for full-screen photos
- `ContentView.swift` - Injected imageCache to AppState

### Performance Impact

**Before:**
- 6 Firebase Storage requests per tab switch
- ~200ms loading time per image
- AsyncImage placeholders visible

**After:**
- 0 Firebase Storage requests after initial load
- <1ms synchronous cache lookup
- No placeholders or loading states

### Memory Management
- **Cache Limit:** 20 images max
- **Size Limit:** 50MB total
- **Eviction:** Automatic under memory pressure
- **Thread Safety:** NSCache is thread-safe by default

### What's Cached
✅ Profile photos (profile.photoURL)
✅ Gallery profile creation photos (profileCreated events)
❌ Task response photos (use Data blobs, not URLs)

### Related Files
- `/Halloo/Services/ImageCacheService.swift` - Cache implementation
- `/Halloo/Core/AppState.swift` - Preloading integration
- `/Halloo/Models/Container.swift` - Service registration
- `/Halloo/Views/Components/ProfileImageView.swift` - UI integration
- `/Halloo/Views/Components/GalleryPhotoView.swift` - UI integration
- `/Halloo/Views/GalleryDetailView.swift` - UI integration

---

# Build Configuration Updates (2025-10-21)

## StoreKit Configuration Fix
**Issue:** Xcode couldn't find StoreKit.storekit file
**Root Cause:** Scheme file referenced wrong path (`Halloo/Views/StoreKit.storekit`)
**Fix:** Updated `Halloo.xcscheme` to correct path (`../StoreKit.storekit`)

**File:** `/Halloo.xcodeproj/xcshareddata/xcschemes/Halloo.xcscheme:78`

## Dead Code Stripping
**Enabled for all build configurations:**
- Reduces app size by removing unused code
- Standard Apple recommendation for production apps
- Enabled in Debug and Release configurations

**File:** `/Halloo.xcodeproj/project.pbxproj`
```
DEAD_CODE_STRIPPING = YES;
```

## iOS 18 API Updates

### Font Registration (AppFonts.swift)
**Changed:** Deprecated `CTFontManagerRegisterGraphicsFont` → Modern `CTFontManagerRegisterFontsForURL`

```swift
// Before (deprecated in iOS 18)
guard let font = CGFont(provider) else { return }
CTFontManagerRegisterGraphicsFont(font, &error)

// After (iOS 13+ compatible)
guard let fontURL = Bundle.main.url(...) else { return }
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
```

### onChange Syntax (iOS 17+)
**Fixed 11 occurrences across:**
- `HabitsView.swift`
- `DashboardView.swift`
- `CardStackView.swift`

```swift
// Before (deprecated)
.onChange(of: value) { newValue in }

// After (iOS 17+)
.onChange(of: value) { oldValue, newValue in }
```

## Compiler Warnings Fixed (9 total)

**1. Unreachable Catch Block** (`App.swift`)
```swift
// Before - HalloApp.configureFirebase() doesn't throw
do {
    HalloApp.configureFirebase()
} catch { }  // Unreachable

// After
HalloApp.configureFirebase()
```

**2. Unnecessary Conditional Casts** (`FirebaseDatabaseService.swift`)
```swift
// Before - document.data() already returns [String: Any]
guard let data = document.data() as? [String: Any] else { }

// After
let data = document.data()
```

**3. Unnecessary try Expressions** (`FirebaseDatabaseService.swift`)
```swift
// Before - No throwing calls inside
return try snapshot.documents.compactMap { }

// After
return snapshot.documents.compactMap { }
```

**4. Unused Variables** (`GalleryHistoryEvent.swift`, `FirebaseDatabaseService.swift`)
```swift
// Before
case .taskResponse(let data):  // 'data' never used
    return "With SMS"

// After
case .taskResponse:
    return "With SMS"
```

---

# HabitsView UI Redesign & Code Deduplication

**Updated: 2025-10-30**

## Overview
Major HabitsView redesign with improved UX, 33% more compact layout, and significant code deduplication through new utility files.

## HabitsView UI Changes

### Week Selector Redesign
**Changed:** Single letter day abbreviations → 3-letter abbreviations

**Before:**
- Day labels: S, M, T, W, T, F, S (confusing, hard to distinguish)
- Selected: White background with border
- Unselected: Grey background

**After:**
- Day labels: Sun, Mon, Tue, Wed, Thu, Fri, Sat (clear, unambiguous)
- Selected: White background (#FFFFFF), black text, no border (raised appearance)
- Unselected: Dark grey (#E8E8E8), light grey text (#9f9f9f) (divot appearance)
- Depth effect: Visual hierarchy through background contrast

### Habit Row Redesign (33% More Compact)
**Changed:** Bulky rows with redundant info → Streamlined, information-dense rows

**Removed Elements:**
- Profile photo (redundant when viewing single profile's habits)
- Profile name text (already known from context)
- Mini week strip visualization (replaced with text)
- Custom Inter font (switched to system fonts)

**Added Elements:**
- Functional icons: 📷 (photo required), 💬 (text required)
- Smart frequency text: "Daily", "Weekdays", "Mon, Wed, Fri", etc.

**Size Changes:**
- Row height: 90pt → 60pt (33% reduction)
- Emoji size: 32pt → 24pt (smaller, cleaner)
- Typography: System font, 17pt, semibold

### Card Structure Changes
**Before:**
- Single card with "All Scheduled Tasks" title
- Week selector and habits in same card

**After:**
- Two separate cards for visual clarity:
  1. Week filter card (top) - Contains week selector only
  2. Habits list card (bottom) - Contains habit rows only
- Removed redundant title text
- Cleaner visual hierarchy

## Navigation Behavior Updates

### Tab Swiping Restrictions
**File:** `/Halloo/Views/ContentView.swift`

**Implementation:**
```swift
TabView(selection: $selectedTab) {
    DashboardView()
        .tag(0)
        // ✅ Swiping enabled to Gallery

    GalleryView()
        .tag(1)
        // ✅ Limited swiping (can swipe back to Dashboard)
        // ❌ Cannot swipe forward to Habits

    HabitsView()
        .tag(2)
        .gesture(DragGesture()) // ❌ Disables ALL swiping
}
```

**Behavior:**
- **Dashboard ↔ Gallery**: Bidirectional swiping enabled
- **Gallery → Habits**: Swiping disabled (no preview effect)
- **Habits**: All tab swiping disabled to prevent swipe-to-delete conflicts
- **Tab bar buttons**: Always functional on all tabs

**Rationale:**
- Habits view uses swipe-to-delete gesture for habit management
- Tab swiping interferes with swipe-to-delete UX
- Tab bar navigation provides clear alternative

## Code Deduplication - New Utility Files

### 1. DateFormatters.swift
**File:** `/Halloo/Core/DateFormatters.swift` (45 lines)

**Problem Solved:**
- 6 duplicate `formatTime()` functions across multiple view files
- Inconsistent time formatting (some ignored device locale/timezone)
- Maintenance burden: Updating time format required changing 6 files

**Solution:**
```swift
import Foundation

struct DateFormatters {
    // Locale-aware time formatting (e.g., "5:00 PM" or "17:00" based on device)
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Task-specific time formatting (e.g., "5PM", "5:00PM")
    static func formatTaskTime(_ date: Date, includeMinutes: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = includeMinutes ? "h:mma" : "ha"
        return formatter.string(from: date)
    }

    // Date formatting (e.g., "October 30, 2025")
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = style
        return formatter.string(from: date)
    }
}
```

**Usage:**
```swift
// Before (in each view file)
func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter.string(from: date)
}

// After (import once, use everywhere)
import DateFormatters
let timeString = DateFormatters.formatTime(task.scheduledTime)
```

**Files Updated:**
- DashboardView.swift
- HabitsView.swift
- TaskViews.swift
- GalleryView.swift
- OnboardingViews.swift
- ProfileViews.swift

### 2. Color+Extensions.swift
**File:** `/Halloo/Core/Color+Extensions.swift` (30 lines)

**Problem Solved:**
- Hex color utility previously defined in DashboardView only
- Other views couldn't use hex colors without duplicating code
- DRY violation: Color parsing logic not reusable

**Solution:**
```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

**Usage:**
```swift
// Available everywhere after import
Color(hex: "f9f9f9")  // Background color
Color(hex: "B9E3FF")  // Button color
Color(hex: "#7A7A7A") // Text color (# prefix optional)
```

**Files Using:**
- DashboardView.swift (moved from here)
- HabitsView.swift
- GalleryView.swift
- All view files using hex colors

### 3. HapticFeedback.swift
**File:** `/Halloo/Core/HapticFeedback.swift` (38 lines)

**Problem Solved:**
- 42 duplicate haptic feedback calls across view files
- Inconsistent patterns: Some used light(), some used medium(), some used heavy()
- Boilerplate code: `UIImpactFeedbackGenerator(style: .light).impactOccurred()` repeated

**Solution:**
```swift
import UIKit

struct HapticFeedback {
    // Impact feedback
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // Selection feedback (for picker/selector changes)
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // Notification feedback
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

**Usage:**
```swift
// Before (in each view file)
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// After (clean, semantic)
HapticFeedback.light()
HapticFeedback.selection() // For week selector changes
HapticFeedback.success()   // For habit completion
```

**Common Patterns:**
- `HapticFeedback.light()`: Button taps, minor interactions
- `HapticFeedback.selection()`: Picker/selector changes (week selector)
- `HapticFeedback.success()`: Task completion, successful actions
- `HapticFeedback.error()`: Validation failures, errors

**Files Updated:**
- HabitsView.swift (week selector taps)
- DashboardView.swift (profile selection)
- TaskViews.swift (habit creation)
- ProfileViews.swift (profile creation)
- CardStackView.swift (swipe actions)

## Impact Summary

### Code Reduction
- **DateFormatters**: Eliminated 6 duplicate functions (~60 lines)
- **Color+Extensions**: Moved from DashboardView, now shared (~30 lines reuse)
- **HapticFeedback**: Replaced 42 duplicate calls (~84 lines → ~42 calls)
- **Total**: ~150 lines of duplicate code eliminated

### Consistency Improvements
- **Time Formatting**: Now respects device locale and timezone settings
- **Hex Colors**: Consistent parsing across all views
- **Haptic Patterns**: Standardized feedback types for common actions

### Maintainability
- **Single Source of Truth**: Utilities in Core/ directory
- **Easy Updates**: Change time format in one place, affects all views
- **Reduced Bugs**: No more inconsistent time formatting edge cases

## Related Files

### New Files Created
- `/Halloo/Core/DateFormatters.swift` (45 lines)
- `/Halloo/Core/Color+Extensions.swift` (30 lines - moved from DashboardView)
- `/Halloo/Core/HapticFeedback.swift` (38 lines)

### Files Modified
- `/Halloo/Views/HabitsView.swift` (complete redesign)
- `/Halloo/Views/DashboardView.swift` (navigation + utility imports)
- `/Halloo/Views/ContentView.swift` (tab swiping configuration)
- `/Halloo/Views/TaskViews.swift` (utility imports)
- `/Halloo/Views/ProfileViews.swift` (utility imports)
- `/Halloo/Views/GalleryView.swift` (utility imports)
- `/Halloo/Views/OnboardingViews.swift` (utility imports)

---

*Last Updated: 2025-10-30*
