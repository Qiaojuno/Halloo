# Data Migration Guide: Fix Task ProfileIds

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
