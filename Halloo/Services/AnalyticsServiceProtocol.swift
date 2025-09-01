import Foundation

// MARK: - Analytics Service Protocol
protocol AnalyticsServiceProtocol {
    
    // MARK: - User Analytics
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics
    func getWeeklyAnalytics(for userId: String) async throws -> WeeklyAnalytics
    func getMonthlyAnalytics(for userId: String) async throws -> MonthlyAnalytics
    func getCustomPeriodAnalytics(for userId: String, from startDate: Date, to endDate: Date) async throws -> CustomPeriodAnalytics
    
    // MARK: - Profile Analytics
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics
    func compareProfilePerformance(profileIds: [String], userId: String) async throws -> AnalyticsProfileComparisonResult
    func getProfileTrends(for profileId: String, userId: String, days: Int) async throws -> ProfileTrendData
    
    // MARK: - Task Analytics
    func getTaskAnalytics(for taskId: String, userId: String) async throws -> TaskAnalytics
    func getCategoryAnalytics(for userId: String) async throws -> CategoryAnalytics
    func getCompletionRateAnalytics(for userId: String) async throws -> CompletionRateAnalytics
    func getResponseTimeAnalytics(for userId: String) async throws -> ResponseTimeAnalytics
    
    // MARK: - Streak and Habit Analytics
    func getStreakAnalytics(for userId: String) async throws -> StreakAnalytics
    func getHabitFormationAnalytics(for userId: String) async throws -> HabitFormationAnalytics
    func getPredictiveAnalytics(for userId: String) async throws -> PredictiveAnalytics
    
    // MARK: - Engagement Analytics
    func getEngagementAnalytics(for userId: String) async throws -> EngagementAnalytics
    func getSMSEngagementAnalytics(for userId: String) async throws -> SMSEngagementAnalytics
    func getNotificationEngagementAnalytics(for userId: String) async throws -> NotificationEngagementAnalytics
    
    // MARK: - Health and Wellness Insights
    func getWellnessInsights(for userId: String) async throws -> WellnessInsights
    func getMedicationAdherenceAnalytics(for userId: String) async throws -> MedicationAdherenceAnalytics
    func getActivityLevelAnalytics(for userId: String) async throws -> ActivityLevelAnalytics
    
    // MARK: - Family Analytics
    func getFamilyOverviewAnalytics(for userId: String) async throws -> FamilyOverviewAnalytics
    func getCaregiverEffectivenessAnalytics(for userId: String) async throws -> CaregiverEffectivenessAnalytics
    
    // MARK: - Real-time Analytics
    func getCurrentDayProgress(for userId: String) async throws -> DayProgressAnalytics
    func getLiveCompletionStats(for userId: String) async throws -> LiveCompletionStats
    
    // MARK: - Export and Reporting
    func generateAnalyticsReport(for userId: String, format: ReportFormat) async throws -> AnalyticsReport
    func exportAnalyticsData(for userId: String, timeRange: AnalyticsTimeRange) async throws -> Data
    func scheduleRecurringReport(for userId: String, frequency: ReportFrequency, format: ReportFormat) async throws
    
    // MARK: - Event Tracking
    func trackEvent(_ eventName: String, parameters: [String: Any]) async
}

// MARK: - Analytics Models

struct WeeklyAnalytics: Codable {
    let userId: String
    let weekStartDate: Date
    let weekEndDate: Date
    let completionRate: Double
    let totalTasks: Int
    let completedTasks: Int
    let currentStreak: Int
    let dailyCompletion: [Double] // 7 days
    let categoryBreakdown: [TaskCategory: CategoryStats]
    let averageResponseTime: TimeInterval
    let improvementFromLastWeek: Double
    let topPerformingProfile: String?
    let generatedAt: Date
    
    var weeklyScore: Int {
        return Int(completionRate * 100)
    }
    
    var isImprovingTrend: Bool {
        return improvementFromLastWeek > 0
    }
}

struct MonthlyAnalytics: Codable {
    let userId: String
    let monthStartDate: Date
    let monthEndDate: Date
    let overallCompletionRate: Double
    let totalTasks: Int
    let completedTasks: Int
    let longestStreak: Int
    let averageWeeklyCompletion: Double
    let weeklyTrends: [WeeklyTrendData]
    let categoryInsights: [CategoryInsight]
    let habitFormationProgress: [HabitProgress]
    let profileComparison: [ProfilePerformanceSummary]
    let goals: [MonthlyGoal]
    let achievements: [Achievement]
    let generatedAt: Date
}

