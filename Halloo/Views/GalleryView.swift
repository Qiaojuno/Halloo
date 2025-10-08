import SwiftUI

// Import the gallery history event model and profile gallery item view
// These imports ensure the new components are available in GalleryView

struct GalleryView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.container) private var container
    @StateObject private var viewModel: GalleryViewModel
    
    // MARK: - Navigation State
    /// Tab selection binding from parent ContentView for floating pill navigation
    @Binding var selectedTab: Int
    
    // MARK: - State
    @State private var selectedFilter: GalleryFilter = .all
    @State private var selectedEventForDetail: GalleryHistoryEvent?
    @State private var showingFilterDropdown = false
    @State private var selectedProfileIndex: Int = 0
    
    // MARK: - Initialization
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        // Initialize with placeholder - will be properly set in onAppear
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            databaseService: MockDatabaseService(),
            authService: MockAuthenticationService(),
            errorCoordinator: ErrorCoordinator()
        ))
    }
    
    var body: some View {
        ZStack {
            // Match DashboardView structure exactly - no NavigationView wrapper
            ScrollView {
                VStack(spacing: 0) { // Match DashboardView spacing: 0 between sections

                    // Header with Remi logo and user profile - using universal component
                    SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)

                    // Gallery card - match spacing ratio with DashboardView profiles
                    VStack(alignment: .leading, spacing: 16) {
                        // White card container (92% screen width)
                        VStack(spacing: 0) {
                            // Gallery card header with title and filter button
                            galleryCardHeader
                                .background(Color.white)

                            // Photo Grid extends naturally without bottom rounding
                            photoGridContent
                                .background(Color.white)
                        }
                        .cornerRadius(10) // Round all corners
                        .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2) // Dark gray shadow
                    }

                    // Bottom padding to prevent content from hiding behind navigation
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match DashboardView (96% width)
            }
            .background(Color(hex: "f9f9f9")) // Light gray app background

            // Reusable bottom gradient navigation (no create button)
            BottomGradientNavigation(selectedTab: $selectedTab)
        }
        .onAppear {
            initializeViewModel()
            print("🔥 GalleryView onAppear - Gallery events: \(viewModel.galleryEvents.count)")
        }
        .task {
            await viewModel.loadGalleryData()
        }
        .fullScreenCover(item: $selectedEventForDetail) { event in
            let currentIndex = viewModel.galleryEvents.firstIndex(where: { $0.id == event.id }) ?? 0
            let totalEvents = viewModel.galleryEvents.count
            
            GalleryDetailView(
                event: event, 
                selectedTab: $selectedTab,
                currentIndex: currentIndex,
                totalEvents: totalEvents,
                onPrevious: {
                    navigateToPrevious(from: event)
                },
                onNext: {
                    navigateToNext(from: event)
                }
            )
            .inject(container: container)
            .animation(.none) // Remove all animations completely
            .transition(.identity) // No transition effect
            .onAppear {
                print("🔥 GalleryDetailView showing for event: \(event.id)")
            }
        }
        .overlay(
            // Clean dropdown overlay positioned below filter button
            Group {
                if showingFilterDropdown {
                    Color.clear // Truly invisible tap target to close dropdown
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingFilterDropdown = false
                            }
                        }
                    
                    VStack {
                        HStack {
                            Spacer()
                            
                            // Filter dropdown positioned below the filter button
                            VStack(spacing: 0) {
                                ForEach(GalleryFilter.allCases, id: \.self) { filter in
                                    Button(action: {
                                        selectedFilter = filter
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showingFilterDropdown = false
                                        }
                                    }) {
                                        HStack {
                                            Text(filter.rawValue)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(selectedFilter == filter ? Color(hex: "007AFF") : Color(hex: "6f6f6f"))
                                            Spacer()
                                            
                                            if selectedFilter == filter {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(Color(hex: "007AFF"))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.white)
                                    }
                                    
                                    if filter != GalleryFilter.allCases.last {
                                        Divider()
                                            .background(Color(hex: "e0e0e0"))
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .frame(width: 140)
                            .padding(.trailing, 16) // Align with filter button
                        }
                        .padding(.top, 90) // Position below header section
                        
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        )
    }
    
    // Rest of implementation continues...
    private func initializeViewModel() {
        // Initialize ViewModel with container services
        viewModel.updateServices(
            databaseService: container.resolve(DatabaseServiceProtocol.self),
            authService: container.resolve(AuthenticationServiceProtocol.self),
            errorCoordinator: container.resolve(ErrorCoordinator.self)
        )
        
        // Gallery data will be loaded when view appears
    }
    
    private func navigateToPrevious(from currentEvent: GalleryHistoryEvent) {
        guard let currentIndex = viewModel.galleryEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex > 0 else { return }
        
        let previousEvent = viewModel.galleryEvents[currentIndex - 1]
        selectedEventForDetail = previousEvent
    }
    
    private func navigateToNext(from currentEvent: GalleryHistoryEvent) {
        guard let currentIndex = viewModel.galleryEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex < viewModel.galleryEvents.count - 1 else { return }
        
        let nextEvent = viewModel.galleryEvents[currentIndex + 1]
        selectedEventForDetail = nextEvent
    }
}

// MARK: - Helper Extensions
extension GalleryView {
    // Gallery Card Header Component
    private var galleryCardHeader: some View {
        HStack {
            // TASK GALLERY title (left aligned)
            Text("TASK GALLERY")
                .tracking(-1)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "9f9f9f"))
            
            Spacer()
            
            // Filter button with hamburger icon (right aligned)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingFilterDropdown.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Text(selectedFilter.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "6f6f6f"))  // Dark grey
                    
                    // Hamburger icon (3 lines)
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color(hex: "6f6f6f"))  // Dark grey
                            .frame(width: 12, height: 1.5)
                        Rectangle()
                            .fill(Color(hex: "6f6f6f"))  // Dark grey
                            .frame(width: 12, height: 1.5)
                        Rectangle()
                            .fill(Color(hex: "6f6f6f"))  // Dark grey
                            .frame(width: 12, height: 1.5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "f0f0f0"))  // Light grey rectangle
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
    
    // Photo Grid Content Component
    private var photoGridContent: some View {
        LazyVStack(spacing: 16) {
            if groupedEventsByDate.isEmpty {
                // Example message when no events exist
                VStack(alignment: .leading, spacing: 8) {
                    // Example header
                    HStack {
                        Text("Create your first Remi!")
                            .tracking(-1)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 12)

                    // Example text message mini display
                    exampleTextMessageBox
                        .padding(.horizontal, 12)
                }
            } else {
                ForEach(groupedEventsByDate, id: \.date) { dateGroup in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date header
                        HStack {
                            Text(formatDateHeader(dateGroup.date))
                                .tracking(-1)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding(.horizontal, 12)

                        // Photo grid for this date
                        LazyVGrid(columns: gridColumns, spacing: 4) {
                            ForEach(dateGroup.events) { event in
                                GalleryPhotoView.taskResponse(event: event)
                                    .onTapGesture {
                                        selectedEventForDetail = event
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
        .padding(.bottom, 120) // Space for last photos + tab bar clearance
    }
    
    // Grid Layout Configuration
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    // Group events by date
    private var groupedEventsByDate: [(date: Date, events: [GalleryHistoryEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.createdAt)
        }
        
        return grouped.map { (date: $0.key, events: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }
    
    // Filter events based on selected filter
    private var filteredEvents: [GalleryHistoryEvent] {
        switch selectedFilter {
        case .all:
            return viewModel.galleryEvents
        case .photos:
            return viewModel.galleryEvents.filter { $0.photoData != nil }
        case .sms:
            return viewModel.galleryEvents.filter { $0.hasTextResponse }
        case .profiles:
            return viewModel.galleryEvents.filter { 
                if case .profileCreated(_) = $0.eventData { 
                    return true 
                } 
                return false 
            }
        }
    }
    
    // Format date for section headers
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    // Example text message box (unclickable)
    private var exampleTextMessageBox: some View {
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
                            [(9, 1.5), (6, 1.5), (11, 1.5), (7, 1.5)],   // Line 1: 25% smaller
                            [(12, 1.5), (5, 1.5), (9, 1.5)],             // Line 2: 25% smaller
                            [(8, 1.5), (10, 1.5), (6, 1.5)]              // Line 3: 25% smaller
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
                            [(11, 1.5), (7, 1.5), (9, 1.5), (5, 1.5)]  // Line 1: 25% smaller
                        ],
                        isOutgoing: false,
                        backgroundColor: Color(hex: "E5E5EA"),
                        tailInset: 8
                    )
                    Spacer()
                }
                .padding(.leading, 6)
            }

            // Small light blue circle in bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color(hex: "ADD8E6"))
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 112, height: 112)
        .cornerRadius(3)
        .allowsHitTesting(false) // Make unclickable
    }
}

// MARK: - Gallery Filter Enum
enum GalleryFilter: String, CaseIterable {
    case all = "All"
    case photos = "Photos"
    case sms = "SMS"
    case profiles = "Profiles"
}

// MARK: - Components moved to separate files
// Photo components moved to /Views/Components/GalleryPhotoView.swift