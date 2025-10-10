//
//  SMSServiceProtocol.swift
//  Hallo
//
//  Purpose: Defines SMS communication contract for elderly care reminders and family coordination
//  Key Features: 
//    • SMS delivery to elderly family members with photo and text support
//    • Response processing and sentiment analysis for care completion tracking
//    • Message templating with elderly-appropriate language and tone
//  Dependencies: Foundation, Twilio SMS API, Core Models (Task, ElderlyProfile)
//  
//  Business Context: Critical communication bridge between families and elderly users via SMS
//  Critical Paths: Task reminder delivery → Elderly SMS response → Family notification → Care coordination
//
//  Created by Claude Code on 2025-07-28
//

import Foundation

/// SMS communication service contract for elderly care reminders and family coordination messaging
///
/// This protocol defines the complete SMS communication interface for the Hallo app's elderly
/// care coordination system. It handles the critical communication pathway between families
/// and elderly users, managing task reminders, confirmation workflows, and response processing
/// with sensitivity to elderly technology comfort levels and communication preferences.
///
/// ## Core Responsibilities:
/// - **Elderly Care Messaging**: Send gentle, clear reminders about medication, exercise, and social tasks
/// - **SMS Confirmation Workflow**: Handle profile setup confirmations with YES/NO response processing
/// - **Response Analysis**: Process elderly SMS responses including text replies and photo submissions
/// - **Communication Templates**: Provide consistent, respectful messaging for different care contexts
/// - **Delivery Tracking**: Monitor SMS delivery success and elderly engagement patterns
///
/// ## Elderly Communication Considerations:
/// - **Simple Language**: Clear, direct messaging appropriate for elderly users
/// - **Flexible Responses**: Accept multiple response formats (YES, DONE, OK, photos)
/// - **Respectful Tone**: Gentle reminders that maintain elderly user dignity and autonomy
/// - **Error Tolerance**: Graceful handling of unclear or incomplete responses from elderly users
///
/// ## Usage Pattern:
/// ```swift
/// let smsService: SMSServiceProtocol = container.makeSMSService()
/// 
/// // Send care reminder to elderly family member
/// let result = try await smsService.sendSMS(
///     to: "+1234567890",
///     message: "Hi Grandma! Time for your morning medication.",
///     profileId: profileId,
///     messageType: .reminder
/// )
/// 
/// // Process elderly person's response
/// let response = try await smsService.processIncomingResponse(
///     from: "+1234567890",
///     message: "DONE",
///     receivedAt: Date(),
///     attachments: nil
/// )
/// ```
///
/// - Important: All SMS communication respects elderly users' communication preferences and capabilities
/// - Note: Supports both text-only and photo-enabled care task confirmations
/// - Warning: SMS delivery failures require family notification for alternative care coordination
protocol SMSServiceProtocol {
    
    // MARK: - Elderly Care SMS Delivery Operations
    
