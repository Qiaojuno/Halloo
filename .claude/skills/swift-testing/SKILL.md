---
name: Swift Unit Testing Assistant
description: Generate XCTest unit tests for ViewModels, Services, and business logic in the Halloo iOS app. Use when asked to create tests, write test cases, or when creating new ViewModels or Services that need test coverage.
version: 1.0.0
---

# Swift Unit Testing Assistant for Halloo

This skill provides testing patterns and templates for the Halloo iOS app's MVVM + AppState architecture.

## Core Testing Principles

### Test Coverage Goals
- **ViewModels**: 80%+ code coverage
- **Services**: 90%+ code coverage
- **Critical paths** (SMS, authentication, profile creation): 100%
- **AppState mutations**: 100%

### Testing Philosophy
- Test behavior, not implementation
- **For Halloo MVP**: Test against real Firebase Emulators (NO mock services)
- Use dependency injection via Container
- Test error paths, not just happy paths
- Use realistic data that matches production types

### Firebase Emulator Setup (Critical for Halloo)

**Context:** Halloo has NO mock services (removed in Phase 1 MVP simplification). All testing uses Firebase Emulators.

**Setup Pattern:**
```swift
import XCTest
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
@testable import Halloo

class HallooTestCase: XCTestCase {
    override class func setUp() {
        super.setUp()

        // Configure Firebase for testing
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
    }

    override func setUp() async throws {
        try await super.setUp()

        // Clear Firestore data before each test
        try await clearFirestoreData()
    }

    private func clearFirestoreData() async throws {
        let db = Firestore.firestore()
        // Delete all test data
        // Implementation depends on your test data structure
    }
}
```

**Running Emulators:**
```bash
# Start Firebase emulators
firebase emulators:start --only firestore,auth

# Or in package.json
"scripts": {
  "test": "firebase emulators:exec --only firestore,auth 'xcodebuild test ...'"
}
```

---

## ViewModel Testing Patterns

### Standard ViewModel Test Template

```swift
import XCTest
@testable import Halloo

@MainActor
final class TaskViewModelTests: XCTestCase {
    // System Under Test
    var sut: TaskViewModel!
    var mockContainer: Container!
    var mockAppState: AppState!

    override func setUp() async throws {
        try await super.setUp()
        mockContainer = Container.makeForTesting()
        mockAppState = mockContainer.appState
        sut = TaskViewModel(container: mockContainer)
    }

    override func tearDown() async throws {
        sut = nil
        mockAppState = nil
        mockContainer = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testAddTask_Success() async throws {
        // Given
        let profile = ElderlyProfile(
            id: "profile-1",
            userId: "user-1",
            name: "Grandma",
            phoneNumber: "+15551234567",
            relationship: "grandmother",
            status: .confirmed
        )
        mockAppState.profiles = [profile]

        let task = Task(
            id: "task-1",
            userId: "user-1",
            profileId: profile.id,
            title: "Take medication",
            category: .medication,
            frequency: .daily,
            scheduledTime: Date()
        )

        // When
        sut.addTask(task)

        // Then
        XCTAssertTrue(mockAppState.tasks.contains(where: { $0.id == task.id }))
        XCTAssertNil(sut.errorMessage, "Should not have error on success")
    }

    func testAddTask_ExceedsMaxLimit_ShowsError() async {
        // Given
        let profile = ElderlyProfile(id: "profile-1", userId: "user-1", name: "Test", phoneNumber: "+15551234567", relationship: "test", status: .confirmed)
        mockAppState.profiles = [profile]

        // Create 10 existing tasks (max limit)
        mockAppState.tasks = (1...10).map { index in
            Task(
                id: "task-\(index)",
                userId: "user-1",
                profileId: profile.id,
                title: "Task \(index)",
                category: .medication,
                frequency: .daily,
                scheduledTime: Date()
            )
        }

        let newTask = Task(
            id: "task-11",
            userId: "user-1",
            profileId: profile.id,
            title: "Task 11",
            category: .medication,
            frequency: .daily,
            scheduledTime: Date()
        )

        // When
        sut.addTask(newTask)

        // Then
        XCTAssertEqual(mockAppState.tasks.count, 10, "Should not exceed max tasks")
        XCTAssertNotNil(sut.errorMessage, "Should show error when exceeding limit")
        XCTAssertTrue(sut.errorMessage?.contains("10") ?? false, "Error should mention task limit")
    }
}
```