struct CustomPeriodAnalytics: Codable {
    let userId: String
    let startDate: Date
    let endDate: Date
    let totalDays: Int
    let completionRate: Double
    let totalTasks: Int
    let completedTasks: Int
    let averageDailyTasks: Double
    let bestDay: Date?
    let worstDay: Date?
    let consistencyScore: Double
    let trendDirection: TrendDirection
    let significantEvents: [AnalyticsEvent]
}

struct ProfileTrendData: Codable {
    let profileId: String
    let profileName: String
    let dailyCompletionRates: [Date: Double]
    let taskCategoryTrends: [TaskCategory: TrendData]
    let responseTimeTrends: [Date: TimeInterval]
    let engagementTrends: [Date: Double]
    let predictionData: PredictionData
}

struct TaskAnalytics: Codable {
    let taskId: String
    let taskTitle: String
    let category: TaskCategory
    let completionRate: Double
    let totalScheduled: Int
    let totalCompleted: Int
    let averageResponseTime: TimeInterval
    let bestResponseTime: TimeInterval
    let worstResponseTime: TimeInterval
    let responseTimeVariance: Double
    let completionPattern: CompletionPattern
    let difficultiesDetected: [TaskDifficulty]
    let improvementSuggestions: [ImprovementSuggestion]
}

struct CategoryAnalytics: Codable {
    let userId: String
    let categoryStats: [TaskCategory: CategoryStats]
    let bestPerformingCategory: TaskCategory?
    let worstPerformingCategory: TaskCategory?
    let categoryTrends: [TaskCategory: TrendDirection]
    let categoryCorrelations: [CategoryCorrelation]
    let generatedAt: Date
}

struct CategoryStats: Codable {
    let category: TaskCategory
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double
    let averageResponseTime: TimeInterval
    let streak: Int
    let improvement: Double
    
    var performanceGrade: PerformanceGrade {
        switch completionRate {
        case 0.9...1.0:
            return .excellent
        case 0.7..<0.9:
            return .good
        case 0.5..<0.7:
            return .fair
        case 0.3..<0.5:
            return .poor
        default:
            return .needsImprovement
        }
    }
}

struct CompletionRateAnalytics: Codable {
    let userId: String
    let overallCompletionRate: Double
    let completionRateByDay: [Weekday: Double]
    let completionRateByTimeOfDay: [Int: Double]
    let completionRateByCategory: [TaskCategory: Double]
    let completionRateByProfile: [String: Double]
    let historicalTrend: [Date: Double]
    let benchmarkComparison: BenchmarkData
    let factors: [CompletionFactor]
}

struct ResponseTimeAnalytics: Codable {
    let userId: String
    let averageResponseTime: TimeInterval
    let medianResponseTime: TimeInterval
    let fastestResponseTime: TimeInterval
    let slowestResponseTime: TimeInterval
    let responseTimeByCategory: [TaskCategory: TimeInterval]
    let responseTimeByProfile: [String: TimeInterval]
    let responseTimeByTimeOfDay: [Int: TimeInterval]
    let responseTimeDistribution: [TimeInterval: Int]
    let improvementTrend: TrendDirection
}

struct StreakAnalytics: Codable {
    let userId: String
    let currentStreak: Int
    let longestStreak: Int
    let totalStreaks: Int
    let averageStreakLength: Double
    let streaksByCategory: [TaskCategory: StreakData]
    let streaksByProfile: [String: StreakData]
    let streakBreakReasons: [StreakBreakReason]
    let streakPrediction: StreakPrediction
    let milestones: [StreakMilestone]
}

struct HabitFormationAnalytics: Codable {
    let userId: String
    let habitStrength: Double // 0-1 scale
    let daysToHabitFormation: Int?
    let habitFormationStage: HabitStage
    let consistencyScore: Double
    let automaticityLevel: Double
    let contextualTriggers: [ContextTrigger]
    let resistanceFactors: [ResistanceFactor]
    let recommendations: [HabitRecommendation]
}

struct PredictiveAnalytics: Codable {
    let userId: String
    let completionPrediction: PredictionResult
    let streakPrediction: PredictionResult
    let engagementPrediction: PredictionResult
    let riskFactors: [RiskFactor]
    let interventionSuggestions: [InterventionSuggestion]
    let confidenceLevel: Double
    let dataQuality: DataQualityScore
}

