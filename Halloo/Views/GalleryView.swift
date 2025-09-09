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
    
    // MARK: - Initialization
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        // Initialize with placeholder - will be properly set in onAppear
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            databaseService: MockDatabaseService(),
            errorCoordinator: ErrorCoordinator(),
            authService: MockAuthenticationService()
        ))
    }
    
    var body: some View {
        ZStack {
            // Match DashboardView structure exactly - no NavigationView wrapper
            ScrollView {
                VStack(spacing: 0) { // Match DashboardView spacing: 0 between sections
                    
                    // Header with Remi logo and user profile - using universal component
                    SharedHeaderSection()
                    
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
            
            // Floating navigation - true overlay that doesn't affect layout
            VStack {
                Spacer()
                FloatingPillNavigation(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            initializeViewModel()
            print("🔥 GalleryView onAppear - Gallery events: \(viewModel.galleryEvents.count)")
        }
        .fullScreenCover(item: $selectedEventForDetail) { event in
            GalleryDetailView(
                event: event, 
                selectedTab: $selectedTab,
                onPrevious: {
                    navigateToPrevious(from: event)
                },
                onNext: {
                    navigateToNext(from: event)
                }
            )
            .inject(container: container)
            .animation(.none, value: selectedEventForDetail) // Remove transition animation
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
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingFilterDropdown = false
                            }
                        }
                }
            }
        )
        .overlay(alignment: .topTrailing) {
            // Filter dropdown positioned relative to button
            if showingFilterDropdown {
                VStack(spacing: 0) {
                    // Spacer to position dropdown below the filter button
                    Spacer()
                        .frame(height: 140) // Approximate distance from top to filter button
                    
                    HStack {
                        Spacer()
                        
                        // Dropdown menu
                        FilterDropdownMenu(
                            selectedFilter: $selectedFilter,
                            isPresented: $showingFilterDropdown
                        )
                        .padding(.trailing, 16) // Match button position
                    }
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.2), value: showingFilterDropdown)
            }
        }
    }
    
    // MARK: - Header Section
    // Removed custom headerSection - now using universal SharedHeaderSection()
    
    // MARK: - Helper Functions
    
    private func findEvent(withId id: String) -> GalleryHistoryEvent? {
        // First try to find in grouped events (what's being displayed)
        for events in groupedEventsByDate.values {
            if let event = events.first(where: { $0.id == id }) {
                return event
            }
        }
        
        // Fallback to viewModel events
        return viewModel.galleryEvents.first(where: { $0.id == id })
    }
    
    // MARK: - Gallery Card Header Section  
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
                HStack(spacing: 12) { // Increased spacing for longer button
                    Text("Filter")
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
                .padding(.horizontal, 16)  // Increased horizontal padding for longer button
                .padding(.vertical, 8)
                .background(Color(hex: "f0f0f0"))  // Light grey rectangle
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)  // Increased top padding to lower the content
        .padding(.bottom, 20) // Increased bottom padding for more vertical space
    }
    
    // MARK: - Gallery Grid Content with Date Grouping (Mixed Content)
    private var photoGridContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(groupedEventsByDate.keys.sorted(by: >), id: \.self) { date in
                VStack(alignment: .leading, spacing: 8) {
                    // Date header (iOS Photos style)
                    HStack {
                        Text(formatDateHeader(date))
                            .tracking(-1)
                            .font(.system(size: 15, weight: .regular))  // Removed .bold
                            .foregroundColor(Color(hex: "9f9f9f"))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    
                    // Mixed gallery grid for this date
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(groupedEventsByDate[date] ?? []) { event in
                            GalleryItemView(event: event)
                                .onTapGesture {
                                    print("🔥 Gallery item tapped! Event ID: \(event.id)")
                                    print("🔥 Event type: \(event.eventType)")
                                    
                                    // Remove animation for seamless transition using transaction
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        selectedEventForDetail = event
                                    }
                                    print("🔥 selectedEventForDetail set to: \(event.id)")
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.bottom, 120) // Space for last photos + tab bar clearance
    }
    
    // MARK: - Helper Properties
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private var filteredEvents: [GalleryHistoryEvent] {
        let allEvents = viewModel.galleryEvents
        
        switch selectedFilter {
        case .all:
            return allEvents
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            return allEvents.filter { $0.createdAt >= weekAgo }
        case .byProfile:
            // TODO: Implement profile-specific filtering
            return allEvents
        }
    }
    
    // Group events by date (iOS Photos style)
    private var groupedEventsByDate: [Date: [GalleryHistoryEvent]] {
        let events = filteredEvents
        let calendar = Calendar.current
        
        return Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.createdAt)
        }
    }
    
    // Helper to convert GalleryHistoryEvent back to SMSResponse for existing detail view
    
    // Format date headers (August 1, 2025 style)
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Methods
    private func initializeViewModel() {
        // Initialize ViewModel with actual Container services
        viewModel.updateServices(
            databaseService: container.resolve(DatabaseServiceProtocol.self),
            errorCoordinator: container.resolve(ErrorCoordinator.self),
            authService: container.resolve(AuthenticationServiceProtocol.self)
        )
        
        // Load gallery data
        _Concurrency.Task {
            await viewModel.loadGalleryData()
        }
    }
    
    // MARK: - Navigation Methods
    private func navigateToPrevious(from currentEvent: GalleryHistoryEvent) {
        let sortedEvents = filteredEvents.sorted { $0.createdAt > $1.createdAt }
        guard let currentIndex = sortedEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex > 0 else { return }
        
        // Remove animation for seamless navigation using transaction
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedEventForDetail = sortedEvents[currentIndex - 1]
        }
    }
    
    private func navigateToNext(from currentEvent: GalleryHistoryEvent) {
        let sortedEvents = filteredEvents.sorted { $0.createdAt > $1.createdAt }
        guard let currentIndex = sortedEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex < sortedEvents.count - 1 else { return }
        
        // Remove animation for seamless navigation using transaction
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedEventForDetail = sortedEvents[currentIndex + 1]
        }
    }
}

