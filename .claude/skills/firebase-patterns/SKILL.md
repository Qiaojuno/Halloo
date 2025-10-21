---
name: Firebase Patterns for Halloo
description: Enforce Firebase Firestore patterns, Storage usage, and Cloud Functions integration for the Halloo iOS app. Use when working with Firestore queries, Storage uploads, nested collections, security rules, or batch operations.
version: 1.0.0
---

# Firebase Patterns for Halloo

This skill enforces Firebase best practices specific to the Halloo elderly care app's nested collection architecture.

## Halloo Firebase Architecture

**Schema Contract:** Nested subcollections under user documents

```
/users/{firebaseUID}                           ← Top-level (Firebase Auth UID)
  /profiles/{profileId}                        ← Subcollection (elderly profiles)
    /habits/{habitId}                          ← Subcollection (tasks)
    /messages/{messageId}                      ← Subcollection (SMS responses)
  /gallery_events/{eventId}                    ← Subcollection (photo timeline)
```

**Why Nested:**
- ✅ Automatic data scoping to user
- ✅ Simpler security rules (inheritance)
- ✅ Cascade delete support
- ✅ Better data isolation
- ✅ Improved query performance

---

## Critical Pattern 1: CollectionPath Enum (Mandatory)

**Rule:** Never use string literals for Firestore paths. Always use the CollectionPath enum.

```swift
// ❌ WRONG - Hardcoded string paths
db.collection("profiles").document(profileId)
db.collection("tasks").whereField("userId", isEqualTo: userId)

// ❌ WRONG - Manual path construction
db.collection("users/\(userId)/profiles")

// ✅ CORRECT - Use CollectionPath enum
private enum CollectionPath {
    case users
    case userProfiles(userId: String)
    case profileHabits(userId: String, profileId: String)
    case profileMessages(userId: String, profileId: String)
    case userGalleryEvents(userId: String)

    var path: String {
        switch self {
        case .users:
            return "users"
        case .userProfiles(let userId):
            return "users/\(userId)/profiles"
        case .profileHabits(let userId, let profileId):
            return "users/\(userId)/profiles/\(profileId)/habits"
        case .profileMessages(let userId, let profileId):
            return "users/\(userId)/profiles/\(profileId)/messages"
        case .userGalleryEvents(let userId):
            return "users/\(userId)/gallery_events"
        }
    }
}

// Usage in service methods
func fetchProfiles(userId: String) async throws -> [ElderlyProfile] {
    let snapshot = try await db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .getDocuments()

    return snapshot.documents.compactMap { doc in
        try? doc.data(as: ElderlyProfile.self)
    }
}
```

**Benefits:**
- Type-safe path construction
- Compile-time path validation
- Easy to refactor paths
- Documents nested structure

---

## Critical Pattern 2: ID Generation Rules

**Rule:** Use consistent, documented ID strategies for each entity type.

### User Documents
```swift
// ✅ CORRECT - Use Firebase Auth UID
let userId = Auth.auth().currentUser!.uid

// ❌ WRONG - Custom UUID
let userId = UUID().uuidString
```

### Profile Documents
```swift
// ✅ CORRECT - Use normalized phone number as ID (allows upserts)
extension String {
    func normalizedE164() -> String {
        var cleaned = self.filter { $0.isNumber }
        if !cleaned.hasPrefix("1") {
            cleaned = "1" + cleaned
        }
        return "+\(cleaned)"
    }
}

let profileId = phoneNumber.normalizedE164()  // "+15551234567"

// ❌ WRONG - Random UUID (can't find profile by phone later)
let profileId = UUID().uuidString
```

**Why phone numbers as profile IDs:**
- Allows SMS webhook to find profile directly
- Prevents duplicate profiles for same phone
- Enables upsert logic (set with merge)
- Natural unique identifier

### Habit/Task Documents
```swift
// ✅ CORRECT - Use UUID (habits are unique per creation)
let habitId = UUID().uuidString

// ❌ WRONG - Task title as ID (not unique)
let habitId = task.title
```

### Message/Response Documents
```swift
// ✅ OPTION A - Twilio Message SID (if available)
let messageId = twilioMessageSid  // "SMxxxxxxxxxxxxxx"

// ✅ OPTION B - UUID (if SID not available)
let messageId = UUID().uuidString

// ❌ WRONG - Timestamp (not unique, race conditions)
let messageId = String(Date().timeIntervalSince1970)
```

---

## Critical Pattern 3: Nested Collection CRUD

### Creating Documents

```swift
// ✅ CORRECT - Create profile with proper nesting
func saveProfile(_ profile: ElderlyProfile, userId: String) async throws {
    let profileData = try Firestore.Encoder().encode(profile)

    try await db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .document(profile.id)
        .setData(profileData)

    // Update parent user's profile count
    try await db.collection("users").document(userId).updateData([
        "profileCount": FieldValue.increment(Int64(1)),
        "updatedAt": FieldValue.serverTimestamp()
    ])
}

// ✅ CORRECT - Create habit under profile
func saveHabit(_ habit: Task, userId: String, profileId: String) async throws {
    let habitData = try Firestore.Encoder().encode(habit)

    try await db
        .collection(CollectionPath.profileHabits(
            userId: userId,
            profileId: profileId
        ).path)
        .document(habit.id)
        .setData(habitData)
}
```

