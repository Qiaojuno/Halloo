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
        confirmedAt: Date? = nil
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

    var daysSinceCreated: Int {
        return Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
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
}