// MARK: - Gallery Filter Enum
enum GalleryFilter: String, CaseIterable {
    case all = "All"
    case thisWeek = "This Week"
    case byProfile = "By Profile"
}

// MARK: - Clean Filter Dropdown Menu
struct FilterDropdownMenu: View {
    @Binding var selectedFilter: GalleryFilter
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(GalleryFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedFilter = filter
                        isPresented = false
                    }
                }) {
                    HStack {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                if filter != GalleryFilter.allCases.last {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 8, x: 0, y: 2)
        .frame(width: 120) // Compact width
    }
}

// MARK: - Unified Gallery Item View (Handles Both Photos and Profile Creation)
struct GalleryItemView: View {
    let event: GalleryHistoryEvent
    
    var body: some View {
        switch event.eventType {
        case .taskResponse:
            SquarePhotoView(event: event)
        case .profileCreated:
            ProfilePhotoView(event: event) // Show profile pictures like regular photos
        }
    }
}

// MARK: - Square Photo Component (Updated for GalleryHistoryEvent)
struct SquarePhotoView: View {
    let event: GalleryHistoryEvent
    
    // Profile emojis for consistency (same as ProfileGalleryItemView)
    private let profileEmojis = [
        "👴🏻", "👵🏻", "👨🏻", "👩🏻", "👴🏽", "👵🏽", 
        "👴🏿", "👵🏿", "🧓🏻", "🧓🏽", "🧓🏿"
    ]
    