### Reading Documents

```swift
// ✅ CORRECT - Query habits for a profile
func fetchHabits(userId: String, profileId: String) async throws -> [Task] {
    let snapshot = try await db
        .collection(CollectionPath.profileHabits(
            userId: userId,
            profileId: profileId
        ).path)
        .whereField("status", isEqualTo: "active")
        .order(by: "scheduledTime")
        .getDocuments()

    return snapshot.documents.compactMap { doc in
        try? doc.data(as: Task.self)
    }
}

// ✅ CORRECT - Get all habits across all profiles for a user
func fetchAllUserHabits(userId: String) async throws -> [Task] {
    var allHabits: [Task] = []

    // First, get all profiles
    let profiles = try await fetchProfiles(userId: userId)

    // Then, get habits for each profile
    for profile in profiles {
        let habits = try await fetchHabits(
            userId: userId,
            profileId: profile.id
        )
        allHabits.append(contentsOf: habits)
    }

    return allHabits
}
```

### Updating Documents

```swift
// ✅ CORRECT - Update with server timestamp
func updateProfile(_ profile: ElderlyProfile, userId: String) async throws {
    var updatedProfile = profile
    updatedProfile.updatedAt = Date()  // Local time for immediate UI update

    let profileData = try Firestore.Encoder().encode(updatedProfile)

    try await db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .document(profile.id)
        .setData(profileData, merge: true)
}

// ✅ CORRECT - Partial update
func updateProfileStatus(
    profileId: String,
    userId: String,
    status: ProfileStatus
) async throws {
    try await db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .document(profileId)
        .updateData([
            "status": status.rawValue,
            "confirmedAt": status == .confirmed ? FieldValue.serverTimestamp() : NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
}
```

---

## Critical Pattern 4: Cascade Delete (Recursive)

**Rule:** When deleting a document with subcollections, delete all nested data first.

```swift
// ✅ CORRECT - Recursive delete with subcollections
func deleteProfile(_ profileId: String, userId: String) async throws {
    let profileRef = db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .document(profileId)

    // Delete all subcollections first
    try await deleteSubcollection(
        parent: profileRef,
        collectionName: "habits"
    )
    try await deleteSubcollection(
        parent: profileRef,
        collectionName: "messages"
    )

    // Then delete the profile document
    try await profileRef.delete()

    // Update parent user's profile count
    try await db.collection("users").document(userId).updateData([
        "profileCount": FieldValue.increment(Int64(-1)),
        "updatedAt": FieldValue.serverTimestamp()
    ])
}

// Helper method for deleting subcollections
private func deleteSubcollection(
    parent: DocumentReference,
    collectionName: String
) async throws {
    let snapshot = try await parent
        .collection(collectionName)
        .limit(to: 500)  // Firestore batch limit
        .getDocuments()

    guard !snapshot.documents.isEmpty else { return }

    let batch = db.batch()
    for document in snapshot.documents {
        batch.deleteDocument(document.reference)
    }
    try await batch.commit()

    // Recursively delete remaining documents if >500
    if snapshot.documents.count == 500 {
        try await deleteSubcollection(
            parent: parent,
            collectionName: collectionName
        )
    }
}

// ✅ CORRECT - Delete user with all nested data
func deleteUser(userId: String) async throws {
    // Delete all profiles (which cascades to habits and messages)
    let profiles = try await fetchProfiles(userId: userId)
    for profile in profiles {
        try await deleteProfile(profile.id, userId: userId)
    }

    // Delete gallery events
    try await deleteSubcollection(
        parent: db.collection("users").document(userId),
        collectionName: "gallery_events"
    )

    // Finally delete user document
    try await db.collection("users").document(userId).delete()
}
```

**Why Recursive Delete:**
- Prevents orphaned data
- Handles batch size limits (500 docs)
- Ensures complete cleanup
- Maintains data integrity

---

## Critical Pattern 5: Batch Operations & Transactions

### Batch Writes (Up to 500 Operations)

```swift
// ✅ CORRECT - Batch create multiple habits
func createHabitsBatch(
    habits: [Task],
    userId: String,
    profileId: String
) async throws {
    guard habits.count <= 500 else {
        throw DatabaseError.batchSizeExceeded
    }

    let batch = db.batch()

    for habit in habits {
        let habitRef = db
            .collection(CollectionPath.profileHabits(
                userId: userId,
                profileId: profileId
            ).path)
            .document(habit.id)

        let habitData = try Firestore.Encoder().encode(habit)
        batch.setData(habitData, forDocument: habitRef)
    }

    try await batch.commit()
}
```

### Transactions (Atomic Updates)

```swift
// ✅ CORRECT - Atomic profile count update
func createProfileWithCountUpdate(
    profile: ElderlyProfile,
    userId: String
) async throws {
    try await db.runTransaction { transaction, errorPointer in
        // Read current profile count
        let userRef = self.db.collection("users").document(userId)
        let userDoc = try transaction.getDocument(userRef)

        guard let currentCount = userDoc.data()?["profileCount"] as? Int else {
            let error = NSError(
                domain: "DatabaseError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Profile count not found"]
            )
            errorPointer?.pointee = error
            return nil
        }

        // Validate max profiles
        guard currentCount < 4 else {
            let error = NSError(
                domain: "DatabaseError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Maximum 4 profiles allowed"]
            )
            errorPointer?.pointee = error
            return nil
        }

        // Write profile
        let profileRef = self.db
            .collection(CollectionPath.userProfiles(userId: userId).path)
            .document(profile.id)

        let profileData = try Firestore.Encoder().encode(profile)
        transaction.setData(profileData, forDocument: profileRef)

        // Update count
        transaction.updateData([
            "profileCount": currentCount + 1,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: userRef)

        return nil
    }
}
```

