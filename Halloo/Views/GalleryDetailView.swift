import SwiftUI

/**
 * GALLERY DETAIL VIEW - Expanded content view for gallery items
 *
 * PURPOSE: Full-screen detailed view of gallery content (photos, SMS texts, profile creation events)
 * Replaces the squished gallery grid with expansive, readable content display
 *
 * CONTENT TYPES:
 * - Photos: Large image with "task confirmed" + task name + completion time
 * - SMS Texts: Conversation-style bubbles with sent/received messages  
 * - Profile Creation: Large profile picture with "profile created" + name + creation time
 *
 * NAVIGATION: Full-screen cover with shared header and bottom pill navigation
 * UI CONSISTENCY: Matches DashboardView and GalleryView design language
 */
struct GalleryDetailView: View {
    
    // MARK: - Properties
    let event: GalleryHistoryEvent
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    
    // Navigation state
    let currentIndex: Int
    let totalEvents: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    // Computed navigation availability
    private var hasPrevious: Bool { currentIndex > 0 }
    private var hasNext: Bool { currentIndex < totalEvents - 1 }
    
    // Profile selection state for header
    @State private var selectedProfileIndex: Int = 0
    
    // MARK: - Initialization
    init(
        event: GalleryHistoryEvent,
        selectedTab: Binding<Int>,
        currentIndex: Int = 0,
        totalEvents: Int = 1,
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {}
    ) {
        self.event = event
        self._selectedTab = selectedTab
        self.currentIndex = currentIndex
        self.totalEvents = totalEvents
        self.onPrevious = onPrevious
        self.onNext = onNext
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "f9f9f9")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Remi logo and profile icon - same as other views
                SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
                    .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match DashboardView/GalleryView alignment
                
                // Full-width white card extending to bottom of screen
                VStack(spacing: 0) {
                    // Navigation header with chevrons and date
                    navigationHeader
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24) // Increased vertical padding
                    
