import Foundation
import Combine

// MARK: - Mock Analytics Service
class MockAnalyticsService: AnalyticsServiceProtocol {
    
    // MARK: - Properties
    private var events: [AnalyticsEvent] = []
    private var userProperties: [String: String] = [:]
    private var sessionStartTime: Date = Date()
    
    // MARK: - AnalyticsServiceProtocol Implementation
    
    // MARK: - User Analytics
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics {
        return UserAnalytics(
            userId: userId,
            totalProfiles: 2,
            activeProfiles: 2,
            totalTasks: 10,
            overallCompletionRate: 0.8,
            profileAnalytics: [
                ProfileAnalytics(
                    profileId: "profile1",
                    totalTasks: 5,
                    completedTasks: 4,
                    averageResponseTime: 280,
                    lastActiveDate: Date(),
                    responseRate: 0.8,
                    preferredResponseType: .text,
                    bestPerformingCategory: .medication,
                    worstPerformingCategory: .exercise,
                    weeklyTrend: [0.8, 0.9, 0.7, 0.8, 0.6, 0.9, 0.8]
                )
            ],
            subscriptionUsage: SubscriptionUsage(
                planType: "premium",
                profilesUsed: 2,
                profilesLimit: 5,
                tasksCreated: 120,
                smssSent: 85,
                storageUsed: 1024000, // 1MB in bytes
                billingPeriodStart: Date().addingTimeInterval(-15 * 24 * 60 * 60), // 15 days ago
                billingPeriodEnd: Date().addingTimeInterval(15 * 24 * 60 * 60) // 15 days from now
            ),
            generatedAt: Date()
        )
    }
    
    func getWeeklyAnalytics(for userId: String) async throws -> WeeklyAnalytics {
        return WeeklyAnalytics(
            userId: userId,
            weekStartDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
            weekEndDate: Date(),
            completionRate: 0.8,
            totalTasks: 35,
            completedTasks: 28,
            currentStreak: 4,
            dailyCompletion: [0.8, 0.9, 0.7, 0.8, 0.6, 0.9, 0.8],
            categoryBreakdown: [:],
            averageResponseTime: 280,
            improvementFromLastWeek: 0.1,
            topPerformingProfile: userId,
            generatedAt: Date()
        )
    }
    
    func getMonthlyAnalytics(for userId: String) async throws -> MonthlyAnalytics {
        return MonthlyAnalytics(
            userId: userId,
            monthStartDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            monthEndDate: Date(),
            overallCompletionRate: 0.75,
            totalTasks: 150,
            completedTasks: 112,
            longestStreak: 7,
            averageWeeklyCompletion: 0.75,
            weeklyTrends: [],
            categoryInsights: [],
            habitFormationProgress: [],
            profileComparison: [],
            goals: [],
            achievements: [],
            generatedAt: Date()
        )
    }
    
    func getCustomPeriodAnalytics(for userId: String, from startDate: Date, to endDate: Date) async throws -> CustomPeriodAnalytics {
        return CustomPeriodAnalytics(
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            totalDays: Int(endDate.timeIntervalSince(startDate)) / (24 * 60 * 60),
            completionRate: 0.8,
            totalTasks: 50,
            completedTasks: 40,
            averageDailyTasks: 2.5,
            bestDay: Date(),
            worstDay: Date(),
            consistencyScore: 0.85,
            trendDirection: .improving,
            significantEvents: []
        )
    }
    
    // MARK: - Profile Analytics
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics {
        return ProfileAnalytics(
            profileId: profileId,
            totalTasks: 20,
            completedTasks: 16,
            averageResponseTime: 250,
            lastActiveDate: Date(),
            responseRate: 0.8,
            preferredResponseType: .text,
            bestPerformingCategory: .medication,
            worstPerformingCategory: .exercise,
            weeklyTrend: [0.8, 0.9, 0.7, 0.8, 0.6, 0.9, 0.8]
        )
    }
    
    func compareProfilePerformance(profileIds: [String], userId: String) async throws -> AnalyticsProfileComparisonResult {
        return AnalyticsProfileComparisonResult(
            profileComparisons: [],
            overallInsights: ["Mock insight"],
            generatedAt: Date()
        )
    }
    
    func getProfileTrends(for profileId: String, userId: String, days: Int) async throws -> ProfileTrendData {
        return ProfileTrendData(
            profileId: profileId,
            profileName: "Mock Profile",
            dailyCompletionRates: [:],
            taskCategoryTrends: [:],
            responseTimeTrends: [:],
            engagementTrends: [:],
            predictionData: PredictionData(
                predictedValue: 0.8,
                confidenceIntervalLower: 0.7,
                confidenceIntervalUpper: 0.9,
                confidence: 0.85
            )
        )
    }
    