---

## Critical Pattern 6: Real-Time Listeners

### Listener Setup with Cleanup

```swift
// ✅ CORRECT - Listener with proper cleanup
class DataSyncCoordinator: ObservableObject {
    @Published var profiles: [ElderlyProfile] = []
    private var profilesListener: ListenerRegistration?

    func startListening(userId: String) {
        // Remove existing listener first
        stopListening()

        profilesListener = db
            .collection(CollectionPath.userProfiles(userId: userId).path)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.profiles = documents.compactMap { doc in
                    try? doc.data(as: ElderlyProfile.self)
                }
            }
    }

    func stopListening() {
        profilesListener?.remove()
        profilesListener = nil
    }

    deinit {
        stopListening()
    }
}
```

### Listener with Document Changes

```swift
// ✅ CORRECT - Process only changed documents
func observeHabits(userId: String, profileId: String) {
    db.collection(CollectionPath.profileHabits(
        userId: userId,
        profileId: profileId
    ).path)
    .addSnapshotListener { [weak self] snapshot, error in
        guard let snapshot = snapshot else { return }

        snapshot.documentChanges.forEach { change in
            guard let habit = try? change.document.data(as: Task.self) else {
                return
            }

            switch change.type {
            case .added:
                self?.handleHabitAdded(habit)
            case .modified:
                self?.handleHabitModified(habit)
            case .removed:
                self?.handleHabitRemoved(habit)
            }
        }
    }
}
```

---

## Critical Pattern 7: Query Optimization

### Compound Queries with Indexes

```swift
// ✅ CORRECT - Optimized query with index
func fetchActiveHabitsForToday(
    userId: String,
    profileId: String
) async throws -> [Task] {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

    let snapshot = try await db
        .collection(CollectionPath.profileHabits(
            userId: userId,
            profileId: profileId
        ).path)
        .whereField("status", isEqualTo: "active")
        .whereField("nextScheduledDate", isGreaterThanOrEqualTo: today)
        .whereField("nextScheduledDate", isLessThan: tomorrow)
        .order(by: "nextScheduledDate")
        .getDocuments()

    return snapshot.documents.compactMap { try? $0.data(as: Task.self) }
}

// Required Firestore index:
// Collection: habits
// Fields: status (ASC), nextScheduledDate (ASC)
```

### Pagination Pattern

```swift
// ✅ CORRECT - Cursor-based pagination
func fetchMessages(
    userId: String,
    profileId: String,
    limit: Int = 20,
    lastDocument: DocumentSnapshot? = nil
) async throws -> ([SMSResponse], DocumentSnapshot?) {
    var query = db
        .collection(CollectionPath.profileMessages(
            userId: userId,
            profileId: profileId
        ).path)
        .order(by: "receivedAt", descending: true)
        .limit(to: limit)

    // Start after last document for pagination
    if let lastDoc = lastDocument {
        query = query.start(afterDocument: lastDoc)
    }

    let snapshot = try await query.getDocuments()

    let messages = snapshot.documents.compactMap { doc in
        try? doc.data(as: SMSResponse.self)
    }

    let lastDoc = snapshot.documents.last
    return (messages, lastDoc)
}
```

---

## Critical Pattern 8: Firebase Storage (Photos)

### Upload Photo with Progress

```swift
// ✅ CORRECT - Upload photo to Storage
func uploadTaskResponsePhoto(
    image: UIImage,
    userId: String,
    profileId: String,
    taskId: String
) async throws -> String {
    guard let imageData = image.jpegData(compressionQuality: 0.7) else {
        throw StorageError.compressionFailed
    }

    // Use nested path matching Firestore structure
    let path = "users/\(userId)/profiles/\(profileId)/responses/\(taskId).jpg"
    let storageRef = Storage.storage().reference().child(path)

    // Upload with metadata
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    metadata.customMetadata = [
        "userId": userId,
        "profileId": profileId,
        "taskId": taskId,
        "uploadedAt": ISO8601DateFormatter().string(from: Date())
    ]

    _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

    // Get download URL
    let downloadURL = try await storageRef.downloadURL()
    return downloadURL.absoluteString
}

// ✅ CORRECT - Download photo with caching
func downloadPhoto(url: String) async throws -> UIImage {
    // Check cache first
    if let cachedImage = ImageCache.shared.get(url: url) {
        return cachedImage
    }

    let storageRef = Storage.storage().reference(forURL: url)
    let data = try await storageRef.data(maxSize: 10 * 1024 * 1024)  // 10MB max

    guard let image = UIImage(data: data) else {
        throw StorageError.invalidImageData
    }

    // Cache for future use
    ImageCache.shared.set(image: image, url: url)
    return image
}
```

### Delete Photo with Document

