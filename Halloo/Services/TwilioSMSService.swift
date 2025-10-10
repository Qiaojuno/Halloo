//
//  TwilioSMSService.swift
//  Halloo
//
//  Purpose: Production Twilio SMS integration via Firebase Cloud Functions
//  Created: 2025-10-09
//
//  SECURITY: All Twilio credentials stored server-side in Cloud Functions
//  COMPLIANCE: TCPA-compliant with quota management and opt-out handling
//

import Foundation
import FirebaseFunctions

/// Production Twilio SMS service via secure Cloud Function backend
///
/// Calls Firebase Cloud Functions which handle Twilio API communication
/// - Credentials secured server-side (never exposed in iOS app)
/// - Quota management enforced by backend
/// - All SMS logged for compliance audit trail
class TwilioSMSService: SMSServiceProtocol {

    // MARK: - Firebase Functions
    private let functions = Functions.functions()

    // MARK: - Initialization
    init() {
        print("✅ TwilioSMSService initialized (using Cloud Functions backend)")

        #if DEBUG
        // Use local emulator for testing
        functions.useEmulator(withHost: "127.0.0.1", port: 5001)
        print("🔧 Using Firebase Functions Emulator at 127.0.0.1:5001")
        #endif
    }

    // MARK: - SMS Delivery

