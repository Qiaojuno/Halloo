import Foundation
import Combine
import StoreKit

// MARK: - Mock Subscription Service
class MockSubscriptionService: SubscriptionServiceProtocol {
    
    // MARK: - Properties
    @Published private var _subscriptionStatus: SubscriptionStatus = .trial
    @Published var availableProducts: [SubscriptionProduct] = []
    
    private var mockProducts: [SubscriptionProduct] = []
    private var mockTrialEndDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
    private var mockSubscriptionEndDate: Date? = nil
    
    init() {
        setupMockProducts()
    }
    
    // MARK: - SubscriptionServiceProtocol Implementation
    
    // MARK: - Subscription Status
    var currentStatus: SubscriptionStatus {
        get async {
            return _subscriptionStatus
        }
    }
    
    var trialEndDate: Date? {
        get async {
            return _subscriptionStatus == .trial ? mockTrialEndDate : nil
        }
    }
    
    var subscriptionEndDate: Date? {
        get async {
            return mockSubscriptionEndDate
        }
    }
    
    var isInTrial: Bool {
        get async {
            return _subscriptionStatus == .trial && Date() < mockTrialEndDate
        }
    }
    
    var isActiveSubscriber: Bool {
        get async {
            return _subscriptionStatus == .active || (_subscriptionStatus == .trial && Date() < mockTrialEndDate)
        }
    }
    
    // MARK: - Product Information
    func getAvailableProducts() async throws -> [SubscriptionProduct] {
        // Simulate network delay
        try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        return mockProducts
    }
    
    func getProduct(identifier: String) async throws -> SubscriptionProduct? {
        return mockProducts.first { $0.id == identifier }
    }
    
    // MARK: - Purchase Management
    func purchase(_ product: SubscriptionProduct) async throws -> PurchaseResult {
        print("💳 Mock: Purchasing product: \(product.displayName)")
        
        // Simulate purchase delay
        try await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock successful purchase
        _subscriptionStatus = .active
        mockSubscriptionEndDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
        
        return .success(product)
    }
    
    func restorePurchases() async throws -> [SubscriptionProduct] {
        print("💳 Mock: Restoring purchases")
        
        // Simulate restore delay
        try await _Concurrency.Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Mock restore - return premium product if active
        if _subscriptionStatus == .active {
            return [mockProducts.first { $0.id == "hallo_premium_monthly" }].compactMap { $0 }
        }
        
        return []
    }
    
    func cancelSubscription() async throws {
        print("💳 Mock: Cancelling subscription")
        _subscriptionStatus = .cancelled
        mockSubscriptionEndDate = Date() // Expire immediately
    }
    
    // MARK: - Trial Management
    func startTrial() async throws -> TrialResult {
        print("💳 Mock: Starting trial")
        
        guard _subscriptionStatus != .trial else {
            throw SubscriptionError.trialAlreadyUsed
        }
        
        _subscriptionStatus = .trial
        mockTrialEndDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        
        return TrialResult(
            isSuccess: true,
            trialEndDate: mockTrialEndDate,
            error: nil
        )
    }
    
    func getTrialDaysRemaining() async -> Int {
        guard _subscriptionStatus == .trial else { return 0 }
        
        let timeRemaining = mockTrialEndDate.timeIntervalSinceNow
        return max(0, Int(ceil(timeRemaining / (24 * 60 * 60))))
    }
    
    func extendTrial(days: Int) async throws {
        guard _subscriptionStatus == .trial else {
            throw SubscriptionError.subscriptionNotActive
        }
        
        mockTrialEndDate = mockTrialEndDate.addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        print("💳 Mock: Extended trial by \(days) days")
    }
    
    // MARK: - Receipt Validation
    func validateReceipt() async throws -> ReceiptValidation {
        print("💳 Mock: Validating receipt")
        
        return ReceiptValidation(
            isValid: true,
            subscriptionStatus: _subscriptionStatus,
            expirationDate: mockSubscriptionEndDate,
            originalPurchaseDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            latestReceiptInfo: [
                "product_id": "hallo_premium_monthly",
                "transaction_id": "mock_transaction_12345"
            ]
        )
    }
    
