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

    // Custom decoder to handle old documents missing new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        userId = try container.decode(String.self, forKey: .userId)
        textResponse = try container.decodeIfPresent(String.self, forKey: .textResponse)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        receivedAt = try container.decode(Date.self, forKey: .receivedAt)
        responseType = try container.decode(ResponseType.self, forKey: .responseType)

        // New fields with defaults for backwards compatibility
        isConfirmationResponse = try container.decodeIfPresent(Bool.self, forKey: .isConfirmationResponse) ?? false
        isPositiveConfirmation = try container.decodeIfPresent(Bool.self, forKey: .isPositiveConfirmation) ?? false
        responseScore = try container.decodeIfPresent(Double.self, forKey: .responseScore)
        processingNotes = try container.decodeIfPresent(String.self, forKey: .processingNotes)
    }

    // Standard initializer for creating new instances
    init(
        id: String,
        taskId: String?,
        profileId: String?,
        userId: String,
        textResponse: String?,
        photoData: Data?,
        isCompleted: Bool,
        receivedAt: Date,
        responseType: ResponseType,
        isConfirmationResponse: Bool,
        isPositiveConfirmation: Bool,
        responseScore: Double?,
        processingNotes: String?
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
            id: IDGenerator.messageID(twilioSID: nil),
            taskId: nil,
            profileId: profileId,
            userId: userId,
            textResponse: textResponse,
            photoData: nil,
            isCompleted: isPositive,
            receivedAt: Date(),
            responseType: .text,
            isConfirmationResponse: true,
            isPositiveConfirmation: isPositive,
            responseScore: nil,
            processingNotes: nil
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
            id: IDGenerator.messageID(twilioSID: nil),
            taskId: taskId,
            profileId: profileId,
            userId: userId,
            textResponse: textResponse,
            photoData: photoData,
            isCompleted: isCompleted,
            receivedAt: Date(),
            responseType: responseType,
            isConfirmationResponse: false,
            isPositiveConfirmation: false,
            responseScore: nil,
            processingNotes: nil
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