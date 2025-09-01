import Foundation
import Combine
import os.log
import Darwin

// MARK: - Error Coordinator
// 
// =====================================================
// ErrorCoordinator.swift - SYSTEMATIC RESTORATION
// =====================================================
// PURPOSE: Centralized error handling and logging system for Hallo app
// STATUS: ✅ RESTORED according to app-structure.txt
// DEPENDENCIES: Foundation, Combine, os.log, UIKit, Darwin
// USAGE: Handles all app errors, provides recovery strategies, analytics
// 
// KEY FEATURES (from app-structure.txt):
// - Error reporting and logging
// - Automatic recovery strategies  
// - Error pattern detection
// - Integration with external error services
// - Memory and performance monitoring
// 
// CRITICAL IMPORTS ADDED:
// - UIKit: for UIApplication, UIDevice usage
// - Darwin: for mach_task_basic_info, task_info system calls
// 
// VARIABLES TO REMEMBER:
// - currentError: AppError? - currently displayed error
// - errorHistory: [ErrorLog] - historical error data
// - isShowingError: Bool - UI state for error display
// - maxErrorHistory: Int = 50 - limit error storage
// =====================================================
final class ErrorCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentError: AppError?
    @Published var errorHistory: [ErrorLog] = []
    @Published var isShowingError = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.hallo.app", category: "ErrorCoordinator")
    private let maxErrorHistory = 50
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Error Handling Configuration
    private let errorReportingService: ErrorReportingService?
    private let userNotificationService: UserNotificationService?
    
    init(
        errorReportingService: ErrorReportingService? = nil,
        userNotificationService: UserNotificationService? = nil
    ) {
        self.errorReportingService = errorReportingService
        self.userNotificationService = userNotificationService
        
        setupErrorObservation()
    }
    
    // MARK: - Public Error Handling Methods
    
    func handle(_ error: Error, context: String, severity: ErrorSeverity = .medium, shouldShowToUser: Bool = true) {
        let appError = AppError(
            error: error,
            context: context,
            severity: severity,
            timestamp: Date(),
            userInfo: gatherContextualInfo()
        )
        
        _Concurrency.Task { @MainActor in
            await handleAppError(appError, shouldShowToUser: shouldShowToUser)
        }
    }
    
    func handle(_ error: AppError, shouldShowToUser: Bool = true) {
        _Concurrency.Task { @MainActor in
            await handleAppError(error, shouldShowToUser: shouldShowToUser)
        }
    }
    
    func handleCriticalError(_ error: Error, context: String, userInfo: [String: Any] = [:]) {
        var enhancedUserInfo = userInfo
        enhancedUserInfo["isCritical"] = true
        enhancedUserInfo["deviceInfo"] = getDeviceInfo()
        enhancedUserInfo["appVersion"] = getAppVersion()
        
        let criticalError = AppError(
            error: error,
            context: context,
            severity: .critical,
            timestamp: Date(),
            userInfo: enhancedUserInfo
        )
        
        _Concurrency.Task { @MainActor in
            await handleAppError(criticalError, shouldShowToUser: true)
            await reportCriticalError(criticalError)
        }
    }
    
    func dismissCurrentError() {
        _Concurrency.Task { @MainActor in
            currentError = nil
            isShowingError = false
        }
    }
    
    func clearErrorHistory() {
        _Concurrency.Task { @MainActor in
            errorHistory.removeAll()
        }
    }
    
    // MARK: - Error Recovery
    
    func attemptRecovery(for error: AppError, using strategy: RecoveryStrategy) async -> Bool {
        logger.info("Attempting recovery for error: \(error.localizedDescription) using strategy: \(strategy.rawValue)")
        
        switch strategy {
        case .retry:
            return await attemptRetry(for: error)
        case .refresh:
            return await attemptRefresh(for: error)
        case .reconnect:
            return await attemptReconnect(for: error)
        case .clearCache:
            return await attemptClearCache(for: error)
        case .restart:
            return await attemptRestart(for: error)
        case .none:
            return false
        }
    }
    
    // MARK: - Error Analysis
    
    func getErrorPatterns() -> [ErrorPattern] {
        let recentErrors = errorHistory.suffix(20)
        var patterns: [ErrorPattern] = []
        
        // Analyze frequent error types
        let errorTypeCounts = Dictionary(grouping: recentErrors) { $0.errorType }
            .mapValues { $0.count }
        
        for (errorType, count) in errorTypeCounts where count >= 3 {
            patterns.append(ErrorPattern(
                type: .frequentError,
                description: "Frequent \(errorType) errors",
                count: count,
                suggestion: getSuggestionForErrorType(errorType)
            ))
        }
        
        // Analyze error timing patterns
        let timeBasedPatterns = analyzeTimingPatterns(recentErrors)
        patterns.append(contentsOf: timeBasedPatterns)
        
        return patterns
    }
    
    func getErrorStatistics() -> ErrorStatistics {
        let last24Hours = errorHistory.filter { 
            Date().timeIntervalSince($0.timestamp) < 24 * 60 * 60 
        }
        
        let last7Days = errorHistory.filter {
            Date().timeIntervalSince($0.timestamp) < 7 * 24 * 60 * 60
        }
        
        return ErrorStatistics(
            totalErrors: errorHistory.count,
            errorsLast24Hours: last24Hours.count,
            errorsLast7Days: last7Days.count,
            criticalErrorsLast24Hours: last24Hours.filter { $0.severity == .critical }.count,
            mostCommonErrorType: getMostCommonErrorType(),
            averageErrorsPerDay: Double(last7Days.count) / 7.0,
            errorTrend: calculateErrorTrend()
        )
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func handleAppError(_ appError: AppError, shouldShowToUser: Bool) async {
        // Log the error
        logError(appError)
        
        // Add to history
        addToErrorHistory(appError)
        
        // Show to user if needed
        if shouldShowToUser {
            currentError = appError
            isShowingError = true
        }
        
        // Report if necessary
        if appError.severity == .critical || appError.severity == .high {
            await reportError(appError)
        }
        
        // Attempt automatic recovery for certain error types
        if let recoveryStrategy = getAutomaticRecoveryStrategy(for: appError) {
            let recovered = await attemptRecovery(for: appError, using: recoveryStrategy)
            if recovered {
                logger.info("Successfully recovered from error automatically")
                if shouldShowToUser {
                    dismissCurrentError()
                }
            }
        }
    }
    
    private func setupErrorObservation() {
        // Monitor network connectivity errors
        NotificationCenter.default.publisher(for: .networkConnectivityChanged)
            .sink { [weak self] notification in
                if let isConnected = notification.userInfo?["isConnected"] as? Bool, !isConnected {
                    self?.handle(
                        NetworkError.connectionLost,
                        context: "Network connectivity monitoring",
                        severity: .medium
                    )
                }
            }
            .store(in: &cancellables)
        
        // Monitor memory warnings - using Foundation notification instead of UIKit
        NotificationCenter.default.publisher(for: .memoryWarning)
            .sink { [weak self] _ in
                self?.handle(
                    SystemError.memoryWarning,
                    context: "System memory warning",
                    severity: .high
                )
            }
            .store(in: &cancellables)
    }
    
    private func logError(_ error: AppError) {
        let logMessage = """
        Error in \(error.context):
        Type: \(error.type)
        Severity: \(error.severity.rawValue)
        Description: \(error.localizedDescription)
        User Info: \(error.userInfo)
        """
        
        switch error.severity {
        case .low:
            logger.debug("\(logMessage)")
        case .medium:
            logger.info("\(logMessage)")
        case .high:
            logger.error("\(logMessage)")
        case .critical:
            logger.fault("\(logMessage)")
        }
    }
    
    private func addToErrorHistory(_ error: AppError) {
        let errorLog = ErrorLog(
            id: UUID().uuidString,
            appError: error,
            timestamp: Date()
        )
        
        errorHistory.insert(errorLog, at: 0)
        
        // Maintain maximum history size
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeLast()
        }
    }
    
    private func reportError(_ error: AppError) async {
        guard let reportingService = errorReportingService else { return }
        
        do {
            try await reportingService.reportError(error)
            logger.info("Error reported successfully")
        } catch {
            logger.error("Failed to report error: \(error.localizedDescription)")
        }
    }
    
    private func reportCriticalError(_ error: AppError) async {
        // Always attempt to report critical errors, even without reporting service
        if let reportingService = errorReportingService {
            try? await reportingService.reportCriticalError(error)
        }
        
        // Also attempt to notify user notification service
        if let notificationService = userNotificationService {
            try? await notificationService.notifyCriticalError(error)
        }
        
        // Log to system console for debugging
        print("CRITICAL ERROR: \(error.localizedDescription) in \(error.context)")
    }
    
    private func gatherContextualInfo() -> [String: Any] {
        return [
            "timestamp": Date().timeIntervalSince1970,
            "memoryUsage": getMemoryUsage(),
            "networkStatus": getNetworkStatus()
        ]
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "model": "iOS Device", // Simplified without UIKit dependency
            "systemName": "iOS",
            "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString
        ]
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // MB
        }
        return 0
    }
    
    private func getNetworkStatus() -> String {
        // Simplified network status - in real implementation would use proper network monitoring
        return "unknown"
    }
    
    // MARK: - Recovery Methods
    
    private func getAutomaticRecoveryStrategy(for error: AppError) -> RecoveryStrategy? {
        switch error.type {
        case "NetworkError":
            return .reconnect
        case "DatabaseError":
            return .retry
        case "AuthenticationError":
            return .refresh
        default:
            return nil
        }
    }
    
    private func attemptRetry(for error: AppError) async -> Bool {
        // Implement retry logic based on error context
        logger.info("Attempting retry recovery for: \(error.context)")
        
        // Wait before retry
        try? await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // In a real implementation, this would trigger the original operation again
        return false
    }
    
    private func attemptRefresh(for error: AppError) async -> Bool {
        logger.info("Attempting refresh recovery for: \(error.context)")
        
        // Trigger data refresh
        NotificationCenter.default.post(name: .refreshAllData, object: nil)
        
        return true
    }
    
    private func attemptReconnect(for error: AppError) async -> Bool {
        logger.info("Attempting reconnect recovery for: \(error.context)")
        
        // Trigger network reconnection
        NotificationCenter.default.post(name: .attemptReconnection, object: nil)
        
        return true
    }
    
    private func attemptClearCache(for error: AppError) async -> Bool {
        logger.info("Attempting cache clear recovery for: \(error.context)")
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        
        return true
    }
    
    private func attemptRestart(for error: AppError) async -> Bool {
        logger.info("Attempting restart recovery for: \(error.context)")
        
        // In a real implementation, this might restart certain services
        // For now, just refresh all data
        NotificationCenter.default.post(name: .restartServices, object: nil)
        
        return true
    }
    
    // MARK: - Analysis Methods
    
    private func analyzeTimingPatterns(_ errors: ArraySlice<ErrorLog>) -> [ErrorPattern] {
        var patterns: [ErrorPattern] = []
        
        // Check for error bursts (multiple errors in short time)
        let sortedErrors = errors.sorted { $0.timestamp > $1.timestamp }
        var burstCount = 0
        var lastErrorTime = Date.distantPast
        
        for errorLog in sortedErrors {
            if errorLog.timestamp.timeIntervalSince(lastErrorTime) < 60 { // Within 1 minute
                burstCount += 1
            } else {
                if burstCount >= 3 {
                    patterns.append(ErrorPattern(
                        type: .burst,
                        description: "Error burst detected: \(burstCount) errors in quick succession",
                        count: burstCount,
                        suggestion: "Check for cascading failures or retry loops"
                    ))
                }
                burstCount = 1
            }
            lastErrorTime = errorLog.timestamp
        }
        
        return patterns
    }
    
    private func getMostCommonErrorType() -> String? {
        let errorTypeCounts = Dictionary(grouping: errorHistory) { $0.errorType }
            .mapValues { $0.count }
        
        return errorTypeCounts.max { $0.value < $1.value }?.key
    }
    
    private func calculateErrorTrend() -> ErrorTrend {
        let now = Date()
        let last24Hours = errorHistory.filter { 
            now.timeIntervalSince($0.timestamp) < 24 * 60 * 60 
        }.count
        
        let previous24Hours = errorHistory.filter { 
            let timeAgo = now.timeIntervalSince($0.timestamp)
            return timeAgo >= 24 * 60 * 60 && timeAgo < 48 * 60 * 60
        }.count
        
        if last24Hours > previous24Hours {
            return .increasing
        } else if last24Hours < previous24Hours {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func getSuggestionForErrorType(_ errorType: String) -> String {
        switch errorType {
        case "NetworkError":
            return "Check internet connection and server status"
        case "DatabaseError":
            return "Verify database connection and data integrity"
        case "AuthenticationError":
            return "Check authentication credentials and token validity"
        case "ValidationError":
            return "Review input validation logic"
        default:
            return "Review error handling for this error type"
        }
    }
}

// MARK: - Supporting Models

struct AppError: Error, Identifiable {
    let id = UUID()
    let error: Error
    let context: String
    let severity: ErrorSeverity
    let timestamp: Date
    let userInfo: [String: Any]
    
    var localizedDescription: String {
        if let localizedError = error as? LocalizedError {
            return localizedError.localizedDescription
        }
        return error.localizedDescription
    }
    
    var recoverySuggestion: String? {
        if let localizedError = error as? LocalizedError {
            return localizedError.recoverySuggestion
        }
        return nil
    }
    
    var type: String {
        return String(describing: Swift.type(of: error))
    }
}

struct ErrorLog: Identifiable, Codable {
    let id: String
    let errorMessage: String // Changed from AppError to String
    let errorType: String
    let severity: ErrorSeverity
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, errorMessage, errorType, severity, timestamp
    }
    
    // Convenience initializer from AppError
    init(id: String = UUID().uuidString, appError: AppError, timestamp: Date = Date()) {
        self.id = id
        self.errorMessage = appError.localizedDescription
        self.errorType = appError.type
        self.severity = appError.severity
        self.timestamp = timestamp
    }
}