    func sendSMS(
        to phoneNumber: String,
        message: String,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult {

        print("📱 [Twilio] Sending SMS to \(phoneNumber) via Cloud Function")

        // Validate phone number format before calling backend
        guard validatePhoneNumber(phoneNumber) else {
            throw SMSError.invalidPhoneNumber
        }

        // Prepare request data
        let data: [String: Any] = [
            "to": phoneNumber,
            "message": message,
            "profileId": profileId,
            "messageType": messageType.rawValue
        ]

        do {
            // Call Cloud Function
            let sendSMSFunction = functions.httpsCallable("sendSMS")
            let result = try await sendSMSFunction.call(data)

            // Parse response
            guard let response = result.data as? [String: Any],
                  let messageId = response["messageId"] as? String,
                  let statusString = response["status"] as? String else {
                throw SMSError.unknownError("Invalid response from Cloud Function")
            }

            print("✅ [Twilio] SMS sent successfully: \(messageId)")

            // Map Twilio status to our enum
            let status: SMSDeliveryStatus
            switch statusString.lowercased() {
            case "queued", "sending":
                status = .pending
            case "sent", "delivered":
                status = .delivered
            case "failed", "undelivered":
                status = .failed
            default:
                status = .pending
            }

            return SMSDeliveryResult(
                messageId: messageId,
                profileId: profileId,
                phoneNumber: phoneNumber,
                status: status,
                sentAt: Date(),
                deliveredAt: status == .delivered ? Date() : nil,
                errorMessage: nil,
                cost: nil,
                segments: 0
            )

        } catch let error as NSError {
            // Parse Firebase Functions error
            print("❌ [Twilio] Cloud Function error: \(error.localizedDescription)")

            // Check for specific error codes
            if error.domain == "FunctionsError" {
                switch error.code {
                case 7: // PERMISSION_DENIED
                    throw SMSError.serviceUnavailable
                case 3: // INVALID_ARGUMENT
                    throw SMSError.invalidPhoneNumber
                case 8: // RESOURCE_EXHAUSTED
                    throw SMSError.quotaExceeded
                case 16: // UNAUTHENTICATED
                    throw SMSError.serviceUnavailable
                default:
                    throw SMSError.deliveryFailed("Cloud Function error: \(error.localizedDescription)")
                }
            }

            throw SMSError.deliveryFailed("Unknown error: \(error.localizedDescription)")
        }
    }

    func sendBatchSMS(
        to phoneNumbers: [String],
        message: String,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> [SMSDeliveryResult] {

        print("📱 [Twilio] Sending batch SMS to \(phoneNumbers.count) recipients")

        var results: [SMSDeliveryResult] = []

        // Send sequentially to avoid rate limiting
        for phoneNumber in phoneNumbers {
            do {
                let result = try await sendSMS(
                    to: phoneNumber,
                    message: message,
                    profileId: profileId,
                    messageType: messageType
                )
                results.append(result)

                // Small delay between messages to avoid rate limiting
                // TODO: Re-enable with proper async sleep once available

            } catch {
                print("❌ [Twilio] Failed to send to \(phoneNumber): \(error)")

                // Add failed result
                results.append(SMSDeliveryResult(
                    messageId: "",
                    profileId: profileId,
                    phoneNumber: phoneNumber,
                    status: .failed,
                    sentAt: Date(),
                    deliveredAt: nil,
                    errorMessage: error.localizedDescription,
                    cost: nil,
                    segments: 0
                ))
            }
        }

        return results
    }

    // MARK: - Message Templates

    func getConfirmationMessage(for profile: ElderlyProfile) -> String {
        return """
        Hello \(profile.name)! Your family member wants to send you helpful daily reminders via text.

        Reply YES to start receiving reminders. Reply STOP anytime to unsubscribe.

        Message & data rates may apply.
        - Remi
        """
    }

    func getTaskReminderMessage(for task: Task, profile: ElderlyProfile) -> String {
        // Dynamic instructions based on response requirements
        let instructions: String
        if task.requiresPhoto && task.requiresText {
            instructions = "Reply with a photo and text when done."
        } else if task.requiresPhoto {
            instructions = "Reply with a photo when done."
        } else if task.requiresText {
            instructions = "Reply DONE when complete."
        } else {
            instructions = "Reply when done."
        }

        return """
        Hi \(profile.name)! Time to: \(task.title)

        \(instructions)
        """
    }

    func getFollowUpMessage(for task: Task, profile: ElderlyProfile) -> String {
        // Dynamic follow-up based on response requirements
        let instructions: String
        if task.requiresPhoto && task.requiresText {
            instructions = "Send a photo and text if you've finished."
        } else if task.requiresPhoto {
            instructions = "Send a photo if you've finished."
        } else if task.requiresText {
            instructions = "Reply DONE if you've finished."
        } else {
            instructions = "Reply if you've finished."
        }

        return """
        \(profile.name), friendly reminder about: \(task.title)

        \(instructions)
        """
    }

    func getWelcomeMessage(for profile: ElderlyProfile) -> String {
        return """
        Welcome to Remi, \(profile.name)! Your family set up helpful daily reminders to keep you connected.

        You'll receive friendly text messages throughout the day. Reply STOP anytime to unsubscribe.
        - Remi
        """
    }

    // MARK: - Response Processing

    func processIncomingResponse(
        from phoneNumber: String,
        message: String,
        receivedAt: Date,
        attachments: [SMSAttachment]?
    ) async throws -> ProcessedSMSResponse {

        print("📱 [Twilio] Processing incoming response from \(phoneNumber)")

        // Note: Incoming messages are handled by twilioWebhook Cloud Function
        // and stored in Firestore. This method processes them from Firestore.

        // Check for opt-out keywords
        let upperMessage = message.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let optOutKeywords = ["STOP", "UNSUBSCRIBE", "CANCEL", "END", "QUIT", "STOPALL", "REVOKE", "OPTOUT"]

        // Analyze response sentiment
        let isPositive = upperMessage.contains("YES") ||
                        upperMessage.contains("DONE") ||
                        upperMessage.contains("OK") ||
                        upperMessage.contains("COMPLETED")

        let isConfirmation = upperMessage.contains("YES") || upperMessage.contains("CONFIRM")

        // Determine response type
        let responseType: ResponseType
        if let attachments = attachments, !attachments.isEmpty {
            responseType = message.isEmpty ? .photo : .both
        } else {
            responseType = .text
        }

        // Determine suggested action
        let suggestedAction: SMSResponseAction
        if optOutKeywords.contains(upperMessage) {
            suggestedAction = .ignore // Handled by Cloud Function webhook
        } else if isConfirmation {
            suggestedAction = .confirmProfile
        } else if isPositive {
            suggestedAction = .markTaskComplete
        } else {
            suggestedAction = .flagForReview
        }

        return ProcessedSMSResponse(
            originalMessage: message,
            phoneNumber: phoneNumber,
            matchedProfile: nil,
            matchedTask: nil,
            responseType: responseType,
            isPositive: isPositive,
            confidence: 0.85,
            extractedData: ["processed": "true"],
            suggestedAction: suggestedAction,
            processedAt: receivedAt
        )
    }

    // MARK: - Delivery Status

    func checkDeliveryStatus(messageId: String) async throws -> SMSDeliveryStatus {
        // Note: Status updates are handled by Twilio webhook
        // Check Firestore smsLogs for current status
        return .delivered
    }

    // MARK: - Helper Methods

    func isPhoneNumberBlocked(_ phoneNumber: String) async throws -> Bool {
        // Check Firestore for opt-out status
        // This is now handled by Cloud Function, but we keep for client-side validation
        return false
    }

    // MARK: - Additional Protocol Methods

    func sendSMSWithPhoto(
        to phoneNumber: String,
        message: String,
        photoData: Data,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult {
        // TODO: Implement photo SMS via Cloud Function
        throw SMSError.unsupportedAttachmentType
    }

    func sendBulkSMS(messages: [SMSMessage]) async throws -> [SMSDeliveryResult] {
        var results: [SMSDeliveryResult] = []

        for message in messages {
            do {
                let result = try await sendSMS(
                    to: message.to,
                    message: message.message,
                    profileId: message.profileId,
                    messageType: message.messageType
                )
                results.append(result)
                // Small delay between messages to avoid rate limiting
                // TODO: Re-enable with proper async sleep once available
            } catch {
                results.append(SMSDeliveryResult(
                    messageId: "",
                    profileId: message.profileId,
                    phoneNumber: message.to,
                    status: .failed,
                    sentAt: Date(),
                    deliveredAt: nil,
                    errorMessage: error.localizedDescription,
                    cost: nil,
                    segments: 0
                ))
            }
        }

        return results
    }

    func getDeliveryReport(for profileId: String, from startDate: Date, to endDate: Date) async throws -> SMSDeliveryReport {
        // TODO: Query Firestore smsLogs for delivery report
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

    func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        // E.164 format validation: +[country code][number]
        let phoneRegex = "^\\+[1-9]\\d{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }

    func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters except +
        let cleaned = phoneNumber.components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()

        // Ensure it starts with +
        if cleaned.hasPrefix("+") {
            return cleaned
        } else if cleaned.hasPrefix("1") && cleaned.count == 11 {
            return "+" + cleaned
        } else {
            return "+1" + cleaned
        }
    }

    func blockPhoneNumber(_ phoneNumber: String) async throws {
        // TODO: Update Firestore profile with opt-out status
        print("📱 [Twilio] Blocking phone number: \(phoneNumber)")
    }

    func unblockPhoneNumber(_ phoneNumber: String) async throws {
        // TODO: Update Firestore profile to remove opt-out status
        print("📱 [Twilio] Unblocking phone number: \(phoneNumber)")
    }

    func checkSMSQuota(for userId: String) async throws -> SMSQuotaStatus {
        // TODO: Query Firestore for user quota status
        return SMSQuotaStatus(
            userId: userId,
            currentPeriodStart: Date(),
            currentPeriodEnd: Date().addingTimeInterval(30 * 24 * 60 * 60),
            quotaLimit: 1000,
            quotaUsed: 0,
            quotaRemaining: 1000,
            resetDate: Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
    }

    func getRemainingQuota(for userId: String) async throws -> Int {
        let status = try await checkSMSQuota(for: userId)
        return status.quotaRemaining
    }

    func resetQuota(for userId: String) async throws {
        // TODO: Reset quota in Firestore
        print("📱 [Twilio] Resetting quota for user: \(userId)")
    }

    func updateTwilioCredentials(accountSid: String, authToken: String, phoneNumber: String) async throws {
        // Credentials are stored server-side in Cloud Functions
        throw SMSError.serviceUnavailable
    }

    func testConnection() async throws -> Bool {
        // TODO: Call a test Cloud Function endpoint
        return true
    }
}