### Testing Computed Properties from AppState

```swift
func testProfilesProperty_ReturnsAppStateProfiles() {
    // Given
    let profiles = [
        ElderlyProfile(id: "1", userId: "user-1", name: "Test 1", phoneNumber: "+15551111111", relationship: "test", status: .confirmed),
        ElderlyProfile(id: "2", userId: "user-1", name: "Test 2", phoneNumber: "+15552222222", relationship: "test", status: .confirmed)
    ]
    mockAppState.profiles = profiles

    // When
    let result = sut.profiles

    // Then
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].id, "1")
    XCTAssertEqual(result[1].id, "2")
}
```

### Testing Async ViewModel Methods

```swift
func testCreateProfileAsync_Success() async throws {
    // Given
    let profile = ElderlyProfile(
        id: "new-profile",
        userId: "user-1",
        name: "New Profile",
        phoneNumber: "+15559999999",
        relationship: "friend",
        status: .pendingConfirmation
    )

    // When
    await sut.createProfileAsync(profile)

    // Then
    XCTAssertTrue(mockAppState.profiles.contains(where: { $0.id == profile.id }))
    XCTAssertNil(sut.errorMessage)
}

func testCreateProfileAsync_DatabaseError_SetsErrorMessage() async {
    // Given
    let profile = ElderlyProfile(id: "bad-profile", userId: "user-1", name: "Bad", phoneNumber: "invalid", relationship: "test", status: .pendingConfirmation)

    // When
    await sut.createProfileAsync(profile)

    // Then
    XCTAssertNotNil(sut.errorMessage, "Should set error message on failure")
    XCTAssertFalse(mockAppState.profiles.contains(where: { $0.id == profile.id }))
}
```

---

## Service Testing Patterns

### Testing with Firebase Emulators

**Important:** Halloo uses real Firebase services in tests via emulators, NOT mock services.

```swift
import XCTest
@testable import Halloo

final class FirebaseDatabaseServiceTests: HallooTestCase {
    var sut: FirebaseDatabaseService!
    var testUserId: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create test user in Auth Emulator
        let authResult = try await Auth.auth().createUser(
            withEmail: "test@example.com",
            password: "testpass123"
        )
        testUserId = authResult.user.uid

        // Create user document in Firestore Emulator
        try await Firestore.firestore()
            .collection("users")
            .document(testUserId)
            .setData([
                "id": testUserId,
                "email": "test@example.com",
                "profileCount": 0
            ])

        sut = FirebaseDatabaseService()
    }

    override func tearDown() async throws {
        // Cleanup test user
        try await Auth.auth().currentUser?.delete()
        sut = nil
        testUserId = nil
        try await super.tearDown()
    }

    func testFetchProfiles_ReturnsEmptyArray_WhenNoProfiles() async throws {
        // When
        let profiles = try await sut.fetchProfiles(userId: testUserId)

        // Then
        XCTAssertTrue(profiles.isEmpty, "Should return empty array for new user")
    }

    func testSaveProfile_CreatesProfileInNestedCollection() async throws {
        // Given
        let profile = ElderlyProfile(
            id: "test-profile-1",
            userId: testUserId,
            name: "Test Grandma",
            phoneNumber: "+15551234567",
            relationship: "grandmother",
            status: .pendingConfirmation
        )

        // When
        try await sut.saveProfile(profile, userId: testUserId)

        // Then
        let snapshot = try await Firestore.firestore()
            .collection("users/\(testUserId)/profiles")
            .document(profile.id)
            .getDocument()

        XCTAssertTrue(snapshot.exists, "Profile should exist in Firestore")
        let savedProfile = try snapshot.data(as: ElderlyProfile.self)
        XCTAssertEqual(savedProfile.name, "Test Grandma")
    }

    func testDeleteProfile_RemovesFromFirestore() async throws {
        // Given
        let profile = ElderlyProfile.makeMock(userId: testUserId)
        try await sut.saveProfile(profile, userId: testUserId)

        // When
        try await sut.deleteProfile(profileId: profile.id, userId: testUserId)

        // Then
        let profiles = try await sut.fetchProfiles(userId: testUserId)
        XCTAssertFalse(profiles.contains(where: { $0.id == profile.id }))
    }
}
```