```swift
// ✅ CORRECT - Delete photo when deleting message
func deleteMessage(
    messageId: String,
    userId: String,
    profileId: String
) async throws {
    let messageRef = db
        .collection(CollectionPath.profileMessages(
            userId: userId,
            profileId: profileId
        ).path)
        .document(messageId)

    // Get message to find photo URL
    let doc = try await messageRef.getDocument()
    guard let message = try? doc.data(as: SMSResponse.self),
          let photoURL = message.photoURL else {
        // No photo, just delete document
        try await messageRef.delete()
        return
    }

    // Delete photo from Storage
    let storageRef = Storage.storage().reference(forURL: photoURL)
    try await storageRef.delete()

    // Then delete Firestore document
    try await messageRef.delete()
}
```

---

## Critical Pattern 9: Error Handling

### Firestore-Specific Errors

```swift
// ✅ CORRECT - Handle Firestore errors properly
func saveProfile(_ profile: ElderlyProfile, userId: String) async throws {
    do {
        try await db
            .collection(CollectionPath.userProfiles(userId: userId).path)
            .document(profile.id)
            .setData(try Firestore.Encoder().encode(profile))
    } catch let error as NSError {
        switch error.code {
        case FirestoreErrorCode.unavailable.rawValue:
            throw DatabaseError.networkUnavailable
        case FirestoreErrorCode.permissionDenied.rawValue:
            throw DatabaseError.permissionDenied
        case FirestoreErrorCode.notFound.rawValue:
            throw DatabaseError.documentNotFound
        case FirestoreErrorCode.alreadyExists.rawValue:
            throw DatabaseError.documentAlreadyExists
        default:
            print("❌ Firestore Error (\(error.code)): \(error.localizedDescription)")
            throw DatabaseError.writeFailed(error)
        }
    }
}
```

### Retry Logic for Transient Errors

```swift
// ✅ CORRECT - Retry with exponential backoff
func fetchProfilesWithRetry(
    userId: String,
    maxRetries: Int = 3
) async throws -> [ElderlyProfile] {
    var lastError: Error?

    for attempt in 0..<maxRetries {
        do {
            return try await fetchProfiles(userId: userId)
        } catch let error as NSError where error.code == FirestoreErrorCode.unavailable.rawValue {
            lastError = error
            let delay = pow(2.0, Double(attempt))  // 1s, 2s, 4s
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            continue
        } catch {
            throw error  // Non-transient error, fail immediately
        }
    }

    throw lastError ?? DatabaseError.maxRetriesExceeded
}
```

---

## Critical Pattern 10: Security Rules

### Nested Collection Rules

```javascript
// ✅ CORRECT - Security rules for Halloo schema
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // User documents
    match /users/{userId} {
      allow read, write: if isOwner(userId);

      // Profiles subcollection
      match /profiles/{profileId} {
        allow read, write: if isOwner(userId);

        // Habits subcollection
        match /habits/{habitId} {
          allow read, write: if isOwner(userId);
        }

        // Messages subcollection
        match /messages/{messageId} {
          allow read, write: if isOwner(userId);
          // Cloud Functions need write access for SMS webhooks
          allow create: if true;  // Validated in Cloud Function
        }
      }

      // Gallery events subcollection
      match /gallery_events/{eventId} {
        allow read, write: if isOwner(userId);
      }
    }
  }
}
```

**Benefits of nested rules:**
- Automatic userId scoping (inherited from parent)
- No need to check `userId` field in nested docs
- Cleaner, more maintainable rules
- Natural access control hierarchy

---

## Critical Pattern 11: Cloud Functions (SMS Webhooks)

### Twilio Webhook Handler

```javascript
// ✅ CORRECT - Cloud Function for SMS webhook
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.processSMSResponse = functions.https.onRequest(async (req, res) => {
  const { From, Body, MediaUrl0, MessageSid } = req.body;

  // Normalize phone number to match profile ID format
  const profileId = normalizePhoneNumber(From);  // "+15551234567"

  // Find user by profile phone number
  const profilesSnapshot = await admin.firestore()
    .collectionGroup('profiles')
    .where('phoneNumber', '==', profileId)
    .limit(1)
    .get();

  if (profilesSnapshot.empty) {
    console.log(`No profile found for ${profileId}`);
    res.status(404).send('Profile not found');
    return;
  }

  const profileDoc = profilesSnapshot.docs[0];
  const userId = profileDoc.ref.parent.parent.id;  // Get parent user ID
  const profileIdInDoc = profileDoc.id;

  // Save message to nested collection
  const messageRef = admin.firestore()
    .collection(`users/${userId}/profiles/${profileIdInDoc}/messages`)
    .doc();

  await messageRef.set({
    id: messageRef.id,
    userId: userId,
    profileId: profileIdInDoc,
    taskId: null,  // Parse from message context if needed
    textResponse: Body || null,
    photoURL: MediaUrl0 || null,
    isCompleted: true,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    responseType: MediaUrl0 ? (Body ? 'both' : 'photo') : 'text',
    twilioMessageSid: MessageSid
  });

  res.status(200).send('OK');
});

function normalizePhoneNumber(phone) {
  // Remove all non-digits
  let cleaned = phone.replace(/\D/g, '');
  // Add +1 if not present
  if (!cleaned.startsWith('1')) {
    cleaned = '1' + cleaned;
  }
  return '+' + cleaned;
}
```

---

## Critical Pattern 12: Environment Configuration

**Rule:** Always configure Firebase environment explicitly for each context.

