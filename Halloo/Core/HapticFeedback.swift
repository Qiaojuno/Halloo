import UIKit

/// Centralized haptic feedback utilities
/// Provides consistent, easy-to-use haptic feedback across the app
struct HapticFeedback {

    // MARK: - Impact Feedback

    /// Light impact feedback (for subtle interactions like selections)
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium impact feedback (for standard button taps)
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy impact feedback (for significant actions)
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Soft impact feedback (for gentle interactions)
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success notification (for completed actions)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning notification (for cautionary actions)
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error notification (for failed actions)
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection change feedback (for picker-style interactions)
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