### Testing Nested Collection Queries

```swift
func testFetchTasks_OnlyReturnsUserTasks() async throws {
    // Given - Create tasks for two different users
    let user1Id = testUserId!
    let user2Id = "other-user-id"

    let user1Task = Task.makeMock(id: "task-1", userId: user1Id)
    let user2Task = Task.makeMock(id: "task-2", userId: user2Id)

    try await sut.saveTask(user1Task, userId: user1Id)
    try await sut.saveTask(user2Task, userId: user2Id)

    // When
    let user1Tasks = try await sut.fetchTasks(userId: user1Id)

    // Then
    XCTAssertEqual(user1Tasks.count, 1)
    XCTAssertEqual(user1Tasks.first?.id, "task-1")
    XCTAssertTrue(user1Tasks.allSatisfy { $0.userId == user1Id },
                  "Should only return tasks for specified user")
}
```

### Testing Error Handling

```swift
func testSaveProfile_InvalidPhoneNumber_ThrowsError() async {
    // Given
    let invalidProfile = ElderlyProfile(
        id: "bad-profile",
        userId: testUserId,
        name: "Test",
        phoneNumber: "invalid-format",  // Not E.164
        relationship: "test",
        status: .pendingConfirmation
    )

    // When/Then
    do {
        try await sut.saveProfile(invalidProfile, userId: testUserId)
        XCTFail("Should throw validation error for invalid phone number")
    } catch {
        XCTAssertTrue(error is ValidationError || error is DatabaseError)
    }
}

func testFetchProfiles_UnauthenticatedUser_ThrowsError() async {
    // Given
    try? await Auth.auth().signOut()  // Sign out

    // When/Then
    do {
        _ = try await sut.fetchProfiles(userId: "some-user-id")
        XCTFail("Should throw authentication error")
    } catch {
        XCTAssertTrue(error is AuthenticationError)
    }
}
```

---

## Testing Real-Time Listeners

### DataSyncCoordinator Testing

```swift
final class DataSyncCoordinatorTests: HallooTestCase {
    var sut: DataSyncCoordinator!
    var testUserId: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create test user
        let authResult = try await Auth.auth().createUser(
            withEmail: "test@example.com",
            password: "testpass123"
        )
        testUserId = authResult.user.uid

        sut = DataSyncCoordinator()
    }

    func testStartListening_ReceivesProfileUpdates() async throws {
        // Given
        let expectation = expectation(description: "Profile update received")
        var receivedProfiles: [ElderlyProfile] = []

        let cancellable = sut.$profiles
            .dropFirst()  // Skip initial empty value
            .sink { profiles in
                receivedProfiles = profiles
                expectation.fulfill()
            }

        // When
        sut.startListening(userId: testUserId)

        // Add profile to Firestore
        let profile = ElderlyProfile.makeMock(userId: testUserId)
        try await Firestore.firestore()
            .collection("users/\(testUserId)/profiles")
            .document(profile.id)
            .setData(try Firestore.Encoder().encode(profile))

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedProfiles.count, 1)
        XCTAssertEqual(receivedProfiles.first?.id, profile.id)

        cancellable.cancel()
    }

    func testBroadcastProfileUpdate_UpdatesAllListeners() async throws {
        // Given
        sut.startListening(userId: testUserId)

        let profile = ElderlyProfile.makeMock(userId: testUserId)
        try await Firestore.firestore()
            .collection("users/\(testUserId)/profiles")
            .document(profile.id)
            .setData(try Firestore.Encoder().encode(profile))

        // Give listener time to receive initial data
        try await Task.sleep(nanoseconds: 500_000_000)

        // When
        var updatedProfile = profile
        updatedProfile.name = "Updated Name"
        sut.broadcastProfileUpdate(updatedProfile)

        // Then
        try await Task.sleep(nanoseconds: 500_000_000)

        let snapshot = try await Firestore.firestore()
            .collection("users/\(testUserId)/profiles")
            .document(profile.id)
            .getDocument()

        let savedProfile = try snapshot.data(as: ElderlyProfile.self)
        XCTAssertEqual(savedProfile.name, "Updated Name")
    }
}
```