    var body: some View {
        ZStack {
            // Check if this is a text-only response
            if event.photoData == nil && event.hasTextResponse {
                textResponsePreview
            } else {
                // Photo response (existing logic)
                if let photoData = event.photoData {
                    if let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 112, height: 112)
                            .clipped()
                            .cornerRadius(3)
                    } else {
                        photoPlaceholder
                    }
                } else {
                    photoPlaceholder
                }
                
                // Profile avatar overlay (bottom-right corner) - only for photos
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProfileAvatarOverlay(event: event)
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Text Response Preview (Mini Speech Bubbles with Tails)
    private var textResponsePreview: some View {
        ZStack {
            // Light blue background for consistency
            Rectangle()
                .fill(Color(hex: "E5F3FF")) // Light blue
                .frame(width: 112, height: 112)
                .cornerRadius(3)
            
            VStack(spacing: 12) {
                // Outgoing message indicator (mini blue bubble with tail)
                HStack {
                    Spacer()
                    MiniBubbleWithTail(isOutgoing: true)
                        .fill(Color(hex: "007AFF"))
                        .frame(width: 45, height: 20)
                }
                .padding(.horizontal, 12)
                
                // Incoming message indicator (mini gray bubble with tail)
                HStack {
                    MiniBubbleWithTail(isOutgoing: false)
                        .fill(Color(hex: "E5E5EA"))
                        .frame(width: 40, height: 20)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            // Profile picture overlay (bottom-right corner) like photo gallery
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ProfileAvatarOverlay(event: event)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    // MARK: - Profile Emoji Generation
    private var profileEmoji: String {
        // Generate consistent emoji based on profile slot + profile name hash
        let profileName = event.profileName
        let emojiIndex = (event.profileSlot + abs(profileName.hashValue)) % profileEmojis.count
        return profileEmojis[emojiIndex]
    }
    
    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color(hex: "f0f0f0"))
            .overlay(
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(Color(hex: "9f9f9f"))
            )
            .frame(width: 112, height: 112)
            .cornerRadius(3)
    }
}

// MARK: - Profile Photo Component (Matches Detailed View Style)
struct ProfilePhotoView: View {
    let event: GalleryHistoryEvent
    
    // Same emoji system as other components
    private let profileEmojis = [
        "👴🏻", "👵🏻", "👨🏻", "👩🏻", "👴🏽", "👵🏽", 
        "👴🏿", "👵🏿", "🧓🏻", "🧓🏽", "🧓🏿"
    ]
    
    var body: some View {
        // Show profile picture as full-size photo (like detailed view)
        Group {
            if let photoURL = event.photoURL, !photoURL.isEmpty {
                AsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 112, height: 112)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color(hex: "f0f0f0"))
                        .frame(width: 112, height: 112)
                        .overlay(
                            ProgressView()
                                .tint(Color(hex: "9f9f9f"))
                        )
                }
            } else {
                // Emoji fallback as full-size photo (like detailed view)
                Rectangle()
                    .fill(profileColor.opacity(0.2))
                    .frame(width: 112, height: 112)
                    .overlay(
                        Text(profileEmoji)
                            .font(.system(size: 40)) // Large emoji for gallery thumbnail
                    )
            }
        }
        .cornerRadius(3) // Match other gallery items
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
        let emojiIndex = (event.profileSlot + abs(event.profileName.hashValue)) % profileEmojis.count
        return profileEmojis[emojiIndex]
    }
}

// MARK: - Profile Avatar Overlay Component (Updated for GalleryHistoryEvent)
struct ProfileAvatarOverlay: View {
    let event: GalleryHistoryEvent
    
    // Use the same profile colors from DashboardView
    private let profileColors: [Color] = [
        Color(hex: "B9E3FF"),         // Profile slot 0 - default light blue
        Color.red.opacity(0.6),       // Profile slot 1 - brighter
        Color.green.opacity(0.6),     // Profile slot 2 - brighter
        Color.purple.opacity(0.6)     // Profile slot 3 - brighter
    ]
    
    var body: some View {
        ZStack {
            Circle()
                .fill(profileBackgroundColor)
                .frame(width: 22, height: 22) // Figma dimensions
            
            // Profile picture or circle placeholder (NO emoji)
            if let photoURL = event.photoURL {
                AsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(profileBackgroundColor.opacity(0.5))
                }
                .frame(width: 18, height: 18)
                .clipShape(Circle())
            } else {
                // Just a plain colored circle - no emoji
                Circle()
                    .fill(profileBackgroundColor.opacity(0.7))
                    .frame(width: 18, height: 18)
            }
        }
        .cornerRadius(3) // 3px radius from Figma
    }
    
    private var profileBackgroundColor: Color {
        let slot = event.profileSlot
        let color = profileColors[slot % profileColors.count]
        return color.opacity(0.3)
    }
}


// MARK: - Gallery ViewModel
class GalleryViewModel: ObservableObject {
    @Published var completedResponses: [SMSResponse] = []
    @Published var galleryEvents: [GalleryHistoryEvent] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var databaseService: DatabaseServiceProtocol
    private var errorCoordinator: ErrorCoordinator
    private var authService: AuthenticationServiceProtocol
    
    init(databaseService: DatabaseServiceProtocol, errorCoordinator: ErrorCoordinator, authService: AuthenticationServiceProtocol) {
        self.databaseService = databaseService
        self.errorCoordinator = errorCoordinator
        self.authService = authService
    }
    
