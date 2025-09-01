import Foundation

// MARK: - Task Frequency
enum TaskFrequency: String, CaseIterable, Codable {
    case once = "once"
    case daily = "daily"
    case weekdays = "weekdays"
    case weekly = "weekly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .once:
            return "One Time"
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays Only"
        case .weekly:
            return "Weekly"
        case .custom:
            return "Custom Days"
        }
    }
    
    var description: String {
        switch self {
        case .once:
            return "This reminder will be sent once at the scheduled time"
        case .daily:
            return "This reminder will be sent every day at the scheduled time"
        case .weekdays:
            return "This reminder will be sent Monday through Friday"
        case .weekly:
            return "This reminder will be sent once per week on the scheduled day"
        case .custom:
            return "This reminder will be sent on selected days of the week"
        }
    }
    
    var requiresCustomDays: Bool {
        return self == .custom
    }
    
    var isRepeating: Bool {
        return self != .once
    }
    
    func isScheduledFor(date: Date, customDays: [Weekday] = []) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch self {
        case .once:
            return false // One-time tasks are handled separately
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
        case .weekly:
            return true // Weekly tasks repeat on the same day they were created
        case .custom:
            let dayOfWeek = Weekday.from(weekday: weekday)
            return customDays.contains(dayOfWeek)
        }
    }
}

// MARK: - Weekday Helper
enum Weekday: String, CaseIterable, Codable {
    case sunday = "sunday"
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    
    var displayName: String {
        switch self {
        case .sunday:
            return "Sunday"
        case .monday:
            return "Monday"
        case .tuesday:
            return "Tuesday"
        case .wednesday:
            return "Wednesday"
        case .thursday:
            return "Thursday"
        case .friday:
            return "Friday"
        case .saturday:
            return "Saturday"
        }
    }
    
    var shortName: String {
        switch self {
        case .sunday:
            return "Sun"
        case .monday:
            return "Mon"
        case .tuesday:
            return "Tue"
        case .wednesday:
            return "Wed"
        case .thursday:
            return "Thu"
        case .friday:
            return "Fri"
        case .saturday:
            return "Sat"
        }
    }
    
    var weekdayNumber: Int {
        switch self {
        case .sunday:
            return 1
        case .monday:
            return 2
        case .tuesday:
            return 3
        case .wednesday:
            return 4
        case .thursday:
            return 5
        case .friday:
            return 6
        case .saturday:
            return 7
        }
    }
    
    static func from(weekday: Int) -> Weekday {
        switch weekday {
        case 1:
            return .sunday
        case 2:
            return .monday
        case 3:
            return .tuesday
        case 4:
            return .wednesday
        case 5:
            return .thursday
        case 6:
            return .friday
        case 7:
            return .saturday
        default:
            return .monday
        }
    }
    
    static var weekdays: [Weekday] {
        return [.monday, .tuesday, .wednesday, .thursday, .friday]
    }
    
    static var weekends: [Weekday] {
        return [.saturday, .sunday]
    }
}