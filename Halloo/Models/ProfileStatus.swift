import Foundation
import SwiftUI

// MARK: - Profile Status
enum ProfileStatus: String, CaseIterable, Codable {
    case pendingConfirmation = "pendingConfirmation"
    case confirmed = "confirmed"
    case inactive = "inactive"
    
    var displayName: String {
        switch self {
        case .pendingConfirmation:
            return "Pending Confirmation"
        case .confirmed:
            return "Confirmed"
        case .inactive:
            return "Inactive"
        }
    }
    
    var canReceiveReminders: Bool {
        return self == .confirmed
    }
    
    var statusColor: Color {
        switch self {
        case .pendingConfirmation:
            return .orange
        case .confirmed:
            return .green
        case .inactive:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .pendingConfirmation:
            return "clock"
        case .confirmed:
            return "checkmark.circle.fill"
        case .inactive:
            return "pause.circle"
        }
    }
}