struct EngagementAnalytics: Codable {
    let userId: String
    let overallEngagementScore: Double
    let engagementTrend: TrendDirection
    let engagementByProfile: [String: Double]
    let engagementByCategory: [TaskCategory: Double]
    let engagementByTimeOfDay: [Int: Double]
    let engagementFactors: [EngagementFactor]
    let disengagementRisks: [DisengagementRisk]
    let boostStrategies: [BoostStrategy]
}

struct SMSEngagementAnalytics: Codable {
    let userId: String
    let responseRate: Double
    let averageResponseTime: TimeInterval
    let positiveResponseRate: Double
    let textVsPhotoPreference: ResponseTypePreference
    let optimalSendingTimes: [Int] // Hours of day
    let messageEffectiveness: [SMSMessageType: Double]
    let engagementTrend: TrendDirection
}

struct NotificationEngagementAnalytics: Codable {
    let userId: String
    let openRate: Double
    let actionRate: Double
    let dismissalRate: Double
    let optimalDeliveryTimes: [Int]
    let categoryPerformance: [AnalyticsNotificationCategory: Double]
    let interactionPatterns: [InteractionPattern]
}

struct WellnessInsights: Codable {
    let userId: String
    let overallWellnessScore: Double
    let medicationAdherence: Double
    let exerciseConsistency: Double
    let socialEngagement: Double
    let healthMonitoring: Double
    let safetyCompliance: Double
    let wellnessTrends: [WellnessTrend]
    let healthRisks: [HealthRisk]
    let recommendations: [WellnessRecommendation]
}

struct MedicationAdherenceAnalytics: Codable {
    let userId: String
    let adherenceRate: Double
    let missedDoses: Int
    let adherenceByMedication: [String: Double]
    let adherenceByTimeOfDay: [Int: Double]
    let adherenceByProfile: [String: Double]
    let riskFactors: [AdherenceRiskFactor]
    let interventions: [AdherenceIntervention]
}

struct ActivityLevelAnalytics: Codable {
    let userId: String
    let averageActivityScore: Double
    let activityTrends: [Date: Double]
    let activityByCategory: [TaskCategory: Double]
    let activityByProfile: [String: Double]
    let activityGoals: [ActivityGoal]
    let progressTowardsGoals: [String: Double]
}

struct FamilyOverviewAnalytics: Codable {
    let userId: String
    let totalProfiles: Int
    let activeProfiles: Int
    let familyCompletionRate: Double
    let profilePerformance: [ProfilePerformanceSummary]
    let familyTrends: [FamilyTrend]
    let caregiverInsights: [CaregiverInsight]
    let familyGoals: [FamilyGoal]
}

struct CaregiverEffectivenessAnalytics: Codable {
    let userId: String
    let effectivenessScore: Double
    let responseRate: Double
    let interventionSuccess: Double
    let supportPatterns: [SupportPattern]
    let communicationQuality: Double
    let caregiverStress: CaregiverStressLevel
    let recommendations: [CaregiverRecommendation]
}

struct DayProgressAnalytics: Codable {
    let userId: String
    let date: Date
    let completedTasks: Int
    let totalScheduledTasks: Int
    let completionRate: Double
    let onTrackForDailyGoal: Bool
    let hoursRemaining: Int
    let upcomingTasks: [UpcomingTask]
    let realtimeStreak: Int
}

struct LiveCompletionStats: Codable {
    let userId: String
    let lastUpdated: Date
    let tasksCompletedToday: Int
    let tasksRemainingToday: Int
    let currentDayScore: Double
    let weeklyProgress: Double
    let activeStreaks: [String: Int] // ProfileId -> streak
    let recentCompletions: [RecentCompletion]
}

struct AnalyticsReport: Codable {
    let userId: String
    let reportType: ReportType
    let generatedAt: Date
    let timeRange: TimeRange
    let format: ReportFormat
    let sections: [ReportSection]
    let summary: ReportSummary
    let recommendations: [ReportRecommendation]
    let appendices: [ReportAppendix]
}

// MARK: - Supporting Types

enum TrendDirection: String, CaseIterable, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    case volatile = "volatile"
}

enum PerformanceGrade: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case needsImprovement = "needsImprovement"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .needsImprovement: return "red"
        }
    }
}

