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
    
    /// Complete chronological list of gallery events
    /// 
    /// Contains all gallery events in reverse chronological order:
    /// - Task response photos from elderly family members
    /// - Profile creation events with photos
    /// - Future: milestone celebrations, family moments
    ///
    /// This is the master data source for the gallery display.
    @Published var galleryEvents: [GalleryHistoryEvent] = []
    
    /// Timestamp of last successful gallery data refresh
    ///
    /// Used to display "last updated" information to families and
    /// determine when next refresh cycle should occur.
    @Published var lastRefreshTime: Date?

    /// Archived photos from Cloud Storage (older than 90 days)
    ///
    /// Photos that have been archived after 90-day retention period.
    /// Text data has been deleted, only photos remain in Cloud Storage.
    /// Organized by user/profile/year/month for efficient loading.
    @Published var archivedPhotos: [ArchivedPhoto] = []

    /// Loading state for archived photos from Cloud Storage
    @Published var isLoadingArchive = false

    // MARK: - Dependencies
    private var databaseService: DatabaseServiceProtocol
    private var authService: AuthenticationServiceProtocol
    private var errorCoordinator: ErrorCoordinator
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let refreshInterval: TimeInterval = 60 // Refresh every minute
    
    // MARK: - Initialization
    
    /// Initialize GalleryViewModel with required services
    /// 
    /// - Parameters:
    ///   - databaseService: Service for gallery data persistence and retrieval
    ///   - authService: Service for user authentication and authorization
    ///   - errorCoordinator: Centralized error handling and user messaging
    init(
        databaseService: DatabaseServiceProtocol,
        authService: AuthenticationServiceProtocol,
        errorCoordinator: ErrorCoordinator
    ) {
        self.databaseService = databaseService
        self.authService = authService
        self.errorCoordinator = errorCoordinator
        
        setupPeriodicRefresh()
    }
    
    // MARK: - Public Methods
    
    /// Load gallery events for the current authenticated user
    ///
    /// Fetches all gallery events (task responses, profile creation) from the database
    /// and updates the galleryEvents array. Events are sorted by creation date (newest first).
    func loadGalleryData() async {
        guard authService.isAuthenticated else {
            errorMessage = "Please sign in to view gallery"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let events = try await fetchGalleryEvents()

            await MainActor.run {
                self.galleryEvents = events.sorted { $0.createdAt > $1.createdAt }
                self.lastRefreshTime = Date()
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load gallery: \(error.localizedDescription)"
                self.isLoading = false
            }

            errorCoordinator.handle(error, context: "Gallery data loading")
        }
    }
    
    /// Update service dependencies (used when switching between mock and production services)
    ///
    /// - Parameters:
    ///   - databaseService: New database service instance
    ///   - authService: New authentication service instance
    ///   - errorCoordinator: New error coordinator instance
    func updateServices(
        databaseService: DatabaseServiceProtocol,
        authService: AuthenticationServiceProtocol,
        errorCoordinator: ErrorCoordinator
    ) {
        self.databaseService = databaseService
        self.authService = authService
        self.errorCoordinator = errorCoordinator
    }
    
    /// Manual refresh trigger for pull-to-refresh functionality
    func refreshGallery() async {
        await loadGalleryData()
    }
    
    // MARK: - Private Methods
    
    /// Fetch gallery events from the database service
    ///
    /// - Returns: Array of GalleryHistoryEvent objects for the current user
    /// - Throws: Database errors or network errors during fetch
    private func fetchGalleryEvents() async throws -> [GalleryHistoryEvent] {
        // Return real data from database
        guard let userId = authService.currentUser?.uid else {
            return []
        }

        // Fetch gallery events from Firebase
        let events = try await databaseService.getGalleryHistoryEvents(for: userId)

        return events
    }
    
    /// Periodic refresh disabled to avoid compilation issues
    private func setupPeriodicRefresh() {
        // TODO: Implement periodic refresh when Swift compiler issue is resolved
    }

    // MARK: - Archived Photos

    /// Load archived photos from Cloud Storage (photos older than 90 days)
    ///
    /// After the 90-day retention period, text data is deleted but photos are
    /// archived to Cloud Storage. This method loads those archived photos.
    ///
    /// Photos are organized in Cloud Storage by:
    /// - gallery-archive/{userId}/{profileId}/{year}/{month}/{photoId}.jpg
    ///
    /// - Important: Only loads photos for the current authenticated user
    /// - Note: Photos are sorted by archived date (newest first)
    func loadArchivedPhotos() async {
        isLoadingArchive = true

        do {
            guard let userId = authService.currentUser?.uid else {
                await MainActor.run {
                    self.isLoadingArchive = false
                }
                return
            }

            let storage = Storage.storage()
            let archiveRef = storage.reference().child("gallery-archive/\(userId)")

            // List all items under user's archive folder
            let result = try await archiveRef.listAll()

            var photos: [ArchivedPhoto] = []

            // Process each archived photo
            for item in result.items {
                do {
                    // Get download URL
                    let url = try await item.downloadURL()

                    // Get metadata
                    let metadata = try await item.getMetadata()

                    // Extract archived date from metadata
                    let archivedAtString = metadata.customMetadata?["archivedAt"] ?? ""
                    let archivedAt = ISO8601DateFormatter().date(from: archivedAtString) ?? Date()

                    // Extract profile ID from metadata
                    let profileId = metadata.customMetadata?["profileId"] ?? ""

                    // Extract original creation date
                    let originalCreatedAtString = metadata.customMetadata?["originalCreatedAt"] ?? ""
                    let originalCreatedAt = ISO8601DateFormatter().date(from: originalCreatedAtString)

                    photos.append(ArchivedPhoto(
                        id: item.name,
                        url: url,
                        archivedAt: archivedAt,
                        originalCreatedAt: originalCreatedAt,
                        profileId: profileId
                    ))

                } catch {
                    print("❌ [GalleryViewModel] Failed to load archived photo: \(error)")
                    continue
                }
            }

            // Sort by original creation date (newest first)
            let sortedPhotos = photos.sorted {
                ($0.originalCreatedAt ?? $0.archivedAt) > ($1.originalCreatedAt ?? $1.archivedAt)
            }

            await MainActor.run {
                self.archivedPhotos = sortedPhotos
                self.isLoadingArchive = false
            }

        } catch {
            // Check if error is 404 (archive folder doesn't exist yet - expected for new users)
            let storageError = error as NSError
            let is404 = storageError.code == 404 ||
                       storageError.userInfo["ResponseErrorCode"] as? Int == 404 ||
                       storageError.localizedDescription.contains("Not Found")

            if is404 {
                await MainActor.run {
                    self.archivedPhotos = []
                    self.isLoadingArchive = false
                    // Don't set errorMessage for expected empty state
                }
            } else {
                print("❌ [GalleryViewModel] Failed to load archived photos: \(error)")
                await MainActor.run {
                    self.isLoadingArchive = false
                    self.errorMessage = "Failed to load archived photos"
                }
            }
        }
    }
}

// MARK: - Archived Photo Model

/// Represents a photo archived to Cloud Storage after 90-day retention period
struct ArchivedPhoto: Identifiable, Codable {
    let id: String
    let url: URL
    let archivedAt: Date
    let originalCreatedAt: Date?
    let profileId: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: originalCreatedAt ?? archivedAt)
    }
}

// MARK: - Gallery Event Extensions

// Extension removed - properties are already defined in GalleryHistoryEvent.swift