---

## SMS Integration Testing

### Testing TwilioSMSService

**Note:** Use Twilio Test Credentials for unit tests, NOT production credentials.

```swift
final class TwilioSMSServiceTests: XCTestCase {
    var sut: TwilioSMSService!

    override func setUp() {
        super.setUp()
        // Use Twilio test credentials
        sut = TwilioSMSService(
            accountSid: "ACtest_account_sid",
            authToken: "test_auth_token",
            fromNumber: "+15005550006"  // Twilio magic test number
        )
    }

    func testSendTaskReminder_ValidE164Number_Succeeds() async throws {
        // Given
        let validNumber = "+15551234567"
        let task = Task.makeMock(title: "Take medication")
        let profile = ElderlyProfile.makeMock(phoneNumber: validNumber)

        // When
        let messageSid = try await sut.sendTaskReminder(task: task, profile: profile)

        // Then
        XCTAssertFalse(messageSid.isEmpty, "Should return message SID")
        XCTAssertTrue(messageSid.hasPrefix("SM"), "Twilio message SIDs start with SM")
    }

    func testSendTaskReminder_InvalidPhoneFormat_ThrowsError() async {
        // Given
        let invalidNumber = "555-123-4567"  // Not E.164
        let task = Task.makeMock()
        let profile = ElderlyProfile.makeMock(phoneNumber: invalidNumber)

        // When/Then
        do {
            _ = try await sut.sendTaskReminder(task: task, profile: profile)
            XCTFail("Should throw invalid phone number error")
        } catch SMSError.invalidPhoneNumber {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testProcessWebhookResponse_ValidSMS_CreatesResponse() async throws {
        // Given
        let webhookData: [String: String] = [
            "From": "+15551234567",
            "Body": "Done!",
            "MessageSid": "SMtest123"
        ]

        // When
        let response = try sut.processWebhookResponse(webhookData)

        // Then
        XCTAssertEqual(response.textResponse, "Done!")
        XCTAssertEqual(response.responseType, .text)
        XCTAssertNotNil(response.receivedAt)
    }
}
```

### Testing SMS Confirmation Flow

```swift
func testProfileCreation_SendsConfirmationSMS() async throws {
    // Given
    let profile = ElderlyProfile.makeMock(
        phoneNumber: "+15551234567",
        status: .pendingConfirmation
    )

    // When
    await viewModel.createProfileAsync(profile)

    // Then
    // Verify SMS was sent (check Twilio logs or mock)
    // Verify profile status is pendingConfirmation
    XCTAssertTrue(viewModel.appState.profiles.contains(where: {
        $0.id == profile.id && $0.status == .pendingConfirmation
    }))
}

func testSMSConfirmation_UpdatesProfileStatus() async throws {
    // Given
    let profile = ElderlyProfile.makeMock(status: .pendingConfirmation)
    mockAppState.profiles = [profile]

    let confirmationResponse = SMSResponse(
        id: "response-1",
        userId: testUserId,
        profileId: profile.id,
        taskId: nil,
        textResponse: "YES",
        isConfirmationResponse: true,
        isPositiveConfirmation: true,
        receivedAt: Date()
    )

    // When
    await sut.processConfirmationResponse(confirmationResponse)

    // Then
    let updatedProfile = mockAppState.profiles.first { $0.id == profile.id }
    XCTAssertEqual(updatedProfile?.status, .confirmed)
    XCTAssertNotNil(updatedProfile?.confirmedAt)
}
```

---

## Service Testing Patterns

## AppState Testing Patterns

### Testing AppState Mutations