                    // Scrollable content area that fills remaining space
                    ScrollView {
                        VStack(spacing: 0) {
                            // Square content area - full width like Instagram
                            contentSquare
                            
                            // Bottom metadata info with padding
                            metadataInfo
                                .padding(.horizontal, 20)
                                .padding(.bottom, 120) // Space for floating navigation
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
                }
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)
                .padding(.top, 20)
                .frame(maxHeight: .infinity) // Extend to bottom
                .ignoresSafeArea(.container, edges: .bottom) // Extend past safe area to screen edge
            }
            
            // Floating bottom navigation with custom dismiss behavior - left-aligned
            VStack {
                Spacer()
                HStack {
                    FloatingPillNavigation(selectedTab: $selectedTab, onTabTapped: {
                        // Dismiss the detail view whenever any tab is tapped
                        dismiss()
                    })
                    Spacer() // Push navigation to left
                }
                .padding(.horizontal, 30) // More side padding from screen edges
                .padding(.bottom, 4) // Even closer to bottom of screen
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("DEBUG: GalleryDetailView appeared with currentIndex=\(currentIndex), totalEvents=\(totalEvents)")
            print("DEBUG: hasPrevious=\(hasPrevious), hasNext=\(hasNext)")
        }
    }
    
    // MARK: - Navigation Header with Chevrons
    private var navigationHeader: some View {
        HStack {
            // Back button with chevron
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if hasPrevious {
                        onPrevious()
                    } else {
                        dismiss()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16, weight: .light))
                }
                .foregroundColor(hasPrevious ? .gray : .gray.opacity(0.5))
            }
            
            Spacer()
            
            // Date in center
            Text(formatEventDate(event.createdAt))
                .font(AppFonts.poppinsMedium(size: 18))
                .foregroundColor(Color(hex: "595959"))
            
            Spacer()
            
            // Next button with chevron - always visible, disabled when not available
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if hasNext {
                        onNext()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Text("Next")
                        .font(.system(size: 16, weight: .light))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(hasNext ? .gray : .gray.opacity(0.3))
            }
            .disabled(!hasNext)
        }
    }
    
    // MARK: - Content View (switches based on event type)
    @ViewBuilder
    private var contentView: some View {
        switch event.eventType {
        case .taskResponse:
            if event.hasPhoto {
                photoContentView
            } else {
                smsConversationView
            }
        case .profileCreated:
            profileCreatedView
        }
    }
    
    // MARK: - Square Content Area
    private var contentSquare: some View {
        VStack(spacing: 0) {
            contentView
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width) // True square
        .cornerRadius(8)
        .clipped()
    }
    
    // MARK: - Bottom Metadata Info
    private var metadataInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch event.eventType {
            case .taskResponse:
                VStack(alignment: .leading, spacing: 4) {
                    Text("task confirmed")
                        .font(AppFonts.poppins(size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))
                    
                    // Combined name and time with bullet separator
                    HStack(spacing: 0) {
                        Text(event.originalTaskTitle + " • " + formatEventTime(event.createdAt))
                            .font(AppFonts.poppinsMedium(size: 18))
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                }
            case .profileCreated:
                VStack(alignment: .leading, spacing: 4) {
                    Text("profile created")
                        .font(AppFonts.poppins(size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))
                    
                    // Combined name and time with bullet separator
                    HStack(spacing: 0) {
                        Text(event.profileName + " • " + formatEventTime(event.createdAt))
                            .font(AppFonts.poppinsMedium(size: 18))
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Photo Content View
    private var photoContentView: some View {
        // Photo fills the entire content area
        Group {
            if let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(hex: "f0f0f0"))
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .overlay(
                        Text("Photo")
                            .font(AppFonts.poppins(size: 16))
                            .foregroundColor(Color(hex: "9f9f9f"))
                    )
            }
        }
    }
    
    // MARK: - SMS Conversation View
    private var smsConversationView: some View {
        VStack(spacing: 20) {
            
            // Conversation bubbles container
            VStack(spacing: 16) {
                
                // Outgoing message (what we sent) - right aligned, blue
                HStack {
                    Spacer(minLength: UIScreen.main.bounds.width * 0.2) // 20% left margin
                    
                    SpeechBubbleView(
                        text: "Reminder: It's time to take your morning medication with breakfast. Please confirm when completed.",
                        isOutgoing: true,
                        backgroundColor: Color(hex: "007AFF"), // iOS blue
                        textColor: .white
                    )
                }
                
                // Incoming message (their response) - left aligned, gray  
                HStack {
                    SpeechBubbleView(
                        text: event.textResponse ?? "OK",
                        isOutgoing: false,
                        backgroundColor: Color(hex: "E5E5EA"), // iOS gray
                        textColor: .black
                    )
                    
                    Spacer(minLength: UIScreen.main.bounds.width * 0.2) // 20% right margin
                }
            }
        }
        .padding(.horizontal, 16) // Add minimal padding for SMS chat bubbles
    }
    
    // MARK: - Profile Created View
    private var profileCreatedView: some View {
        // Profile picture fills the entire content area like regular photos
        Group {
            if let photoURL = event.photoURL, !photoURL.isEmpty {
                AsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color(hex: "f0f0f0"))
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                        .overlay(
                            ProgressView()
                                .tint(Color(hex: "9f9f9f"))
                        )
                }
            } else {
                // Emoji fallback as full-size photo
                Rectangle()
                    .fill(profileColor.opacity(0.2))
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .overlay(
                        Text(profileEmoji)
                            .font(.system(size: 120)) // Large emoji to fill space
                    )
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var hasPhoto: Bool {
        if case .taskResponse(let data) = event.eventData {
            return data.photoData != nil
        }
        return false
    }
    
    private var profileColor: Color {
        let colors: [Color] = [
            Color(hex: "B9E3FF"),         // Blue
            Color.red.opacity(0.6),       // Red  
            Color.green.opacity(0.6),     // Green
            Color.purple.opacity(0.6)     // Purple
        ]
        return colors[event.profileSlot % colors.count]
    }
    
    private var profileEmoji: String {
        let emojis = ["👴🏻", "👵🏻", "👴🏽", "👵🏽", "👴🏿", "👵🏿"]
        let emojiIndex = (event.profileSlot + abs(event.profileName.hashValue)) % emojis.count
        return emojis[emojiIndex]
    }
    
    // MARK: - Helper Functions
    
    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}


// MARK: - Preview Support
#if DEBUG
struct GalleryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Simple preview without complex mock data
        VStack(spacing: 20) {
            SpeechBubbleView(
                text: "Take your medication",
                isOutgoing: true,
                backgroundColor: Color(hex: "007AFF"),
                textColor: .white
            )
            
            SpeechBubbleView(
                text: "Done!",
                isOutgoing: false,
                backgroundColor: Color(hex: "E5E5EA"),
                textColor: .black
            )
        }
        .padding()
        .previewDisplayName("Speech Bubbles")
    }
}
#endif