import Foundation

// MARK: - SMS Response Model
struct SMSResponse: Codable, Identifiable, Hashable {
    let id: String
    let taskId: String?
    let profileId: String?
    let userId: String
    let textResponse: String?
    let photoData: Data?
    let isCompleted: Bool
    let receivedAt: Date
    let responseType: ResponseType
    let isConfirmationResponse: Bool
    let isPositiveConfirmation: Bool
    let responseScore: Double?
    let processingNotes: String?
    
    init(
        id: String,
        taskId: String? = nil,
        profileId: String? = nil,
        userId: String,
        textResponse: String? = nil,
        photoData: Data? = nil,
        isCompleted: Bool = false,
        receivedAt: Date = Date(),
        responseType: ResponseType = .text,
        isConfirmationResponse: Bool = false,
        isPositiveConfirmation: Bool = false,
        responseScore: Double? = nil,
        processingNotes: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.profileId = profileId
        self.userId = userId
        self.textResponse = textResponse
        self.photoData = photoData
        self.isCompleted = isCompleted
        self.receivedAt = receivedAt
        self.responseType = responseType
        self.isConfirmationResponse = isConfirmationResponse
        self.isPositiveConfirmation = isPositiveConfirmation
        self.responseScore = responseScore
        self.processingNotes = processingNotes
    }
}

// MARK: - SMS Response Extensions
extension SMSResponse {
    var hasTextResponse: Bool {
        return textResponse?.isEmpty == false
    }
    
    var hasPhotoResponse: Bool {
        return photoData != nil
    }
    
    // MARK: - Gallery View Properties
    var photoURL: String? {
        // In production, this would be a URL to the uploaded photo
        // For now, return a placeholder or nil
        return hasPhotoResponse ? "placeholder_photo_url" : nil
    }
    
    var textContent: String? {
        return textResponse
    }
    
    var taskTitle: String? {
        // In production, this would fetch the task title from taskId
        // For now, return a placeholder
        return taskId != nil ? "Task \(taskId?.suffix(6) ?? "")" : nil
    }
    
    var isFavorite: Bool {
        // This would be stored in user preferences or database
        // For now, return false as placeholder
        return false
    }
    
    var responseContent: String {
        if let text = textResponse, !text.isEmpty {
            return text
        } else if hasPhotoResponse {
            return "📷 Photo response"
        } else {
            return "No response content"
        }
    }
    
    var isValidResponse: Bool {
        return hasTextResponse || hasPhotoResponse
    }
    
    var isTaskResponse: Bool {
        return taskId != nil
    }
    
    var isProfileConfirmation: Bool {
        return isConfirmationResponse && profileId != nil
    }
    
    var formattedReceivedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: receivedAt)
    }
    
    var timeSinceReceived: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(receivedAt)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    var responseQuality: ResponseQuality {
        if isConfirmationResponse {
            return isPositiveConfirmation ? .excellent : .poor
        }
        
        guard let score = responseScore else {
            return .unknown
        }
        
        if score >= 0.8 {
            return .excellent
        } else if score >= 0.6 {
            return .good
        } else if score >= 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
    
    static func createConfirmationResponse(
        profileId: String,
        userId: String,
        textResponse: String,
        isPositive: Bool
    ) -> SMSResponse {
        return SMSResponse(
            id: UUID().uuidString,
            profileId: profileId,
            userId: userId,
            textResponse: textResponse,
            isCompleted: isPositive,
            responseType: .text,
            isConfirmationResponse: true,
            isPositiveConfirmation: isPositive
        )
    }
    
    static func createTaskResponse(
        taskId: String,
        profileId: String,
        userId: String,
        textResponse: String? = nil,
        photoData: Data? = nil,
        isCompleted: Bool = true
    ) -> SMSResponse {
        let responseType: ResponseType
        if textResponse != nil && photoData != nil {
            responseType = .both
        } else if photoData != nil {
            responseType = .photo
        } else {
            responseType = .text
        }
        
        return SMSResponse(
            id: UUID().uuidString,
            taskId: taskId,
            profileId: profileId,
            userId: userId,
            textResponse: textResponse,
            photoData: photoData,
            isCompleted: isCompleted,
            responseType: responseType
        )
    }
}

// MARK: - Response Quality
enum ResponseQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        case .unknown:
            return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent:
            return "star.fill"
        case .good:
            return "hand.thumbsup.fill"
        case .fair:
            return "hand.raised.fill"
        case .poor:
            return "hand.thumbsdown.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor:
            return "red"
        case .unknown:
            return "gray"
        }
    }
}