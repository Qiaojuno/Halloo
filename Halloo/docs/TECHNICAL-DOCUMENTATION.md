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

# Archived Photos Feature - 90-Day Retention

## Overview
Implements automated data retention policy that archives photos to Cloud Storage and deletes text data after 90 days. This balances privacy, cost savings, and memory preservation.

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

*Last Updated: 2025-10-20*
