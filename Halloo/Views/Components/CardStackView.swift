import SwiftUI

/// Original card stack design showing completed task evidence
/// Empty state: Paper airplane with message
/// Active state: Dark cards with SMS bubbles and stacking effect
struct CardStackView: View {

    // MARK: - Properties
    let events: [GalleryHistoryEvent]
    @Binding var currentTopEvent: GalleryHistoryEvent?
    let imageCache: ImageCacheService
    @State private var stackedEvents: [GalleryHistoryEvent] = []
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero

    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    
    // MARK: - Constants
    private let sidePadding: CGFloat = 20 // Padding on each side
    private var cardWidth: CGFloat {
        // Card width: screen width minus side padding, optimized for engagement (~95% of available width)
        (UIScreen.main.bounds.width - (sidePadding * 2)) * 0.95
    }
    private var cardHeight: CGFloat {
        // Card height: taller than wide for vertical card shape (aspect ratio ~1.4:1)
        cardWidth * 1.4
    }
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            if stackedEvents.isEmpty {
                emptyCard
            } else {
                cardStack
            }
        }
        .frame(width: cardWidth, height: cardHeight) // Enforce vertical card ratio
        .onAppear {
            stackedEvents = events
            currentTopEvent = stackedEvents.first
        }
        .onChange(of: events) { oldEvents, newEvents in
            stackedEvents = newEvents
            currentTopEvent = newEvents.first
        }
        .onChange(of: stackedEvents) { oldEvents, newEvents in
            currentTopEvent = stackedEvents.first
        }
    }
    
    private var emptyCard: some View {
        VStack(spacing: 19.2) { // 24 × 0.8 = 19.2 (20% smaller)
            Spacer()
            Image(systemName: "paperplane.fill")
                .font(.system(size: 64, weight: .light)) // 80 × 0.8 = 64 (20% smaller)
                .foregroundColor(.white)
            Text("Your loved one's moments will appear\nhere as beautiful cards")
                .font(.system(size: 14.4, weight: .medium)) // 18 × 0.8 = 14.4 (20% smaller)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3.2) // 4 × 0.8 = 3.2 (20% smaller)
            Spacer()
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color(red: 0.108, green: 0.108, blue: 0.108)) // 0.12 × 0.9 = 0.108 (10% darker)
        .cornerRadius(10)
    }
    
    private var cardStack: some View {
        ZStack {
            // All cards in one ForEach so they can animate between positions
            ForEach(Array(stackedEvents.enumerated()), id: \.element.id) { originalIndex, event in
                if originalIndex < 5 {
                    // Calculate current visual position after any reordering
                    let currentIndex = stackedEvents.firstIndex(where: { $0.id == event.id }) ?? originalIndex
                    
                    cardView(for: event, cardIndex: currentIndex)
                        .scaleEffect(getCardScale(for: currentIndex))
                        .offset(
                            x: currentIndex == 0 ? dragOffset.width : getCardXOffset(for: currentIndex),
                            y: currentIndex == 0 ? dragOffset.height : getCardYOffset(for: currentIndex)
                        )
                        .rotationEffect(.degrees(
                            currentIndex == 0 ? Double(dragOffset.width * 0.02) : getCardRotation(for: currentIndex)
                        ))
                        .opacity(1.0)
                        .zIndex(currentIndex == 0 ? 100 : Double(10 - currentIndex))
                        .animation(currentIndex == 0 && isDragging ? nil : .easeOut(duration: 0.35), value: dragOffset)
                        .animation(currentIndex == 0 && isDragging ? nil : .linear(duration: 0.2), value: stackedEvents.map(\.id))
                }
            }
        }
        .gesture(DragGesture()
            .onChanged { value in
                isDragging = true
                // Track horizontal movement only
                dragOffset = CGSize(width: value.translation.width, height: 0)
            }
            .onEnded { value in
                isDragging = false
                
                if abs(value.translation.width) > swipeThreshold && stackedEvents.count > 1 {
                    // Smooth exit animation - continue from current position
                    let targetX = value.translation.width > 0 ? 450 : -450
                    dragOffset = CGSize(
                        width: targetX,
                        height: 0
                    )
                    
                    // Reorder after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        // Move top card to back
                        let topCard = stackedEvents.removeFirst()
                        stackedEvents.append(topCard)
                        
                        // Reset drag offset immediately
                        dragOffset = .zero
                    }
                } else {
                    // Snap back to center
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = .zero
                    }
                }
            })
    }
    
    // MARK: - Card Positioning Helpers

    private func getCardScale(for index: Int) -> CGFloat {
        switch index {
        case 0: return 1.0      // Front card: full size
        case 1, 2: return 0.98  // Cards 1&2: 98% size (bigger)
        case 3, 4: return 0.96  // Cards 3&4: 96% size (bigger)
        default: return 0.50    // Cards 5+: 50% size
        }
    }

    private func getCardXOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: return -12      // Card 1: left
        case 2: return 12       // Card 2: right
        case 3: return 0        // Card 3: center
        case 4: return -6       // Card 4: slight left
        default: return CGFloat(index % 2 == 0 ? -4 : 4)
        }
    }

    private func getCardYOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: return -16      // Card 1: peek from top
        case 2: return -16      // Card 2: peek from top
        case 3: return 16       // Card 3: peek from bottom
        case 4: return -8       // Card 4: slight top
        default: return CGFloat(-index * 2)
        }
    }

    private func getCardRotation(for index: Int) -> Double {
        switch index {
        case 1: return -4.75    // Card 1: left tilt (5% less: -5 × 0.95)
        case 2: return 3.61     // Card 2: right tilt (another 5% less: 3.8 × 0.95)
        default: return Double(index % 2 == 0 ? -2 : 2)  // Cards 3+: minimal tilt
        }
    }
    
    private func cardView(for event: GalleryHistoryEvent, cardIndex: Int) -> some View {
        // Photo cards: Full-bleed photo as card background
        // Text cards: Dark background with speech bubbles
        if event.hasPhoto {
            return AnyView(photoCardView(for: event, cardIndex: cardIndex))
        } else {
            return AnyView(textCardView(for: event, cardIndex: cardIndex))
        }
    }

    private func photoCardView(for event: GalleryHistoryEvent, cardIndex: Int) -> some View {
        ZStack {
            // Photo fills entire card (background layer)
            Group {
                // Try cached image first (fast path - no decoding needed)
                if let cachedImage = imageCache.getCachedGalleryImage(for: event.id) {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                    // Fallback: Decode on-the-fly if cache miss (slow path)
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Photo exists but couldn't be loaded - dark fallback
                    Color(red: 0.08, green: 0.08, blue: 0.08)
                    Image(systemName: "photo")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()

            // Overlay header and circle on top of photo
            VStack {
                // Header with semi-transparent background for readability
                HStack {
                    // Clean card counter: "1/5" format in rounded pill
                    Text("\(cardIndex + 1)/\(stackedEvents.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                )

                Spacer()

                // Bottom banner with task info
                HStack(spacing: 12) {
                    // Profile image using ProfileImageView (single source of truth)
                    if let profile = appState.profiles.first(where: { $0.id == event.profileId }),
                       let profileSlot = appState.profiles.firstIndex(where: { $0.id == event.profileId }) {
                        ProfileImageView(
                            profile: profile,
                            profileSlot: profileSlot,
                            isSelected: false,
                            size: .custom(45)
                        )
                    }

                    // Task name
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Completion time
                    Text(formatEventTime(event.createdAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)
    }

    // MARK: - Helper: Format Event Time
    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func textCardView(for event: GalleryHistoryEvent, cardIndex: Int) -> some View {
        // Calculate progressive lightening for text cards
        let baseColor: Double = 0.08
        let lighteningAmount = Double(cardIndex) * 0.05
        let cardColor = Color(red: baseColor + lighteningAmount,
                             green: baseColor + lighteningAmount,
                             blue: baseColor + lighteningAmount)

        return ZStack {
            cardColor

            VStack {
                // Header
                HStack {
                    // Clean card counter: "1/5" format in rounded pill
                    Text("\(cardIndex + 1)/\(stackedEvents.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }

                Spacer()

                // SMS bubbles
                VStack(spacing: 18) {
                    HStack {
                        Spacer(minLength: 0)
                        SpeechBubbleView(
                            text: "Reminder: \(event.title). Please confirm when completed.",
                            isOutgoing: true,
                            backgroundColor: Color.blue,
                            textColor: .white,
                            maxWidth: 287,
                            scale: 0.85
                        )
                    }

                    HStack {
                        SpeechBubbleView(
                            text: event.textResponse ?? "Completed!",
                            isOutgoing: false,
                            backgroundColor: Color(red: 0.9, green: 0.9, blue: 0.9),
                            textColor: .black,
                            maxWidth: 242,
                            scale: 0.85
                        )
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Bottom banner with task info
                HStack(spacing: 12) {
                    // Profile image using ProfileImageView (single source of truth)
                    if let profile = appState.profiles.first(where: { $0.id == event.profileId }),
                       let profileSlot = appState.profiles.firstIndex(where: { $0.id == event.profileId }) {
                        ProfileImageView(
                            profile: profile,
                            profileSlot: profileSlot,
                            isSelected: false,
                            size: .custom(45)
                        )
                    }

                    // Task name
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Completion time
                    Text(formatEventTime(event.createdAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.black.opacity(0.3)  // Solid overlay for text cards (no gradient needed)
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)
    }
}

#Preview {
    let imageCache = ImageCacheService()
    return CardStackView(
        events: [],
        currentTopEvent: .constant(nil),
        imageCache: imageCache
    )
    .padding()
}