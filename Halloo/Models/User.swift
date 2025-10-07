import Foundation
import FirebaseFirestore

// MARK: - User Model
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

    // Auto-calculated fields (updated by DatabaseService)
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
        profileCount: Int = 0,
        taskCount: Int = 0,
        updatedAt: Date = Date(),
        lastSyncTimestamp: Date? = nil
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

    // MARK: - Custom Codable Implementation with Diagnostic Logging

    enum CodingKeys: String, CodingKey {
        case id, email, fullName, phoneNumber, createdAt
        case isOnboardingComplete, subscriptionStatus, trialEndDate, quizAnswers
        case profileCount, taskCount, updatedAt, lastSyncTimestamp
    }

    init(from decoder: Decoder) throws {
        DiagnosticLogger.debug(.userModel, "Decoding User from Firestore")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        fullName = try container.decode(String.self, forKey: .fullName)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        isOnboardingComplete = try container.decode(Bool.self, forKey: .isOnboardingComplete)
        subscriptionStatus = try container.decode(SubscriptionStatus.self, forKey: .subscriptionStatus)

        // Optional fields
        trialEndDate = try? container.decodeIfPresent(Date.self, forKey: .trialEndDate)
        quizAnswers = try? container.decodeIfPresent([String: String].self, forKey: .quizAnswers)

        // Date fields (handle Firestore Timestamp)
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            DiagnosticLogger.warning(.userModel, "createdAt missing, using current date", context: ["userId": id])
            createdAt = Date()
        }

        // Auto-calculated fields with fallback
        profileCount = (try? container.decodeIfPresent(Int.self, forKey: .profileCount)) ?? 0
        taskCount = (try? container.decodeIfPresent(Int.self, forKey: .taskCount)) ?? 0

        // updatedAt field (handle Firestore Timestamp or Date)
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .updatedAt) {
            updatedAt = date
        } else {
            DiagnosticLogger.warning(.userModel, "updatedAt missing, using current date", context: ["userId": id])
            updatedAt = Date()
        }

        // lastSyncTimestamp (optional)
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .lastSyncTimestamp) {
            lastSyncTimestamp = timestamp.dateValue()
        } else {
            lastSyncTimestamp = try? container.decodeIfPresent(Date.self, forKey: .lastSyncTimestamp)
        }

        DiagnosticLogger.success(.userModel, "User decoded successfully", context: [
            "userId": id,
            "email": email,
            "profileCount": profileCount,
            "taskCount": taskCount
        ])
    }

    func encode(to encoder: Encoder) throws {
        DiagnosticLogger.debug(.userModel, "Encoding User to Firestore", context: ["userId": id])

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isOnboardingComplete, forKey: .isOnboardingComplete)
        try container.encode(subscriptionStatus, forKey: .subscriptionStatus)
        try container.encodeIfPresent(trialEndDate, forKey: .trialEndDate)
        try container.encodeIfPresent(quizAnswers, forKey: .quizAnswers)
        try container.encode(profileCount, forKey: .profileCount)
        try container.encode(taskCount, forKey: .taskCount)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastSyncTimestamp, forKey: .lastSyncTimestamp)

        DiagnosticLogger.debug(.userModel, "User encoded", context: [
            "userId": id,
            "profileCount": profileCount,
            "taskCount": taskCount
        ])
    }
}

// MARK: - User Extensions
extension User {
    var isTrialActive: Bool {
        guard subscriptionStatus == .trial else { return false }
        guard let trialEnd = trialEndDate else { return false }
        return Date() < trialEnd
    }
    
    var isSubscriptionActive: Bool {
        switch subscriptionStatus {
        case .active:
            return true
        case .trial:
            return isTrialActive
        case .expired, .cancelled:
            return false
        }
    }
    
    var subscriptionDisplayText: String {
        switch subscriptionStatus {
        case .trial:
            if isTrialActive {
                return "Free Trial"
            } else {
                return "Trial Expired"
            }
        case .active:
            return "Active Subscription"
        case .expired:
            return "Subscription Expired"
        case .cancelled:
            return "Subscription Cancelled"
        }
    }
}