import SwiftUI

// Import the gallery history event model and profile gallery item view
// These imports ensure the new components are available in GalleryView

struct GalleryView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.container) private var container
    @Environment(\.isScrollDisabled) private var isScrollDisabled

    // PHASE 3: Single source of truth for shared state
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: GalleryViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    // MARK: - Navigation State
    /// Tab selection binding from parent ContentView for floating pill navigation
    @Binding var selectedTab: Int

    /// Controls whether to show header (false when rendered in ContentView's layered architecture)
    var showHeader: Bool = true

    /// Controls whether to show bottom navigation (false when rendered in ContentView's layered architecture)
    var showNav: Bool = true

    // MARK: - State
    @State private var selectedFilter: GalleryFilter = .all
    @State private var selectedEventForDetail: GalleryHistoryEvent?
    @State private var showingFilterDropdown = false
    @State private var showingAccountSettings = false
    @State private var previousTab: Int = 0
    @State private var transitionDirection: Int = 1
    @State private var isTransitioning: Bool = false
    
    // MARK: - Initialization
    init(selectedTab: Binding<Int>, showHeader: Bool = true, showNav: Bool = true) {
        self._selectedTab = selectedTab
        self.showHeader = showHeader
        self.showNav = showNav
        // Initialize with placeholder - will be properly set in onAppear
        let container = Container.shared
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            databaseService: container.resolve(DatabaseServiceProtocol.self),
            authService: container.resolve(AuthenticationServiceProtocol.self)
        ))
    }
    
    var body: some View {
        ZStack {
            // Match DashboardView structure exactly - no NavigationView wrapper
            ScrollView {
                VStack(spacing: 0) { // Match DashboardView spacing: 0 between sections

                    // Header with Remi logo and settings (no profile selection needed for Gallery) (conditionally rendered)
                    if showHeader {
                        galleryHeaderSection
                    }

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
                                .animation(.easeInOut(duration: 0.3), value: selectedFilter)
                        }
                        .cornerRadius(10) // Round all corners
                        .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2) // Dark gray shadow
                    }
                    .padding(.top, showHeader ? 0 : 100) // Add top padding when header is hidden (static header height)

                    // Bottom padding to prevent content from hiding behind navigation
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match DashboardView (96% width)
            }
            .scrollDisabled(isScrollDisabled)
            .background(Color(hex: "f9f9f9")) // Light gray app background

            // Reusable bottom gradient navigation (no create button) (conditionally rendered)
            if showNav {
                BottomGradientNavigation(selectedTab: $selectedTab, previousTab: $previousTab, transitionDirection: $transitionDirection, isTransitioning: $isTransitioning)
            }
        }
        .onAppear {
            initializeViewModel()
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
        .fullScreenCover(item: $selectedEventForDetail) { event in
            // PHASE 4: Read from AppState instead of ViewModel
            let currentIndex = appState.galleryEvents.firstIndex(where: { $0.id == event.id }) ?? 0
            let totalEvents = appState.galleryEvents.count

            GalleryDetailView(
                event: event,
                selectedTab: $selectedTab,
                previousTab: $previousTab,
                transitionDirection: $transitionDirection,
                isTransitioning: $isTransitioning,
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
            .transition(.identity) // No transition effect for gallery detail
        }
    }
    
    // Rest of implementation continues...
    private func initializeViewModel() {
        // Initialize ViewModel with container services
        viewModel.updateServices(
            databaseService: container.resolve(DatabaseServiceProtocol.self),
            authService: container.resolve(AuthenticationServiceProtocol.self)
        )

        // Gallery data will be loaded when view appears
    }
    
    private func navigateToPrevious(from currentEvent: GalleryHistoryEvent) {
        // PHASE 4: Read from AppState instead of ViewModel
        guard let currentIndex = appState.galleryEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex > 0 else { return }

        let previousEvent = appState.galleryEvents[currentIndex - 1]
        selectedEventForDetail = previousEvent
    }

    private func navigateToNext(from currentEvent: GalleryHistoryEvent) {
        // PHASE 4: Read from AppState instead of ViewModel
        guard let currentIndex = appState.galleryEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex < appState.galleryEvents.count - 1 else { return }

        let nextEvent = appState.galleryEvents[currentIndex + 1]
        selectedEventForDetail = nextEvent
    }

    /// Get profile initial letter for display in gallery
    /// PHASE 3: Looks up profile by ID from AppState and returns first letter of name
    private func getProfileInitial(for profileId: String) -> String? {
        guard let profile = appState.profiles.first(where: { $0.id == profileId }) else {
            return nil
        }
        return String(profile.name.prefix(1)).uppercased()
    }

    /// Get profile slot index for color coding
    /// PHASE 3: Looks up profile by ID from AppState and returns its index
    private func getProfileSlot(for profileId: String) -> Int? {
        guard let index = appState.profiles.firstIndex(where: { $0.id == profileId }) else {
            return nil
        }
        return index
    }

    /// Render appropriate gallery view based on event type
    @ViewBuilder
    private func galleryEventView(for event: GalleryHistoryEvent) -> some View {
        switch event.eventData {
        case .taskResponse:
            GalleryPhotoView.taskResponse(
                event: event,
                profileInitial: getProfileInitial(for: event.profileId),
                profileSlot: getProfileSlot(for: event.profileId)
            )
        case .profileCreated:
            GalleryPhotoView.profilePhoto(
                event: event,
                profileInitial: getProfileInitial(for: event.profileId),
                profileSlot: getProfileSlot(for: event.profileId)
            )
        }
    }
}

