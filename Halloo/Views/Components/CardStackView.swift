import SwiftUI

/// Original card stack design showing completed task evidence
/// Empty state: Paper airplane with message
/// Active state: Dark cards with SMS bubbles and stacking effect
struct CardStackView: View {
    
    // MARK: - Properties
    let events: [GalleryHistoryEvent]
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
            stackedEvents = createMockEvents()
        }
    }
    
    private var emptyCard: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "paperplane.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white)
            Text("Your loved one's moments will appear\nhere as beautiful cards")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .cornerRadius(20)
    }
    
    private var cardStack: some View {
        ZStack {
            // All cards in one ForEach so they can animate between positions
            ForEach(Array(stackedEvents.enumerated()), id: \.element.id) { originalIndex, event in
                if originalIndex < 5 {
                    // Calculate current visual position after any reordering
                    let currentIndex = stackedEvents.firstIndex(where: { $0.id == event.id }) ?? originalIndex
                    
                    cardView(for: event)
                        .scaleEffect(currentIndex == 0 ? 1.0 : 0.95 - CGFloat(currentIndex) * 0.02)
                        .offset(
                            x: currentIndex == 0 ? dragOffset.width : CGFloat(currentIndex % 2 == 0 ? -8 : 8),
                            y: currentIndex == 0 ? dragOffset.height : CGFloat(-currentIndex * 4)
                        )
                        .rotationEffect(.degrees(
                            currentIndex == 0 ? Double(dragOffset.width * 0.02) : Double(currentIndex % 2 == 0 ? -3 : 3)
                        ))
                        .opacity(1.0)
                        .zIndex(currentIndex == 0 ? 100 : Double(10 - currentIndex))
                        .animation(currentIndex == 0 && isDragging ? nil : .linear(duration: 0.3), value: stackedEvents.map(\.id))
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
                    // Fast exit animation
                    withAnimation(.easeOut(duration: 0.15)) {
                        dragOffset = CGSize(
                            width: value.translation.width > 0 ? 800 : -800,
                            height: 0
                        )
                    }
                    
                    // Immediately reorder after very short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
    
    private func cardView(for event: GalleryHistoryEvent) -> some View {
        ZStack {
            Color(red: 0.12, green: 0.12, blue: 0.12)
            
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Done for today")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Today")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    Spacer()
                }
                
                Spacer()
                
                // Content
                if event.hasPhoto {
                    Image(systemName: "photo")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    VStack(spacing: 24) {
                        HStack {
                            Spacer(minLength: 60)
                            SpeechBubbleView(
                                text: "Reminder: \(event.title). Please confirm when completed.",
                                isOutgoing: true,
                                backgroundColor: Color.blue,
                                textColor: .white
                            )
                        }
                        
                        HStack {
                            SpeechBubbleView(
                                text: event.textResponse ?? "Completed!",
                                isOutgoing: false,
                                backgroundColor: Color.gray.opacity(0.2),
                                textColor: .black
                            )
                            Spacer(minLength: 60)
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
    
    private func createMockEvents() -> [GalleryHistoryEvent] {
        return [
            GalleryHistoryEvent(
                userId: "mock-user",
                profileId: "mock-profile-1",
                eventType: .taskResponse,
                eventData: .taskResponse(GalleryEventData.SMSResponseData(
                    taskId: "1",
                    textResponse: nil,
                    photoData: Data("mock-photo".utf8),
                    responseType: "photo",
                    taskTitle: "Take Medication"
                ))
            ),
            GalleryHistoryEvent(
                userId: "mock-user",
                profileId: "mock-profile-1", 
                eventType: .taskResponse,
                eventData: .taskResponse(GalleryEventData.SMSResponseData(
                    taskId: "2",
                    textResponse: "Done!",
                    photoData: nil,
                    responseType: "sms",
                    taskTitle: "Call Doctor"
                ))
            ),
            GalleryHistoryEvent(
                userId: "mock-user",
                profileId: "mock-profile-1",
                eventType: .taskResponse,
                eventData: .taskResponse(GalleryEventData.SMSResponseData(
                    taskId: "3",
                    textResponse: nil,
                    photoData: Data("mock-photo".utf8),
                    responseType: "photo",
                    taskTitle: "Exercise"
                ))
            ),
            GalleryHistoryEvent(
                userId: "mock-user",
                profileId: "mock-profile-1",
                eventType: .taskResponse,
                eventData: .taskResponse(GalleryEventData.SMSResponseData(
                    taskId: "4",
                    textResponse: "Completed",
                    photoData: nil,
                    responseType: "sms",
                    taskTitle: "Drink Water"
                ))
            )
        ]
    }
}

#Preview {
    CardStackView(events: [])
        .padding()
}