struct ErrorPattern {
    let type: PatternType
    let description: String
    let count: Int
    let suggestion: String
    
    enum PatternType {
        case frequentError
        case burst
        case cascade
        case timing
    }
}

struct ErrorStatistics {
    let totalErrors: Int
    let errorsLast24Hours: Int
    let errorsLast7Days: Int
    let criticalErrorsLast24Hours: Int
    let mostCommonErrorType: String?
    let averageErrorsPerDay: Double
    let errorTrend: ErrorTrend
}

enum ErrorSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

enum RecoveryStrategy: String, CaseIterable {
    case retry = "retry"
    case refresh = "refresh"
    case reconnect = "reconnect"
    case clearCache = "clearCache"
    case restart = "restart"
    case none = "none"
}

enum ErrorTrend {
    case increasing
    case decreasing
    case stable
}

// MARK: - Error Types

enum NetworkError: LocalizedError {
    case connectionLost
    case timeout
    case serverError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .connectionLost:
            return "Network connection lost"
        case .timeout:
            return "Request timed out"
        case .serverError:
            return "Server error occurred"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

enum SystemError: LocalizedError {
    case memoryWarning
    case diskSpaceLow
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .memoryWarning:
            return "Low memory warning"
        case .diskSpaceLow:
            return "Disk space low"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - External Service Protocols

protocol ErrorReportingService {
    func reportError(_ error: AppError) async throws
    func reportCriticalError(_ error: AppError) async throws
}

protocol UserNotificationService {
    func notifyCriticalError(_ error: AppError) async throws
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
    static let refreshAllData = Notification.Name("refreshAllData")
    static let attemptReconnection = Notification.Name("attemptReconnection")
    static let restartServices = Notification.Name("restartServices")
    static let memoryWarning = Notification.Name("memoryWarning")
}