    // MARK: - Task Analytics
    func getTaskAnalytics(for taskId: String, userId: String) async throws -> TaskAnalytics {
        return TaskAnalytics(
            taskId: taskId,
            taskTitle: "Mock Task",
            category: .medication,
            completionRate: 0.85,
            totalScheduled: 20,
            totalCompleted: 17,
            averageResponseTime: 300,
            bestResponseTime: 120,
            worstResponseTime: 600,
            responseTimeVariance: 0.3,
            completionPattern: CompletionPattern(
                patternType: "consistent",
                description: "Consistent completion",
                strength: 0.8
            ),
            difficultiesDetected: [],
            improvementSuggestions: []
        )
    }
    
    func getCategoryAnalytics(for userId: String) async throws -> CategoryAnalytics {
        return CategoryAnalytics(
            userId: userId,
            categoryStats: [:],
            bestPerformingCategory: .medication,
            worstPerformingCategory: .exercise,
            categoryTrends: [:],
            categoryCorrelations: [],
            generatedAt: Date()
        )
    }
    
    func getCompletionRateAnalytics(for userId: String) async throws -> CompletionRateAnalytics {
        return CompletionRateAnalytics(
            userId: userId,
            overallCompletionRate: 0.8,
            completionRateByDay: [:],
            completionRateByTimeOfDay: [:],
            completionRateByCategory: [:],
            completionRateByProfile: [:],
            historicalTrend: [:],
            benchmarkComparison: BenchmarkData(
                averageRate: 0.75,
                topPerformerRate: 0.95,
                percentileRank: 80
            ),
            factors: []
        )
    }
    
    func getResponseTimeAnalytics(for userId: String) async throws -> ResponseTimeAnalytics {
        return ResponseTimeAnalytics(
            userId: userId,
            averageResponseTime: 300,
            medianResponseTime: 280,
            fastestResponseTime: 60,
            slowestResponseTime: 900,
            responseTimeByCategory: [:],
            responseTimeByProfile: [:],
            responseTimeByTimeOfDay: [:],
            responseTimeDistribution: [:],
            improvementTrend: .improving
        )
    }
    
    // MARK: - Streak and Habit Analytics
    func getStreakAnalytics(for userId: String) async throws -> StreakAnalytics {
        return StreakAnalytics(
            userId: userId,
            currentStreak: 5,
            longestStreak: 12,
            totalStreaks: 8,
            averageStreakLength: 6.5,
            streaksByCategory: [:],
            streaksByProfile: [:],
            streakBreakReasons: [],
            streakPrediction: StreakPrediction(
                predictedDuration: 8,
                confidence: 0.7,
                riskFactors: []
            ),
            milestones: []
        )
    }
    
    func getHabitFormationAnalytics(for userId: String) async throws -> HabitFormationAnalytics {
        return HabitFormationAnalytics(
            userId: userId,
            habitStrength: 0.6,
            daysToHabitFormation: 21,
            habitFormationStage: .formation,
            consistencyScore: 0.8,
            automaticityLevel: 0.4,
            contextualTriggers: [],
            resistanceFactors: [],
            recommendations: []
        )
    }
    
    func getPredictiveAnalytics(for userId: String) async throws -> PredictiveAnalytics {
        return PredictiveAnalytics(
            userId: userId,
            completionPrediction: PredictionResult(
                predictedValue: 0.85,
                confidence: 0.8,
                timeHorizon: 7
            ),
            streakPrediction: PredictionResult(
                predictedValue: 8,
                confidence: 0.7,
                timeHorizon: 14
            ),
            engagementPrediction: PredictionResult(
                predictedValue: 0.9,
                confidence: 0.75,
                timeHorizon: 7
            ),
            riskFactors: [],
            interventionSuggestions: [],
            confidenceLevel: 0.8,
            dataQuality: DataQualityScore(
                overall: 0.9,
                completeness: 0.95,
                consistency: 0.85,
                recency: 0.9
            )
        )
    }
    
    // MARK: - Engagement Analytics
    func getEngagementAnalytics(for userId: String) async throws -> EngagementAnalytics {
        return EngagementAnalytics(
            userId: userId,
            overallEngagementScore: 0.8,
            engagementTrend: .improving,
            engagementByProfile: [:],
            engagementByCategory: [:],
            engagementByTimeOfDay: [:],
            engagementFactors: [],
            disengagementRisks: [],
            boostStrategies: []
        )
    }
    
    func getSMSEngagementAnalytics(for userId: String) async throws -> SMSEngagementAnalytics {
        return SMSEngagementAnalytics(
            userId: userId,
            responseRate: 0.85,
            averageResponseTime: 300,
            positiveResponseRate: 0.9,
            textVsPhotoPreference: ResponseTypePreference(
                preferredType: .text,
                preferenceStrength: 0.7
            ),
            optimalSendingTimes: [9, 14, 19],
            messageEffectiveness: [:],
            engagementTrend: .stable
        )
    }
    
    func getNotificationEngagementAnalytics(for userId: String) async throws -> NotificationEngagementAnalytics {
        return NotificationEngagementAnalytics(
            userId: userId,
            openRate: 0.75,
            actionRate: 0.6,
            dismissalRate: 0.25,
            optimalDeliveryTimes: [9, 14, 19],
            categoryPerformance: [:],
            interactionPatterns: []
        )
    }
    