```swift
@MainActor
final class AppStateTests: XCTestCase {
    var sut: AppState!
    var mockContainer: Container!

    override func setUp() async throws {
        try await super.setUp()
        mockContainer = Container.makeForTesting()
        sut = mockContainer.appState
    }

    override func tearDown() async throws {
        sut = nil
        mockContainer = nil
        try await super.tearDown()
    }

    func testAddProfile_AddsToProfilesArray() {
        // Given
        let profile = ElderlyProfile(id: "1", userId: "user-1", name: "Test", phoneNumber: "+15551234567", relationship: "test", status: .confirmed)
        XCTAssertTrue(sut.profiles.isEmpty)

        // When
        sut.addProfile(profile)

        // Then
        XCTAssertEqual(sut.profiles.count, 1)
        XCTAssertEqual(sut.profiles.first?.id, profile.id)
    }

    func testUpdateProfile_ModifiesExistingProfile() {
        // Given
        let originalProfile = ElderlyProfile(id: "1", userId: "user-1", name: "Original", phoneNumber: "+15551234567", relationship: "test", status: .pendingConfirmation)
        sut.profiles = [originalProfile]

        let updatedProfile = ElderlyProfile(id: "1", userId: "user-1", name: "Updated", phoneNumber: "+15551234567", relationship: "test", status: .confirmed)

        // When
        sut.updateProfile(updatedProfile)

        // Then
        XCTAssertEqual(sut.profiles.count, 1)
        XCTAssertEqual(sut.profiles.first?.name, "Updated")
        XCTAssertEqual(sut.profiles.first?.status, .confirmed)
    }

    func testDeleteProfile_RemovesFromArray() {
        // Given
        let profile1 = ElderlyProfile(id: "1", userId: "user-1", name: "Keep", phoneNumber: "+15551111111", relationship: "test", status: .confirmed)
        let profile2 = ElderlyProfile(id: "2", userId: "user-1", name: "Delete", phoneNumber: "+15552222222", relationship: "test", status: .confirmed)
        sut.profiles = [profile1, profile2]

        // When
        sut.deleteProfile(profile2.id)

        // Then
        XCTAssertEqual(sut.profiles.count, 1)
        XCTAssertEqual(sut.profiles.first?.id, profile1.id)
    }

    func testLoadUserData_LoadsAllData() async throws {
        // Given
        sut.currentUser = AuthUser(id: "user-1", email: "test@example.com", displayName: "Test User")

        // When
        await sut.loadUserData()

        // Then
        // Verify data was loaded (actual assertions depend on mock data)
        XCTAssertFalse(sut.isLoading, "Should finish loading")
        // Add more specific assertions based on your mock data
    }
}
```

---

## Mock Data & Test Helpers

### Consistent Test Data

Always use consistent IDs and factory methods for predictable tests:

```swift
// Factory methods in test target
extension ElderlyProfile {
    static func makeMock(
        id: String = "test-profile-\(UUID().uuidString.prefix(8))",
        userId: String = "test-user-1",
        name: String = "Test Grandma",
        phoneNumber: String = "+15551234567",
        status: ProfileStatus = .confirmed
    ) -> ElderlyProfile {
        ElderlyProfile(
            id: id,
            userId: userId,
            name: name,
            phoneNumber: phoneNumber,
            relationship: "grandmother",
            status: status,
            photoURL: nil,
            createdAt: Date(),
            updatedAt: Date(),
            confirmedAt: status == .confirmed ? Date() : nil
        )
    }
}

extension Task {
    static func makeMock(
        id: String = "test-task-\(UUID().uuidString.prefix(8))",
        userId: String = "test-user-1",
        profileId: String = "test-profile-1",
        title: String = "Take medication"
    ) -> Task {
        Task(
            id: id,
            userId: userId,
            profileId: profileId,
            title: title,
            description: "Test description",
            category: .medication,
            frequency: .daily,
            scheduledTime: Date(),
            deadlineMinutes: 10,
            requiresPhoto: false,
            requiresText: true,
            status: .active,
            createdAt: Date(),
            lastModifiedAt: Date()
        )
    }
}
```

### Test Base Class Pattern

