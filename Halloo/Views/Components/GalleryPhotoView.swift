import SwiftUI

/// Unified Gallery Photo Component - ZERO DUPLICATES
/// 
/// This component consolidates SquarePhotoView, ProfilePhotoView, and PreviewSquarePhotoView
/// into a single, reusable 112x112 square photo display component.
/// 
/// Usage:
/// - Task Response: GalleryPhotoView(event: event, type: .taskResponse)
/// - Profile Photo: GalleryPhotoView(event: event, type: .profilePhoto)
/// - Preview/Mock: GalleryPhotoView(mockPhoto: photo, type: .preview)
struct GalleryPhotoView: View {
    // MARK: - Data Sources
    let event: GalleryHistoryEvent?
    let mockPhoto: MockPhoto?
    let type: PhotoDisplayType
    
    // MARK: - Photo Display Types
    enum PhotoDisplayType {
        case taskResponse    // Task response photos with overlay
        case profilePhoto    // Profile photos (clean, no overlay)
        case preview         // Mock/preview photos for development
    }
    
    // MARK: - Convenience Initializers
    
    /// Task response photo display
    static func taskResponse(event: GalleryHistoryEvent) -> GalleryPhotoView {
        GalleryPhotoView(event: event, mockPhoto: nil, type: .taskResponse)
    }
    
    /// Profile photo display  
    static func profilePhoto(event: GalleryHistoryEvent) -> GalleryPhotoView {
        GalleryPhotoView(event: event, mockPhoto: nil, type: .profilePhoto)
    }
    
    /// Preview/mock photo display
    static func preview(mockPhoto: MockPhoto) -> GalleryPhotoView {
        GalleryPhotoView(event: nil, mockPhoto: mockPhoto, type: .preview)
    }
    
    // MARK: - Configuration
    private let photoSize: CGFloat = 112 // Standard gallery photo size
    private let cornerRadius: CGFloat = 3 // Figma spec
    
    // Profile emojis for consistency across all photo types
    private let profileEmojis = [
        "👴🏻", "👵🏻", "👨🏻", "👩🏻", "👴🏽", "👵🏽", 
        "👴🏿", "👵🏿", "🧓🏻", "🧓🏽", "🧓🏿"
    ]
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Main photo content
            photoContent
            
            // Overlay content (only for task responses)
            if type == .taskResponse {
                overlayContent
            }
        }
        .frame(width: photoSize, height: photoSize)
        .cornerRadius(cornerRadius)
    }
    
    // MARK: - Photo Content
    @ViewBuilder
    private var photoContent: some View {
        switch type {
        case .taskResponse:
            taskResponsePhotoContent
        case .profilePhoto:
            profilePhotoContent
        case .preview:
            previewPhotoContent
        }
    }
    
    @ViewBuilder
    private var taskResponsePhotoContent: some View {
        if let event = event {
            if event.photoData == nil && event.hasTextResponse {
            // Text-only response
            textResponsePreview(for: event)
        } else if let photoData = event.photoData,
                  let uiImage = UIImage(data: photoData) {
            // Photo response
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: photoSize, height: photoSize)
                .clipped()
            } else {
                placeholderPhoto
            }
        } else {
            placeholderPhoto
        }
    }
    
    @ViewBuilder
    private var profilePhotoContent: some View {
        if let event = event {
            if let photoURL = event.photoURL, !photoURL.isEmpty {
            AsyncImage(url: URL(string: photoURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: photoSize, height: photoSize)
                    .clipped()
            } placeholder: {
                loadingPlaceholder
            }
            } else {
                // Emoji fallback for profile photos
                emojiPlaceholder(for: event)
            }
        } else {
            placeholderPhoto
        }
    }
    
    @ViewBuilder
    private var previewPhotoContent: some View {
        // Mock photo placeholder for previews
        placeholderPhoto
    }
    
    // MARK: - Overlay Content
    @ViewBuilder
    private var overlayContent: some View {
        if let event = event, event.photoData != nil {
            // Profile avatar overlay (bottom-right corner) - only for photos with data
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    profileAvatarOverlay(for: event)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var placeholderPhoto: some View {
        Rectangle()
            .fill(Color(hex: "e8e8e8"))
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.title)
                    .foregroundColor(Color(hex: "b8b8b8"))
            )
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color(hex: "f0f0f0"))
            .overlay(
                ProgressView()
                    .tint(Color(hex: "9f9f9f"))
            )
    }
    
    private func emojiPlaceholder(for event: GalleryHistoryEvent) -> some View {
        let emoji = profileEmojis[abs(event.profileId.hashValue) % profileEmojis.count]
        
        return Rectangle()
            .fill(Color(hex: "f0f0f0"))
            .overlay(
                Text(emoji)
                    .font(.system(size: 48))
            )
    }
    
    private func textResponsePreview(for event: GalleryHistoryEvent) -> some View {
        VStack(spacing: 0) {
            // Top black line
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)
            
            // Message bubble area
            VStack(spacing: 8) {
                // Small outgoing message bubble (top)
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(hex: "007AFF"))
                        .frame(width: 40, height: 16)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 8)
                
                // Middle black line separator
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                
                // Small incoming message bubble (bottom)
                HStack {
                    Rectangle()
                        .fill(Color(hex: "E5E5EA"))
                        .frame(width: 24, height: 16)
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
            .background(Color(hex: "f5f5f5"))
            
            // Bottom black line
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)
        }
    }
    
    private func profileAvatarOverlay(for event: GalleryHistoryEvent) -> some View {
        // Small profile avatar overlay (20x20) in bottom-right corner
        let emoji = profileEmojis[abs(event.profileId.hashValue) % profileEmojis.count]
        
        return Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(
                Text(emoji)
                    .font(.system(size: 10))
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Mock Photo Support
struct MockPhoto {
    let id: String
    let profileName: String
    // Add other mock properties as needed
}

// MARK: - Preview
#Preview("Gallery Photo Types") {
    let mockEvent = GalleryHistoryEvent(
        id: "preview-event",
        userId: "preview-user",
        profileId: "preview-profile",
        eventType: .taskResponse,
        createdAt: Date(),
        eventData: .taskResponse(GalleryEventData.SMSResponseData(
            taskId: "preview-task",
            textResponse: "Sample response",
            photoData: nil,
            responseType: "text",
            taskTitle: "Take Medication"
        ))
    )
    
    let mockPhoto = MockPhoto(
        id: "preview-photo",
        profileName: "Preview Profile"
    )
    
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            // Task Response Examples
            GalleryPhotoView.taskResponse(event: mockEvent)
            GalleryPhotoView.profilePhoto(event: mockEvent)
            GalleryPhotoView.preview(mockPhoto: mockPhoto)
        }
        
        Text("Gallery Photo View - Unified Component")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(hex: "f9f9f9"))
}