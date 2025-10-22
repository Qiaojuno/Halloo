//
//  GalleryViewModel.swift
//  Hallo
//
//  Purpose: Photo gallery management for elderly care response history and family memories
//  Key Features: 
//    • Display chronological history of elderly task responses with photos
//    • Filter gallery by event type (task responses, profile creation)
//    • Real-time photo upload and display from SMS responses
//  Dependencies: DatabaseService, AuthenticationService, ErrorCoordinator
//  
//  Business Context: Visual history of elderly engagement and family moments
//  Critical Paths: Photo response display → Family engagement tracking → Memory preservation
//
//  Created by Claude Code on 2025-01-15
//

import Foundation
import SwiftUI
import Combine
import FirebaseStorage
import OSLog

/// Gallery management for elderly care photo history and family memories
///
/// This ViewModel manages the visual timeline of elderly family member interactions,
/// displaying photos from task responses, profile creation events, and other family
/// moments. It provides filtering capabilities and real-time updates as elderly
/// users respond with photos via SMS.
///
/// ## Key Responsibilities:
/// - **Photo History Display**: Chronological timeline of elderly response photos
/// - **Event Filtering**: Filter by task responses, profile creation, or show all
/// - **Real-time Updates**: Live photo feed as elderly users respond via SMS
/// - **Memory Management**: Efficient loading and caching of photo history
/// - **Family Context**: Group photos by elderly family member for easy browsing
///
/// ## Elderly Care Considerations:
/// - **Visual Engagement**: Photos provide evidence of elderly participation and wellbeing
/// - **Family Connection**: Visual timeline helps families stay connected with elderly daily life
/// - **Memory Preservation**: Creates lasting visual record of care journey
/// - **Easy Navigation**: Simple interface for families to browse elderly responses
///
/// ## Usage Example:
/// ```swift
/// let galleryViewModel = container.makeGalleryViewModel()
/// // Automatically loads gallery events and displays photo timeline
/// let events = galleryViewModel.galleryEvents
/// let filteredEvents = galleryViewModel.filteredEvents
/// ```
///
/// - Important: Gallery updates in real-time as elderly users send photo responses
/// - Note: Photos are cached for offline viewing and family sharing
/// - Warning: Large photo collections may require pagination for performance
@MainActor
final class GalleryViewModel: ObservableObject {
    
    // MARK: - Gallery State Properties
    
    /// Loading state for gallery data and photo retrieval
    /// 
    /// This property shows loading during:
    /// - Initial gallery data loading from database
    /// - Photo download and caching operations
    /// - Real-time event synchronization from SMS responses
    ///
    /// Used by families to understand when gallery content is being updated.
    @Published var isLoading = false
    
    /// User-friendly error messages for gallery operation failures
    /// 
    /// This property displays context-aware error messages when:
    /// - Gallery data loading fails
    /// - Photo download or upload encounters issues  
    /// - Real-time event synchronization fails
    ///
    /// Used by families to understand gallery reliability issues.
    @Published var errorMessage: String?
    
    // PHASE 4 REFACTOR: galleryEvents moved to AppState
    // - Read from: appState.galleryEvents (via GalleryView)
    // - Real-time updates: DataSyncCoordinator.galleryEventUpdates → AppState
    // - No manual loading needed: Firebase listener auto-updates

    // MARK: - Dependencies
    private var databaseService: DatabaseServiceProtocol
    private var authService: AuthenticationServiceProtocol
    /// Logger for gallery operations tracking and error diagnosis
    private let logger = Logger(subsystem: "com.halloo.app", category: "Gallery")
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let refreshInterval: TimeInterval = 60 // Refresh every minute
    
    // MARK: - Initialization
    
    /// Initialize GalleryViewModel with required services
    /// 
    /// - Parameters:
    ///   - databaseService: Service for gallery data persistence and retrieval
    ///   - authService: Service for user authentication and authorization
    init(
        databaseService: DatabaseServiceProtocol,
        authService: AuthenticationServiceProtocol
    ) {
        self.databaseService = databaseService
        self.authService = authService

        // PHASE 4: No periodic refresh needed - real-time listener handles updates
    }
    
    // MARK: - Public Methods
    
    // MARK: - Service Management

    /// Update service dependencies (used when switching between mock and production services)
    ///
    /// - Parameters:
    ///   - databaseService: New database service instance
    ///   - authService: New authentication service instance
    func updateServices(
        databaseService: DatabaseServiceProtocol,
        authService: AuthenticationServiceProtocol
    ) {
        self.databaseService = databaseService
        self.authService = authService
    }
}

// MARK: - Gallery Event Extensions

// Extension removed - properties are already defined in GalleryHistoryEvent.swift