```swift
// Base class for all Halloo tests
class HallooTestCase: XCTestCase {
    var testUserId: String!

    override class func setUp() {
        super.setUp()

        // Configure Firebase Emulators once
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.host = "localhost:8080"
        firestoreSettings.cacheSettings = MemoryCacheSettings()
        firestoreSettings.isSSLEnabled = false
        Firestore.firestore().settings = firestoreSettings

        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
    }

    override func setUp() async throws {
        try await super.setUp()

        // Create fresh test user for each test
        let authResult = try await Auth.auth().createUser(
            withEmail: "test-\(UUID().uuidString)@example.com",
            password: "testpass123"
        )
        testUserId = authResult.user.uid

        // Create user document
        try await Firestore.firestore()
            .collection("users")
            .document(testUserId)
            .setData([
                "id": testUserId,
                "email": authResult.user.email ?? "",
                "profileCount": 0,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ])
    }

    override func tearDown() async throws {
        // Cleanup: Delete test user
        try? await Auth.auth().currentUser?.delete()

        // Cleanup: Delete all test data
        if let testUserId = testUserId {
            try? await deleteUserData(userId: testUserId)
        }

        testUserId = nil
        try await super.tearDown()
    }

    private func deleteUserData(userId: String) async throws {
        let db = Firestore.firestore()

        // Delete profiles
        let profiles = try await db.collection("users/\(userId)/profiles").getDocuments()
        for doc in profiles.documents {
            try await doc.reference.delete()
        }

        // Delete tasks
        let tasks = try await db.collection("users/\(userId)/tasks").getDocuments()
        for doc in tasks.documents {
            try await doc.reference.delete()
        }

        // Delete user document
        try await db.collection("users").document(userId).delete()
    }
}
```

### Container for Testing

```swift
// In Container.swift - Testing factory
extension Container {
    static func makeForTesting() -> Container {
        let container = Container()

        // All services point to Firebase Emulators
        // No mock services needed - emulators provide real behavior

        return container
    }
}
```

**Important:** Halloo MVP has NO mock services. All testing uses Firebase Emulators to provide real Firebase behavior in a local, isolated environment.

---

## Test Organization

### File Structure

```
HallooTests/
├── ViewModels/
│   ├── ProfileViewModelTests.swift
│   ├── TaskViewModelTests.swift
│   ├── DashboardViewModelTests.swift
│   └── GalleryViewModelTests.swift
├── Services/
│   ├── FirebaseAuthenticationServiceTests.swift
│   ├── FirebaseDatabaseServiceTests.swift
│   └── TwilioSMSServiceTests.swift
├── Core/
│   ├── AppStateTests.swift
│   └── DataSyncCoordinatorTests.swift
├── Models/
│   ├── ElderlyProfileTests.swift
│   └── TaskTests.swift
└── Mocks/
    ├── MockData+Extensions.swift
    └── MockServices.swift
```

### Test Naming Convention

```swift
// Pattern: test[MethodName]_[Condition]_[ExpectedResult]

func testAddProfile_ValidProfile_AddsToAppState() { }
func testAddProfile_ExceedsLimit_ShowsError() { }
func testDeleteTask_ExistingTask_RemovesFromAppState() { }
func testDeleteTask_NonexistentTask_DoesNothing() { }
```

---

## Testing Async/Await Code

### Proper Async Test Patterns

```swift
// ✅ CORRECT - Using async test method
func testAsyncMethod() async throws {
    let result = try await sut.performAsyncOperation()
    XCTAssertNotNil(result)
}

// ✅ CORRECT - Testing completion handlers
func testCompletionHandler() {
    let expectation = expectation(description: "Completion called")

    sut.performOperation { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
}

// ✅ CORRECT - Testing @Published properties
func testPublishedPropertyUpdates() async {
    let expectation = expectation(description: "Property updated")

    let cancellable = sut.$profiles
        .dropFirst()  // Skip initial value
        .sink { profiles in
            XCTAssertFalse(profiles.isEmpty)
            expectation.fulfill()
        }

    sut.loadProfiles()

    await fulfillment(of: [expectation], timeout: 2.0)
    cancellable.cancel()
}
```

---

## Business Logic Testing

### Testing Validation Rules

```swift
func testProfileValidation_InvalidPhoneNumber_ReturnsFalse() {
    // Given
    let invalidProfile = ElderlyProfile(
        id: "1",
        userId: "user-1",
        name: "Test",
        phoneNumber: "123",  // Invalid format
        relationship: "test",
        status: .pendingConfirmation
    )

    // When
    let isValid = sut.validateProfile(invalidProfile)

    // Then
    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.errorMessage)
}

func testMaxProfileLimit_ExceedsLimit_ReturnsFalse() {
    // Given
    sut.profiles = [
        .makeMock(id: "1"),
        .makeMock(id: "2"),
        .makeMock(id: "3"),
        .makeMock(id: "4")
    ]

    // When
    let canAddMore = sut.canAddProfile()

    // Then
    XCTAssertFalse(canAddMore, "Should not allow more than 4 profiles")
}
```

