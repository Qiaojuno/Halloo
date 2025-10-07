# Firestore Indexes Documentation

**Last Updated:** 2025-10-03
**Status:** ✅ All required indexes documented

---

## Overview

This document maps all Firestore queries in the codebase to their required composite indexes. Firestore requires composite indexes for queries that:
1. Use multiple `whereField` clauses
2. Combine `whereField` with `order(by:)` on a different field

---

## Current Indexes (firestore.indexes.json)

### 1. Tasks Index #1: User + Status + Schedule
```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "nextScheduledDate", "order": "ASCENDING" }
  ]
}
```

**Used By:**
- `getActiveTasks(for userId:)` - Line 226-231
  - Filters: `userId`, `status = active`
  - Orders: `nextScheduledDate`

---

### 2. Tasks Index #2: Profile + Status + Schedule
```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "profileId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "nextScheduledDate", "order": "ASCENDING" }
  ]
}
```

**Used By:**
- Future profile-specific active tasks queries (not currently used)
- Prepared for dashboard filtering

---

### 3. Responses Index #1: User + Completion + Time
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "isCompleted", "order": "ASCENDING" },
    { "fieldPath": "receivedAt", "order": "DESCENDING" }
  ]
}
```

**Used By:**
- Future filtered response queries (not currently used)
- Prepared for completion tracking

---

### 4. Responses Index #2: Completion + Type + Time
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "isCompleted", "order": "ASCENDING" },
    { "fieldPath": "responseType", "order": "ASCENDING" },
    { "fieldPath": "receivedAt", "order": "DESCENDING" }
  ]
}
```

**Used By:**
- `getCompletedResponsesWithPhotos()` - Line 351-356
  - Filters: `isCompleted = true`, `responseType IN [photo, both]`
  - Orders: `receivedAt DESC`

---

### 5. Profiles Index: User + CreatedAt
```json
{
  "collectionGroup": "profiles",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "ASCENDING" }
  ]
}
```

**Used By:**
- `getElderlyProfiles(for userId:)` - Line 102-111
  - Filters: `userId`
  - Orders: `createdAt`
- `observeUserProfiles(_:)` - Line 425-430
  - Same query with real-time listener

---

## Queries That DON'T Need Composite Indexes

### Single Field Queries
Firestore automatically indexes single fields, so these work without custom indexes:

1. **getUser()** - Single document fetch
2. **getElderlyProfile()** - Single document fetch
3. **getTask()** - Single document fetch
4. **getSMSResponse()** - Single document fetch

### Single WhereField Queries
Simple equality filters don't need composite indexes:

1. **getProfileTasks()** - Line 151-160
   - Filter: `profileId` only
   - Order: `createdAt` (same field as filter)

2. **getSMSResponses(for taskId:)** - Line 287-296
   - Filter: `taskId` only
   - Order: `receivedAt` (different field, but single where clause)

3. **getConfirmationResponses()** - Line 339-349
   - Filters: `profileId`, `responseType`
   - Order: `receivedAt`
   - ❓ **Potential Issue:** May need composite index

### Range Queries
Firestore automatically supports range queries on the same field being ordered:

1. **getTasksScheduledFor(date:userId:)** - Line 185-200
   - Filters: `userId`, `nextScheduledDate >= start`, `nextScheduledDate < end`
   - Order: `nextScheduledDate`
   - ✅ Works with Tasks Index #1

2. **getTodaysTasks()** - Line 209-224
   - Filters: `userId`, `nextScheduledDate >= today`, `nextScheduledDate < tomorrow`
   - Order: `nextScheduledDate`
   - ✅ Works with Tasks Index #1

3. **getSMSResponses(for userId:date:)** - Line 310-325
   - Filters: `userId`, `receivedAt >= start`, `receivedAt < end`
   - Order: `receivedAt`
   - ✅ Single field order, no composite needed

---

## Missing Indexes ⚠️

### 1. Profiles: User + Status + CreatedAt
**Query:** `getConfirmedProfiles(for userId:)` - Line 101-111

**Current Code:**
```swift
.whereField("userId", isEqualTo: userId)
.whereField("status", isEqualTo: "confirmed")
.order(by: "createdAt", descending: true)
```

**Required Index:**
```json
{
  "collectionGroup": "profiles",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

---

### 2. Tasks: Profile + User + CreatedAt
**Query:** `getTasks(for profileId:userId:)` - Line 173-183

**Current Code:**
```swift
.whereField("profileId", isEqualTo: profileId)
.whereField("userId", isEqualTo: userId)
.order(by: "createdAt")
```

**Required Index:**
```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "profileId", "order": "ASCENDING" },
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "ASCENDING" }
  ]
}
```

---

### 3. Responses: Profile + User + ReceivedAt
**Query:** `getSMSResponses(for profileId:userId:)` - Line 298-308

**Current Code:**
```swift
.whereField("profileId", isEqualTo: profileId)
.whereField("userId", isEqualTo: userId)
.order(by: "receivedAt", descending: true)
```

**Required Index:**
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "profileId", "order": "ASCENDING" },
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "receivedAt", "order": "DESCENDING" }
  ]
}
```

---

### 4. Responses: Profile + ResponseType + ReceivedAt
**Query:** `getConfirmationResponses(for profileId:)` - Line 339-349

**Current Code:**
```swift
.whereField("profileId", isEqualTo: profileId)
.whereField("responseType", isEqualTo: ResponseType.text.rawValue)
.order(by: "receivedAt", descending: true)
```

**Required Index:**
```json
{
  "collectionGroup": "responses",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "profileId", "order": "ASCENDING" },
    { "fieldPath": "responseType", "order": "ASCENDING" },
    { "fieldPath": "receivedAt", "order": "DESCENDING" }
  ]
}
```

---

### 5. Gallery Events: User + CreatedAt
**Query:** `getGalleryHistoryEvents(for userId:)` - Line 120-129

**Current Code:**
```swift
.whereField("userId", isEqualTo: userId)
.order(by: "createdAt", descending: true)
```

**Required Index:**
```json
{
  "collectionGroup": "gallery_events",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

---

## Recommended Actions

### Immediate (Required for Production)
1. ✅ Add missing index for `getConfirmedProfiles()` (profiles)
2. ✅ Add missing index for `getTasks(profileId, userId)` (tasks)
3. ✅ Add missing index for `getSMSResponses(profileId, userId)` (responses)
4. ✅ Add missing index for `getConfirmationResponses()` (responses)
5. ✅ Add missing index for `getGalleryHistoryEvents()` (gallery_events)

### Testing
1. Deploy updated `firestore.indexes.json` to Firebase
2. Run all database queries in staging environment
3. Monitor Firestore console for "Index required" errors
4. Verify query performance (should be <100ms for small datasets)

### Future Optimization
1. Consider denormalization to reduce multi-field queries
2. Add field value arrays for common filters (e.g., `tags: ["active", "confirmed"]`)
3. Use collection group queries sparingly (they scan all collections)

---

## Deployment Commands

```bash
# Deploy indexes to Firebase
firebase deploy --only firestore:indexes

# Check deployment status
firebase firestore:indexes

# Monitor index build progress (can take minutes for large datasets)
# Visit: https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes
```

---

## Schema Compliance Checklist

- [x] All queries documented
- [ ] All required indexes added to firestore.indexes.json (5 missing)
- [ ] Indexes deployed to Firebase
- [ ] Queries tested in production
- [ ] No "Index required" errors in logs

---

**Next Steps:** Update `firestore.indexes.json` with 5 missing indexes and deploy.