### Development Workflow

**Halloo's Firebase Usage:**
- **Local Development (Xcode):** Production Firebase for manual testing with real data
- **SwiftUI Previews:** Production Firebase (no emulator support in previews)
- **Automated Tests (XCTest):** Firebase Emulators for isolated, repeatable tests
- **CI/CD (GitHub Actions):** Firebase Emulators (no production credentials)
- **Production Builds:** Real Firebase with performance monitoring

### Environment Switching Pattern

```swift
// ✅ CORRECT - Environment-aware Firebase configuration
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

enum FirebaseEnvironment {
    case production
    case emulator

    var isEmulator: Bool {
        return self == .emulator
    }
}

class FirebaseConfig {
    static var currentEnvironment: FirebaseEnvironment = .production

    static func configure() {
        // Configure Firebase with GoogleService-Info.plist
        FirebaseApp.configure()

        // Check if we should use emulators
        #if DEBUG
        if shouldUseEmulators() {
            configureEmulators()
            currentEnvironment = .emulator
            print("🧪 Using Firebase Emulators")
        } else {
            configureProduction()
            print("🔥 Using Production Firebase")
        }
        #else
        configureProduction()
        #endif
    }

    private static func shouldUseEmulators() -> Bool {
        // Check environment variable (set in test schemes)
        if ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "true" {
            return true
        }

        // Check if running in XCTest environment
        if NSClassFromString("XCTestCase") != nil {
            return true
        }

        return false
    }

    private static func configureEmulators() {
        // Firestore Emulator
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.host = "localhost:8080"
        firestoreSettings.cacheSettings = MemoryCacheSettings()
        firestoreSettings.isSSLEnabled = false
        Firestore.firestore().settings = firestoreSettings

        // Auth Emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        // Storage Emulator
        Storage.storage().useEmulator(withHost: "localhost", port: 9199)
    }

    private static func configureProduction() {
        // Firestore Production Settings
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.isPersistenceEnabled = true  // Offline cache
        firestoreSettings.cacheSizeBytes = 100 * 1024 * 1024  // 100MB cache
        Firestore.firestore().settings = firestoreSettings

        // Auth persistence (automatic)
        // Storage settings (default)
    }
}

// Usage in App.swift
@main
struct HallooApp: App {
    init() {
        FirebaseConfig.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Test Scheme Configuration

**Xcode Test Scheme Setup:**

1. Edit Scheme → Test → Arguments → Environment Variables
2. Add: `USE_FIREBASE_EMULATOR` = `true`
3. Tests will automatically use emulators

### CI/CD Configuration

```yaml
# .github/workflows/test.yml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v2

      - name: Install Firebase Tools
        run: npm install -g firebase-tools

      - name: Start Firebase Emulators
        run: |
          firebase emulators:start \
            --only firestore,auth,storage \
            --project demo-test &
          sleep 10  # Wait for emulators to start

      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme Halloo \
            -destination 'platform=iOS Simulator,name=iPhone 15'
        env:
          USE_FIREBASE_EMULATOR: true

      - name: Stop Emulators
        run: pkill -f firebase
```

---

## Critical Pattern 13: Offline Persistence (Critical for Elderly Users)

**Rule:** Enable offline persistence for users with poor connectivity.

**Why Critical for Halloo:**
- Elderly users may have unreliable internet
- Family caregivers in areas with poor signal
- SMS responses should be viewable offline
- Task lists must be accessible without connectivity
- Photos should cache for offline viewing

### Offline Cache Configuration

```swift
// ✅ CORRECT - Enable offline persistence
private static func configureProduction() {
    let settings = Firestore.firestore().settings

    // Enable offline cache
    settings.isPersistenceEnabled = true

    // Set cache size (100MB recommended for Halloo)
    // Stores: ~500 profiles, ~5000 tasks, ~10000 messages
    settings.cacheSizeBytes = 100 * 1024 * 1024  // 100MB

    // Garbage collection runs when cache exceeds size
    Firestore.firestore().settings = settings
}