---

## Integration Testing Patterns

### End-to-End Profile Creation Flow

```swift
final class ProfileCreationFlowTests: HallooTestCase {
    var appState: AppState!
    var profileViewModel: ProfileViewModel!
    var container: Container!

    override func setUp() async throws {
        try await super.setUp()

        container = Container.makeForTesting()
        appState = container.appState
        appState.currentUser = AuthUser(
            id: testUserId,
            email: "test@example.com",
            displayName: "Test User"
        )

        profileViewModel = ProfileViewModel(container: container)
    }

    func testCompleteProfileCreationFlow() async throws {
        // Given - New profile data
        let profile = ElderlyProfile(
            id: UUID().uuidString,
            userId: testUserId,
            name: "Test Grandma",
            phoneNumber: "+15551234567",
            relationship: "grandmother",
            status: .pendingConfirmation
        )

        // When - Create profile (triggers SMS)
        await profileViewModel.createProfileAsync(profile)

        // Then - Verify profile created
        XCTAssertTrue(appState.profiles.contains(where: { $0.id == profile.id }))
        XCTAssertEqual(appState.profiles.first?.status, .pendingConfirmation)

        // Simulate SMS confirmation received
        let confirmationResponse = SMSResponse(
            id: UUID().uuidString,
            userId: testUserId,
            profileId: profile.id,
            taskId: nil,
            textResponse: "YES",
            isConfirmationResponse: true,
            isPositiveConfirmation: true,
            receivedAt: Date()
        )

        // When - Process confirmation
        await appState.processSMSConfirmation(confirmationResponse)

        // Then - Verify profile confirmed
        let confirmedProfile = appState.profiles.first { $0.id == profile.id }
        XCTAssertEqual(confirmedProfile?.status, .confirmed)
        XCTAssertNotNil(confirmedProfile?.confirmedAt)
    }
}
```

### Task Response Workflow Testing

```swift
func testCompleteTaskResponseFlow() async throws {
    // Given - Confirmed profile and active task
    let profile = ElderlyProfile.makeMock(
        userId: testUserId,
        status: .confirmed
    )
    await appState.addProfile(profile)

    let task = Task.makeMock(
        userId: testUserId,
        profileId: profile.id,
        title: "Take morning medication"
    )
    await appState.addTask(task)

    // When - SMS response received
    let smsResponse = SMSResponse(
        id: UUID().uuidString,
        userId: testUserId,
        profileId: profile.id,
        taskId: task.id,
        textResponse: "Done! Feeling good today.",
        photoURL: "https://storage.example.com/photo.jpg",
        isCompleted: true,
        receivedAt: Date(),
        responseType: .both
    )

    await appState.processTaskResponse(smsResponse)

    // Then - Verify response saved and task updated
    XCTAssertTrue(appState.smsResponses.contains(where: { $0.id == smsResponse.id }))

    let updatedTask = appState.tasks.first { $0.id == task.id }
    XCTAssertNotNil(updatedTask?.lastCompletedAt)
    XCTAssertEqual(updatedTask?.completionCount, 1)

    // Verify gallery event created
    XCTAssertTrue(appState.galleryEvents.contains(where: {
        $0.taskId == task.id && $0.photoURL != nil
    }))
}
```

### Multi-Device Sync Testing

