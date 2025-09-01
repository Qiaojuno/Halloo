import Foundation
import SwiftUI

// MARK: - Task Status
enum TaskStatus: String, CaseIterable, Codable {
    case active = "active"
    case paused = "paused"
    case archived = "archived"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .archived:
            return "Archived"
        case .expired:
            return "Expired"
        }
    }
    
    var description: String {
        switch self {
        case .active:
            return "Task is actively sending reminders"
        case .paused:
            return "Task reminders are temporarily stopped"
        case .archived:
            return "Task is no longer active and archived"
        case .expired:
            return "Task has passed its end date"
        }
    }
    
    var isExecutable: Bool {
        return self == .active
    }
    
    var canBeResumed: Bool {
        return self == .paused
    }
    
    var canBeArchived: Bool {
        return self == .active || self == .paused
    }
    
    var statusColor: Color {
        switch self {
        case .active:
            return .green
        case .paused:
            return .orange
        case .archived:
            return .gray
        case .expired:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .active:
            return "play.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .archived:
            return "archivebox.fill"
        case .expired:
            return "clock.badge.xmark"
        }
    }
}