enum HabitStage: String, CaseIterable, Codable {
    case formation = "formation"      // 0-21 days
    case development = "development"  // 21-66 days
    case maintenance = "maintenance"  // 66+ days
    case mastery = "mastery"         // Highly automatic
}

enum ReportFormat: String, CaseIterable, Codable {
    case pdf = "pdf"
    case csv = "csv"
    case json = "json"
    case html = "html"
}

enum ReportFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
}

enum ReportType: String, CaseIterable, Codable {
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"
    case medical = "medical"
    case family = "family"
}

// MARK: - Analytics Time Range (RESTORED FROM app-structure.txt)
// =====================================================
// AnalyticsTimeRange - SYSTEMATIC RESTORATION
// =====================================================
// PURPOSE: Defines time period options for analytics queries
// STATUS: ✅ RESTORED - was incorrectly removed during previous session
// USAGE: Used in AnalyticsServiceProtocol and AnalyticsViewModel
// VARIABLES TO REMEMBER: thisWeek, thisMonth, thisYear, last30Days, etc.
// =====================================================
enum AnalyticsTimeRange: String, CaseIterable, Codable {
    case today = "today"                // NOTE: Used in AnalyticsViewModel
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case thisYear = "thisYear"
    case last7Days = "last7Days"        // NOTE: AnalyticsViewModel expects this case
    case last30Days = "last30Days"      // NOTE: Also used in AnalyticsViewModel  
    case last90Days = "last90Days"
    case allTime = "allTime"
    case custom = "custom"
}

// MARK: - Missing Model Definitions

// =====================================================
// NOTE: AnalyticsEvent is defined in MockAnalyticsService.swift  
// Making it Codable-compatible there instead of duplicating
// =====================================================

struct AnalyticsProfileComparisonResult: Codable {
    let profileComparisons: [ProfilePerformanceSummary]
    let overallInsights: [String]
    let generatedAt: Date
}

struct WeeklyTrendData: Codable {
    let weekStartDate: Date
    let completionRate: Double
    let totalTasks: Int
    let completedTasks: Int
}

struct CategoryInsight: Codable {
    let category: TaskCategory
    let completionRate: Double
    let averageResponseTime: TimeInterval
    let insight: String
}

struct HabitProgress: Codable {
    let taskId: String
    let taskTitle: String
    let daysActive: Int
    let currentStreak: Int
    let formationPercentage: Double
}

struct ProfilePerformanceSummary: Codable {
    let profileId: String
    let profileName: String
    let completionRate: Double
    let averageResponseTime: TimeInterval
    let currentStreak: Int
}

struct MonthlyGoal: Codable {
    let goalId: String
    let title: String
    let targetValue: Double
    let currentValue: Double
    let isAchieved: Bool
}

struct Achievement: Codable {
    let achievementId: String
    let title: String
    let description: String
    let unlockedAt: Date
    let badgeIcon: String
}

// MARK: - Additional Missing Type Definitions

struct TrendData: Codable {
    let direction: TrendDirection
    let changePercentage: Double
    let dataPoints: [Date: Double]
}

struct PredictionData: Codable {
    let predictedValue: Double
    let confidenceIntervalLower: Double
    let confidenceIntervalUpper: Double
    let confidence: Double
}

struct CompletionPattern: Codable {
    let patternType: String
    let description: String
    let strength: Double
}

struct TaskDifficulty: Codable {
    let type: String
    let severity: Double
    let description: String
}

struct ImprovementSuggestion: Codable {
    let suggestionId: String
    let title: String
    let description: String
    let priority: Int
}

struct CategoryCorrelation: Codable {
    let category1: TaskCategory
    let category2: TaskCategory
    let correlationStrength: Double
}

struct BenchmarkData: Codable {
    let averageRate: Double
    let topPerformerRate: Double
    let percentileRank: Double
}

struct CompletionFactor: Codable {
    let factorName: String
    let impact: Double
    let description: String
}

struct StreakData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let averageStreak: Double
}

struct StreakBreakReason: Codable {
    let reason: String
    let frequency: Int
    let preventable: Bool
}

struct StreakPrediction: Codable {
    let predictedDuration: Int
    let confidence: Double
    let riskFactors: [String]
}

struct StreakMilestone: Codable {
    let days: Int
    let title: String
    let achieved: Bool
    let achievedDate: Date?
}

struct ContextTrigger: Codable {
    let triggerType: String
    let effectiveness: Double
    let description: String
}

