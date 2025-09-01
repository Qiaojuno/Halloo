//
//  AnalyticsViewModel.swift
//  Hallo
//
//  Purpose: Analytics and insights interface for family care tracking and performance monitoring
//  Key Features: 
//    • Care analytics dashboard with completion trends and family insights
//    • Weekly and monthly progress reports for elderly care management
//    • Predictive analytics for care patterns and intervention opportunities
//  Dependencies: AnalyticsService, DatabaseService, AuthenticationService, ErrorCoordinator
//  
//  Business Context: Family insights and reporting for optimizing elderly care effectiveness
//  Critical Paths: Analytics loading → Trend analysis → Family reports → Care optimization
//
//  Created by Claude Code on 2025-08-07
//

import Foundation
import SwiftUI
import Combine

/// Analytics and insights ViewModel for family care tracking and performance monitoring
///
/// This ViewModel provides comprehensive analytics and reporting capabilities for families
/// managing elderly care. It transforms raw task completion and SMS response data into
/// actionable insights, helping families optimize care schedules and identify patterns
/// that improve elderly wellbeing and care adherence.
///
/// ## Key Responsibilities:
/// - **Analytics Dashboard**: Real-time analytics on care task completion and SMS engagement
/// - **Progress Reports**: Weekly/monthly family reports with trends and achievements
/// - **Predictive Insights**: Pattern analysis to predict care needs and optimal scheduling
/// - **Performance Tracking**: Completion rate monitoring across all elderly profiles
/// - **Care Optimization**: Data-driven recommendations for improving care effectiveness
///
/// ## Family Benefits:
/// - **Care Visibility**: Clear metrics on elderly care adherence and wellbeing trends
/// - **Proactive Planning**: Insights that help families anticipate care needs
/// - **Progress Celebration**: Achievement tracking and milestone recognition
/// - **Care Adjustment**: Data-driven adjustments to care schedules and approaches
///
/// ## Usage Example:
/// ```swift
/// let analyticsViewModel = container.makeAnalyticsViewModel()
/// await analyticsViewModel.loadWeeklyAnalytics()
/// let completionRate = analyticsViewModel.weeklyAnalytics?.completionRate
/// ```
///
/// - Important: Analytics provide insights while respecting elderly privacy and dignity
/// - Note: All analytics focus on care improvement rather than surveillance
@MainActor
final class AnalyticsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Loading state for analytics data
    @Published var isLoading: Bool = false
    
    /// Current weekly analytics data
    @Published var weeklyAnalytics: WeeklyAnalytics?
    
    /// Current monthly analytics data  
    @Published var monthlyAnalytics: MonthlyAnalytics?
    
    /// User-defined custom period analytics
    @Published var customAnalytics: CustomPeriodAnalytics?
    
    /// Current analytics error state
    @Published var errorMessage: String?
    
    /// Analytics time range selection
    @Published var selectedTimeRange: AnalyticsTimeRange = .thisWeek
    
    /// Whether analytics are available (sufficient data)
    @Published var analyticsAvailable: Bool = true
    
    // MARK: - Dependencies
    
    private let analyticsService: AnalyticsServiceProtocol
    private let databaseService: DatabaseServiceProtocol
    private let authService: AuthenticationServiceProtocol
    private let errorCoordinator: ErrorCoordinator
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        analyticsService: AnalyticsServiceProtocol,
        databaseService: DatabaseServiceProtocol,
        authService: AuthenticationServiceProtocol,
        errorCoordinator: ErrorCoordinator
    ) {
        self.analyticsService = analyticsService
        self.databaseService = databaseService
        self.authService = authService
        self.errorCoordinator = errorCoordinator
        
        setupBindings()
        setupAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Load analytics for the currently selected time range
    func loadAnalytics() async {
        guard let userId = authService.currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            switch selectedTimeRange {
            case .thisWeek:
                weeklyAnalytics = try await analyticsService.getWeeklyAnalytics(for: userId)
            case .thisMonth:
                monthlyAnalytics = try await analyticsService.getMonthlyAnalytics(for: userId)
            case .last7Days:
                // Load last 7 days analytics (using weekly for now as placeholder)
                weeklyAnalytics = try await analyticsService.getWeeklyAnalytics(for: userId)
            case .last30Days:
                // Load last 30 days analytics (using monthly for now as placeholder)
                monthlyAnalytics = try await analyticsService.getMonthlyAnalytics(for: userId)
            case .today:
                // Load today's analytics (using weekly for now as placeholder)
                weeklyAnalytics = try await analyticsService.getWeeklyAnalytics(for: userId)
            case .thisYear:
                // Load yearly analytics (using monthly for now as placeholder)
                monthlyAnalytics = try await analyticsService.getMonthlyAnalytics(for: userId)
            case .last90Days:
                // Load last 90 days analytics (using monthly for now as placeholder)
                monthlyAnalytics = try await analyticsService.getMonthlyAnalytics(for: userId)
            case .allTime:
                // Load all time analytics (using monthly for now as placeholder)
                monthlyAnalytics = try await analyticsService.getMonthlyAnalytics(for: userId)
            case .custom:
                // Load custom range analytics (using monthly for now as placeholder)
                monthlyAnalytics = try await analyticsService.getMonthlyAnalytics(for: userId)
            }
            
            analyticsAvailable = true
            
        } catch AnalyticsError.insufficientData {
            analyticsAvailable = false
            errorMessage = "Not enough data yet. Keep using Hallo to see your family care insights!"
            
        } catch {
            analyticsAvailable = true
            errorMessage = error.localizedDescription
            errorCoordinator.handle(error, context: "Analytics loading", severity: .medium)
        }
        
        isLoading = false
    }
    
    /// Load weekly analytics specifically
    func loadWeeklyAnalytics() async {
        selectedTimeRange = .thisWeek
        await loadAnalytics()
    }
    
    /// Load monthly analytics specifically
    func loadMonthlyAnalytics() async {
        selectedTimeRange = .thisMonth
        await loadAnalytics()
    }
    
    /// Load custom period analytics
    func loadCustomAnalytics(from startDate: Date, to endDate: Date) async {
        // Use appropriate time range based on the date range
        let daysDifference = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if daysDifference <= 7 {
            selectedTimeRange = .last7Days
        } else if daysDifference <= 30 {
            selectedTimeRange = .last30Days
        } else {
            selectedTimeRange = .thisYear
        }
        await loadAnalytics()
    }
    
    /// Refresh current analytics data
    func refresh() async {
        await loadAnalytics()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-load analytics when time range changes
        $selectedTimeRange
            .dropFirst()
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    await self?.loadAnalytics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoRefresh() {
        // Refresh analytics every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            _Concurrency.Task {
                await self.loadAnalytics()
            }
        }
    }
}

