import Foundation

// MARK: - Elderly Profile Model
struct ElderlyProfile: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let phoneNumber: String
    let relationship: String
    let isEmergencyContact: Bool
    let timeZone: String
    let notes: String
    var photoURL: String?
    var status: ProfileStatus
    let createdAt: Date
    var lastActiveAt: Date
    var confirmedAt: Date?
    
    // MARK: - Streak Properties
    var currentStreak: Int
    var lastCompletionDate: Date?
    
    init(
        id: String,
        userId: String,
        name: String,
        phoneNumber: String,
        relationship: String,
        isEmergencyContact: Bool = false,
        timeZone: String = TimeZone.current.identifier,
        notes: String = "",
        photoURL: String? = nil,
        status: ProfileStatus = .pendingConfirmation,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        confirmedAt: Date? = nil,
        currentStreak: Int = 0,
        lastCompletionDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isEmergencyContact = isEmergencyContact
        self.timeZone = timeZone
        self.notes = notes
        self.photoURL = photoURL
        self.status = status
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.confirmedAt = confirmedAt
        self.currentStreak = currentStreak
        self.lastCompletionDate = lastCompletionDate
    }
}

// MARK: - Elderly Profile Extensions
extension ElderlyProfile {
    var isConfirmed: Bool {
        return status == .confirmed && confirmedAt != nil
    }
    
    var canReceiveTasks: Bool {
        return status == .confirmed
    }
    
    var displayTimeZone: TimeZone {
        return TimeZone(identifier: timeZone) ?? TimeZone.current
    }
    
    var formattedPhoneNumber: String {
        return phoneNumber.formattedPhoneNumber
    }
    
    var daysSinceCreated: Int {
        return Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
    
    var daysSinceLastActive: Int {
        return Calendar.current.dateComponents([.day], from: lastActiveAt, to: Date()).day ?? 0
    }
    
    var isRecentlyActive: Bool {
        return daysSinceLastActive <= 7
    }
    
    mutating func markAsActive() {
        self.lastActiveAt = Date()
    }
    
    mutating func confirmProfile() {
        self.status = .confirmed
        self.confirmedAt = Date()
        self.lastActiveAt = Date()
    }
    
    mutating func deactivateProfile() {
        self.status = .inactive
    }
    
    // MARK: - Streak Methods
    
    /// Updates streak based on task completion for a given date
    /// If at least one task completed: increment streak (or maintain if same day)
    /// If tasks exist but zero completed: reset streak to 0
    /// If no tasks scheduled: no change to streak
    mutating func updateStreak(tasksCompletedToday: Int, totalTasksToday: Int, completionDate: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: completionDate)
        let lastCompletionDay = lastCompletionDate.map { calendar.startOfDay(for: $0) }
        
        // If no tasks scheduled today, no change to streak
        guard totalTasksToday > 0 else { return }
        
        // If tasks exist but none completed, reset streak
        guard tasksCompletedToday > 0 else {
            currentStreak = 0
            // Don't update lastCompletionDate since nothing was completed
            return
        }
        
        // At least one task was completed
        if let lastDay = lastCompletionDay {
            if today == lastDay {
                // Same day completion - no change to streak count
                return
            } else if calendar.dateComponents([.day], from: lastDay, to: today).day == 1 {
                // Next consecutive day - increment streak
                currentStreak += 1
            } else {
                // Gap in days - restart streak at 1
                currentStreak = 1
            }
        } else {
            // First ever completion
            currentStreak = 1
        }
        
        lastCompletionDate = completionDate
    }
    
    /// Checks if streak should be reset due to missed day with tasks
    mutating func checkStreakReset(totalTasksYesterday: Int) {
        guard totalTasksYesterday > 0 else { return } // No tasks yesterday, no reset needed
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        let lastCompletionDay = lastCompletionDate.map { calendar.startOfDay(for: $0) }
        
        // If last completion wasn't yesterday and there were tasks, reset streak
        if lastCompletionDay != yesterdayStart {
            currentStreak = 0
        }
    }
}