    func updateServices(databaseService: DatabaseServiceProtocol, errorCoordinator: ErrorCoordinator, authService: AuthenticationServiceProtocol) {
        self.databaseService = databaseService
        self.errorCoordinator = errorCoordinator
        self.authService = authService
    }
    
    @MainActor
    func loadGalleryData() async {
        isLoading = true
        
        do {
            // Get user ID
            guard let userId = authService.currentUser?.uid else {
                throw DatabaseError.insufficientPermissions
            }
            
            // Load gallery events directly from database (includes all mock events)
            let events = try await databaseService.getGalleryHistoryEvents(for: userId)
            self.galleryEvents = events.sorted { $0.createdAt > $1.createdAt }
            
            // Also populate completedResponses for backward compatibility with detail view
            let responses = try await databaseService.getCompletedResponsesWithPhotos()
            self.completedResponses = responses.sorted { $0.receivedAt > $1.receivedAt }
            
        } catch {
            errorCoordinator.handle(error, context: "Loading gallery data")
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topRight), 
                         control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY), 
                         control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft), 
                         control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addQuadCurve(to: CGPoint(x: rect.minX + topLeft, y: rect.minY), 
                         control: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}

// MARK: - Preview Support
#if DEBUG
struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // SIMPLE FALLBACK PREVIEW
            VStack {
                Text("GalleryView Canvas Preview")
                    .font(.headline)
                Text("Canvas loading...")
                    .foregroundColor(.gray)
            }
            .previewDisplayName("📱 Simple Fallback")
            
            // COMPREHENSIVE GALLERY LAYOUT PREVIEW
            PreviewGalleryLayout()
                .previewDisplayName("📱 Complete Gallery Layout")
        }
    }
}

// MARK: - Preview Gallery Layout
struct PreviewGalleryLayout: View {
    // Mock data for Day 1 (3x2 = 6 photos) and Day 2 (3x3 = 9 photos)
    private let mockPhotosByDate: [(String, [MockPhoto])] = [
        ("August 25, 2025", [
            MockPhoto(id: "1", profileName: "Grandpa Joe", profileEmoji: "👴🏻", color: .blue),
            MockPhoto(id: "2", profileName: "Grandma Maria", profileEmoji: "👵🏽", color: .red),
            MockPhoto(id: "3", profileName: "Uncle Robert", profileEmoji: "👴🏿", color: .green),
            MockPhoto(id: "4", profileName: "Grandpa Joe", profileEmoji: "👴🏻", color: .blue),
            MockPhoto(id: "5", profileName: "Grandma Maria", profileEmoji: "👵🏽", color: .red),
            MockPhoto(id: "6", profileName: "Uncle Robert", profileEmoji: "👴🏿", color: .green)
        ]),
        ("August 24, 2025", [
            MockPhoto(id: "7", profileName: "Grandpa Joe", profileEmoji: "👴🏻", color: .blue),
            MockPhoto(id: "8", profileName: "Grandma Maria", profileEmoji: "👵🏽", color: .red),
            MockPhoto(id: "9", profileName: "Uncle Robert", profileEmoji: "👴🏿", color: .green),
            MockPhoto(id: "10", profileName: "Grandpa Joe", profileEmoji: "👴🏻", color: .blue),
            MockPhoto(id: "11", profileName: "Grandma Maria", profileEmoji: "👵🏽", color: .red),
            MockPhoto(id: "12", profileName: "Uncle Robert", profileEmoji: "👴🏿", color: .green),
            MockPhoto(id: "13", profileName: "Grandpa Joe", profileEmoji: "👴🏻", color: .blue),
            MockPhoto(id: "14", profileName: "Grandma Maria", profileEmoji: "👵🏽", color: .red),
            MockPhoto(id: "15", profileName: "Uncle Robert", profileEmoji: "👴🏿", color: .green)
        ])
    ]
    
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Match DashboardView structure exactly - no NavigationView wrapper
            ScrollView {
                VStack(spacing: 0) { // Match DashboardView spacing: 0 between sections
                    
                    // Header with Remi logo and user profile - using universal component
                    SharedHeaderSection()
                    
                    // Gallery card - match spacing ratio with DashboardView profiles
                    VStack(alignment: .leading, spacing: 16) {
                        // White card container (92% screen width) 
                        VStack(spacing: 0) {
                            // Gallery card header with title and filter button
                            PreviewGalleryCardHeader()
                                .background(Color.white)
                            
                            // Photo Grid extends naturally without bottom rounding
                            LazyVStack(spacing: 16) {
                                ForEach(mockPhotosByDate, id: \.0) { dateGroup in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Date header
                                        HStack {
                                            Text(dateGroup.0)
                                                .tracking(-1)
                                                .font(.system(size: 15, weight: .regular))  // Removed .bold
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        
                                        // Photo grid for this date
                                        LazyVGrid(columns: gridColumns, spacing: 4) {
                                            ForEach(dateGroup.1) { photo in
                                                PreviewSquarePhotoView(photo: photo)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                    }
                                }
                            }
                            .padding(.bottom, 120) // Space for last photos + tab bar clearance
                            .background(Color.white)
                        }
                        .cornerRadius(10, corners: [.topLeft, .topRight]) // Only round top corners
                        .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2) // Dark gray shadow
                    }
                    
                    // Bottom padding to prevent content from hiding behind navigation
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match DashboardView (96% width)
            }
            .background(Color(hex: "f9f9f9")) // Light gray app background
        }
    }
}

