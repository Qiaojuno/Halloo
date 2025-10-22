import SwiftUI

/// Original card stack design showing completed task evidence
/// Empty state: Paper airplane with message
/// Active state: Dark cards with SMS bubbles and stacking effect
struct CardStackView: View {
    
    // MARK: - Properties
    let events: [GalleryHistoryEvent]
    @Binding var currentTopEvent: GalleryHistoryEvent?
    @State private var stackedEvents: [GalleryHistoryEvent] = []
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    
    // MARK: - Constants
    private let cardWidth: CGFloat = 334
    private let cardHeight: CGFloat = 453
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            if stackedEvents.isEmpty {
                emptyCard
            } else {
                cardStack
            }
        }
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
        .cornerRadius(20)
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
        case 1, 2: return 0.95  // Cards 1&2: 95% size
        default: return 0.50    // Cards 3+: 50% size
        }
    }

    private func getCardXOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: return -8       // Card 1: left fan
        case 2: return 8        // Card 2: right fan
        default: return CGFloat(index % 2 == 0 ? -4 : 4)  // Cards 3+: minimal fan
        }
    }

    private func getCardYOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: return -24      // Card 1: raised higher for more peek
        case 2: return -34      // Card 2: raised even higher
        default: return CGFloat(-index * 2)     // Cards 3+: minimal offset
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
        // Calculate progressive lightening for text cards only
        let baseColor: Double = 0.08  // Darker: reduced from 0.12 to 0.08
        let lighteningAmount = event.hasPhoto ? 0.0 : Double(cardIndex) * 0.05
        let cardColor = Color(red: baseColor + lighteningAmount,
                             green: baseColor + lighteningAmount,
                             blue: baseColor + lighteningAmount)
        
        return ZStack {
            cardColor
            
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Done for today: \(stackedEvents.count)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        Text(event.responseMethod)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    Spacer()
                }
                
                Spacer()
                
                // Content
                if event.hasPhoto, let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                    // Display actual photo from MMS response
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth - 40, height: cardHeight - 100)
                        .clipped()
                        .cornerRadius(12)
                } else if event.hasPhoto {
                    // Fallback: Photo exists but couldn't be loaded
                    Image(systemName: "photo")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    VStack(spacing: 18) {  // Reduced from 24 to 18
                        HStack {
                            Spacer(minLength: 0)
                            SpeechBubbleView(
                                text: "Reminder: \(event.title). Please confirm when completed.",
                                isOutgoing: true,
                                backgroundColor: Color.blue,
                                textColor: .white,
                                maxWidth: 287,  // Blue bubble: 95% of content area (302pt × 0.95)
                                scale: 0.85  // 15% reduction: text 15.3pt, corners 15.3pt, tail 12.75pt
                            )
                        }

                        HStack {
                            SpeechBubbleView(
                                text: event.textResponse ?? "Completed!",
                                isOutgoing: false,
                                backgroundColor: Color(red: 0.9, green: 0.9, blue: 0.9),
                                textColor: .black,
                                maxWidth: 242,  // Grey bubble: 80% of content area (302pt × 0.8)
                                scale: 0.85  // 15% reduction: text 15.3pt, corners 15.3pt, tail 12.75pt
                            )
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // Circle
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color(red: 0x43/255, green: 0x43/255, blue: 0x43/255))
                        .frame(width: 35, height: 36)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(20)
    }
}

#Preview {
    // Remove unused @State variable (not used in preview)
    return CardStackView(events: [], currentTopEvent: .constant(nil))
        .padding()
}