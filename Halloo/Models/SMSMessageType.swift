import Foundation

// MARK: - SMS Message Type
enum SMSMessageType: String, CaseIterable, Codable {
    case confirmation = "confirmation"
    case reminder = "reminder"
    case followUp = "followUp"
    case help = "help"
    case welcome = "welcome"
    
    var displayName: String {
        switch self {
        case .confirmation:
            return "Confirmation"
        case .reminder:
            return "Reminder"
        case .followUp:
            return "Follow-up"
        case .help:
            return "Help"
        case .welcome:
            return "Welcome"
        }
    }
    
    var description: String {
        switch self {
        case .confirmation:
            return "SMS sent to confirm profile setup"
        case .reminder:
            return "Task reminder SMS"
        case .followUp:
            return "Follow-up SMS for missed tasks"
        case .help:
            return "Help message explaining how to respond"
        case .welcome:
            return "Welcome message for new profiles"
        }
    }
    
    var priority: Int {
        switch self {
        case .confirmation:
            return 5 // Highest priority
        case .reminder:
            return 4
        case .followUp:
            return 3
        case .help:
            return 2
        case .welcome:
            return 1 // Lowest priority
        }
    }
    
    var expectsResponse: Bool {
        switch self {
        case .confirmation, .reminder:
            return true
        case .followUp, .help, .welcome:
            return false
        }
    }
}