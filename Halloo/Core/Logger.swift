//
//  Logger.swift
//  Halloo
//
//  Created on 2025-10-28
//  Compile-time logging system with performance optimization
//

import Foundation
import os.log

// MARK: - Compile-Time Logging Configuration

/// Set to `false` in production to disable all debug logs at compile time (zero runtime cost)
/// Set to `true` during development for full logging
fileprivate let DEBUG_LOGGING_ENABLED = true

/// Fine-grained control: Disable verbose logs even in debug builds
fileprivate let VERBOSE_LOGGING_ENABLED = true

// MARK: - Log Categories

enum LogCategory: String {
    case appState = "AppState"
    case firebase = "Firebase"
    case sms = "SMS"
    case profile = "Profile"
    case task = "Task"
    case auth = "Auth"
    case image = "Image"
    case ui = "UI"
    case network = "Network"
    case error = "Error"

    var emoji: String {
        switch self {
        case .appState: return "🔵"
        case .firebase: return "🔥"
        case .sms: return "📱"
        case .profile: return "👤"
        case .task: return "✓"
        case .auth: return "🔐"
        case .image: return "📸"
        case .ui: return "🎨"
        case .network: return "🌐"
        case .error: return "❌"
        }
    }
}

// MARK: - Log Levels

enum LogLevel: Int, Comparable {
    case verbose = 0  // Detailed step-by-step logs
    case info = 1     // General informational logs
    case success = 2  // Successful operations
    case warning = 3  // Non-critical issues
    case error = 4    // Errors and failures

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .verbose: return "🔍"
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// MARK: - AppLogger

/// High-performance logging utility with compile-time optimization
///
/// **Usage:**
/// ```swift
/// AppLogger.log(.profile, .info, "Profile loaded: \(name)")
/// AppLogger.success(.task, "Task completed: \(task.title)")
/// AppLogger.error(.firebase, "Failed to save: \(error)")
/// ```
///
/// **Performance:**
/// - When `DEBUG_LOGGING_ENABLED = false`, all log calls are compiled out (zero runtime cost)
/// - When `VERBOSE_LOGGING_ENABLED = false`, verbose logs are disabled
/// - Uses Swift's `@autoclosure` for lazy evaluation (message only computed if logged)
struct AppLogger {

    // MARK: - Core Logging

    /// Main logging function with compile-time optimization
    ///
    /// - Parameters:
    ///   - category: Log category (Firebase, SMS, Profile, etc.)
    ///   - level: Log level (verbose, info, success, warning, error)
    ///   - message: Log message (lazy-evaluated via @autoclosure)
    ///   - context: Calling function (auto-captured via #function)
    ///   - file: Source file (auto-captured)
    ///   - line: Line number (auto-captured)
    @inlinable
    static func log(
        _ category: LogCategory,
        _ level: LogLevel,
        _ message: @autoclosure () -> String,
        context: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
        guard DEBUG_LOGGING_ENABLED else { return }

        // Skip verbose logs if disabled
        if level == .verbose && !VERBOSE_LOGGING_ENABLED {
            return
        }

        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let prefix = "\(level.emoji) \(category.emoji) [\(category.rawValue)]"
        let location = "[\(fileName):\(line)]"

        print("\(prefix) \(message()) - \(context) \(location)")
        #endif
    }

    // MARK: - Convenience Methods

    /// Log verbose details (disabled in production, optional in debug)
    @inlinable
    static func verbose(
        _ category: LogCategory,
        _ message: @autoclosure () -> String,
        context: String = #function
    ) {
        log(category, .verbose, message(), context: context)
    }

    /// Log informational message
    @inlinable
    static func info(
        _ category: LogCategory,
        _ message: @autoclosure () -> String,
        context: String = #function
    ) {
        log(category, .info, message(), context: context)
    }

    /// Log successful operation
    @inlinable
    static func success(
        _ category: LogCategory,
        _ message: @autoclosure () -> String,
        context: String = #function
    ) {
        log(category, .success, message(), context: context)
    }

    /// Log warning (non-critical issue)
    @inlinable
    static func warning(
        _ category: LogCategory,
        _ message: @autoclosure () -> String,
        context: String = #function
    ) {
        log(category, .warning, message(), context: context)
    }

    /// Log error (critical failure) - ALWAYS enabled even in production
    @inlinable
    static func error(
        _ category: LogCategory,
        _ message: @autoclosure () -> String,
        context: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        // Errors are ALWAYS logged, even in production
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let prefix = "\(LogLevel.error.emoji) \(category.emoji) [\(category.rawValue)]"
        let location = "[\(fileName):\(line)]"

        print("\(prefix) \(message()) - \(context) \(location)")
    }
}

// MARK: - Migration Guide

/*
 MIGRATION GUIDE: Replace existing print() statements

 ✅ BEFORE (old style):
 print("✅ [ProfileViewModel] Profile added to AppState: \(profile.name)")
 print("❌ [Firebase] Failed to save: \(error.localizedDescription)")
 print("🔍 [TaskViewModel] Checking task status...")

 ✅ AFTER (new AppLogger):
 AppLogger.success(.profile, "Profile added to AppState: \(profile.name)")
 AppLogger.error(.firebase, "Failed to save: \(error.localizedDescription)")
 AppLogger.verbose(.task, "Checking task status...")

 BENEFITS:
 1. Compile-time elimination in production (zero performance cost)
 2. Lazy evaluation with @autoclosure (message only computed if logged)
 3. Automatic context tracking (#function)
 4. Consistent formatting across codebase
 5. Category-based filtering
 6. Fine-grained control (disable verbose logs separately)
 */
