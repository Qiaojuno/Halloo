import Foundation

/// Centralized date and time formatting utilities
/// Uses cached formatters to avoid recreating DateFormatter objects (expensive operation)
/// All formatters use device locale and timezone for consistent, user-appropriate formatting
struct DateFormatters {

    // MARK: - Cached Formatters

    /// Shared time formatter: "5:23 PM"
    static let timeFormatter12Hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale.current // Use user's locale
        formatter.timeZone = TimeZone.current // Use user's timezone
        return formatter
    }()

    /// Shared time formatter (short style): "5:23 PM"
    static let timeFormatterShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current // Use user's locale
        formatter.timeZone = TimeZone.current // Use user's timezone
        return formatter
    }()

    /// Shared date formatter: "January 15, 2025"
    static let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale.current // Use user's locale
        formatter.timeZone = TimeZone.current // Use user's timezone
        return formatter
    }()

    // MARK: - Convenience Methods

    /// Format time as "5:23 PM"
    static func formatTime(_ date: Date) -> String {
        return timeFormatter12Hour.string(from: date)
    }

    /// Format time using short style
    static func formatTimeShort(_ date: Date) -> String {
        return timeFormatterShort.string(from: date)
    }

    /// Format date for section headers: "January 15, 2025"
    static func formatDateHeader(_ date: Date) -> String {
        return dateHeaderFormatter.string(from: date)
    }
}
