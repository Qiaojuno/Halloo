# 🛠️ Schema Migration Implementation Guide
**Project:** Halloo/Remi iOS App
**Prepared:** 2025-10-03
**For:** Development Team

---

## 📋 Overview

This guide provides **step-by-step instructions** to migrate from the current flat Firestore structure to the desired nested subcollection architecture.

**Estimated Total Time:** 30-40 hours
**Risk Level:** 🔴 High (breaking changes, data migration required)
**Rollback Plan:** Included ✅

---

## 🎯 Migration Goals

1. ✅ Move from flat collections to nested subcollections
2. ✅ Standardize ID generation across all entities
3. ✅ Fix User model field mismatches
4. ✅ Implement safe cascade delete logic
5. ✅ Add schema validation tests
6. ✅ Zero data loss during migration

---

## 📅 Migration Timeline (4 Weeks)

### Week 1: Non-Breaking Improvements
**Goal:** Fix issues that don't require data migration

### Week 2: Testing & Preparation
**Goal:** Build migration tools and test thoroughly

### Week 3: Dual-Write Period
**Goal:** Write to both old and new structure simultaneously

### Week 4: Migration & Cleanup
**Goal:** Complete migration and remove old structure

---

## 🔧 WEEK 1: Non-Breaking Improvements

### Day 1-2: TODO #3 - Fix User Model (2-3 hours)

**File:** `Halloo/Models/User.swift`

**Current Code (Lines 4-14):**
```swift
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let fullName: String
    let phoneNumber: String
    let createdAt: Date
    let isOnboardingComplete: Bool
    let subscriptionStatus: SubscriptionStatus
    let trialEndDate: Date?
    let quizAnswers: [String: String]?
}
```

**New Code:**
```swift
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let fullName: String
    let phoneNumber: String
    let createdAt: Date
    let isOnboardingComplete: Bool
    let subscriptionStatus: SubscriptionStatus
    let trialEndDate: Date?
    let quizAnswers: [String: String]?

    // ✅ NEW FIELDS (match Firestore writes)
    var profileCount: Int
    var taskCount: Int
    var updatedAt: Date
    var lastSyncTimestamp: Date?

    init(
        id: String,
        email: String,
        fullName: String,
        phoneNumber: String,
        createdAt: Date,
        isOnboardingComplete: Bool = false,
        subscriptionStatus: SubscriptionStatus = .trial,
        trialEndDate: Date? = nil,
        quizAnswers: [String: String]? = nil,
        profileCount: Int = 0,           // ✅ NEW
        taskCount: Int = 0,              // ✅ NEW
        updatedAt: Date = Date(),        // ✅ NEW
        lastSyncTimestamp: Date? = nil   // ✅ NEW
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.isOnboardingComplete = isOnboardingComplete
        self.subscriptionStatus = subscriptionStatus
        self.trialEndDate = trialEndDate
        self.quizAnswers = quizAnswers
        self.profileCount = profileCount
        self.taskCount = taskCount
        self.updatedAt = updatedAt
        self.lastSyncTimestamp = lastSyncTimestamp
    }
}
```

**Verification:**
1. Build project (should succeed)
2. Check all User initializations still work
3. Run existing tests

**Confidence:** 9/10

---

### Day 2-3: TODO #5 - Centralize User Creation (2 hours)

**File:** `Halloo/Services/FirebaseAuthenticationService.swift`

**Find & Replace:**

**Location 1: Google Sign-In (Lines 173-206)**
**OLD:**
```swift
if isNewUser {
    let userData: [String: Any] = [
        "id": user.id,
        "email": user.email,
        "fullName": user.displayName ?? "",
        "createdAt": FieldValue.serverTimestamp(),
        "subscriptionStatus": SubscriptionStatus.trial.rawValue,
        "profileCount": 0
    ]
    try await db.collection("users").document(user.id).setData(userData)
}
```