    /// Sends care reminder SMS to elderly family member with delivery tracking
    /// 
    /// Delivers gentle, clear care reminders to elderly users via SMS with proper
    /// message formatting, delivery confirmation, and family notification capabilities.
    /// Handles timezone adjustments and elderly-appropriate communication timing.
    ///
    /// - Parameter phoneNumber: Elderly family member's phone number for SMS delivery
    /// - Parameter message: Care reminder text with clear, respectful language
    /// - Parameter profileId: Elderly profile receiving the care reminder
    /// - Parameter messageType: Type of reminder (medication, exercise, social, confirmation)
    /// - Returns: Delivery result with success status and delivery timestamp
    /// - Throws: SMSError if delivery fails or phone number is blocked
    /// - Important: Message content should use elderly-appropriate language and tone
    func sendSMS(
        to phoneNumber: String,
        message: String,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult
    
    /// Sends care reminder with photo attachment for visual proof tasks
    /// 
    /// Delivers care reminders that include reference photos or visual instructions
    /// to help elderly users understand task requirements and provide appropriate
    /// photo responses for completion verification.
    ///
    /// - Parameter phoneNumber: Elderly family member's phone number for SMS delivery
    /// - Parameter message: Care reminder text explaining photo requirements
    /// - Parameter photoData: Reference image or instructional photo attachment
    /// - Parameter profileId: Elderly profile receiving the care reminder
    /// - Parameter messageType: Type of reminder requiring photo response
    /// - Returns: Delivery result with success status and delivery timestamp
    /// - Throws: SMSError if delivery fails or attachment is too large
    /// - Note: Photo attachments increase SMS delivery time and cost
    func sendSMSWithPhoto(
        to phoneNumber: String,
        message: String,
        photoData: Data,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult
    
    /// Sends multiple care reminders efficiently to elderly family members
    /// 
    /// Batch delivery system for sending care reminders to multiple elderly
    /// profiles or multiple reminders to the same elderly person with
    /// optimized delivery timing and rate limiting.
    ///
    /// - Parameter messages: Array of care reminder messages for batch delivery
    /// - Returns: Array of delivery results for each SMS in the batch
    /// - Throws: SMSError if batch processing fails or quota is exceeded
    /// - Important: Respects rate limiting to prevent elderly SMS overwhelming
    func sendBulkSMS(
        messages: [SMSMessage]
    ) async throws -> [SMSDeliveryResult]
    
    // MARK: - Elderly-Appropriate Message Template Generation
    
    /// Generates SMS confirmation message for elderly profile setup workflow
    /// 
    /// Creates warm, clear confirmation message that explains the purpose of
    /// SMS reminders and provides simple YES/NO response options for elderly
    /// users to consent to receiving care coordination messages.
    ///
    /// - Parameter profile: Elderly profile requiring SMS confirmation
    /// - Returns: Personalized confirmation message with clear instructions
    /// - Important: Message tone should be respectful and non-intimidating for elderly users
    func getConfirmationMessage(for profile: ElderlyProfile) -> String
    
    /// Generates personalized care task reminder message for elderly family member
    /// 
    /// Creates gentle, specific reminder message tailored to the care task type,
    /// elderly person's name, and communication preferences with clear completion
    /// instructions and appropriate urgency level.
    ///
    /// - Parameter task: Care task requiring SMS reminder delivery
    /// - Parameter profile: Elderly profile receiving the care reminder
    /// - Returns: Personalized task reminder with clear completion instructions
    /// - Note: Message content adapts based on task category and elderly preferences
    func getTaskReminderMessage(for task: Task, profile: ElderlyProfile) -> String
    
    /// Generates gentle follow-up message for overdue or missed care tasks
    /// 
    /// Creates supportive follow-up message for elderly users who haven't
    /// responded to initial care reminders, offering help and maintaining
    /// respectful communication without pressure or judgment.
    ///
    /// - Parameter task: Care task requiring follow-up reminder
    /// - Parameter profile: Elderly profile receiving the follow-up message
    /// - Returns: Gentle follow-up message with help options and support tone
    /// - Important: Follow-up messages should be supportive, not demanding
    func getFollowUpMessage(for task: Task, profile: ElderlyProfile) -> String

    /// Generates warm welcome message for newly confirmed elderly profiles
    /// 
    /// Creates friendly introduction message that welcomes elderly users to
    /// the care coordination system and sets positive expectations for the
    /// SMS reminder experience with family support context.
    ///
    /// - Parameter profile: Newly confirmed elderly profile
    /// - Returns: Welcoming message explaining care reminder benefits
    /// - Important: Welcome message should build confidence and trust with elderly users
    func getWelcomeMessage(for profile: ElderlyProfile) -> String
    
    // MARK: - SMS Delivery Monitoring and Analytics
    
    /// Checks current delivery status for specific care reminder SMS
    /// 
    /// Provides real-time delivery status tracking for family peace of mind,
    /// enabling families to know when elderly users have received care reminders
    /// and can expect responses or follow-up actions.
    ///
    /// - Parameter messageId: Unique identifier for the SMS delivery to track
    /// - Returns: Current delivery status (sent, delivered, failed, pending)
    /// - Throws: SMSError if status check fails or message not found
    /// - Important: Delivery status enables families to coordinate timely care intervention
    func checkDeliveryStatus(messageId: String) async throws -> SMSDeliveryStatus
    
    /// Generates comprehensive SMS delivery report for elderly profile analytics
    /// 
    /// Creates detailed delivery and engagement report for specific elderly
    /// profile over a date range, including delivery success rates, response
    /// patterns, and communication effectiveness metrics for family coordination.
    ///
    /// - Parameter profileId: Elderly profile for delivery report generation
    /// - Parameter startDate: Beginning of reporting period
    /// - Parameter endDate: End of reporting period
    /// - Returns: Comprehensive SMS delivery and engagement report
    /// - Throws: SMSError if report generation fails
    /// - Note: Reports help families optimize communication timing and frequency
    func getDeliveryReport(for profileId: String, from startDate: Date, to endDate: Date) async throws -> SMSDeliveryReport
    
    // MARK: - Elderly SMS Response Processing and Analysis
    
    /// Processes incoming SMS response from elderly family member with intelligent analysis
    /// 
    /// Analyzes elderly person's SMS response including text sentiment, photo attachments,
    /// and completion intent recognition with flexible interpretation for varying technology
    /// comfort levels and communication styles typical of elderly users.
    ///
    /// ## Response Processing Features:
    /// - **Flexible Text Recognition**: Accepts YES, DONE, OK, COMPLETED, and variations
    /// - **Photo Analysis**: Processes photo attachments for visual task completion proof
    /// - **Sentiment Analysis**: Determines positive/negative response intent and confidence
    /// - **Context Matching**: Associates responses with specific tasks and care contexts
    /// - **Help Recognition**: Identifies requests for assistance or confusion indicators
    ///
    /// - Parameter phoneNumber: Phone number of elderly family member sending response
    /// - Parameter message: Text content of SMS response from elderly user
    /// - Parameter receivedAt: Timestamp when response was received
    /// - Parameter attachments: Optional photo attachments for visual task proof
    /// - Returns: Processed response with completion analysis and recommended actions
    /// - Throws: SMSError if response processing fails or phone number not recognized
    /// - Important: Processing accommodates elderly communication patterns and technology limitations
    func processIncomingResponse(
        from phoneNumber: String,
        message: String,
        receivedAt: Date,
        attachments: [SMSAttachment]?
    ) async throws -> ProcessedSMSResponse
    
    // MARK: - Elderly Contact Management and Validation
    
    /// Validates phone number format for SMS delivery to elderly family members
    /// 
    /// Ensures phone number is properly formatted for reliable SMS delivery
    /// to elderly users, supporting international formats and carrier compatibility
    /// for consistent care reminder delivery.
    ///
    /// - Parameter phoneNumber: Phone number to validate for SMS compatibility
    /// - Returns: True if phone number is valid for SMS delivery
    /// - Note: Validation includes carrier compatibility checks for elderly user devices
    func validatePhoneNumber(_ phoneNumber: String) -> Bool
    
    /// Formats phone number for consistent SMS delivery and elderly profile management
    /// 
    /// Standardizes phone number format for reliable SMS delivery and consistent
    /// elderly profile identification across family care coordination workflows.
    ///
    /// - Parameter phoneNumber: Raw phone number input for standardization
    /// - Returns: Properly formatted phone number for SMS delivery
    /// - Important: Consistent formatting prevents duplicate elderly profile creation
    func formatPhoneNumber(_ phoneNumber: String) -> String
    
    /// Checks if elderly family member's phone number is blocked from SMS delivery
    /// 
    /// Verifies SMS delivery eligibility for elderly phone numbers, respecting
    /// opt-out requests and preventing SMS delivery to blocked contacts while
    /// maintaining family notification about delivery restrictions.
    ///
    /// - Parameter phoneNumber: Elderly family member's phone number to check
    /// - Returns: True if phone number is blocked from receiving SMS
    /// - Throws: SMSError if block status check fails
    func isPhoneNumberBlocked(_ phoneNumber: String) async throws -> Bool
    
    /// Blocks phone number from receiving care reminder SMS messages
    /// 
    /// Prevents SMS delivery to specific elderly phone number while maintaining
    /// family notification about communication restrictions and providing
    /// alternative care coordination options.
    ///
    /// - Parameter phoneNumber: Elderly phone number to block from SMS delivery
    /// - Throws: SMSError if blocking operation fails
    /// - Important: Blocking respects elderly user communication preferences and consent
    func blockPhoneNumber(_ phoneNumber: String) async throws
    
    /// Removes SMS delivery block for elderly family member's phone number
    /// 
    /// Restores SMS delivery capability for elderly phone number after consent
    /// is reestablished or communication preferences are updated by family
    /// coordination or elderly user request.
    ///
    /// - Parameter phoneNumber: Elderly phone number to unblock for SMS delivery
    /// - Throws: SMSError if unblocking operation fails
    /// - Note: Unblocking requires reconfirmation of elderly user consent
    func unblockPhoneNumber(_ phoneNumber: String) async throws
    
    // MARK: - SMS Usage Management and Elderly Protection
    
    /// Checks SMS quota status to prevent overwhelming elderly family members
    /// 
    /// Monitors SMS usage to ensure families don't exceed reasonable limits
    /// that could overwhelm elderly users with excessive reminders while
    /// providing usage feedback for family care coordination planning.
    ///
    /// - Parameter userId: Family user ID for quota status checking
    /// - Returns: Current SMS quota status with usage details and limits
    /// - Throws: SMSError if quota check fails
    /// - Important: Quota limits protect elderly users from SMS overwhelming
    func checkSMSQuota(for userId: String) async throws -> SMSQuotaStatus
    
    /// Retrieves remaining SMS quota for family care coordination planning
    /// 
    /// Provides families with current SMS usage availability for care reminder
    /// planning and helps prevent quota exhaustion during critical care periods
    /// while maintaining elderly user communication protection.
    ///
    /// - Parameter userId: Family user ID for remaining quota calculation
    /// - Returns: Number of SMS messages remaining in current quota period
    /// - Throws: SMSError if quota retrieval fails
    func getRemainingQuota(for userId: String) async throws -> Int
    
    /// Resets SMS quota for family user (administrative operation)
    /// 
    /// Administrative function to reset SMS quota limits for families
    /// experiencing legitimate high-usage periods or quota adjustment
    /// needs while maintaining elderly user protection principles.
    ///
    /// - Parameter userId: Family user ID for quota reset operation
    /// - Throws: SMSError if quota reset fails
    /// - Warning: Quota resets should be used carefully to maintain elderly user protection
    func resetQuota(for userId: String) async throws
    
    // MARK: - SMS Service Configuration and Health Monitoring
    
    /// Updates Twilio SMS service credentials for elderly care communication
    /// 
    /// Configures SMS service provider credentials for reliable care reminder
    /// delivery to elderly family members with proper authentication and
    /// service integration for consistent communication workflows.
    ///
    /// - Parameter accountSid: Twilio account identifier for SMS service access
    /// - Parameter authToken: Secure authentication token for API access
    /// - Parameter phoneNumber: Twilio phone number for SMS message origination
    /// - Throws: SMSError if credential update fails or authentication is invalid
    /// - Important: Secure credential storage protects elderly communication privacy
    func updateTwilioCredentials(accountSid: String, authToken: String, phoneNumber: String) async throws
    
    /// Tests SMS service connectivity and readiness for elderly care communication
    /// 
    /// Validates SMS service availability and proper configuration to ensure
    /// reliable care reminder delivery to elderly family members before
    /// critical care coordination periods.
    ///
    /// - Returns: True if SMS service is ready for elderly care communication
    /// - Throws: SMSError if connection test fails or service is unavailable
    /// - Note: Regular connection testing ensures reliable elderly care reminder delivery
    func testConnection() async throws -> Bool
}

// MARK: - SMS Models

struct SMSMessage: Codable {
    let id: String
    let to: String
    let message: String
    let profileId: String
    let messageType: SMSMessageType
    let photoData: Data?
    let scheduledTime: Date?
    let priority: SMSPriority
    
    init(
        id: String = UUID().uuidString,
        to: String,
        message: String,
        profileId: String,
        messageType: SMSMessageType,
        photoData: Data? = nil,
        scheduledTime: Date? = nil,
        priority: SMSPriority = .normal
    ) {
        self.id = id
        self.to = to
        self.message = message
        self.profileId = profileId
        self.messageType = messageType
        self.photoData = photoData
        self.scheduledTime = scheduledTime
        self.priority = priority
    }
}

struct SMSDeliveryResult: Codable {
    let messageId: String
    let profileId: String
    let phoneNumber: String
    let status: SMSDeliveryStatus
    let sentAt: Date
    let deliveredAt: Date?
    let errorMessage: String?
    let cost: Double?
    let segments: Int
    
    var isSuccessful: Bool {
        return status == .delivered || status == .sent
    }
    
    var formattedCost: String {
        guard let cost = cost else { return "N/A" }
        return String(format: "$%.4f", cost)
    }
}

struct ProcessedSMSResponse: Codable {
    let originalMessage: String
    let phoneNumber: String
    let matchedProfile: ElderlyProfile?
    let matchedTask: Task?
    let responseType: ResponseType
    let isPositive: Bool
    let confidence: Double
    let extractedData: [String: String] // Changed from [String: Any] to [String: String]
    let suggestedAction: SMSResponseAction
    let processedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case originalMessage, phoneNumber, matchedProfile, matchedTask
        case responseType, isPositive, confidence, extractedData, suggestedAction, processedAt
    }
}

struct SMSAttachment: Codable {
    let id: String
    let contentType: String
    let size: Int
    let url: String?
    let data: Data?
    
