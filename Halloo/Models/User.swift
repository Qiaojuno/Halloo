import Foundation

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