**NEW:**
```swift
if isNewUser {
    let newUser = User(
        id: user.id,
        email: user.email,
        fullName: user.displayName ?? "",
        phoneNumber: "", // Will be set during onboarding
        createdAt: Date(),
        isOnboardingComplete: false,
        subscriptionStatus: .trial,
        trialEndDate: Date().addingTimeInterval(14 * 24 * 3600), // 14 days
        quizAnswers: nil,
        profileCount: 0,
        taskCount: 0,
        updatedAt: Date(),
        lastSyncTimestamp: nil
    )
    try await databaseService.createUser(newUser)
}
```

**Location 2: Apple Sign-In (Lines 120-153)**
Apply same pattern.

**Verification:**
1. Test Google Sign-In with new account
2. Test Apple Sign-In with new account
3. Verify user document created in Firestore
4. Check all fields present

**Confidence:** 9/10

---

### Day 3-4: TODO #2 - Implement IDGenerator (4-6 hours)

**Step 1: Add IDGenerator.swift**
✅ Already created at `Halloo/Core/IDGenerator.swift`

**Step 2: Update ProfileViewModel.swift**

**File:** `Halloo/ViewModels/ProfileViewModel.swift`

**Find (Line 557):**
```swift
let profile = ElderlyProfile(
    id: UUID().uuidString,
    userId: userId,
    name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
    phoneNumber: formattedPhone,
    // ...
)
```

**Replace With:**
```swift
let profile = ElderlyProfile(
    id: IDGenerator.profileID(phoneNumber: formattedPhone), // ✅ Use phone as ID
    userId: userId,
    name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
    phoneNumber: formattedPhone,
    // ...
)
```

**Step 3: Update All UUID() Calls**

**Find & Replace Across Project:**

| File | Current | Replace With |
|------|---------|--------------|
| `TaskViewModel.swift:619` | `id: UUID().uuidString` | `id: IDGenerator.habitID()` |
| `DashboardViewModel.swift:722` | `id: UUID().uuidString` | `id: IDGenerator.habitID()` |
| `SMSResponse.swift:130` | `id: UUID().uuidString` | `id: IDGenerator.messageID()` |
| `SMSResponse.swift:164` | `id: UUID().uuidString` | `id: IDGenerator.messageID()` |
| `GalleryHistoryEvent.swift:13` | `id: String = UUID().uuidString` | `id: String = IDGenerator.galleryEventID()` |

**Verification:**
1. Build project (should succeed)
2. Create test profile with phone "+1-555-123-4567"
3. Verify profile ID is "+15551234567" (normalized)
4. Create another profile with same phone
5. Verify it updates existing instead of creating duplicate

**Confidence:** 8/10

---

### Day 4-5: TODO #4 - Recursive Delete Helper (3-4 hours)

**File:** Create `Halloo/Services/FirebaseDatabaseService+Delete.swift`

**New Extension:**
```swift
import Foundation
import Firebase
import FirebaseFirestore

extension FirebaseDatabaseService {

    /// Recursively delete a document and all its subcollections
    /// Handles batching automatically for large datasets
    func deleteDocumentRecursively(
        _ docRef: DocumentReference,
        subcollections: [String]
    ) async throws {
        // Delete all subcollections first
        for collectionName in subcollections {
            try await deleteCollectionRecursively(
                docRef.collection(collectionName)
            )
        }

        // Then delete the document itself
        try await docRef.delete()
    }

    /// Recursively delete all documents in a collection
    /// Handles batch size limits (500 operations per batch)
    private func deleteCollectionRecursively(
        _ collectionRef: CollectionReference,
        batchSize: Int = 500
    ) async throws {
        var hasMore = true

        while hasMore {
            let snapshot = try await collectionRef
                .limit(to: batchSize)
                .getDocuments()

            if snapshot.documents.isEmpty {
                hasMore = false
                continue
            }

            // Delete this batch
            let batch = collectionRef.firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()

            // Check if there are more documents
            hasMore = snapshot.documents.count >= batchSize
        }
    }
}
```

**Update deleteElderlyProfile() in FirebaseDatabaseService.swift:**