struct ResistanceFactor: Codable {
    let factorType: String
    let impact: Double
    let mitigation: String
}

struct HabitRecommendation: Codable {
    let recommendationId: String
    let title: String
    let description: String
    let expectedImpact: Double
}

struct PredictionResult: Codable {
    let predictedValue: Double
    let confidence: Double
    let timeHorizon: Int // days
}

struct RiskFactor: Codable {
    let riskType: String
    let severity: Double
    let description: String
}

struct InterventionSuggestion: Codable {
    let suggestionId: String
    let type: String
    let description: String
    let urgency: Int
}

struct DataQualityScore: Codable {
    let overall: Double
    let completeness: Double
    let consistency: Double
    let recency: Double
}

struct EngagementFactor: Codable {
    let factorName: String
    let contribution: Double
    let trend: TrendDirection
}

struct DisengagementRisk: Codable {
    let riskType: String
    let probability: Double
    let impact: String
}

struct BoostStrategy: Codable {
    let strategyId: String
    let title: String
    let description: String
    let expectedImpact: Double
}

struct ResponseTypePreference: Codable {
    let preferredType: ResponseType
    let preferenceStrength: Double
}

struct InteractionPattern: Codable {
    let patternType: String
    let frequency: Int
    let description: String
}

struct WellnessTrend: Codable {
    let metric: String
    let direction: TrendDirection
    let changePercentage: Double
}

struct HealthRisk: Codable {
    let riskType: String
    let severity: Double
    let description: String
}

struct WellnessRecommendation: Codable {
    let recommendationId: String
    let category: String
    let title: String
    let description: String
}

struct AdherenceRiskFactor: Codable {
    let factorType: String
    let impact: Double
    let frequency: Int
}

struct AdherenceIntervention: Codable {
    let interventionId: String
    let type: String
    let description: String
    let effectiveness: Double
}

struct ActivityGoal: Codable {
    let goalId: String
    let title: String
    let targetValue: Double
    let currentValue: Double
}

struct FamilyTrend: Codable {
    let trendType: String
    let direction: TrendDirection
    let description: String
}

struct CaregiverInsight: Codable {
    let insightId: String
    let type: String
    let message: String
    let actionable: Bool
}

struct FamilyGoal: Codable {
    let goalId: String
    let title: String
    let progress: Double
}

struct SupportPattern: Codable {
    let patternType: String
    let frequency: Int
    let effectiveness: Double
}

enum CaregiverStressLevel: String, Codable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
}

struct CaregiverRecommendation: Codable {
    let recommendationId: String
    let title: String
    let description: String
    let priority: Int
}

struct UpcomingTask: Codable {
    let taskId: String
    let title: String
    let scheduledTime: Date
    let profileName: String
}

struct RecentCompletion: Codable {
    let taskId: String
    let taskTitle: String
    let completedAt: Date
    let profileName: String
}

struct ReportSection: Codable {
    let title: String
    let content: String
    let charts: [String]
}

struct ReportSummary: Codable {
    let keyMetrics: [String: Double]
    let highlights: [String]
    let concerns: [String]
}

struct ReportRecommendation: Codable {
    let title: String
    let description: String
    let priority: Int
}

struct ReportAppendix: Codable {
    let title: String
    let content: String
}

enum AnalyticsNotificationCategory: String, Codable {
    case taskReminder = "taskReminder"
    case responseReceived = "responseReceived"
    case streakUpdate = "streakUpdate"
    case achievement = "achievement"
    case alert = "alert"
}

struct TimeRange: Codable {
    let startDate: Date
    let endDate: Date
}

// MARK: - Analytics Errors

enum AnalyticsError: LocalizedError {
    case insufficientData
    case calculationFailed
    case invalidTimeRange
    case userNotFound
    case dataCorrupted
    case reportGenerationFailed
    case exportFailed
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Not enough data to generate analytics. Please use the app for a few days first."
        case .calculationFailed:
            return "Failed to calculate analytics. Please try again."
        case .invalidTimeRange:
            return "Invalid time range specified for analytics."
        case .userNotFound:
            return "User not found for analytics calculation."
        case .dataCorrupted:
            return "Analytics data appears to be corrupted."
        case .reportGenerationFailed:
            return "Failed to generate analytics report."
        case .exportFailed:
            return "Failed to export analytics data."
        case .unknownError(let message):
            return "Analytics error: \(message)"
        }
    }
}