// ❌ WRONG - Disabling cache (bad for elderly users!)
settings.isPersistenceEnabled = false
```

### Offline-Aware Queries

```swift
// ✅ CORRECT - Handle offline gracefully
func fetchHabits(
    userId: String,
    profileId: String
) async throws -> [Task] {
    do {
        let snapshot = try await db
            .collection(CollectionPath.profileHabits(
                userId: userId,
                profileId: profileId
            ).path)
            .getDocuments()

        // Check if data is from cache
        if snapshot.metadata.isFromCache {
            print("📱 Data loaded from offline cache")
        } else {
            print("☁️ Data loaded from server")
        }

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Task.self)
        }
    } catch let error as NSError where error.code == FirestoreErrorCode.unavailable.rawValue {
        // Network unavailable - try to load from cache
        print("⚠️ Network unavailable, loading cached data")

        // Firestore automatically returns cached data if available
        throw DatabaseError.networkUnavailable
    }
}
```

### Optimistic UI Updates

```swift
// ✅ CORRECT - Update UI immediately, sync in background
func updateTaskStatus(
    taskId: String,
    userId: String,
    profileId: String,
    newStatus: TaskStatus
) async throws {
    // Update local AppState immediately (optimistic update)
    await MainActor.run {
        if let index = appState.tasks.firstIndex(where: { $0.id == taskId }) {
            appState.tasks[index].status = newStatus
        }
    }

    // Sync to Firestore in background
    _Concurrency.Task {
        do {
            try await db
                .collection(CollectionPath.profileHabits(
                    userId: userId,
                    profileId: profileId
                ).path)
                .document(taskId)
                .updateData([
                    "status": newStatus.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            // Revert optimistic update on failure
            await MainActor.run {
                if let index = appState.tasks.firstIndex(where: { $0.id == taskId }) {
                    appState.tasks[index].status = .active  // Revert
                }
            }
            print("❌ Failed to sync status: \(error)")
        }
    }
}
```

### Cache-First Strategy

```swift
// ✅ CORRECT - Prefer cache, fallback to network
func fetchProfilesWithCacheFirst(userId: String) async throws -> [ElderlyProfile] {
    // Try cache first (instant)
    do {
        let snapshot = try await db
            .collection(CollectionPath.userProfiles(userId: userId).path)
            .getDocuments(source: .cache)

        if !snapshot.documents.isEmpty {
            print("📱 Loaded profiles from cache")
            return snapshot.documents.compactMap { try? $0.data(as: ElderlyProfile.self) }
        }
    } catch {
        print("⚠️ Cache miss, fetching from server")
    }

    // Fallback to server
    let snapshot = try await db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .getDocuments(source: .server)

    return snapshot.documents.compactMap { try? $0.data(as: ElderlyProfile.self) }
}
```

### Offline Photo Caching

```swift
// ✅ CORRECT - Cache photos locally
class PhotoCache {
    static let shared = PhotoCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("photos")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func cache(image: UIImage, url: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? data.write(to: fileURL)
    }

    func get(url: String) -> UIImage? {
        let filename = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func clearOldCache(olderThan days: Int = 30) {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)

        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        for file in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                  let modificationDate = attributes[.modificationDate] as? Date,
                  modificationDate < cutoffDate else {
                continue
            }
            try? fileManager.removeItem(at: file)
        }
    }
}
```

---

## Critical Pattern 14: Performance Monitoring

**Rule:** Track performance of critical operations to identify bottlenecks.

### Firebase Performance Setup

```swift
import FirebasePerformance

// ✅ CORRECT - Track critical database operations
func fetchHabitsWithTracking(
    userId: String,
    profileId: String
) async throws -> [Task] {
    let trace = Performance.startTrace(name: "fetch_habits")
    trace?.setValue(userId, forAttribute: "user_id")
    trace?.setValue(profileId, forAttribute: "profile_id")

    defer {
        trace?.stop()
    }

    do {
        let habits = try await fetchHabits(userId: userId, profileId: profileId)
        trace?.setValue(String(habits.count), forAttribute: "habit_count")
        trace?.incrementMetric("success_count", by: 1)
        return habits
    } catch {
        trace?.incrementMetric("error_count", by: 1)
        throw error
    }
}
```

### Custom Traces for User Flows

```swift
// ✅ CORRECT - Track complete user flows
func createProfileFlow(profile: ElderlyProfile, userId: String) async throws {
    let trace = Performance.startTrace(name: "profile_creation_flow")
    trace?.setValue(userId, forAttribute: "user_id")

    let startTime = Date()

    do {
        // Step 1: Validate phone
        trace?.incrementMetric("validation_started", by: 1)
        guard profile.phoneNumber.isValidE164PhoneNumber else {
            trace?.incrementMetric("validation_failed", by: 1)
            throw ValidationError.invalidPhoneNumber
        }

        // Step 2: Create profile in Firestore
        trace?.incrementMetric("firestore_write_started", by: 1)
        try await saveProfile(profile, userId: userId)
        trace?.incrementMetric("firestore_write_completed", by: 1)

        // Step 3: Send SMS confirmation
        trace?.incrementMetric("sms_send_started", by: 1)
        try await smsService.sendConfirmation(to: profile.phoneNumber)
        trace?.incrementMetric("sms_send_completed", by: 1)

        // Track total duration
        let duration = Date().timeIntervalSince(startTime)
        trace?.setValue(String(format: "%.2f", duration), forAttribute: "total_duration_seconds")

        trace?.stop()
    } catch {
        trace?.incrementMetric("error_count", by: 1)
        trace?.setValue(String(describing: error), forAttribute: "error_type")
        trace?.stop()
        throw error
    }
}
```

### Automatic HTTP Tracing

```swift
// ✅ CORRECT - Automatic tracing for network requests
// Firebase Performance automatically tracks:
// - URLSession requests
// - Firebase SDK operations
// - App startup time
// - Screen rendering

// Just ensure Performance is initialized
import FirebasePerformance

@main
struct HallooApp: App {
    init() {
        FirebaseApp.configure()
        // Performance monitoring starts automatically
    }
}
```

### Monitor Specific Metrics

```swift
// ✅ CORRECT - Track SMS webhook processing time
func processSMSWebhook(data: [String: String]) async throws {
    let trace = Performance.startTrace(name: "sms_webhook_processing")

    defer { trace?.stop() }

    // Track parsing time
    let parseStart = Date()
    let response = try parseSMSResponse(data)
    let parseTime = Date().timeIntervalSince(parseStart)
    trace?.setValue(String(format: "%.3f", parseTime), forAttribute: "parse_time_seconds")

    // Track Firestore write time
    let writeStart = Date()
    try await saveMessage(response)
    let writeTime = Date().timeIntervalSince(writeStart)
    trace?.setValue(String(format: "%.3f", writeTime), forAttribute: "write_time_seconds")

    // Track if message had photo
    trace?.setValue(response.photoURL != nil ? "true" : "false", forAttribute: "has_photo")
}
```

---

## Critical Pattern 15: Cost Optimization

**Rule:** Minimize Firestore reads, writes, and bandwidth to reduce costs.

**Halloo Cost Considerations:**
- 🔴 **High cost:** Gallery photos (Storage bandwidth)
- 🟡 **Medium cost:** SMS responses (Firestore writes)
- 🟢 **Low cost:** Profile queries (cached, infrequent)

### Optimize Queries with Limits

```swift
// ❌ EXPENSIVE - Reads all habits (could be 1000+)
let habits = try await db
    .collection(CollectionPath.profileHabits(userId: userId, profileId: profileId).path)
    .getDocuments()
// Cost: 1000 reads if 1000 habits exist

// ✅ CHEAP - Only reads what's needed
let activeHabits = try await db
    .collection(CollectionPath.profileHabits(userId: userId, profileId: profileId).path)
    .whereField("status", isEqualTo: "active")
    .whereField("nextScheduledDate", isLessThanOrEqualTo: Date())
    .limit(to: 50)
    .getDocuments()
// Cost: 50 reads maximum
```

### Use Cache When Possible

```swift
// ❌ EXPENSIVE - Always fetches from server
let profiles = try await db
    .collection(CollectionPath.userProfiles(userId: userId).path)
    .getDocuments(source: .server)

// ✅ CHEAP - Uses cache if available (0 reads if cached)
let profiles = try await db
    .collection(CollectionPath.userProfiles(userId: userId).path)
    .getDocuments(source: .default)  // Cache first, then server
```

### Batch Writes Instead of Individual

```swift
// ❌ EXPENSIVE - 10 separate writes
for habit in habits {
    try await db.collection("...").document(habit.id).setData(...)
}
// Cost: 10 writes

// ✅ CHEAP - 1 batch write
let batch = db.batch()
for habit in habits {
    let ref = db.collection("...").document(habit.id)
    batch.setData(try Firestore.Encoder().encode(habit), forDocument: ref)
}
try await batch.commit()
// Cost: 10 writes (same cost, but atomic + faster)
```

### Storage Optimization for Photos

```swift
// ❌ EXPENSIVE - Upload full resolution (5MB photo)
let imageData = image.jpegData(compressionQuality: 1.0)
// Cost: 5MB upload + 5MB storage

// ✅ CHEAP - Compress before upload (500KB photo)
let maxDimension: CGFloat = 1920  // Max width/height
let resizedImage = image.resized(toMaxDimension: maxDimension)
let imageData = resizedImage.jpegData(compressionQuality: 0.7)
// Cost: 500KB upload + 500KB storage (10x cheaper!)

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized ?? self
    }
}
```

### Aggregate Data to Reduce Reads

```swift
// ❌ EXPENSIVE - Read all habits to count (100 reads)
let habits = try await db
    .collection(CollectionPath.profileHabits(userId: userId, profileId: profileId).path)
    .getDocuments()