**Replace Lines 118-151:**
```swift
func deleteElderlyProfile(_ profileId: String) async throws {
    // Get profile to get userId
    let profileDoc = try await db.collection("profiles").document(profileId).getDocument()
    guard let profileData = profileDoc.data(),
          let userId = profileData["userId"] as? String else {
        throw DatabaseError.documentNotFound
    }

    // ✅ Use recursive delete helper
    try await deleteDocumentRecursively(
        profileDoc.reference,
        subcollections: ["tasks", "responses"]  // Will change to "habits", "messages" in Phase 2
    )

    // Update user's profile count
    try await updateUserProfileCount(userId)
}
```

**Verification:**
1. Create test profile with 5 tasks
2. Delete profile
3. Verify all tasks deleted
4. Verify no orphaned documents

**Confidence:** 9/10

---

## 🧪 WEEK 2: Testing & Migration Prep

### Day 6-7: TODO #7 - Schema Validation Tests (6-8 hours)

**File:** Create `HallooTests/FirebaseSchemaTests.swift`

```swift
import XCTest
@testable import Halloo
import Firebase
import FirebaseFirestore

class FirebaseSchemaTests: XCTestCase {
    var db: Firestore!
    var testUserId: String!

    override func setUp() async throws {
        // Use Firebase emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        db = Firestore.firestore()
        testUserId = "test-user-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        // Clean up test data
        try await cleanupTestData()
    }

    // MARK: - ID Generation Tests

    func testProfileIDUsesPhoneNumber() throws {
        let phone1 = "555-123-4567"
        let phone2 = "+1 (555) 123-4567"

        let id1 = IDGenerator.profileID(phoneNumber: phone1)
        let id2 = IDGenerator.profileID(phoneNumber: phone2)

        XCTAssertEqual(id1, "+15551234567")
        XCTAssertEqual(id1, id2, "Same phone should generate same ID")
    }

    func testHabitIDIsUUID() {
        let id1 = IDGenerator.habitID()
        let id2 = IDGenerator.habitID()

        XCTAssertNotEqual(id1, id2)
        XCTAssertNotNil(UUID(uuidString: id1))
        XCTAssertNotNil(UUID(uuidString: id2))
    }

    // MARK: - Model Sync Tests

    func testUserModelMatchesFirestoreWrites() async throws {
        let user = User(
            id: testUserId,
            email: "test@example.com",
            fullName: "Test User",
            phoneNumber: "+15551234567",
            createdAt: Date(),
            isOnboardingComplete: false,
            subscriptionStatus: .trial,
            trialEndDate: Date().addingTimeInterval(14 * 24 * 3600),
            quizAnswers: nil,
            profileCount: 0,
            taskCount: 0,
            updatedAt: Date(),
            lastSyncTimestamp: nil
        )

        // Create user in Firestore
        let userData = try encodeToFirestore(user)
        try await db.collection("users").document(user.id).setData(userData)

        // Read back
        let doc = try await db.collection("users").document(user.id).getDocument()
        let firestoreFields = Set(doc.data()?.keys ?? [])

        // Get model fields
        let mirror = Mirror(reflecting: user)
        let modelFields = Set(mirror.children.compactMap { $0.label })

        // Compare
        XCTAssertEqual(firestoreFields, modelFields, "User model fields must match Firestore")
    }

    // MARK: - Cascade Delete Tests

    func testDeletingProfileDeletesAllSubcollections() async throws {
        // Create test profile
        let profileId = "+15551234567"
        let profileData: [String: Any] = [
            "id": profileId,
            "userId": testUserId,
            "name": "Test Profile",
            "phoneNumber": profileId,
            "status": "confirmed"
        ]
        try await db.collection("profiles").document(profileId).setData(profileData)

        // Create 3 test tasks
        for i in 1...3 {
            let taskData: [String: Any] = [
                "id": "task-\(i)",
                "profileId": profileId,
                "userId": testUserId,
                "title": "Test Task \(i)"
            ]
            try await db.collection("tasks").document("task-\(i)").setData(taskData)
        }

        // Create 2 test responses
        for i in 1...2 {
            let responseData: [String: Any] = [
                "id": "response-\(i)",
                "profileId": profileId,
                "userId": testUserId,
                "textResponse": "Test Response \(i)"
            ]
            try await db.collection("responses").document("response-\(i)").setData(responseData)
        }

        // Delete profile using service
        let databaseService = FirebaseDatabaseService()
        try await databaseService.deleteElderlyProfile(profileId)

        // Verify all tasks deleted
        let tasksSnapshot = try await db.collection("tasks")
            .whereField("profileId", isEqualTo: profileId)
            .getDocuments()
        XCTAssertEqual(tasksSnapshot.documents.count, 0, "All tasks should be deleted")

        // Verify all responses deleted
        let responsesSnapshot = try await db.collection("responses")
            .whereField("profileId", isEqualTo: profileId)
            .getDocuments()
        XCTAssertEqual(responsesSnapshot.documents.count, 0, "All responses should be deleted")
    }

    // MARK: - Helper Methods

    private func encodeToFirestore<T: Codable>(_ object: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(object)
        let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dictionary ?? [:]
    }

    private func cleanupTestData() async throws {
        // Delete all test documents
        try await db.collection("users").document(testUserId).delete()
    }
}
```

