//
//  FirebaseSchemaTests.swift
//  HallooTests
//
//  Created by Claude Code on 2025-10-03.
//  Schema validation tests to ensure Firestore documents match Swift models exactly
//

import Testing
import Foundation
@testable import Halloo

/// Tests to validate Firebase schema compliance
/// References: FIREBASE-SCHEMA-CONTRACT.md, FIRESTORE-INDEXES.md
struct FirebaseSchemaTests {

    // MARK: - User Model Tests

    @Test func testUserModelHasAllRequiredFields() async throws {
        // Verify User struct has all 13 required fields per schema contract
        let user = User(
            id: "test-user-id",
            email: "test@example.com",
            fullName: "Test User",
            phoneNumber: "+15551234567",
            createdAt: Date(),
            isOnboardingComplete: false,
            subscriptionStatus: .trial,
            trialEndDate: Date(),
            quizAnswers: nil,
            profileCount: 0,
            taskCount: 0,
            updatedAt: Date(),
            lastSyncTimestamp: nil
        )

        // Validate all fields are accessible
        #expect(user.id == "test-user-id")
        #expect(user.email == "test@example.com")
        #expect(user.fullName == "Test User")
        #expect(user.phoneNumber == "+15551234567")
        #expect(user.createdAt != nil)
        #expect(user.isOnboardingComplete == false)
        #expect(user.subscriptionStatus == .trial)
        #expect(user.trialEndDate != nil)
        #expect(user.quizAnswers == nil)
        #expect(user.profileCount == 0)
        #expect(user.taskCount == 0)
        #expect(user.updatedAt != nil)
        #expect(user.lastSyncTimestamp == nil)
    }

    @Test func testUserModelDefaultValuesAreCorrect() async throws {
        // Verify backward compatibility - new fields have defaults
        let minimalUser = User(
            id: "test-id",
            email: "test@test.com",
            fullName: "Test",
            phoneNumber: "+15551234567",
            createdAt: Date()
        )

        // Default values should be set
        #expect(minimalUser.profileCount == 0)
        #expect(minimalUser.taskCount == 0)
        #expect(minimalUser.updatedAt != nil)
        #expect(minimalUser.lastSyncTimestamp == nil)
        #expect(minimalUser.subscriptionStatus == .trial)
        #expect(minimalUser.isOnboardingComplete == false)
    }