    func refreshReceiptData() async throws {
        print("💳 Mock: Refreshing receipt data")
        // Mock implementation - no actual refresh needed
    }
    
    // MARK: - User Management
    func updateSubscriptionForUser(_ userId: String, status: SubscriptionStatus) async throws {
        print("💳 Mock: Updating subscription for user \(userId) to \(status.rawValue)")
        _subscriptionStatus = status
    }
    
    func getSubscriptionInfo(for userId: String) async throws -> UserSubscriptionInfo {
        return UserSubscriptionInfo(
            userId: userId,
            subscriptionStatus: _subscriptionStatus,
            currentProduct: _subscriptionStatus == .active ? "hallo_premium_monthly" : nil,
            purchaseDate: _subscriptionStatus == .active ? Date().addingTimeInterval(-7 * 24 * 60 * 60) : nil,
            expirationDate: mockSubscriptionEndDate,
            trialEndDate: _subscriptionStatus == .trial ? mockTrialEndDate : nil,
            isAutoRenewing: _subscriptionStatus == .active,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Setup
    private func setupMockProducts() {
        mockProducts = [
            SubscriptionProduct(
                id: "hallo_basic_monthly",
                displayName: "Basic Plan - Monthly",
                description: "Up to 2 elderly profiles, unlimited tasks",
                price: Decimal(9.99),
                priceString: "$9.99",
                currency: "USD",
                subscriptionPeriod: .monthly,
                introductoryOffer: IntroductoryOffer(
                    price: Decimal(0.99),
                    priceString: "$0.99",
                    period: .monthly,
                    numberOfPeriods: 1,
                    type: .payAsYouGo
                ),
                isPopular: false,
                features: [
                    "Up to 2 elderly profiles",
                    "Unlimited daily tasks",
                    "SMS reminders",
                    "Basic analytics"
                ]
            ),
            SubscriptionProduct(
                id: "hallo_premium_monthly",
                displayName: "Premium Plan - Monthly", 
                description: "Up to 5 elderly profiles, advanced features",
                price: Decimal(19.99),
                priceString: "$19.99",
                currency: "USD",
                subscriptionPeriod: .monthly,
                introductoryOffer: IntroductoryOffer(
                    price: Decimal(1.99),
                    priceString: "$1.99",
                    period: .monthly,
                    numberOfPeriods: 1,
                    type: .payAsYouGo
                ),
                isPopular: true,
                features: [
                    "Up to 5 elderly profiles",
                    "Unlimited tasks",
                    "SMS & push notifications",
                    "Advanced analytics",
                    "Photo responses",
                    "Emergency contacts"
                ]
            ),
            SubscriptionProduct(
                id: "hallo_premium_yearly",
                displayName: "Premium Plan - Yearly",
                description: "Up to 5 elderly profiles, advanced features (20% savings)",
                price: Decimal(191.88), // 20% savings from monthly
                priceString: "$191.88",
                currency: "USD",
                subscriptionPeriod: .yearly,
                introductoryOffer: IntroductoryOffer(
                    price: Decimal(0.00),
                    priceString: "Free",
                    period: .monthly,
                    numberOfPeriods: 1,
                    type: .freeTrial
                ),
                isPopular: false,
                features: [
                    "Up to 5 elderly profiles",
                    "Unlimited tasks",
                    "SMS & push notifications",
                    "Advanced analytics",
                    "Photo responses",
                    "Emergency contacts",
                    "20% savings vs monthly"
                ]
            )
        ]
        
        availableProducts = mockProducts
    }
}

// MARK: - Mock Trial Extension
extension MockSubscriptionService {
    
    func simulateTrialExpiring() async {
        mockTrialEndDate = Date().addingTimeInterval(24 * 60 * 60) // Expires in 1 day
    }
    
    func simulateTrialExpired() async {
        _subscriptionStatus = .expired
        mockTrialEndDate = Date().addingTimeInterval(-1) // Already expired
    }
    
    func simulateActivePurchase() async {
        _subscriptionStatus = .active
        mockSubscriptionEndDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
    }
}