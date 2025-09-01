import Foundation
import SwiftUI

// MARK: - Task Category
enum TaskCategory: String, CaseIterable, Codable {
    case medication = "medication"
    case exercise = "exercise"
    case social = "social"
    case health = "health"
    case meal = "meal"
    case hygiene = "hygiene"
    case safety = "safety"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .medication:
            return "Medication"
        case .exercise:
            return "Exercise"
        case .social:
            return "Social"
        case .health:
            return "Health Check"
        case .meal:
            return "Meals"
        case .hygiene:
            return "Personal Care"
        case .safety:
            return "Safety"
        case .other:
            return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .medication:
            return "pills.fill"
        case .exercise:
            return "figure.walk"
        case .social:
            return "person.2.fill"
        case .health:
            return "heart.fill"
        case .meal:
            return "fork.knife"
        case .hygiene:
            return "drop.fill"
        case .safety:
            return "shield.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .medication:
            return .red
        case .exercise:
            return .green
        case .social:
            return .blue
        case .health:
            return .pink
        case .meal:
            return .orange
        case .hygiene:
            return .cyan
        case .safety:
            return .yellow
        case .other:
            return .gray
        }
    }
    
    var defaultDeadlineMinutes: Int {
        switch self {
        case .medication:
            return 15 // More urgent
        case .health, .safety:
            return 30 // Important but not as time-sensitive
        case .exercise, .hygiene:
            return 60 // Can be done within an hour
        case .meal:
            return 30 // Food timing matters
        case .social:
            return 120 // Social activities are flexible
        case .other:
            return 60 // Default
        }
    }
    
    var suggestedReminders: [String] {
        switch self {
        case .medication:
            return [
                "Take morning medication",
                "Take evening medication",
                "Check blood pressure",
                "Apply prescription cream"
            ]
        case .exercise:
            return [
                "Take a 10-minute walk",
                "Do stretching exercises",
                "Physical therapy exercises",
                "Chair exercises"
            ]
        case .social:
            return [
                "Call family member",
                "Video chat with grandchildren",
                "Attend community activity",
                "Check in with neighbor"
            ]
        case .health:
            return [
                "Check blood glucose",
                "Weigh yourself",
                "Take temperature",
                "Record symptoms"
            ]
        case .meal:
            return [
                "Eat breakfast",
                "Drink water",
                "Take vitamins with lunch",
                "Prepare dinner"
            ]
        case .hygiene:
            return [
                "Brush teeth",
                "Take shower",
                "Apply moisturizer",
                "Trim nails"
            ]
        case .safety:
            return [
                "Check door locks",
                "Turn off stove",
                "Charge medical alert device",
                "Clear walkways"
            ]
        case .other:
            return [
                "Custom reminder",
                "Daily check-in",
                "Complete task"
            ]
        }
    }
}