**Setup Firebase Emulator:**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize emulator
firebase init emulators

# Start emulator
firebase emulators:start --only firestore
```

**Run Tests:**
```bash
# In Xcode
Cmd + U

# Or via command line
xcodebuild test -scheme Halloo -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Confidence:** 8/10

---

### Day 8-9: TODO #8 - SwiftLint Rules (2-3 hours)

**File:** Create `.swiftlint.yml` in project root

```yaml
# SwiftLint Configuration for Halloo

disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - explicit_init

included:
  - Halloo/

excluded:
  - Pods/
  - build/
  - HallooTests/

# Custom Schema Validation Rules
custom_rules:
  no_uuid_for_profiles:
    name: "Profiles must use phone number as ID"
    regex: 'ElderlyProfile\([\s\S]*?id:\s*UUID\(\)\.uuidString'
    message: "Use IDGenerator.profileID(phoneNumber:) instead of UUID for profile IDs"
    severity: error
    match_kinds:
      - identifier

  no_uuid_for_users:
    name: "Users must use Firebase Auth UID"
    regex: 'User\([\s\S]*?id:\s*UUID\(\)\.uuidString'
    message: "Use Firebase Auth UID for user IDs, not UUID"
    severity: error

  no_flat_firestore_profiles:
    name: "Use nested subcollections for profiles"
    regex: 'db\.collection\("profiles"\)'
    message: "Profiles should be nested under users: db.collection(\"users/\\(uid)/profiles\")"
    severity: warning  # Warning during migration, will be error after

  no_flat_firestore_tasks:
    name: "Use nested subcollections for tasks"
    regex: 'db\.collection\("tasks"\)'
    message: "Tasks should be nested: db.collection(\"users/\\(uid)/profiles/\\(pid)/habits\")"
    severity: warning

  no_flat_firestore_responses:
    name: "Use nested subcollections for responses"
    regex: 'db\.collection\("responses"\)'
    message: "Responses should be nested: db.collection(\"users/\\(uid)/profiles/\\(pid)/messages\")"
    severity: warning

  require_id_generator:
    name: "Use IDGenerator for ID creation"
    regex: 'id:\s*UUID\(\)\.uuidString(?!.*IDGenerator)'
    message: "Use IDGenerator.habitID(), .messageID(), etc. instead of direct UUID calls"
    severity: warning

  no_manual_firestore_user_creation:
    name: "Use DatabaseService for user creation"
    regex: 'db\.collection\("users"\)\.document\([^)]+\)\.setData\('
    message: "Use databaseService.createUser() instead of manual Firestore writes"
    severity: warning
```

