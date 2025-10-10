import Foundation

// MARK: - Minimal Mock SMS Service for UI Development
class MockSMSService: SMSServiceProtocol {
    
    // MARK: - SMSServiceProtocol Implementation (Minimal Stubs)
    
    func sendSMS(
        to phoneNumber: String,
        message: String,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult {
        print("📱 Mock SMS sent to \(phoneNumber): \(message)")
        return SMSDeliveryResult(
            messageId: "mock-sms-\(UUID().uuidString)",
            profileId: profileId,
            phoneNumber: phoneNumber,
            status: .delivered,
            sentAt: Date(),
            deliveredAt: Date(),
            errorMessage: nil,
            cost: 0.0075,
            segments: 1
        )
    }
    
    func sendSMSWithPhoto(
        to phoneNumber: String,
        message: String,
        photoData: Data,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult {
        print("📱 Mock SMS with photo sent to \(phoneNumber)")
        return SMSDeliveryResult(
            messageId: "mock-photo-sms-\(UUID().uuidString)",
            profileId: profileId,
            phoneNumber: phoneNumber,
            status: .delivered,
            sentAt: Date(),
            deliveredAt: Date(),
            errorMessage: nil,
            cost: 0.0150, // Photo messages typically cost more
            segments: 2
        )
    }
    
    func sendBulkSMS(
        messages: [SMSMessage]
    ) async throws -> [SMSDeliveryResult] {
        print("📱 Mock bulk SMS sent: \(messages.count) messages")
        return messages.map { message in
            SMSDeliveryResult(
                messageId: "mock-bulk-\(UUID().uuidString)",
                profileId: message.profileId,
                phoneNumber: message.to,
                status: .delivered,
                sentAt: Date(),
                deliveredAt: Date(),
                errorMessage: nil,
                cost: 0.0075,
                segments: 1
            )
        }
    }
    
    func getConfirmationMessage(for profile: ElderlyProfile) -> String {
        return "Hi \(profile.name), please reply YES to confirm you received this message."
    }
    
    func getTaskReminderMessage(for task: Task, profile: ElderlyProfile) -> String {
        return "Hi \(profile.name)! Reminder: \(task.title). Reply DONE when completed."
    }
    
    func getFollowUpMessage(for task: Task, profile: ElderlyProfile) -> String {
        return "Hi \(profile.name), checking in on: \(task.title). Reply DONE if completed."
    }
    
    func getWelcomeMessage(for profile: ElderlyProfile) -> String {
        return "Welcome to Remi, \(profile.name)! Your family set up reminders to help you stay connected."
    }
    
    func checkDeliveryStatus(messageId: String) async throws -> SMSDeliveryStatus {
        return .delivered
    }
    
    func getDeliveryReport(
        for profileId: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> SMSDeliveryReport {
        print("📱 Mock: Generating delivery report for profile \(profileId)")

        // Return empty report - no hardcoded sample data
        return SMSDeliveryReport(
            profileId: profileId,
            startDate: startDate,
            endDate: endDate,
            totalSent: 0,
            totalDelivered: 0,
            totalFailed: 0,
            totalCost: 0.0,
            averageDeliveryTime: 0.0,
            deliveryDetails: []
        )
    }
    
    func processIncomingResponse(
        from phoneNumber: String,
        message: String,
        receivedAt: Date,
        attachments: [SMSAttachment]?
    ) async throws -> ProcessedSMSResponse {
        print("📱 Mock incoming SMS from \(phoneNumber): \(message)")
        
        // Mock analysis of the response
        let upperMessage = message.uppercased()
        let isPositive = upperMessage.contains("YES") || upperMessage.contains("DONE") || upperMessage.contains("OK") || upperMessage.contains("COMPLETED")
        let isHelpRequest = upperMessage.contains("HELP") || upperMessage.contains("STUCK")
        let isConfirmation = upperMessage.contains("YES") || upperMessage.contains("CONFIRM")
        
        // Determine response type based on message content and attachments
        let responseType: ResponseType
        if let attachments = attachments, !attachments.isEmpty {
            responseType = message.isEmpty ? .photo : .both
        } else {
            responseType = .text
        }
        
        // Determine suggested action
        let suggestedAction: SMSResponseAction
        if isConfirmation {
            suggestedAction = .confirmProfile
        } else if isHelpRequest {
            suggestedAction = .requestHelp
        } else if isPositive {
            suggestedAction = .markTaskComplete
        } else if !isPositive && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            suggestedAction = .scheduleFollowUp
        } else {
            suggestedAction = .ignore
        }
        
        return ProcessedSMSResponse(
            originalMessage: message,
            phoneNumber: phoneNumber,
            matchedProfile: nil, // Mock service doesn't maintain profile state
            matchedTask: nil, // Mock service doesn't maintain task state
            responseType: responseType,
            isPositive: isPositive,
            confidence: 0.85, // Mock confidence score
            extractedData: ["processed_message": message.lowercased()],
            suggestedAction: suggestedAction,
            processedAt: receivedAt
        )
    }
    
    func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = #"^\+?[1-9]\d{1,14}$"#
        return phoneNumber.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    func formatPhoneNumber(_ phoneNumber: String) -> String {
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if digits.count == 10 {
            return "+1\(digits)"
        } else if digits.count == 11 && digits.hasPrefix("1") {
            return "+\(digits)"
        }
        
        return phoneNumber
    }
    
    func isPhoneNumberBlocked(_ phoneNumber: String) async throws -> Bool {
        return false // Never blocked in mock
    }
    
    func blockPhoneNumber(_ phoneNumber: String) async throws {
        print("📱 Mock: Blocked phone number \(phoneNumber)")
    }
    
    func unblockPhoneNumber(_ phoneNumber: String) async throws {
        print("📱 Mock: Unblocked phone number \(phoneNumber)")
    }
    
    func checkSMSQuota(for userId: String) async throws -> SMSQuotaStatus {
        return SMSQuotaStatus(
            userId: userId,
            currentPeriodStart: Date().addingTimeInterval(-86400),
            currentPeriodEnd: Date().addingTimeInterval(86400),
            quotaLimit: 1000,
            quotaUsed: 25,
            quotaRemaining: 975,
            resetDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        )
    }
    
    func getRemainingQuota(for userId: String) async throws -> Int {
        return 975
    }
    
    func resetQuota(for userId: String) async throws {
        print("📱 Mock: Reset SMS quota for user \(userId)")
    }
    
    func updateTwilioCredentials(
        accountSid: String,
        authToken: String,
        phoneNumber: String
    ) async throws {
        print("📱 Mock: Updated Twilio credentials")
    }
    
    func testConnection() async throws -> Bool {
        return true
    }
}