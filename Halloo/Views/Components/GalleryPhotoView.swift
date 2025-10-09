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
        ZStack {
            // Light background
            Color(hex: "f5f5f5")

            // Middle aligned vertically
            VStack(spacing: 6) {
                // Outgoing message bubble (blue, top right) with 3 lines of broken up bars
                HStack {
                    Spacer()
                    MiniSpeechBubble(
                        textLines: [
                            [(11, 1.5), (13, 1.5), (15, 1.5)],   // Line 1: 3 segments = 2 gaps
                            [(18, 1.5), (17, 1.5)],              // Line 2: 2 segments = 1 gap
                            [(10, 1.5), (14, 1.5), (12, 1.5)]    // Line 3: 3 segments = 2 gaps
                        ],
                        isOutgoing: true,
                        backgroundColor: Color(hex: "007AFF"),
                        tailInset: 8
                    )
                }
                .padding(.trailing, 6)

                // Incoming message bubble (gray, bottom left) with 1 line of broken up bars
                HStack {
                    MiniSpeechBubble(
                        textLines: [
                            [(13, 1.5), (15, 1.5), (10, 1.5)]  // Line 1: 3 segments = 2 gaps
                        ],
                        isOutgoing: false,
                        backgroundColor: Color(hex: "E5E5EA"),
                        tailInset: 8
                    )
                    Spacer()
                }
                .padding(.leading, 6)
            }

            // Profile avatar overlay in bottom right (same as photo squares)
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
    
    private func profileAvatarOverlay(for event: GalleryHistoryEvent) -> some View {
        // Small profile avatar overlay (20x20) in bottom-right corner - clean style
        let emoji = profileEmojis[abs(event.profileId.hashValue) % profileEmojis.count]

        return Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(
                Text(emoji)
                    .font(.system(size: 10))
            )
    }
}

// MARK: - Mini Speech Bubble for Gallery (scaled down version with BubbleWithTail)
struct MiniSpeechBubble: View {
    let textLines: [[(width: CGFloat, height: CGFloat)]]  // Array of lines, each line has multiple "words"
    let isOutgoing: Bool
    let backgroundColor: Color
    let tailInset: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            ForEach(0..<textLines.count, id: \.self) { lineIndex in
                HStack(spacing: 1) {  // 1px spacing between word segments
                    ForEach(0..<textLines[lineIndex].count, id: \.self) { wordIndex in
                        // Text segment
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: textLines[lineIndex][wordIndex].width,
                                   height: textLines[lineIndex][wordIndex].height)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isOutgoing && textLines.count > 1 ? 9 : 7)
        .background(
            MiniBubbleWithTail(isOutgoing: isOutgoing, cornerRadius: 4, tailSize: 6, tailInset: tailInset)
                .fill(backgroundColor)
        )
    }
}

// MARK: - Mini Bubble With Tail (customizable tail position)
struct MiniBubbleWithTail: Shape {
    let isOutgoing: Bool
    let cornerRadius: CGFloat
    let tailSize: CGFloat
    let tailInset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        if isOutgoing {
            // Outgoing bubble - tail on bottom right
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

            // Tail closer to right edge
            path.addLine(to: CGPoint(x: width - tailInset, y: height))
            path.addLine(to: CGPoint(x: width - tailInset - tailSize, y: height))
            path.addLine(to: CGPoint(x: width - tailInset, y: height + tailSize))
            path.addLine(to: CGPoint(x: width - tailInset, y: height))

            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // Incoming bubble - tail on bottom left
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

            // Tail closer to left edge
            path.addLine(to: CGPoint(x: 0, y: height - cornerRadius))
            path.addLine(to: CGPoint(x: tailInset, y: height))
            path.addLine(to: CGPoint(x: tailInset + tailSize, y: height))
            path.addLine(to: CGPoint(x: tailInset, y: height + tailSize))
            path.addLine(to: CGPoint(x: tailInset, y: height))
            path.addLine(to: CGPoint(x: 0, y: height - cornerRadius))

            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        return path
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