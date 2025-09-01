//
//  SubscriptionViewModel.swift
//  Hallo
//
//  Purpose: Subscription management interface for Hallo premium family care features
//  Key Features: 
//    • Subscription status monitoring and premium feature access control
//    • In-app purchase flow for monthly/yearly/lifetime subscriptions
//    • Trial management and subscription renewal handling
//  Dependencies: SubscriptionService, AuthenticationService, ErrorCoordinator
//  
//  Business Context: Revenue management and premium feature access for enhanced family care
//  Critical Paths: Trial signup → Purchase flow → Subscription renewal → Premium access
//
//  Created by Claude Code on 2025-08-07
//

import Foundation
import SwiftUI
import Combine
import StoreKit

/// Subscription management ViewModel for premium family care features
///
/// This ViewModel manages all subscription-related functionality including trial periods,
/// in-app purchases, subscription renewals, and premium feature access control. It
/// provides families with clear information about subscription benefits and seamless
/// purchasing experiences for enhanced elderly care management capabilities.
///
/// ## Key Responsibilities:
/// - **Subscription Status**: Real-time monitoring of subscription status and renewal dates
/// - **Purchase Management**: Streamlined in-app purchase flow for premium subscriptions  
/// - **Trial Management**: Free trial activation and progression tracking
/// - **Feature Access**: Premium feature unlocking based on subscription status
/// - **Billing Support**: Subscription restoration and billing issue resolution
///
/// ## Premium Features:
/// - **Advanced Analytics**: Detailed family care insights and predictive analytics
/// - **Multiple Profiles**: Support for multiple elderly family members
/// - **Priority SMS**: Enhanced SMS delivery and response tracking
/// - **Custom Scheduling**: Advanced task scheduling and reminder customization
///
/// ## Usage Example:
/// ```swift
/// let subscriptionViewModel = container.makeSubscriptionViewModel()
/// await subscriptionViewModel.loadSubscriptionStatus()
/// let isPremium = subscriptionViewModel.isActiveSubscriber
/// ```
///
/// - Important: Subscription management respects privacy and focuses on family care value
/// - Note: Trial periods provide full access to help families evaluate premium benefits
@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current subscription status
    @Published var subscriptionStatus: SubscriptionStatus = .trial
    
    /// Whether user has an active subscription
    @Published var isActiveSubscriber: Bool = false
    
    /// Whether user is currently in trial period
    @Published var isInTrial: Bool = false
    
    /// Number of trial days remaining
    @Published var trialDaysRemaining: Int = 0
    
    /// Trial end date
    @Published var trialEndDate: Date?
    
    /// Subscription end date
    @Published var subscriptionEndDate: Date?
    
    /// Available subscription products
    @Published var availableProducts: [SubscriptionProduct] = []
    
    /// Loading states
    @Published var isLoadingProducts: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var isRestoringPurchases: Bool = false
    
    /// Current error message
    @Published var errorMessage: String?
    
    /// Show purchase success message
    @Published var showPurchaseSuccess: Bool = false
    
    /// Selected product for purchase
    @Published var selectedProduct: SubscriptionProduct?
    
    /// Premium feature access flags
    @Published var canAccessAdvancedAnalytics: Bool = false
    @Published var canAddMultipleProfiles: Bool = false
    @Published var canUsePrioritySMS: Bool = false
    @Published var canUseCustomScheduling: Bool = false
    
    // MARK: - Dependencies
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let authService: AuthenticationServiceProtocol
    private let errorCoordinator: ErrorCoordinator
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        subscriptionService: SubscriptionServiceProtocol,
        authService: AuthenticationServiceProtocol,
        errorCoordinator: ErrorCoordinator
    ) {
        self.subscriptionService = subscriptionService
        self.authService = authService
        self.errorCoordinator = errorCoordinator
        
        setupBindings()
        setupStatusMonitoring()
        
        _Concurrency.Task {
            await loadSubscriptionStatus()
            await loadAvailableProducts()
        }
    }
    
    deinit {
        statusCheckTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Load current subscription status
    func loadSubscriptionStatus() async {
        let status = await subscriptionService.currentStatus
        let inTrial = await subscriptionService.isInTrial
        let isActive = await subscriptionService.isActiveSubscriber
        let trialEnd = await subscriptionService.trialEndDate
        let subscriptionEnd = await subscriptionService.subscriptionEndDate
        let daysRemaining = await subscriptionService.getTrialDaysRemaining()
        
        subscriptionStatus = status
        isInTrial = inTrial
        isActiveSubscriber = isActive
        trialEndDate = trialEnd
        subscriptionEndDate = subscriptionEnd
        trialDaysRemaining = daysRemaining
        
        updateFeatureAccess()
    }
    
    /// Load available subscription products
    func loadAvailableProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        
        do {
            availableProducts = try await subscriptionService.getAvailableProducts()
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Products loading", severity: .medium)
        }
        
        isLoadingProducts = false
    }
    
    /// Purchase a subscription product
    func purchase(_ product: SubscriptionProduct) async {
        isPurchasing = true
        errorMessage = nil
        selectedProduct = product
        
        do {
            let result = try await subscriptionService.purchase(product)
            
            switch result {
            case .success(_):
                showPurchaseSuccess = true
                await loadSubscriptionStatus()
                
            case .cancelled:
                // User cancelled, no error needed
                break
                
            case .failed(let error):
                errorMessage = error.localizedDescription
                errorCoordinator.handle(error, context: "Purchase failed", severity: .medium)
                
            case .pending:
                errorMessage = "Purchase is pending approval. Please check back later."
            }
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Purchase error", severity: .medium)
        }
        
        isPurchasing = false
        selectedProduct = nil
    }
    
    /// Restore previous purchases
    func restorePurchases() async {
        isRestoringPurchases = true
        errorMessage = nil
        
        do {
            let restored = try await subscriptionService.restorePurchases()
            
            if restored.isEmpty {
                errorMessage = "No previous purchases found to restore."
            } else {
                await loadSubscriptionStatus()
                showPurchaseSuccess = true
            }
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Restore purchases", severity: .medium)
        }
        
        isRestoringPurchases = false
    }
    
    /// Start free trial
    func startTrial() async {
        guard !isInTrial && subscriptionStatus != .active else { return }
        
        do {
            let result = try await subscriptionService.startTrial()
            
            if result.isSuccess {
                await loadSubscriptionStatus()
            } else if let error = result.error {
                errorMessage = error.localizedDescription
                errorCoordinator.handle(error, context: "Trial start", severity: .medium)
            }
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Trial start error", severity: .medium)
        }
    }
    
    /// Cancel subscription
    func cancelSubscription() async {
        do {
            try await subscriptionService.cancelSubscription()
            await loadSubscriptionStatus()
            
        } catch {
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Subscription cancellation", severity: .medium)
        }
    }
    
    /// Refresh subscription data
    func refresh() async {
        await loadSubscriptionStatus()
        await loadAvailableProducts()
    }
    
    /// Dismiss error message
    func dismissError() {
        errorMessage = nil
    }
    
    /// Dismiss purchase success message
    func dismissPurchaseSuccess() {
        showPurchaseSuccess = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor authentication changes
        authService.authStatePublisher
            .sink { [weak self] isAuthenticated in
                if !isAuthenticated {
                    _Concurrency.Task { @MainActor in
                        self?.resetSubscriptionState()
                    }
                } else {
                    _Concurrency.Task { @MainActor in
                        await self?.loadSubscriptionStatus()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusMonitoring() {
        // Check subscription status every 5 minutes
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                await self?.loadSubscriptionStatus()
            }
        }
    }
    
    private func updateFeatureAccess() {
        let hasAccess = isActiveSubscriber || isInTrial
        
        canAccessAdvancedAnalytics = hasAccess
        canAddMultipleProfiles = hasAccess
        canUsePrioritySMS = hasAccess
        canUseCustomScheduling = hasAccess
    }
    
    private func resetSubscriptionState() {
        subscriptionStatus = .trial
        isActiveSubscriber = false
        isInTrial = false
        trialDaysRemaining = 0
        trialEndDate = nil
        subscriptionEndDate = nil
        
        canAccessAdvancedAnalytics = false
        canAddMultipleProfiles = false
        canUsePrioritySMS = false
        canUseCustomScheduling = false
    }
}

// MARK: - Computed Properties

extension SubscriptionViewModel {
    
    /// Whether trial is ending soon (less than 3 days)
    var isTrialEndingSoon: Bool {
        return isInTrial && trialDaysRemaining <= 3
    }
    
    /// Whether subscription is ending soon (less than 7 days)
    var isSubscriptionEndingSoon: Bool {
        guard let endDate = subscriptionEndDate else { return false }
        let daysUntilEnd = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return daysUntilEnd <= 7
    }
    
    /// Formatted trial end date
    var formattedTrialEndDate: String {
        guard let endDate = trialEndDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: endDate)
    }
    
    /// Formatted subscription end date
    var formattedSubscriptionEndDate: String {
        guard let endDate = subscriptionEndDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: endDate)
    }
    
    /// Most popular product (for UI highlighting)
    var popularProduct: SubscriptionProduct? {
        return availableProducts.first { $0.isPopular }
    }
    
    /// Best value product (usually yearly)
    var bestValueProduct: SubscriptionProduct? {
        return availableProducts.first { $0.subscriptionPeriod == .yearly }
    }
}