import Foundation
import SwiftUI

// MARK: - Analytics Time Range
/// Defines time range options for filtering analytics data
enum AnalyticsTimeRange: String, CaseIterable, Codable, Hashable {
    case today = "today"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case last7Days = "last7Days"
    case last30Days = "last30Days"
    case thisYear = "thisYear"
    case allTime = "allTime"

    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .thisWeek:
            return "This Week"
        case .thisMonth:
            return "This Month"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .thisYear:
            return "This Year"
        case .allTime:
            return "All Time"
        }
    }

    var description: String {
        switch self {
        case .today:
            return "Analytics for today only"
        case .thisWeek:
            return "Analytics from the start of this week"
        case .thisMonth:
            return "Analytics from the start of this month"
        case .last7Days:
            return "Analytics for the past 7 days"
        case .last30Days:
            return "Analytics for the past 30 days"
        case .thisYear:
            return "Analytics from the start of this year"
        case .allTime:
            return "Analytics for all available data"
        }
    }

    /// Returns the date range (start, end) for the selected time range
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return (startOfDay, endOfDay)

        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
            return (startOfWeek, endOfWeek)

        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
            return (startOfMonth, endOfMonth)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)

        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) ?? now
            return (startOfYear, endOfYear)

        case .allTime:
            // Return a very early date to present for all-time analytics
            let distantPast = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date.distantPast
            return (distantPast, now)
        }
    }

    /// Icon to display for the time range
    var icon: String {
        switch self {
        case .today:
            return "calendar"
        case .thisWeek:
            return "calendar.badge.clock"
        case .thisMonth:
            return "calendar.circle"
        case .last7Days:
            return "arrow.counterclockwise"
        case .last30Days:
            return "arrow.counterclockwise.circle"
        case .thisYear:
            return "calendar.badge.plus"
        case .allTime:
            return "infinity"
        }
    }

    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .today:
            return "1D"
        case .thisWeek:
            return "1W"
        case .thisMonth:
            return "1M"
        case .last7Days:
            return "7D"
        case .last30Days:
            return "30D"
        case .thisYear:
            return "1Y"
        case .allTime:
            return "All"
        }
    }
}
