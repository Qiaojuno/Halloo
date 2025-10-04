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
    private var currentProductId: String?

    init() {
        // No hardcoded products - products should be set at runtime
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
        return mockProducts // Return empty array if not set
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
        currentProductId = product.id
        _subscriptionStatus = .active
        mockSubscriptionEndDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now

        return .success(product)
    }
    
    func restorePurchases() async throws -> [SubscriptionProduct] {
        print("💳 Mock: Restoring purchases")

        // Simulate restore delay
        try await _Concurrency.Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Mock restore - return current product if active
        if _subscriptionStatus == .active, let productId = currentProductId {
            return [mockProducts.first { $0.id == productId }].compactMap { $0 }
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

        var receiptInfo: [String: String] = [:]
        if let productId = currentProductId {
            receiptInfo["product_id"] = productId
            receiptInfo["transaction_id"] = UUID().uuidString
        }

        return ReceiptValidation(
            isValid: _subscriptionStatus == .active,
            subscriptionStatus: _subscriptionStatus,
            expirationDate: mockSubscriptionEndDate,
            originalPurchaseDate: mockSubscriptionEndDate?.addingTimeInterval(-30 * 24 * 60 * 60),
            latestReceiptInfo: receiptInfo
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
            currentProduct: _subscriptionStatus == .active ? currentProductId : nil,
            purchaseDate: mockSubscriptionEndDate?.addingTimeInterval(-7 * 24 * 60 * 60),
            expirationDate: mockSubscriptionEndDate,
            trialEndDate: _subscriptionStatus == .trial ? mockTrialEndDate : nil,
            isAutoRenewing: _subscriptionStatus == .active,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Public Setup Methods (for runtime configuration)
    func setMockProducts(_ products: [SubscriptionProduct]) {
        mockProducts = products
        availableProducts = products
    }

    func addMockProduct(_ product: SubscriptionProduct) {
        mockProducts.append(product)
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