    // MARK: - Health and Wellness Insights
    func getWellnessInsights(for userId: String) async throws -> WellnessInsights {
        return WellnessInsights(
            userId: userId,
            overallWellnessScore: 0.8,
            medicationAdherence: 0.9,
            exerciseConsistency: 0.7,
            socialEngagement: 0.6,
            healthMonitoring: 0.8,
            safetyCompliance: 0.95,
            wellnessTrends: [],
            healthRisks: [],
            recommendations: []
        )
    }
    
    func getMedicationAdherenceAnalytics(for userId: String) async throws -> MedicationAdherenceAnalytics {
        return MedicationAdherenceAnalytics(
            userId: userId,
            adherenceRate: 0.92,
            missedDoses: 3,
            adherenceByMedication: [:],
            adherenceByTimeOfDay: [:],
            adherenceByProfile: [:],
            riskFactors: [],
            interventions: []
        )
    }
    
    func getActivityLevelAnalytics(for userId: String) async throws -> ActivityLevelAnalytics {
        return ActivityLevelAnalytics(
            userId: userId,
            averageActivityScore: 0.7,
            activityTrends: [:],
            activityByCategory: [:],
            activityByProfile: [:],
            activityGoals: [],
            progressTowardsGoals: [:]
        )
    }
    
    // MARK: - Family Analytics
    func getFamilyOverviewAnalytics(for userId: String) async throws -> FamilyOverviewAnalytics {
        return FamilyOverviewAnalytics(
            userId: userId,
            totalProfiles: 3,
            activeProfiles: 2,
            familyCompletionRate: 0.8,
            profilePerformance: [],
            familyTrends: [],
            caregiverInsights: [],
            familyGoals: []
        )
    }
    
    func getCaregiverEffectivenessAnalytics(for userId: String) async throws -> CaregiverEffectivenessAnalytics {
        return CaregiverEffectivenessAnalytics(
            userId: userId,
            effectivenessScore: 0.85,
            responseRate: 0.9,
            interventionSuccess: 0.8,
            supportPatterns: [],
            communicationQuality: 0.9,
            caregiverStress: .low,
            recommendations: []
        )
    }
    
    // MARK: - Real-time Analytics
    func getCurrentDayProgress(for userId: String) async throws -> DayProgressAnalytics {
        return DayProgressAnalytics(
            userId: userId,
            date: Date(),
            completedTasks: 5,
            totalScheduledTasks: 8,
            completionRate: 0.625,
            onTrackForDailyGoal: true,
            hoursRemaining: 8,
            upcomingTasks: [],
            realtimeStreak: 3
        )
    }
    
    func getLiveCompletionStats(for userId: String) async throws -> LiveCompletionStats {
        return LiveCompletionStats(
            userId: userId,
            lastUpdated: Date(),
            tasksCompletedToday: 5,
            tasksRemainingToday: 3,
            currentDayScore: 0.75,
            weeklyProgress: 0.8,
            activeStreaks: [:],
            recentCompletions: []
        )
    }
    
    // MARK: - Export and Reporting
    func generateAnalyticsReport(for userId: String, format: ReportFormat) async throws -> AnalyticsReport {
        return AnalyticsReport(
            userId: userId,
            reportType: .weekly,
            generatedAt: Date(),
            timeRange: TimeRange(startDate: Date().addingTimeInterval(-7 * 24 * 60 * 60), endDate: Date()),
            format: format,
            sections: [],
            summary: ReportSummary(
                keyMetrics: [:],
                highlights: [],
                concerns: []
            ),
            recommendations: [],
            appendices: []
        )
    }
    
    func exportAnalyticsData(for userId: String, timeRange: AnalyticsTimeRange) async throws -> Data {
        let mockData = ["userId": userId, "timeRange": timeRange.rawValue]
        return try JSONSerialization.data(withJSONObject: mockData)
    }
    
    func scheduleRecurringReport(for userId: String, frequency: ReportFrequency, format: ReportFormat) async throws {
        print("📊 Mock: Scheduled recurring report for user \(userId)")
    }
    
    // MARK: - Event Tracking
    
    func trackEvent(_ eventName: String, parameters: [String: Any]) async {
        print("📊 Mock: Tracked event '\(eventName)' with parameters: \(parameters)")
        
        // Store event in local array if needed
        let event = AnalyticsEvent(
            name: eventName,
            parameters: parameters.compactMapValues { "\($0)" }, // Convert Any to String
            timestamp: Date(),
            userId: nil
        )
        events.append(event)
    }
}

// MARK: - Mock Analytics Models

struct AnalyticsEvent: Codable {
    let name: String
    let parameters: [String: String] // Changed from [String: Any] for Codable compatibility
    let timestamp: Date
    let userId: String?
}

// NOTE: UserAnalytics, ProfileAnalytics, and Weekday are already defined in DatabaseServiceProtocol.swift