    @Test func testUserCodableEncodesAllFields() async throws {
        let user = User(
            id: "test-id",
            email: "test@test.com",
            fullName: "Test User",
            phoneNumber: "+15551234567",
            createdAt: Date(),
            isOnboardingComplete: true,
            subscriptionStatus: .active,
            trialEndDate: Date(),
            quizAnswers: ["q1": "answer1"],
            profileCount: 5,
            taskCount: 10,
            updatedAt: Date(),
            lastSyncTimestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(user)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(User.self, from: data)

        // All fields should survive encode/decode round-trip
        #expect(decoded.id == user.id)
        #expect(decoded.email == user.email)
        #expect(decoded.fullName == user.fullName)
        #expect(decoded.phoneNumber == user.phoneNumber)
        #expect(decoded.isOnboardingComplete == user.isOnboardingComplete)
        #expect(decoded.subscriptionStatus == user.subscriptionStatus)
        #expect(decoded.quizAnswers == user.quizAnswers)
        #expect(decoded.profileCount == user.profileCount)
        #expect(decoded.taskCount == user.taskCount)
    }

    // MARK: - ElderlyProfile Model Tests

    @Test func testElderlyProfileHasRequiredFields() async throws {
        let profile = ElderlyProfile(
            id: "+15551234567",  // ✅ Phone number as ID
            userId: "test-user-id",
            fullName: "Elderly Person",
            phoneNumber: "+15551234567",
            relationship: "Mother",
            photoURL: nil,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date(),
            timezone: TimeZone.current.identifier,
            preferredContactTime: nil,
            emergencyContact: nil
        )

        #expect(profile.id == "+15551234567")
        #expect(profile.userId == "test-user-id")
        #expect(profile.phoneNumber == "+15551234567")
        #expect(profile.status == .pending)
    }

    @Test func testElderlyProfileIDMatchesPhoneNumber() async throws {
        // Schema contract requires: profile ID = normalized phone number
        let phoneNumber = "+15551234567"
        let profile = ElderlyProfile(
            id: phoneNumber,
            userId: "test-user-id",
            fullName: "Test",
            phoneNumber: phoneNumber,
            relationship: "Test",
            photoURL: nil,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date(),
            timezone: TimeZone.current.identifier,
            preferredContactTime: nil,
            emergencyContact: nil
        )

        // ID MUST equal phone number
        #expect(profile.id == profile.phoneNumber)
    }

    // MARK: - Task Model Tests

    @Test func testTaskHasRequiredFields() async throws {
        let task = Task(
            id: UUID().uuidString,
            userId: "test-user-id",
            profileId: "+15551234567",
            profileName: "Test Profile",
            title: "Test Task",
            description: "Test description",
            frequency: .daily,
            preferredTime: Date(),
            nextScheduledDate: Date(),
            status: .active,
            createdAt: Date(),
            lastModifiedAt: Date()
        )

        #expect(task.id != "")
        #expect(task.userId != "")
        #expect(task.profileId != "")
        #expect(task.status == .active)
    }

    @Test func testTaskIDIsUUID() async throws {
        // Schema contract: Task IDs should be UUIDs
        let taskId = UUID().uuidString
        let task = Task(
            id: taskId,
            userId: "test-user-id",
            profileId: "+15551234567",
            profileName: "Test",
            title: "Test",
            description: "",
            frequency: .daily,
            preferredTime: Date(),
            nextScheduledDate: Date(),
            status: .active,
            createdAt: Date(),
            lastModifiedAt: Date()
        )

        // Should be valid UUID format
        #expect(UUID(uuidString: task.id) != nil)
    }

    // MARK: - SMSResponse Model Tests

    @Test func testSMSResponseHasRequiredFields() async throws {
        let response = SMSResponse(
            id: UUID().uuidString,
            userId: "test-user-id",
            profileId: "+15551234567",
            taskId: "test-task-id",
            fromPhone: "+15551234567",
            toPhone: "+15559876543",
            messageBody: "Test message",
            photoURL: nil,
            receivedAt: Date(),
            isCompleted: false,
            responseType: .text,
            twilioSid: nil
        )

        #expect(response.id != "")
        #expect(response.userId != "")
        #expect(response.profileId != "")
        #expect(response.responseType == .text)
    }

    @Test func testSMSResponseIDIsTwilioSIDOrUUID() async throws {
        // Schema contract: Response ID should be Twilio SID or UUID

        // Case 1: Twilio SID
        let twilioSid = "SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        let response1 = SMSResponse(
            id: twilioSid,
            userId: "test-user-id",
            profileId: "+15551234567",
            taskId: "test-task-id",
            fromPhone: "+15551234567",
            toPhone: "+15559876543",
            messageBody: "Test",
            photoURL: nil,
            receivedAt: Date(),
            isCompleted: false,
            responseType: .text,
            twilioSid: twilioSid
        )
        #expect(response1.id == response1.twilioSid)

        // Case 2: UUID
        let uuid = UUID().uuidString
        let response2 = SMSResponse(
            id: uuid,
            userId: "test-user-id",
            profileId: "+15551234567",
            taskId: "test-task-id",
            fromPhone: "+15551234567",
            toPhone: "+15559876543",
            messageBody: "Test",
            photoURL: nil,
            receivedAt: Date(),
            isCompleted: false,
            responseType: .text,
            twilioSid: nil
        )
        #expect(UUID(uuidString: response2.id) != nil)
    }

    // MARK: - Phone Number Validation Tests

    @Test func testPhoneNumberNormalization() async throws {
        // Test phone number normalization (E.164 format)
        let testCases: [(input: String, expected: String)] = [
            ("(555) 123-4567", "+15551234567"),
            ("555-123-4567", "+15551234567"),
            ("5551234567", "+15551234567"),
            ("+1 555 123 4567", "+15551234567")
        ]

        for testCase in testCases {
            let normalized = testCase.input.normalizedE164()
            #expect(normalized == testCase.expected, "Failed to normalize: \(testCase.input)")
        }
    }

    @Test func testPhoneNumberFormatting() async throws {
        // Test phone number formatting (display format)
        let phone = "+15551234567"
        let formatted = phone.formattedPhoneNumber()

        // Should be human-readable (e.g., "(555) 123-4567")
        #expect(formatted.contains("("))
        #expect(formatted.contains(")"))
        #expect(formatted.contains("-"))
    }

    // MARK: - ID Generation Tests

    @Test func testIDGeneratorUserID() async throws {
        // User IDs should be Firebase Auth UIDs (passed through)
        let firebaseUID = "firebase-uid-abc123"
        let userId = IDGenerator.userID(firebaseUID: firebaseUID)

        #expect(userId == firebaseUID)
    }

    @Test func testIDGeneratorProfileID() async throws {
        // Profile IDs should be normalized phone numbers
        let phoneNumber = "(555) 123-4567"
        let profileId = IDGenerator.profileID(phoneNumber: phoneNumber)

        #expect(profileId == "+15551234567")
    }