let completedCount = habits.documents.filter {
    ($0.data()["status"] as? String) == "completed"
}.count
// Cost: 100 reads

// ✅ CHEAP - Store count in profile document (1 read)
let profileDoc = try await db
    .collection(CollectionPath.userProfiles(userId: userId).path)
    .document(profileId)
    .getDocument()
let completedCount = profileDoc.data()?["completedHabitCount"] as? Int ?? 0
// Cost: 1 read

// Update count when habit status changes
func completeHabit(habitId: String, userId: String, profileId: String) async throws {
    try await db.runTransaction { transaction, errorPointer in
        // Update habit status
        let habitRef = self.db
            .collection(CollectionPath.profileHabits(userId: userId, profileId: profileId).path)
            .document(habitId)
        transaction.updateData(["status": "completed"], forDocument: habitRef)

        // Increment count
        let profileRef = self.db
            .collection(CollectionPath.userProfiles(userId: userId).path)
            .document(profileId)
        transaction.updateData([
            "completedHabitCount": FieldValue.increment(Int64(1))
        ], forDocument: profileRef)

        return nil
    }
}
```

### Pagination to Avoid Large Reads

```swift
// ❌ EXPENSIVE - Load all 10,000 gallery events at once
let allEvents = try await db
    .collection(CollectionPath.userGalleryEvents(userId: userId).path)
    .getDocuments()
// Cost: 10,000 reads

