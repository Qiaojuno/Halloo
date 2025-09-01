import SwiftUI

struct GalleryView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.container) private var container
    @StateObject private var viewModel: GalleryViewModel
    
    // MARK: - State
    @State private var selectedFilter: GalleryFilter = .all
    @State private var showingPhotoDetail = false
    @State private var selectedPhoto: SMSResponse?
    @State private var showingFilterDropdown = false
    
    // MARK: - Initialization
    init() {
        // Initialize with placeholder - will be properly set in onAppear
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            databaseService: MockDatabaseService(),
            errorCoordinator: ErrorCoordinator()
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) { // Added spacing between header and card
                // Header with halloo logo and user profile
                headerSection
                
                // White card container (92% screen width)
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Gallery card header with title and filter button
                            galleryCardHeader
                                .background(Color.white)
                            
                            // Photo Grid extends naturally without bottom rounding
                            photoGridContent
                                .background(Color.white)
                        }
                        .cornerRadius(10, corners: [.topLeft, .topRight]) // Only round top corners
                        .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2) // Dark gray shadow
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // 92% screen width
                }
            }
            .background(Color(hex: "f9f9f9"))
            .navigationBarHidden(true)
        }
        .onAppear {
            initializeViewModel()
        }
        .sheet(isPresented: $showingPhotoDetail) {
            if let selectedPhoto = selectedPhoto {
                PhotoDetailView(response: selectedPhoto)
            }
        }
        .sheet(isPresented: $showingFilterDropdown) {
            FilterDropdownView(
                selectedFilter: $selectedFilter,
                isPresented: $showingFilterDropdown
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .center) {
            // MAIN LOGO: "halloo." brand text (same as DashboardView)
            HStack(spacing: -2) { // Negative spacing to overlap slightly
                Text("halloo ")
                    .font(.custom("Inter", size: 37.5))
                    .fontWeight(.regular)
                    .tracking(-3.1)
                    .foregroundColor(.black)
                
                Text("•")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.black)
                    .offset(x: -5, y: 9)
            }
            
            Spacer()
            
            // User profile icon (caregiver profile)
            Button(action: {}) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Gallery Card Header Section  
    private var galleryCardHeader: some View {
        HStack {
            // TASK GALLERY title (left aligned)
            Text("TASK GALLERY")
                .tracking(-1)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Filter button with hamburger icon (right aligned)
            Button(action: {
                showingFilterDropdown = true
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
    
    // MARK: - Photo Grid Content with Date Grouping
    private var photoGridContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(groupedPhotosByDate.keys.sorted(by: >), id: \.self) { date in
                VStack(alignment: .leading, spacing: 8) {
                    // Date header (iOS Photos style)
                    HStack {
                        Text(formatDateHeader(date))
                            .tracking(-1)
                            .font(.system(size: 15, weight: .regular))  // Removed .bold
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    
                    // Photo grid for this date
                    LazyVGrid(columns: gridColumns, spacing: 4) {
                        ForEach(groupedPhotosByDate[date] ?? []) { response in
                            SquarePhotoView(response: response)
                                .onTapGesture {
                                    selectedPhoto = response
                                    showingPhotoDetail = true
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
    
    private var filteredPhotos: [SMSResponse] {
        let allPhotos = viewModel.completedResponses
        
        switch selectedFilter {
        case .all:
            return allPhotos
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            return allPhotos.filter { $0.receivedAt >= weekAgo }
        case .byProfile:
            // TODO: Implement profile-specific filtering
            return allPhotos
        }
    }
    
    // Group photos by date (iOS Photos style)
    private var groupedPhotosByDate: [Date: [SMSResponse]] {
        let photos = filteredPhotos
        let calendar = Calendar.current
        
        return Dictionary(grouping: photos) { response in
            calendar.startOfDay(for: response.receivedAt)
        }
    }
    
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
            errorCoordinator: container.resolve(ErrorCoordinator.self)
        )
        
        // Load gallery data
        _Concurrency.Task {
            await viewModel.loadGalleryData()
        }
    }
}

// MARK: - Gallery Filter Enum
enum GalleryFilter: String, CaseIterable {
    case all = "All"
    case thisWeek = "This Week"
    case byProfile = "By Profile"
}

// MARK: - Filter Dropdown Component
struct FilterDropdownView: View {
    @Binding var selectedFilter: GalleryFilter
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ForEach(GalleryFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        isPresented = false
                    }) {
                        HStack {
                            Text(filter.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    if filter != GalleryFilter.allCases.last {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Filter Photos")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.3)])
    }
}

// MARK: - Square Photo Component (iOS Photos App Style)
struct SquarePhotoView: View {
    let response: SMSResponse
    
    var body: some View {
        ZStack {
            // Photo (square aspect ratio)
            AsyncImage(url: URL(string: response.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(hex: "f0f0f0"))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(Color(hex: "9f9f9f"))
                    )
            }
            .frame(width: 112, height: 112) // Square format based on Figma dimensions
            .clipped()
            .cornerRadius(3) // 3px radius from Figma
            
            // Profile avatar overlay (bottom-right corner)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ProfileAvatarOverlay(response: response)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Profile Avatar Overlay Component
struct ProfileAvatarOverlay: View {
    let response: SMSResponse
    
    var body: some View {
        ZStack {
            // Profile color background (no outline as specified)
            let backgroundColor: Color = {
                // Determine profile color based on profileId or name
                switch response.profileId ?? "unknown" {
                case _ where response.profileId?.contains("grandpa") == true: return Color.blue
                case _ where response.profileId?.contains("grandma") == true: return Color.red
                case _ where response.profileId?.contains("uncle") == true: return Color.green
                default: return Color.purple
                }
            }()
            
            Circle()
                .fill(backgroundColor.opacity(0.2)) // Pastel background
                .frame(width: 22, height: 22) // Figma dimensions
            
            // Profile emoji or initial
            Text("👴🏻") // TODO: This should be dynamic based on profile
                .font(.system(size: 12))
        }
        .cornerRadius(3) // 3px radius from Figma
    }
}

// MARK: - Photo Detail View (Placeholder)
struct PhotoDetailView: View {
    let response: SMSResponse
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // Full-size photo
                AsyncImage(url: URL(string: response.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(hex: "f0f0f0"))
                        .overlay(
                            ProgressView()
                        )
                }
                
                Spacer()
                
                // Response details
                VStack(alignment: .leading, spacing: 12) {
                    Text(response.taskTitle ?? "Task")
                        .font(.custom("Inter", size: 18))
                        .fontWeight(.semibold)
                    
                    Text("Completed: \(formatDateTime(response.receivedAt))")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))
                    
                    if let textContent = response.textContent, !textContent.isEmpty {
                        Text("Message: \"\(textContent)\"")
                            .font(.custom("Inter", size: 14))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Habit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Toggle favorite
                    }) {
                        Image(systemName: response.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Gallery ViewModel (Placeholder)
class GalleryViewModel: ObservableObject {
    @Published var completedResponses: [SMSResponse] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var databaseService: DatabaseServiceProtocol
    private var errorCoordinator: ErrorCoordinator
    
    init(databaseService: DatabaseServiceProtocol, errorCoordinator: ErrorCoordinator) {
        self.databaseService = databaseService
        self.errorCoordinator = errorCoordinator
    }
    
    func updateServices(databaseService: DatabaseServiceProtocol, errorCoordinator: ErrorCoordinator) {
        self.databaseService = databaseService
        self.errorCoordinator = errorCoordinator
    }
    
    @MainActor
    func loadGalleryData() async {
        isLoading = true
        
        do {
            // Load completed responses with photos
            let responses = try await databaseService.getCompletedResponsesWithPhotos()
            self.completedResponses = responses.sorted { $0.receivedAt > $1.receivedAt }
        } catch {
            errorCoordinator.handle(error, context: "Loading gallery photos")
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
        NavigationView {
            VStack(spacing: 16) { // Added spacing between header and card
                // Header with halloo logo and user profile (same as main view)
                PreviewHeaderSection()
                
                // White card container (92% screen width)
                GeometryReader { geometry in
                    ScrollView {
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
                    .padding(.horizontal, geometry.size.width * 0.04) // 92% screen width
                }
            }
            .background(Color(hex: "f9f9f9"))
            .navigationBarHidden(true)
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
struct PreviewHeaderSection: View {
    var body: some View {
        HStack(alignment: .center) {
            // MAIN LOGO: "halloo." brand text
            HStack(spacing: -2) {
                Text("halloo ")
                    .font(.custom("Inter", size: 37.5))
                    .fontWeight(.regular)
                    .tracking(-3.1)
                    .foregroundColor(.black)
                
                Text("•")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.black)
                    .offset(x: -5, y: 9)
            }
            
            Spacer()
            
            // User profile icon (caregiver profile)
            Button(action: {}) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

struct PreviewGalleryCardHeader: View {
    var body: some View {
        HStack {
            // TASK GALLERY title (left aligned)
            Text("TASK GALLERY")
                .tracking(-1)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
            
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
#endif
