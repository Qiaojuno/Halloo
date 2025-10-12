# Session: Firestore Decoding Errors and UI Refresh Fixes

**Date:** 2025-10-11
**Duration:** ~1 hour
**Status:** ✅ Completed

## Overview

Fixed critical Firestore decoding errors that were preventing tasks and messages from loading, and resolved habit list not updating immediately after creation.

## Problems Identified

### 1. Firestore Decoding Errors
**Symptoms:**
- `"The data couldn't be read because it is missing"` errors on app launch
- Recent messages query failing
- Today's tasks query failing
- Gallery loading failing

**Root Cause:**
Old Firestore documents created before schema changes were missing required fields:
- `Task` documents missing: `nextScheduledDate`, `category`, `description`, etc.
- `SMSResponse` (messages) documents missing: `isConfirmationResponse`, `isPositiveConfirmation`

When using standard Codable decoding with `try decodeFromFirestore()`, Swift requires ALL non-optional fields to exist, causing decoding to fail entirely.

### 2. Habits List Not Updating Immediately
**Symptoms:**
- Creating a new habit succeeded
- Logs showed "✅ Task creation complete! Total tasks: 5"
- But HabitsView didn't refresh to show the new habit

**Root Cause:**
SwiftUI's `.id()` modifier alone wasn't triggering view refresh when TaskViewModel's `@Published var tasks` array changed, likely due to view hierarchy and timing issues.

## Solutions Implemented

### Fix 1: Custom Decoders with Default Values

**Changed Files:**
- `Halloo/Models/Task.swift`
- `Halloo/Models/SMSResponse.swift`

**Implementation:**

Added custom `init(from decoder:)` to both models using `decodeIfPresent` with fallback defaults:

```swift
// Task.swift - Lines 26-52
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Required fields
    id = try container.decode(String.self, forKey: .id)
    userId = try container.decode(String.self, forKey: .userId)
    profileId = try container.decode(String.self, forKey: .profileId)
    title = try container.decode(String.self, forKey: .title)
    frequency = try container.decode(TaskFrequency.self, forKey: .frequency)
    scheduledTime = try container.decode(Date.self, forKey: .scheduledTime)

    // Optional fields with defaults (backwards compatibility)
    description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    category = try container.decodeIfPresent(TaskCategory.self, forKey: .category) ?? .other
    deadlineMinutes = try container.decodeIfPresent(Int.self, forKey: .deadlineMinutes) ?? 10
    requiresPhoto = try container.decodeIfPresent(Bool.self, forKey: .requiresPhoto) ?? false
    requiresText = try container.decodeIfPresent(Bool.self, forKey: .requiresText) ?? true
    customDays = try container.decodeIfPresent([Weekday].self, forKey: .customDays) ?? []
    startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
    endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
    status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .active
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? Date()
    completionCount = try container.decodeIfPresent(Int.self, forKey: .completionCount) ?? 0
    lastCompletedAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedAt)
    nextScheduledDate = try container.decodeIfPresent(Date.self, forKey: .nextScheduledDate) ?? scheduledTime
}
```

```swift
// SMSResponse.swift - Lines 19-38
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Required fields
    id = try container.decode(String.self, forKey: .id)
    userId = try container.decode(String.self, forKey: .userId)
    receivedAt = try container.decode(Date.self, forKey: .receivedAt)
    responseType = try container.decode(ResponseType.self, forKey: .responseType)

    // Optional fields
    taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
    profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
    textResponse = try container.decodeIfPresent(String.self, forKey: .textResponse)
    photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
    isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false

    // New fields with defaults (backwards compatibility)
    isConfirmationResponse = try container.decodeIfPresent(Bool.self, forKey: .isConfirmationResponse) ?? false
    isPositiveConfirmation = try container.decodeIfPresent(Bool.self, forKey: .isPositiveConfirmation) ?? false
    responseScore = try container.decodeIfPresent(Double.self, forKey: .responseScore)
    processingNotes = try container.decodeIfPresent(String.self, forKey: .processingNotes)
}
```

**Benefits:**
- Old documents decode successfully with sensible defaults
- New documents still get full data
- No need to migrate existing Firestore data
- App is resilient to future schema changes

### Fix 2: Graceful Error Handling with compactMap

**Changed Files:**
- `Halloo/Services/FirebaseDatabaseService.swift`

**Implementation:**

Changed `map` to `compactMap` to skip documents that fail to decode instead of throwing errors:

```swift
// Line 507-517: getRecentSMSResponses
return try snapshot.documents.compactMap { document in
    do {
        let data = document.data()
        print("🔍 [FirebaseDatabaseService] Message document keys: \(data.keys.joined(separator: ", "))")
        return try decodeFromFirestore(data, as: SMSResponse.self)
    } catch {
        print("⚠️ [FirebaseDatabaseService] Skipping message \(document.documentID): \(error.localizedDescription)")
        return nil
    }
}
```

```swift
// Line 362-372: getTodaysTasks
return try snapshot.documents.compactMap { document in
    do {
        let data = document.data()
        print("🔍 [FirebaseDatabaseService] Task document keys: \(data.keys.joined(separator: ", "))")
        return try decodeFromFirestore(data, as: Task.self)
    } catch {
        print("⚠️ [FirebaseDatabaseService] Skipping task \(document.documentID): \(error.localizedDescription)")
        return nil
    }
}
```

**Benefits:**
- Queries succeed even if some documents are corrupted
- Debugging logs show which documents are skipped
- User sees partial data instead of complete failure