    var isImage: Bool {
        return contentType.hasPrefix("image/")
    }
    
    var isVideo: Bool {
        return contentType.hasPrefix("video/")
    }
}

struct SMSDeliveryReport: Codable {
    let profileId: String
    let startDate: Date
    let endDate: Date
    let totalSent: Int
    let totalDelivered: Int
    let totalFailed: Int
    let totalCost: Double
    let averageDeliveryTime: TimeInterval
    let deliveryDetails: [SMSDeliveryResult]
    
    var deliveryRate: Double {
        return totalSent > 0 ? Double(totalDelivered) / Double(totalSent) : 0
    }
    
    var formattedTotalCost: String {
        return String(format: "$%.2f", totalCost)
    }
}

struct SMSQuotaStatus: Codable {
    let userId: String
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let quotaLimit: Int
    let quotaUsed: Int
    let quotaRemaining: Int
    let resetDate: Date
    
    var utilizationPercentage: Double {
        return quotaLimit > 0 ? Double(quotaUsed) / Double(quotaLimit) : 0
    }
    
    var isNearLimit: Bool {
        return utilizationPercentage > 0.8
    }
    
    var isOverLimit: Bool {
        return quotaUsed >= quotaLimit
    }
}

// MARK: - SMS Enums

enum SMSDeliveryStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case sent = "sent"
    case delivered = "delivered"
    case failed = "failed"
    case undelivered = "undelivered"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .sent:
            return "Sent"
        case .delivered:
            return "Delivered"
        case .failed:
            return "Failed"
        case .undelivered:
            return "Undelivered"
        case .rejected:
            return "Rejected"
        }
    }
    
    var isFailureState: Bool {
        return self == .failed || self == .undelivered || self == .rejected
    }
    
    var isSuccessState: Bool {
        return self == .delivered || self == .sent
    }
}