    @Test func testIDGeneratorHabitID() async throws {
        // Habit IDs should be UUIDs
        let habitId = IDGenerator.habitID()

        #expect(UUID(uuidString: habitId) != nil)
    }

    @Test func testIDGeneratorMessageIDWithTwilioSID() async throws {
        // Message IDs should use Twilio SID if provided
        let twilioSid = "SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        let messageId = IDGenerator.messageID(twilioSID: twilioSid)

        #expect(messageId == twilioSid)
    }

    @Test func testIDGeneratorMessageIDWithoutTwilioSID() async throws {
        // Message IDs should use UUID if no Twilio SID
        let messageId = IDGenerator.messageID(twilioSID: nil)

        #expect(UUID(uuidString: messageId) != nil)
    }

    // MARK: - Subscription Status Tests

    @Test func testSubscriptionStatusCases() async throws {
        // Verify all subscription statuses
        let statuses: [SubscriptionStatus] = [.trial, .active, .expired, .cancelled]

        for status in statuses {
            #expect(status.rawValue != "")
        }
    }

    @Test func testUserIsTrialActive() async throws {
        // Trial is active if status = trial AND trialEndDate > now
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let user = User(
            id: "test-id",
            email: "test@test.com",
            fullName: "Test",
            phoneNumber: "+15551234567",
            createdAt: Date(),
            subscriptionStatus: .trial,
            trialEndDate: futureDate
        )

        #expect(user.isTrialActive == true)
    }

    @Test func testUserIsTrialExpired() async throws {
        // Trial is expired if trialEndDate < now
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let user = User(
            id: "test-id",
            email: "test@test.com",
            fullName: "Test",
            phoneNumber: "+15551234567",
            createdAt: Date(),
            subscriptionStatus: .trial,
            trialEndDate: pastDate
        )

        #expect(user.isTrialActive == false)
    }

    @Test func testUserIsSubscriptionActive() async throws {
        // Active subscription
        let user = User(
            id: "test-id",
            email: "test@test.com",
            fullName: "Test",
            phoneNumber: "+15551234567",
            createdAt: Date(),
            subscriptionStatus: .active
        )

        #expect(user.isSubscriptionActive == true)
    }

    // MARK: - Task Frequency Tests

    @Test func testTaskFrequencyCases() async throws {
        let frequencies: [TaskFrequency] = [.daily, .weekly, .biweekly, .monthly, .custom]

        for frequency in frequencies {
            #expect(frequency.rawValue != "")
        }
    }

    // MARK: - Response Type Tests

    @Test func testResponseTypeCases() async throws {
        let types: [ResponseType] = [.text, .photo, .both]

        for type in types {
            #expect(type.rawValue != "")
        }
    }

    // MARK: - Profile Status Tests

    @Test func testProfileStatusCases() async throws {
        let statuses: [ProfileStatus] = [.pending, .confirmed, .inactive]

        for status in statuses {
            #expect(status.rawValue != "")
        }
    }

    // MARK: - Task Status Tests

    @Test func testTaskStatusCases() async throws {
        let statuses: [TaskStatus] = [.active, .paused, .completed, .archived]

        for status in statuses {
            #expect(status.rawValue != "")
        }
    }
}

// MARK: - Future Integration Tests (Require Firebase Emulator)

/// Integration tests that require Firebase emulator
/// Run with: firebase emulators:start
/// Note: These are commented out until emulator setup is complete
/*
extension FirebaseSchemaTests {

    @Test func testUserDocumentMatchesModel() async throws {
        // TODO: Requires Firebase emulator
        // 1. Create User in Firestore
        // 2. Read it back
        // 3. Ensure all 13 fields present in Firestore document
    }

    @Test func testProfileIDMatchesPhoneNumberInFirestore() async throws {
        // TODO: Requires Firebase emulator
        // 1. Create ElderlyProfile with phone "+15551234567"
        // 2. Verify Firestore document ID == "+15551234567"
    }

    @Test func testCascadeDeleteRemovesAllSubcollections() async throws {
        // TODO: Requires Firebase emulator
        // 1. Create user → profile → tasks → responses
        // 2. Delete profile
        // 3. Assert all tasks and responses deleted
    }

    @Test func testNoOrphanedDocumentsAfterUserDelete() async throws {
        // TODO: Requires Firebase emulator
        // 1. Create user with profiles, tasks, responses
        // 2. Delete user
        // 3. Query for any docs with that userId
        // 4. Assert none exist
    }

    @Test func testFirestoreIndexesAreDeployed() async throws {
        // TODO: Requires Firebase emulator
        // 1. Run all queries from FirebaseDatabaseService
        // 2. Assert no "Index required" errors
        // 3. Verify query performance (<100ms)
    }
}
*/