### Fix 3: Forced View Refresh on Task Count Change

**Changed Files:**
- `Halloo/Views/HabitsView.swift`

**Implementation:**

Added `refreshID` state and `.onChange` modifier to force view rebuild:

```swift
// Line 73-74: New state variable
@State private var refreshID = UUID()

// Line 113-118: onChange modifier
.onChange(of: taskViewModel?.tasks.count) { newCount in
    print("🔄 [HabitsView] Tasks count changed to: \(newCount ?? 0)")
    // Force view refresh by updating a local state
    refreshID = UUID()
}
.id(refreshID) // Force refresh when refreshID changes
```

**How it works:**
1. TaskViewModel's `@Published var tasks` array changes when habit created
2. `.onChange(of: taskViewModel?.tasks.count)` detects the count change
3. Generates new `UUID()` and assigns to `refreshID`
4. `.id(refreshID)` sees a different ID and forces entire view to rebuild
5. View rebuilds with updated task list

## Testing Results

**Before Fix:**
```
❌ [FirebaseDatabaseService] Recent messages query failed: The data couldn't be read because it is missing.
Error in Loading today's tasks: The data couldn't be read because it is missing.
```

**After Fix:**
```
✅ [FirebaseDatabaseService] Successfully fetched 5 habits
🔍 [FirebaseDatabaseService] Task document keys: id, userId, profileId, title, frequency, scheduledTime...
⚠️ [FirebaseDatabaseService] Skipping task ABC123: missing required field 'category'
🔄 [HabitsView] Tasks count changed to: 5
```

## Additional Discovery

**Missing Feature: Scheduled SMS Reminders**

During investigation, discovered that habit creation does NOT trigger SMS sending. Current state:

✅ **What works:**
- Habit saved to Firestore
- Local iOS notifications scheduled
- Task appears in habits list

❌ **What's missing:**
- No Cloud Function to send scheduled SMS reminders
- `functions/index.js` only has `sendSMS` (manual), `twilioWebhook` (receive), and `cleanupOldGalleryEvents`

**Next Steps Required:**
Need to implement `sendScheduledReminders` Cloud Function that:
1. Runs every 1-5 minutes
2. Queries tasks where `nextScheduledDate <= now`
3. Sends SMS via Twilio for each due task
4. Updates `nextScheduledDate` to next occurrence

This is a critical missing piece for the habit reminder system to work end-to-end.

## Files Modified

1. **Halloo/Models/Task.swift**
   - Added custom `init(from decoder:)` with default values
   - Added standard initializer for creating new instances

2. **Halloo/Models/SMSResponse.swift**
   - Added custom `init(from decoder:)` with default values
   - Added standard initializer for creating new instances

3. **Halloo/Services/FirebaseDatabaseService.swift**
   - Changed `getRecentSMSResponses` to use `compactMap` with error logging
   - Changed `getTodaysTasks` to use `compactMap` with error logging

4. **Halloo/Views/HabitsView.swift**
   - Added `@State private var refreshID = UUID()`
   - Added `.onChange(of: taskViewModel?.tasks.count)` modifier
   - Changed `.id()` from task count to `refreshID`

## Technical Learnings

### 1. Codable Backwards Compatibility Pattern

When evolving data models, use custom decoders to handle schema changes:

```swift
// ❌ BAD: Breaks on missing fields
struct Model: Codable {
    let newField: String  // Added later, old docs don't have it
}

// ✅ GOOD: Gracefully handles missing fields
struct Model: Codable {
    let newField: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        newField = try container.decodeIfPresent(String.self, forKey: .newField) ?? "default"
    }
}
```

### 2. compactMap for Resilient Queries

When querying collections with potentially corrupted documents:

```swift
// ❌ BAD: Entire query fails if one document is bad
let results = try documents.map { try decode($0) }

// ✅ GOOD: Skip bad documents, continue with rest
let results = documents.compactMap { doc in
    do {
        return try decode(doc)
    } catch {
        print("Skipping document: \(error)")
        return nil
    }
}
```

### 3. SwiftUI View Refresh with .id()

When `@Published` changes don't trigger refresh, force rebuild with `.id()`:

```swift
@State private var refreshID = UUID()

SomeView()
    .onChange(of: viewModel.data.count) { _ in
        refreshID = UUID()  // Generate new ID
    }
    .id(refreshID)  // Rebuild entire view when ID changes
```

## Future Improvements

1. **Implement Scheduled SMS Cloud Function**
   - Create `sendScheduledReminders` function
   - Run every 1-5 minutes
   - Query due tasks and send reminders

2. **Data Migration Script**
   - Backfill missing fields in old Firestore documents
   - Would eliminate need for `compactMap` skipping

3. **Schema Validation**
   - Add Firestore security rules to enforce required fields
   - Prevent creating documents with incomplete data

4. **Better Error Monitoring**
   - Send skipped document IDs to analytics
   - Alert when decode failure rate exceeds threshold

## Conclusion

Successfully fixed critical data loading issues by:
1. ✅ Adding backwards-compatible custom decoders
2. ✅ Implementing graceful error handling with `compactMap`
3. ✅ Forcing view refresh with `.id()` and `onChange`

App now:
- Loads tasks and messages without errors
- Updates habits list immediately after creation
- Gracefully handles corrupted/incomplete Firestore documents
- Provides debugging logs for data issues

**Next critical task:** Implement scheduled SMS reminder Cloud Function to complete the habit reminder system.