// ✅ CHEAP - Load 20 at a time with pagination
func fetchGalleryPage(
    userId: String,
    pageSize: Int = 20,
    lastDocument: DocumentSnapshot? = nil
) async throws -> ([GalleryHistoryEvent], DocumentSnapshot?) {
    var query = db
        .collection(CollectionPath.userGalleryEvents(userId: userId).path)
        .order(by: "timestamp", descending: true)
        .limit(to: pageSize)

    if let lastDoc = lastDocument {
        query = query.start(afterDocument: lastDoc)
    }

    let snapshot = try await query.getDocuments()
    let events = snapshot.documents.compactMap { try? $0.data(as: GalleryHistoryEvent.self) }

    return (events, snapshot.documents.last)
}
// Cost: 20 reads per page (user only loads what they view)
```

### Cost Monitoring Dashboard

```swift
// ✅ GOOD PRACTICE - Log expensive operations in development
#if DEBUG
func logFirestoreCost(operation: String, documentCount: Int) {
    let cost = Double(documentCount) * 0.000036  // $0.036 per 100k reads
    print("💰 Firestore Cost - \(operation): \(documentCount) docs = $\(String(format: "%.6f", cost))")
}
#endif
```

---

## Testing Patterns

### Firebase Emulator Setup

```swift
// ✅ CORRECT - Configure emulators in tests
class HallooTestCase: XCTestCase {
    override class func setUp() {
        super.setUp()

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Connect to Firestore Emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        // Connect to Auth Emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        // Connect to Storage Emulator
        Storage.storage().useEmulator(withHost: "localhost", port: 9199)
    }
}
```

### Test Nested Collection Queries

```swift
func testNestedCollectionQuery() async throws {
    // Create test data
    let userId = "test-user"
    let profileId = "+15551234567"

    // Create profile
    try await db
        .collection(CollectionPath.userProfiles(userId: userId).path)
        .document(profileId)
        .setData([
            "id": profileId,
            "userId": userId,
            "name": "Test Profile"
        ])

    // Create habit under profile
    let habitId = UUID().uuidString
    try await db
        .collection(CollectionPath.profileHabits(
            userId: userId,
            profileId: profileId
        ).path)
        .document(habitId)
        .setData([
            "id": habitId,
            "userId": userId,
            "profileId": profileId,
            "title": "Test Habit"
        ])

    // Query habits
    let habits = try await sut.fetchHabits(
        userId: userId,
        profileId: profileId
    )

    XCTAssertEqual(habits.count, 1)
    XCTAssertEqual(habits.first?.id, habitId)
}
```

---

## Common Violations to Flag

### Critical Issues (Must Fix)

- ❌ Using flat collections instead of nested
- ❌ Hardcoded collection path strings
- ❌ Not using phone number as profile ID
- ❌ Missing cascade delete for subcollections
- ❌ Not handling Firestore errors properly
- ❌ Forgetting to update parent counts
- ❌ Listeners without cleanup (memory leaks)
- ❌ Batch operations exceeding 500 documents
- ❌ Missing server timestamps
- ❌ Storage paths not matching Firestore structure
- ❌ **Offline persistence disabled in production**
- ❌ **Using production Firebase in automated tests**
- ❌ **No environment configuration (hardcoded to production)**
- ❌ **Uploading full-resolution photos (>2MB)**
- ❌ **Queries without limits (unbounded reads)**

### Medium Issues (Should Fix)

- ⚠️ Not using transactions for atomic updates
- ⚠️ Missing retry logic for transient errors
- ⚠️ No pagination for large result sets
- ⚠️ Not caching downloaded photos
- ⚠️ Missing metadata on Storage uploads
- ⚠️ Not using compound indexes for complex queries
- ⚠️ **No performance traces on critical operations**
- ⚠️ **Not using cache-first strategy**
- ⚠️ **Missing optimistic UI updates**
- ⚠️ **Aggregate counts calculated via queries instead of stored**

---

## Code Review Checklist

When reviewing Firebase code, verify:

- [ ] Uses `CollectionPath` enum, never string literals
- [ ] Profile IDs use normalized phone numbers
- [ ] All paths follow nested structure (users/{uid}/profiles/{pid}/...)
- [ ] Cascade delete implemented for documents with subcollections
- [ ] Batch operations stay under 500 documents
- [ ] Server timestamps used for `createdAt`/`updatedAt`
- [ ] Listeners have proper cleanup in `deinit`
- [ ] Storage paths mirror Firestore structure
- [ ] Photos deleted from Storage when documents deleted
- [ ] Error handling covers Firestore-specific errors
- [ ] Transactions used for atomic count updates
- [ ] Security rules enforce nested access control
- [ ] Indexes documented for compound queries
- [ ] **Environment configuration correct for context (emulator vs production)**
- [ ] **Offline persistence enabled for production builds**
- [ ] **Performance traces added for critical operations**
- [ ] **Queries use limits to control read costs**
- [ ] **Photos compressed before upload (max 1920px, 0.7 quality)**
- [ ] **Pagination implemented for large result sets**
- [ ] **Cache-first strategy for frequently accessed data**

---

## When to Apply This Skill

This skill should be invoked when:
- Writing Firestore queries or mutations
- Creating new collection paths
- Implementing delete operations
- Setting up real-time listeners
- Uploading/downloading photos to Storage
- Writing Cloud Functions for webhooks
- Creating or updating security rules
- Implementing batch or transaction operations
- Debugging Firestore errors
- Reviewing database-related code
- Setting up Firebase Emulators for testing
- Optimizing query performance
- Working on SMS response processing
- **Configuring Firebase environment (dev/test/prod)**
- **Implementing offline support for poor connectivity**
- **Adding performance monitoring to critical flows**
- **Optimizing costs (reads/writes/bandwidth)**
- **Setting up CI/CD with Firebase Emulators**
- **Implementing photo caching for offline viewing**
- **Creating optimistic UI updates for better UX**
