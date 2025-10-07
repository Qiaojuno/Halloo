import Foundation

/// Consolidated diagnostic logging utility for runtime debugging
/// Usage: DiagnosticLogger.log(.schema, "Delete operation started", context: ["profileId": "abc123"])
enum DiagnosticLogger {

    // MARK: - Log Categories

    enum Category: String {
        case schema = "SCHEMA"           // Firebase schema operations (delete, batch, cascade)
        case userModel = "USER-MODEL"    // User model encoding/decoding
        case profileId = "PROFILE-ID"    // Profile ID generation and lookup
        case vmInit = "VM-INIT"          // ViewModel initialization
        case vmAuth = "VM-AUTH"          // ViewModel auth state changes
        case vmLoad = "VM-LOAD"          // ViewModel data loading
        case asyncTask = "ASYNC-TASK"    // Async task execution
        case uiUpdate = "UI-UPDATE"      // UI state updates
        case database = "DATABASE"       // Database operations
        case error = "ERROR"             // Error conditions
        case performance = "PERF"        // Performance measurements

        var emoji: String {
            switch self {
            case .schema: return "🗄️"
            case .userModel: return "👤"
            case .profileId: return "🆔"
            case .vmInit: return "🏗️"
            case .vmAuth: return "🔐"
            case .vmLoad: return "📥"
            case .asyncTask: return "⚡️"
            case .uiUpdate: return "🎨"
            case .database: return "💾"
            case .error: return "❌"
            case .performance: return "⏱️"
            }
        }
    }

    // MARK: - Log Levels

    enum Level {
        case debug      // 🔵 Detailed debugging info
        case info       // 🔴 Important state changes
        case warning    // ⚠️ Potential issues
        case error      // ❌ Actual errors
        case success    // ✅ Successful operations

        var emoji: String {
            switch self {
            case .debug: return "🔵"
            case .info: return "🔴"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }
    }

    // MARK: - Configuration

    static var isEnabled = true
    static var enabledCategories: Set<Category> = Set(Category.allCases)
    static var minLevel: Level = .debug

    // MARK: - Core Logging Functions

    /// Main logging function
    static func log(
        _ category: Category,
        _ message: String,
        level: Level = .info,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled, enabledCategories.contains(category) else { return }

        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line)"

        var logMessage = "\(level.emoji) [\(category.emoji) \(category.rawValue)] \(message)"

        if !context.isEmpty {
            let contextString = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logMessage += " {\(contextString)}"
        }

        if level == .error {
            logMessage += " @\(location)"
        }

        print("\(timestamp) \(logMessage)")
    }

    // MARK: - Convenience Functions

    static func debug(_ category: Category, _ message: String, context: [String: Any] = [:]) {
        log(category, message, level: .debug, context: context)
    }

    static func info(_ category: Category, _ message: String, context: [String: Any] = [:]) {
        log(category, message, level: .info, context: context)
    }

    static func warning(_ category: Category, _ message: String, context: [String: Any] = [:]) {
        log(category, message, level: .warning, context: context)
    }

    static func error(_ category: Category, _ message: String, context: [String: Any] = [:], error: Error? = nil) {
        var fullContext = context
        if let error = error {
            fullContext["error"] = error.localizedDescription
        }
        log(category, message, level: .error, context: fullContext)
    }

    static func success(_ category: Category, _ message: String, context: [String: Any] = [:]) {
        log(category, message, level: .success, context: context)
    }

    // MARK: - Performance Tracking

    class PerformanceTracker {
        let category: Category
        let operation: String
        let startTime: Date
        var context: [String: Any]

        init(category: Category, operation: String, context: [String: Any] = [:]) {
            self.category = category
            self.operation = operation
            self.startTime = Date()
            self.context = context

            DiagnosticLogger.info(category, "\(operation) STARTED", context: context)
        }

        func end(success: Bool = true, additionalContext: [String: Any] = [:]) {
            let duration = Date().timeIntervalSince(startTime)
            var finalContext = context.merging(additionalContext) { _, new in new }
            finalContext["duration_ms"] = Int(duration * 1000)

            if success {
                DiagnosticLogger.success(category, "\(operation) COMPLETED", context: finalContext)
            } else {
                DiagnosticLogger.error(category, "\(operation) FAILED", context: finalContext)
            }
        }
    }

    static func track(_ category: Category, _ operation: String, context: [String: Any] = [:]) -> PerformanceTracker {
        return PerformanceTracker(category: category, operation: operation, context: context)
    }

    // MARK: - Call ID Generation

    static func generateCallId() -> String {
        return UUID().uuidString.prefix(8).uppercased().description
    }

    // MARK: - Thread Information

    static func threadInfo() -> String {
        return Thread.isMainThread ? "Main" : "Background"
    }

    // MARK: - Structured Logging Helpers

    /// Log a function entry
    static func enter(_ category: Category, _ function: String, context: [String: Any] = [:]) {
        var fullContext = context
        fullContext["thread"] = threadInfo()
        debug(category, "→ ENTER \(function)", context: fullContext)
    }

    /// Log a function exit
    static func exit(_ category: Category, _ function: String, context: [String: Any] = [:]) {
        var fullContext = context
        fullContext["thread"] = threadInfo()
        debug(category, "← EXIT \(function)", context: fullContext)
    }

    /// Log a state change
    static func stateChange(_ category: Category, _ property: String, from oldValue: Any?, to newValue: Any?) {
        info(category, "STATE CHANGE: \(property)", context: [
            "from": oldValue ?? "nil",
            "to": newValue ?? "nil"
        ])
    }
}

// MARK: - Category CaseIterable

extension DiagnosticLogger.Category: CaseIterable {}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Usage Examples

/*

 // Basic logging
 DiagnosticLogger.info(.schema, "Delete operation started")
 DiagnosticLogger.warning(.profileId, "Using UUID instead of phone")
 DiagnosticLogger.error(.database, "Failed to fetch user", error: someError)
 DiagnosticLogger.success(.vmLoad, "Loaded profiles")

 // With context
 DiagnosticLogger.info(.schema, "Profile delete", context: [
     "profileId": "abc123",
     "userId": "user456"
 ])

 // Performance tracking
 let tracker = DiagnosticLogger.track(.database, "Fetch profiles", context: ["userId": "abc"])
 // ... do work ...
 tracker.end(success: true, additionalContext: ["count": 5])

 // Function entry/exit
 DiagnosticLogger.enter(.vmInit, "ProfileViewModel.init", context: ["userId": userId])
 // ... initialization code ...
 DiagnosticLogger.exit(.vmInit, "ProfileViewModel.init", context: ["profileCount": 0])

 // State changes
 DiagnosticLogger.stateChange(.vmAuth, "isAuthenticated", from: false, to: true)

 // Thread info
 DiagnosticLogger.info(.asyncTask, "Task started", context: ["thread": DiagnosticLogger.threadInfo()])

 // Call ID for tracking async operations
 let callId = DiagnosticLogger.generateCallId()
 DiagnosticLogger.info(.vmLoad, "Starting load", context: ["callId": callId])
 // ... async work ...
 DiagnosticLogger.info(.vmLoad, "Completed load", context: ["callId": callId])

 */
