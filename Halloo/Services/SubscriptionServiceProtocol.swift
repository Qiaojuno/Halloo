import Foundation
import StoreKit

// MARK: - Subscription Service Protocol
protocol SubscriptionServiceProtocol {
    
    // MARK: - Subscription Status
    var currentStatus: SubscriptionStatus { get async }
    var trialEndDate: Date? { get async }
    var subscriptionEndDate: Date? { get async }
    var isInTrial: Bool { get async }
    var isActiveSubscriber: Bool { get async }
    
    // MARK: - Product Information
    func getAvailableProducts() async throws -> [SubscriptionProduct]
    func getProduct(identifier: String) async throws -> SubscriptionProduct?
    
    // MARK: - Purchase Management
    func purchase(_ product: SubscriptionProduct) async throws -> PurchaseResult
    func restorePurchases() async throws -> [SubscriptionProduct]
    func cancelSubscription() async throws
    
    // MARK: - Trial Management
    func startTrial() async throws -> TrialResult
    func getTrialDaysRemaining() async -> Int
    func extendTrial(days: Int) async throws
    
    // MARK: - Receipt Validation
    func validateReceipt() async throws -> ReceiptValidation
    func refreshReceiptData() async throws
    
    // MARK: - User Management
    func updateSubscriptionForUser(_ userId: String, status: SubscriptionStatus) async throws
    func getSubscriptionInfo(for userId: String) async throws -> UserSubscriptionInfo
}

// MARK: - Supporting Models

struct SubscriptionProduct: Codable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let price: Decimal
    let priceString: String
    let currency: String
    let subscriptionPeriod: SubscriptionPeriod
    let introductoryOffer: IntroductoryOffer?
    let isPopular: Bool
    let features: [String]
}

enum SubscriptionPeriod: String, CaseIterable, Codable {
    case monthly = "monthly"
    case yearly = "yearly"
    case lifetime = "lifetime"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }
    
    var savingsPercentage: Int? {
        switch self {
        case .monthly: return nil
        case .yearly: return 20 // 20% savings compared to monthly
        case .lifetime: return 50 // 50% savings compared to yearly
        }
    }
}

struct IntroductoryOffer: Codable {
    let price: Decimal
    let priceString: String
    let period: SubscriptionPeriod
    let numberOfPeriods: Int
    let type: OfferType
    
    enum OfferType: String, CaseIterable, Codable {
        case freeTrial = "freeTrial"
        case payAsYouGo = "payAsYouGo"
        case payUpFront = "payUpFront"
    }
}

enum PurchaseResult {
    case success(SubscriptionProduct)
    case cancelled
    case failed(Error)
    case pending
}

struct TrialResult {
    let isSuccess: Bool
    let trialEndDate: Date?
    let error: Error?
}

struct ReceiptValidation {
    let isValid: Bool
    let subscriptionStatus: SubscriptionStatus
    let expirationDate: Date?
    let originalPurchaseDate: Date?
    let latestReceiptInfo: [String: Any]
}

struct UserSubscriptionInfo: Codable {
    let userId: String
    let subscriptionStatus: SubscriptionStatus
    let currentProduct: String?
    let purchaseDate: Date?
    let expirationDate: Date?
    let trialEndDate: Date?
    let isAutoRenewing: Bool
    let lastUpdated: Date
}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case productNotFound
    case purchaseFailed(String)
    case receiptValidationFailed
    case userNotAuthenticated
    case subscriptionNotActive
    case trialAlreadyUsed
    case restoreFailed
    case networkError
    case storeKitError(Error)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .receiptValidationFailed:
            return "Unable to validate purchase receipt"
        case .userNotAuthenticated:
            return "User must be signed in to manage subscription"
        case .subscriptionNotActive:
            return "No active subscription found"
        case .trialAlreadyUsed:
            return "Trial period has already been used"
        case .restoreFailed:
            return "Failed to restore previous purchases"
        case .networkError:
            return "Network error occurred"
        case .storeKitError(let error):
            return "App Store error: \(error.localizedDescription)"
        case .unknownError(let message):
            return "Subscription error: \(message)"
        }
    }
}