// MARK: - Helper Extensions
extension GalleryView {
    // Simple header with just logo and settings (no profile selection)
    private var galleryHeaderSection: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Remi")
                .font(AppFonts.poppinsMedium(size: 37.5))
                .tracking(-3.1)
                .foregroundColor(.black)
                .fixedSize()
                .layoutPriority(1)

            Spacer()

            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingAccountSettings = true
            }) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .fullScreenCover(isPresented: $showingAccountSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(profileViewModel)
        }
    }

    // Gallery Card Header Component
    private var galleryCardHeader: some View {
        HStack {
            // Task Gallery title (left aligned)
            Text("Task Gallery")
                .tracking(-1)
                .font(AppFonts.poppinsMedium(size: 15))
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
                // Empty state: Black card in first grid position [content][empty][empty]
                LazyVGrid(columns: gridColumns, spacing: 4) {
                    // First column: Empty state card
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.white)
                        Text("Make your first\nreminder ~")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                    .cornerRadius(3)

                    // Second and third columns: Empty (invisible placeholders)
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
                .padding(.horizontal, 12)
            } else {
                ForEach(groupedEventsByDate, id: \.date) { dateGroup in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date header
                        HStack {
                            Text(formatDateHeader(dateGroup.date))
                                .tracking(-1)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(hex: "9f9f9f"))  // Dark grey
                            Spacer()
                        }
                        .padding(.horizontal, 12)

                        // Photo grid for this date
                        LazyVGrid(columns: gridColumns, spacing: 4) {
                            ForEach(dateGroup.events) { event in
                                // Render appropriate view based on event type
                                galleryEventView(for: event)
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
        print("🎨 [GalleryView] groupedEventsByDate computed")
        print("🎨 [GalleryView] filteredEvents.count = \(filteredEvents.count)")

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.createdAt)
        }

        let result = grouped.map { (date: $0.key, events: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }

        print("🎨 [GalleryView] groupedEventsByDate.count = \(result.count)")
        print("🎨 [GalleryView] groupedEventsByDate.isEmpty = \(result.isEmpty)")

        return result
    }
    
    // Filter events based on selected filter
    // PHASE 4: Read from AppState (single source of truth) instead of ViewModel
    private var filteredEvents: [GalleryHistoryEvent] {
        print("🎨 [GalleryView] filteredEvents computed")
        print("🎨 [GalleryView] appState.galleryEvents.count = \(appState.galleryEvents.count)")
        print("🎨 [GalleryView] selectedFilter = \(selectedFilter)")

        if !appState.galleryEvents.isEmpty {
            print("🎨 [GalleryView] Gallery events available:")
            for event in appState.galleryEvents {
                print("   - Event ID: \(event.id), Type: \(event.eventType), Created: \(event.createdAt)")
            }
        }

        switch selectedFilter {
        case .all:
            return appState.galleryEvents
        case .photos:
            return appState.galleryEvents.filter { $0.photoData != nil }
        case .sms:
            return appState.galleryEvents.filter { $0.hasTextResponse }
        case .profiles:
            return appState.galleryEvents.filter {
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