**Install SwiftLint:**
```bash
brew install swiftlint

# Or add to Xcode build phase
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

**Run SwiftLint:**
```bash
swiftlint lint
```

**Expected Output:**
```
⚠️ Warning: Use nested subcollections for profiles (FirebaseDatabaseService.swift:84)
⚠️ Warning: Use nested subcollections for tasks (FirebaseDatabaseService.swift:185)
⚠️ Warning: Use IDGenerator for ID creation (ProfileViewModel.swift:557)
```

**Confidence:** 9/10

---

### Day 10: TODO #6 - Firestore Indexes (1-2 hours)

**File:** Update `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "profiles",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "habits",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "nextScheduledDate", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "profileId", "order": "ASCENDING" },
        { "fieldPath": "receivedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "isCompleted", "order": "ASCENDING" },
        { "fieldPath": "receivedAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Deploy Indexes:**
```bash
firebase deploy --only firestore:indexes
```

**Verification:**
```bash
# Check index status
firebase firestore:indexes
```

**Confidence:** 10/10

---

## 🚀 WEEK 3-4: Migration to Nested Structure

### TODO #1: Migrate to Nested Subcollections (8-12 hours)

**THIS IS THE BIG ONE - BREAKING CHANGE**

---

### Step 1: Create New CollectionPath Enum

**File:** `Halloo/Services/FirebaseDatabaseService.swift`

**Replace Lines 16-24:**
```swift
// ❌ OLD
private enum Collection: String {
    case users = "users"
    case profiles = "profiles"
    case tasks = "tasks"
    case responses = "responses"
    case galleryEvents = "gallery_events"

    var path: String { rawValue }
}
```

**With:**
```swift
// ✅ NEW - Dynamic Path Building
private enum CollectionPath {
    case users
    case userProfiles(userId: String)
    case userGalleryEvents(userId: String)
    case profileHabits(userId: String, profileId: String)
    case profileMessages(userId: String, profileId: String)

    var path: String {
        switch self {
        case .users:
            return "users"

        case .userProfiles(let userId):
            return "users/\(userId)/profiles"

        case .userGalleryEvents(let userId):
            return "users/\(userId)/gallery_events"

        case .profileHabits(let userId, let profileId):
            return "users/\(userId)/profiles/\(profileId)/habits"

        case .profileMessages(let userId, let profileId):
            return "users/\(userId)/profiles/\(profileId)/messages"
        }
    }
}
```

---

### Step 2: Update All Profile Operations

**createElderlyProfile() - Lines 84-90:**
```swift
// ❌ OLD
func createElderlyProfile(_ profile: ElderlyProfile) async throws {
    let profileData = try encodeToFirestore(profile)
    try await db.collection("profiles").document(profile.id).setData(profileData)

    try await updateUserProfileCount(profile.userId)
}

// ✅ NEW
func createElderlyProfile(_ profile: ElderlyProfile) async throws {
    let profileData = try encodeToFirestore(profile)
    let collectionPath = CollectionPath.userProfiles(userId: profile.userId).path
    try await db.collection(collectionPath).document(profile.id).setData(profileData)

    try await updateUserProfileCount(profile.userId)
}
```

**getElderlyProfile() - Lines 92-100:**
```swift
// ❌ OLD
func getElderlyProfile(_ profileId: String) async throws -> ElderlyProfile? {
    let document = try await db.collection("profiles").document(profileId).getDocument()
    // ...
}

// ✅ NEW - Requires userId now!
func getElderlyProfile(_ profileId: String, userId: String) async throws -> ElderlyProfile? {
    let collectionPath = CollectionPath.userProfiles(userId: userId).path
    let document = try await db.collection(collectionPath).document(profileId).getDocument()
    // ...
}
```

**getElderlyProfiles() - Lines 102-111:**
```swift
// ❌ OLD
func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile] {
    let snapshot = try await db.collection("profiles")
        .whereField("userId", isEqualTo: userId)
        .order(by: "createdAt")
        .getDocuments()
    // ...
}

// ✅ NEW - Simpler query (no userId filter needed!)
func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile] {
    let collectionPath = CollectionPath.userProfiles(userId: userId).path
    let snapshot = try await db.collection(collectionPath)
        .order(by: "createdAt")  // No need to filter by userId!
        .getDocuments()
    // ...
}
```

**Continue this pattern for ALL profile operations.**

---

### Step 3: Update All Task/Habit Operations

**createTask() - Lines 185-191:**
```swift
// ✅ NEW
func createTask(_ task: Task) async throws {
    let taskData = try encodeToFirestore(task)
    let collectionPath = CollectionPath.profileHabits(
        userId: task.userId,
        profileId: task.profileId
    ).path
    try await db.collection(collectionPath).document(task.id).setData(taskData)

    try await updateUserTaskCount(task.userId)
}
```

**getProfileTasks() - Lines 203-212:**
```swift
// ✅ NEW - Much simpler!
func getProfileTasks(_ profileId: String, userId: String) async throws -> [Task] {
    let collectionPath = CollectionPath.profileHabits(
        userId: userId,
        profileId: profileId
    ).path

    let snapshot = try await db.collection(collectionPath)
        .order(by: "createdAt")  // No need for userId or profileId filter!
        .getDocuments()

    return try snapshot.documents.map { document in
        try decodeFromFirestore(document.data(), as: Task.self)
    }
}
```

---

### Step 4: Update All Response/Message Operations

Apply same pattern as tasks.

---

### Step 5: Update Security Rules

**File:** `firestore.rules`

**Replace Lines 28-58:**
```javascript
// ✅ NEW - Nested Structure with Inheritance
match /users/{userId} {
  allow read, write: if isAuthenticated() && isOwner(userId);

  // Profiles are automatically scoped to parent user
  match /profiles/{profileId} {
    allow read, write: if isAuthenticated() && isOwner(userId);

    // Habits are automatically scoped to parent profile
    match /habits/{habitId} {
      allow read, write: if isAuthenticated() && isOwner(userId);
    }

    // Messages are automatically scoped to parent profile
    match /messages/{messageId} {
      allow read, write: if isAuthenticated() && isOwner(userId);
    }
  }

  // Gallery events are automatically scoped to parent user
  match /gallery_events/{eventId} {
    allow read, write: if isAuthenticated() && isOwner(userId);
  }
}
```

**Deploy Rules:**
```bash
firebase deploy --only firestore:rules
```

---

### Step 6: Write Migration Script

**File:** Create `migration/migrate-to-nested-structure.js`

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateToNestedStructure() {
  console.log('🚀 Starting migration to nested structure...\n');

  const usersSnapshot = await db.collection('users').get();
  console.log(`📊 Found ${usersSnapshot.size} users to migrate\n`);

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    console.log(`👤 Migrating user: ${userId}`);

    // Migrate profiles
    const profilesSnapshot = await db.collection('profiles')
      .where('userId', '==', userId)
      .get();

    console.log(`  📋 Found ${profilesSnapshot.size} profiles`);

    for (const profileDoc of profilesSnapshot.docs) {
      const profileId = profileDoc.id;
      const profileData = profileDoc.data();

      // Write to new location
      await db.collection(`users/${userId}/profiles`)
        .doc(profileId)
        .set(profileData);

      console.log(`    ✅ Migrated profile: ${profileId}`);

      // Migrate tasks for this profile
      const tasksSnapshot = await db.collection('tasks')
        .where('profileId', '==', profileId)
        .get();

      console.log(`      🔧 Found ${tasksSnapshot.size} tasks`);

      for (const taskDoc of tasksSnapshot.docs) {
        const taskId = taskDoc.id;
        const taskData = taskDoc.data();

        await db.collection(`users/${userId}/profiles/${profileId}/habits`)
          .doc(taskId)
          .set(taskData);

        console.log(`        ✅ Migrated task: ${taskId}`);
      }

      // Migrate responses for this profile
      const responsesSnapshot = await db.collection('responses')
        .where('profileId', '==', profileId)
        .get();

      console.log(`      💬 Found ${responsesSnapshot.size} responses`);

      for (const responseDoc of responsesSnapshot.docs) {
        const responseId = responseDoc.id;
        const responseData = responseDoc.data();

        await db.collection(`users/${userId}/profiles/${profileId}/messages`)
          .doc(responseId)
          .set(responseData);

        console.log(`        ✅ Migrated response: ${responseId}`);
      }
    }

    console.log(`  ✅ Completed user: ${userId}\n`);
  }

  console.log('✅ Migration complete!');
  console.log('\n⚠️  Next steps:');
  console.log('1. Verify data integrity');
  console.log('2. Test app with new structure');
  console.log('3. Delete old collections (profiles, tasks, responses)');
}

// Run migration
migrateToNestedStructure()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  });
```

**Run Migration:**
```bash
cd migration
npm install firebase-admin
node migrate-to-nested-structure.js
```

---

### Step 7: Verification & Testing

**Manual Verification:**
1. Open Firebase Console → Firestore
2. Navigate to `/users/{uid}/profiles`
3. Verify profiles exist
4. Navigate to `/users/{uid}/profiles/{pid}/habits`
5. Verify habits exist
6. Verify old collections still exist (don't delete yet!)

**Automated Verification:**
```bash
# Run schema tests
xcodebuild test -scheme Halloo -destination 'platform=iOS Simulator,name=iPhone 15'