```swift
final class MultiDeviceSyncTests: HallooTestCase {
    var device1AppState: AppState!
    var device2AppState: AppState!
    var syncCoordinator1: DataSyncCoordinator!
    var syncCoordinator2: DataSyncCoordinator!

    override func setUp() async throws {
        try await super.setUp()

        // Simulate two devices
        device1AppState = AppState(userId: testUserId)
        device2AppState = AppState(userId: testUserId)

        syncCoordinator1 = DataSyncCoordinator()
        syncCoordinator2 = DataSyncCoordinator()
    }

    func testProfileUpdate_SyncsAcrossDevices() async throws {
        // Given - Both devices listening
        syncCoordinator1.startListening(userId: testUserId)
        syncCoordinator2.startListening(userId: testUserId)

        let profile = ElderlyProfile.makeMock(userId: testUserId)

        // When - Device 1 creates profile
        try await Firestore.firestore()
            .collection("users/\(testUserId)/profiles")
            .document(profile.id)
            .setData(try Firestore.Encoder().encode(profile))

        // Then - Device 2 receives update
        let expectation = expectation(description: "Device 2 receives profile")

        let cancellable = syncCoordinator2.$profiles
            .dropFirst()
            .sink { profiles in
                if profiles.contains(where: { $0.id == profile.id }) {
                    expectation.fulfill()
                }
            }

        await fulfillment(of: [expectation], timeout: 3.0)
        cancellable.cancel()
    }
}
```

---

## Testing Checklist

### Before Running Tests

- [ ] Firebase Emulators are running (`firebase emulators:start`)
- [ ] Firestore Emulator on localhost:8080
- [ ] Auth Emulator on localhost:9099
- [ ] Test environment variables are set (if needed for Twilio test credentials)

### When Writing Tests

- [ ] Test inherits from `HallooTestCase` for proper setup/teardown
- [ ] Test is marked with `@MainActor` if testing `@MainActor` code
- [ ] Uses Firebase Emulators, NOT mock services
- [ ] Tests both success and failure paths
- [ ] Uses realistic test data with proper E.164 phone format
- [ ] Properly cleans up in `tearDown()` (delete test users/data)
- [ ] Uses descriptive test names following convention
- [ ] Tests behavior, not implementation details
- [ ] Includes XCTAssert with descriptive failure messages
- [ ] Tests async code with proper `async`/`await`
- [ ] Verifies error messages are set correctly
- [ ] Tests nested Firestore collection structure
- [ ] Validates E.164 phone number format in SMS tests

---

## Common Testing Patterns

### Testing State Changes

```swift
func testStateTransition_PendingToConfirmed() {
    // Given
    let profile = ElderlyProfile.makeMock(status: .pendingConfirmation)
    sut.profiles = [profile]

    // When
    sut.confirmProfile(profile.id)

    // Then
    let updatedProfile = sut.profiles.first { $0.id == profile.id }
    XCTAssertEqual(updatedProfile?.status, .confirmed)
    XCTAssertNotNil(updatedProfile?.confirmedAt)
}
```

### Testing Side Effects

```swift
func testDeleteProfile_AlsoDeletesAssociatedTasks() {
    // Given
    let profile = ElderlyProfile.makeMock(id: "profile-1")
    let task1 = Task.makeMock(id: "task-1", profileId: "profile-1")
    let task2 = Task.makeMock(id: "task-2", profileId: "profile-1")
    sut.profiles = [profile]
    sut.tasks = [task1, task2]

    // When
    sut.deleteProfile("profile-1")

    // Then
    XCTAssertTrue(sut.profiles.isEmpty)
    XCTAssertTrue(sut.tasks.isEmpty, "Should also delete associated tasks")
}
```

---

## When to Apply This Skill

This skill should be invoked when:
- Asked to "write tests" or "create test cases"
- Creating new ViewModels or Services (suggest tests)
- Reviewing code that lacks test coverage
- Debugging test failures
- Setting up test infrastructure with Firebase Emulators
- Writing integration tests for critical flows (SMS, profile creation)
- Testing async/await code
- Testing business logic and validation rules
- Testing real-time Firestore listeners
- Testing multi-device synchronization via DataSyncCoordinator
- Validating E.164 phone number formatting
- Testing Twilio SMS integration

### Halloo-Specific Testing Priorities

**High Priority (100% Coverage Required):**
- Profile creation and SMS confirmation flow
- Task creation and SMS reminder flow
- E.164 phone number validation
- AppState mutations (add/update/delete)
- DataSyncCoordinator real-time sync
- Business rules (4 profiles max, 10 tasks max)

**Medium Priority (80%+ Coverage):**
- ViewModel business logic
- Firebase service operations
- Error handling and validation
- Authentication flows

**Test with Firebase Emulators, NOT mock services** - Halloo MVP uses real Firebase behavior in tests.