// MARK: - Mock Photo Data Structure
struct MockPhoto: Identifiable {
    let id: String
    let profileName: String
    let profileEmoji: String
    let color: Color
}

// MARK: - Preview Components
// Removed PreviewHeaderSection - now using universal SharedHeaderSection()

struct PreviewGalleryCardHeader: View {
    var body: some View {
        HStack {
            // TASK GALLERY title (left aligned)
            Text("TASK GALLERY")
                .tracking(-1)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "9f9f9f"))
            
            Spacer()
            
            // Filter button with hamburger icon (right aligned)
            Button(action: {}) {
                HStack(spacing: 12) {
                    Text("Filter")
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
}

struct PreviewSquarePhotoView: View {
    let photo: MockPhoto
    
    var body: some View {
        ZStack {
            // Photo placeholder (square format)
            Rectangle()
                .fill(Color(hex: "e8e8e8"))
                .overlay(
                    Image(systemName: "photo.fill")
                        .font(.title)
                        .foregroundColor(Color(hex: "b8b8b8"))
                )
                .frame(width: 112, height: 112) // Square format based on Figma dimensions
                .clipped()
                .cornerRadius(3) // 3px radius from Figma
            
            // Profile avatar overlay (bottom-right corner)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    PreviewProfileAvatarOverlay(photo: photo)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

struct PreviewProfileAvatarOverlay: View {
    let photo: MockPhoto
    
    var body: some View {
        ZStack {
            // Profile color background (no outline as specified)
            Circle()
                .fill(photo.color.opacity(0.2)) // Pastel background
                .frame(width: 22, height: 22) // Figma dimensions
            
            // Profile emoji
            Text(photo.profileEmoji)
                .font(.system(size: 12))
        }
        .cornerRadius(3) // 3px radius from Figma
    }
}

// MARK: - Mini Speech Bubble Shape (Gallery Thumbnails)
struct MiniBubbleWithTail: Shape {
    let isOutgoing: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let cornerRadius: CGFloat = 8  // Smaller corner radius for mini bubbles
        let tailSize: CGFloat = 10     // Bigger tail for better visibility
        let tailInset: CGFloat = 8     // Closer to edge for mini version
        
        // Create rounded rectangle body
        let bubbleRect = CGRect(x: 0, y: 0, width: width, height: height - 3) // Leave space for tail
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        if isOutgoing {
            // Left-pointing triangle for outgoing (positioned near right edge)
            let triangleStart = CGPoint(x: width - tailInset, y: height - 3)
            path.move(to: triangleStart)
            path.addLine(to: CGPoint(x: width - tailInset - tailSize, y: height - 3))
            path.addLine(to: CGPoint(x: width - tailInset, y: height))
            path.closeSubpath()
        } else {
            // Right-pointing triangle for incoming (positioned near left edge)
            let triangleStart = CGPoint(x: tailInset, y: height - 3)
            path.move(to: triangleStart)
            path.addLine(to: CGPoint(x: tailInset + tailSize, y: height - 3))
            path.addLine(to: CGPoint(x: tailInset, y: height))
            path.closeSubpath()
        }
        
        return path
    }
}
#endif
