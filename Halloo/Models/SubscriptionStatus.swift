import Foundation

// MARK: - Subscription Status
enum SubscriptionStatus: String, CaseIterable, Codable {
    case trial = "trial"
    case active = "active"
    case expired = "expired"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .trial:
            return "Free Trial"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var isValidForUsage: Bool {
        switch self {
        case .trial, .active:
            return true
        case .expired, .cancelled:
            return false
        }
    }
}