# All tests should pass with new structure
```

**App Testing:**
1. Sign in with test account
2. View existing profiles (should load from new location)
3. Create new profile (should save to new location)
4. Create new habit (should save to new location)
5. Delete profile (should cascade delete habits & messages)

---

### Step 8: Cleanup Old Collections (DANGER ZONE ⚠️)

**Only after 7 days of production monitoring:**

```javascript
// delete-old-collections.js
async function deleteOldCollections() {
  console.log('⚠️  DANGER: Deleting old collections...');

  // Delete old profiles collection
  await deleteCollection(db.collection('profiles'), 500);
  console.log('✅ Deleted profiles collection');

  // Delete old tasks collection
  await deleteCollection(db.collection('tasks'), 500);
  console.log('✅ Deleted tasks collection');

  // Delete old responses collection
  await deleteCollection(db.collection('responses'), 500);
  console.log('✅ Deleted responses collection');

  console.log('✅ Cleanup complete!');
}

async function deleteCollection(collectionRef, batchSize) {
  const query = collectionRef.limit(batchSize);
  return deleteQueryBatch(db, query, batchSize);
}

async function deleteQueryBatch(db, query, batchSize) {
  const snapshot = await query.get();

  if (snapshot.size === 0) {
    return 0;
  }

  const batch = db.batch();
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  if (snapshot.size >= batchSize) {
    return deleteQueryBatch(db, query, batchSize);
  }
}
```

---

## 📊 Migration Checklist

### Pre-Migration
- [ ] Complete TODO #2-#8 (all non-breaking changes)
- [ ] All tests passing
- [ ] Firebase emulator set up
- [ ] Migration script tested with emulator
- [ ] Rollback plan documented
- [ ] Team notified of maintenance window

### Migration Day
- [ ] Create full Firestore backup
- [ ] Deploy new app version with dual-read support
- [ ] Run migration script
- [ ] Verify data integrity (spot checks)
- [ ] Deploy security rules update
- [ ] Test app functionality
- [ ] Monitor error logs for 2 hours

### Post-Migration (Week 1)
- [ ] Daily data integrity checks
- [ ] Monitor user reports
- [ ] Performance monitoring
- [ ] No rollback needed for 7 days

### Cleanup (Week 2)
- [ ] Remove dual-read code
- [ ] Delete old collections
- [ ] Update documentation
- [ ] Post-mortem meeting

---

## 🔄 Rollback Plan

**If migration fails:**

1. **Immediate Rollback (< 2 hours):**
   - Deploy previous app version
   - Old collections still exist (not deleted)
   - Users continue using old structure
   - Debug migration script offline

2. **Partial Rollback (2-24 hours):**
   - Keep new collections
   - Enable dual-read (read from both)
   - Fix migration script
   - Re-run migration for affected users only

3. **Full Rollback (> 24 hours):**
   - Delete new nested collections
   - Keep old flat collections
   - Revert code changes
   - Plan migration 2.0

---

## 🎯 Success Criteria

Migration is successful when:

✅ 100% of user data migrated to new structure
✅ Zero data loss (verified by checksums)
✅ All app functionality works
✅ Security rules properly restrict access
✅ Query performance same or better
✅ No user-reported issues for 7 days
✅ Old collections safely deleted

---

## 📞 Emergency Contacts

**If something goes wrong:**

- **Database Issues:** [DBA Name] - [Phone]
- **App Issues:** [Lead Dev] - [Phone]
- **Firebase Support:** firebase-support@google.com
- **On-Call Engineer:** [Name] - [Phone]

---

**YARRR!** Migration guide complete. Confidence: 8/10

**Proceed with caution - this is a breaking change that requires careful testing!**