enum SMSPriority: Int, CaseIterable, Codable {
    case low = 1
    case normal = 2
    case high = 3
    case urgent = 4
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        case .urgent:
            return "Urgent"
        }
    }
    
    var queueDelay: TimeInterval {
        switch self {
        case .urgent:
            return 0 // Send immediately
        case .high:
            return 30 // 30 seconds
        case .normal:
            return 60 // 1 minute
        case .low:
            return 300 // 5 minutes
        }
    }
}

enum SMSResponseAction: String, CaseIterable, Codable {
    case markTaskComplete = "markTaskComplete"
    case confirmProfile = "confirmProfile"
    case requestHelp = "requestHelp"
    case scheduleFollowUp = "scheduleFollowUp"
    case flagForReview = "flagForReview"
    case ignore = "ignore"
    
    var displayName: String {
        switch self {
        case .markTaskComplete:
            return "Mark Task Complete"
        case .confirmProfile:
            return "Confirm Profile"
        case .requestHelp:
            return "Send Help Message"
        case .scheduleFollowUp:
            return "Schedule Follow-up"
        case .flagForReview:
            return "Flag for Review"
        case .ignore:
            return "Ignore"
        }
    }
}

// MARK: - SMS Errors

enum SMSError: LocalizedError {
    case invalidPhoneNumber
    case messageEmpty
    case quotaExceeded
    case serviceUnavailable
    case authenticationFailed
    case rateLimitExceeded
    case messageQueueFull
    case deliveryFailed(String)
    case invalidCredentials
    case phoneNumberBlocked
    case messageTooLong
    case attachmentTooLarge
    case unsupportedAttachmentType
    case networkError
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "The phone number is invalid or not properly formatted."
        case .messageEmpty:
            return "The message cannot be empty."
        case .quotaExceeded:
            return "SMS quota exceeded. Please upgrade your plan or wait for quota reset."
        case .serviceUnavailable:
            return "SMS service is temporarily unavailable. Please try again later."
        case .authenticationFailed:
            return "SMS service authentication failed. Please check your credentials."
        case .rateLimitExceeded:
            return "Too many messages sent. Please wait before sending more."
        case .messageQueueFull:
            return "Message queue is full. Please try again later."
        case .deliveryFailed(let reason):
            return "Message delivery failed: \(reason)"
        case .invalidCredentials:
            return "Invalid Twilio credentials. Please check your configuration."
        case .phoneNumberBlocked:
            return "This phone number has been blocked."
        case .messageTooLong:
            return "Message is too long. Please shorten your message."
        case .attachmentTooLarge:
            return "Attachment is too large. Please use a smaller file."
        case .unsupportedAttachmentType:
            return "Attachment type is not supported."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unknownError(let message):
            return "SMS error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Please check the phone number format and try again."
        case .quotaExceeded:
            return "Upgrade your subscription or wait for the quota to reset."
        case .rateLimitExceeded:
            return "Wait a few minutes before sending more messages."
        case .messageQueueFull:
            return "Try again in a few minutes when the queue has space."
        case .messageTooLong:
            return "Split your message into smaller parts or remove some text."
        case .attachmentTooLarge:
            return "Compress the image or choose a smaller file."
        default:
            return "Please try again later or contact support if the problem persists."
        }
    }
}

// MARK: - SMS Result Types (RESTORED FROM app-structure.txt)
// =====================================================
// BulkSMSResult & SMSResponseResult - SYSTEMATIC RESTORATION
// =====================================================
// PURPOSE: Result types for bulk SMS operations and response processing
// STATUS: ✅ RESTORED - were incorrectly removed during previous session
// USAGE: Used in MockSMSService methods as return types
// VARIABLES TO REMEMBER: successfulSends, failedSends, responseId, isSuccessful
// =====================================================
struct BulkSMSResult: Codable {
    let successfulSends: [SMSDeliveryResult]
    let failedSends: [String]  // Simplified from [SMSError] for Codable compatibility
    let totalSent: Int
    let totalFailed: Int
    
    var successRate: Double {
        let total = totalSent + totalFailed
        return total > 0 ? Double(totalSent) / Double(total) : 0.0
    }
}

struct SMSResponseResult: Codable {
    let responseId: String
    let profileId: String
    let taskId: String?
    let response: String
    let processedAt: Date
    let isSuccessful: Bool
    let errorMessage: String?
}

