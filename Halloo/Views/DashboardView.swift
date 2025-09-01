import SwiftUI

/**
 * DASHBOARD VIEW - Main Home Screen for Elderly Care Coordination
 *
 * PURPOSE: This is the primary interface families use to coordinate elderly care.
 * Shows today's tasks for selected elderly family member, allows creating new habits,
 * and provides quick access to profile management.
 *
 * KEY BUSINESS LOGIC:
 * - Families can manage up to 4 elderly profiles
 * - Tasks are filtered by selected profile (not "show all")
 * - Only today's tasks are displayed (upcoming vs completed)
 * - Profile-specific task creation with preselected family member
 *
 * NAVIGATION: Custom pill-shaped bottom nav (home active, gallery inactive)
 * SHEETS: ProfileCreationView and TaskCreationView with proper ViewModel injection
 */
struct DashboardView: View {
    
    // MARK: - Environment & Dependencies
    /// Dependency injection container providing access to all app services
    /// (DatabaseService, AuthenticationService, NotificationService, etc.)
    @Environment(\.container) private var container
    
    /// Reactive data source for dashboard content (profiles, tasks, filtering logic)
    /// Uses @Published properties to automatically update UI when data changes
    @EnvironmentObject private var viewModel: DashboardViewModel
    
    /// Profile management for onboarding flow - shared across Dashboard and ProfileCreation
    /// Fixes ViewModel instance isolation by using same instance for profile creation
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    // MARK: - UI State Management
    /// Tracks which elderly profile is currently selected (0-3 max)
    /// IMPORTANT: This drives task filtering - only selected profile's tasks show
    @State private var selectedProfileIndex: Int = 0
    
    
    /// Controls TaskCreationView sheet presentation with profile preselection
    /// Triggered by + button in "Create Custom Habit" section
    @State private var showingTaskCreation = false
    
    /// Controls direct ProfileOnboardingFlow presentation
    /// Alternative to ProfileCreationView sheet for smoother UX
    @State private var showingDirectOnboarding = false
    
    var body: some View {
        /*
         * RESPONSIVE LAYOUT STRUCTURE:
         * GeometryReader provides actual screen dimensions for responsive design
         * Uses 5% screen padding and proportional sizing for different devices
         */
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                /*
                 * MAIN SCROLLABLE CONTENT AREA:
                 * Contains all dashboard sections in vertical flow
                 * Background: Light gray (#f9f9f9) for card contrast
                 */
                ScrollView {
                    VStack(spacing: 0) { // Removed .leading alignment for centered content
                        
                        // 🏠 HEADER: App branding + account access
                        headerSection
                        
                        // 👥 PROFILES: Elderly family member selection (max 4)
                        // CRITICAL: This drives all task filtering below
                        profilesSection
                        
                        // ✨ HABIT CREATION: Visual call-to-action with illustrations
                        // Opens TaskCreationView with selected profile preselected
                        createHabitSection
                        
                        // ⏰ UPCOMING: Today's pending tasks for selected profile only
                        // Shows tasks that still need to be completed today
                        upcomingSection
                        
                        // ✅ COMPLETED: Today's finished tasks with "view" buttons
                        // Allows viewing completion evidence (photos/SMS responses)
                        completedTasksSection
                        
                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04) // Match GalleryView (96% width)
                }
                .background(Color(hex: "f9f9f9")) // Light gray app background
                
                /*
                 * 🧭 CUSTOM BOTTOM NAVIGATION:
                 * Pill-shaped design with exact Figma dimensions (94×43.19px)
                 * Positioned 10px from right, 20px from bottom
                 * Home tab active (black), Gallery tab inactive (gray)
                 */
                bottomTabNavigation
            }
        }
        .ignoresSafeArea(.container, edges: .bottom) // Full-screen layout
        .onAppear {
            /*
             * DATA LOADING & PROFILE SELECTION:
             * Load dashboard data and auto-select first profile for task filtering
             */
            loadData()
        }
        /*
         * 📝 TASK CREATION SHEET:
         * Presents TaskCreationView when "Create Custom Habit" + button tapped
         * IMPORTANT: Preselects currently selected elderly profile for convenience
         * Injects TaskViewModel via container for proper dependency management
         */
        .sheet(isPresented: $showingTaskCreation) {
            TaskCreationView(preselectedProfileId: selectedProfile?.id)
                .environmentObject(container.makeTaskViewModel())
        }
        /*
         * 🚀 DIRECT PROFILE ONBOARDING:
         * Full-screen onboarding flow without double presentation
         * Uses shared ProfileViewModel to maintain state continuity
         */
        .fullScreenCover(isPresented: $showingDirectOnboarding) {
            ProfileOnboardingFlow()
                .environmentObject(profileViewModel) // Shared instance maintains state
        }
    }
    
    // MARK: - 🏠 Header Section
    /**
     * APP HEADER: Brand identity and account access
     * 
     * LAYOUT: Left-aligned logo, right-aligned profile button
     * TYPOGRAPHY: Custom Inter font with exact Figma specifications
     * PURPOSE: Establishes app identity and provides settings access
     */
    private var headerSection: some View {
        SharedHeaderSection()
    }
    
    // MARK: - 👥 Profiles Section
    /**
     * ELDERLY PROFILE SELECTION: The heart of the family care coordination
     * 
     * CRITICAL BUSINESS LOGIC:
     * - Maximum 4 elderly family members per family account
     * - NO horizontal scrolling (fixed layout prevents confusion)
     * - Profile selection drives ALL task filtering below
     * - Each profile gets consistent color (Blue→Red→Green→Purple)
     * 
     * VISUAL SYSTEM:
     * - Selected profile: Colored border (profile-specific color)
     * - Unselected profiles: Gray border
     * - Unconfirmed profiles: 50% opacity (waiting for SMS confirmation)
     * - Emoji placeholders: 6 diverse grandparent emojis for missing photos
     */
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            /*
             * SECTION HEADER: "PROFILES:" label
             * Matches other section headers for consistency
             * Gray color to de-emphasize (profiles themselves are the focus)
             */
            Text("PROFILES:")
                .tracking(-1)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            
            /*
             * PROFILE DISPLAY: Fixed 4-profile layout (NO scrolling)
             * This prevents UI confusion and enforces business rule of max 4 profiles
             */
            HStack(spacing: 20) {
                
                /*
                 * PROFILE IMAGES: Elderly family member circles
                 * Each profile displays photo or emoji placeholder
                 * Tap gesture updates selectedProfileIndex and triggers task filtering
                 */
                ForEach(Array(viewModel.profiles.enumerated()), id: \.offset) { index, profile in
                    ProfileImageView(
                        profile: profile,
                        profileSlot: index, // Ensures consistent color assignment
                        isSelected: selectedProfileIndex == index
                    )
                    .onTapGesture {
                        /*
                         * PROFILE SELECTION LOGIC:
                         * 1. Update local UI state (selectedProfileIndex)
                         * 2. Update ViewModel for task filtering
                         * 3. This triggers @Published property updates
                         * 4. UI automatically refreshes with filtered tasks
                         */
                        selectedProfileIndex = index
                        if index < viewModel.profiles.count {
                            viewModel.selectProfile(profileId: viewModel.profiles[index].id)
                        }
                    }
                }
                
                /*
                 * ADD PROFILE BUTTON: Only appears when < 4 profiles exist
                 * This enforces the business rule maximum and saves screen space
                 * Opens ProfileCreationView sheet when tapped
                 */
                if viewModel.profiles.count < 4 {
                    Button(action: {
                        // Direct onboarding launch (improved UX, no double presentation)
                        profileViewModel.startProfileOnboarding()
                        showingDirectOnboarding = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 45, height: 45)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "e0e0e0"), lineWidth: 2)
                                )
                            
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "5f5f5f"))
                        }
                    }
                }
                
                Spacer() // Left-aligns all profiles (no center alignment)
            }
            .padding(.horizontal, 12) // Matches header alignment
        }
        .padding(.bottom, 40) // Spacing before next section
    }
    
    // MARK: - ✨ Create Custom Habit Section
    /**
     * HABIT CREATION CALL-TO-ACTION: Visual prompt for task creation
     * 
     * PURPOSE: Encourages families to create new care tasks for elderly members
     * Combines delightful illustrations with functional button for engagement
     * 
     * BUSINESS LOGIC:
     * - Opens TaskCreationView with currently selected profile preselected
     * - This saves families from having to select the profile again
     * - White card design draws attention and provides clear action area
     * 
     * ILLUSTRATIONS:
     * - Birds: Centered, convey freedom and care
     * - Mascot: Right-aligned gentleman character (app personality)
     * - Assets: "Bird1", "Bird2", "Mascot" (case-sensitive names)
     */
    private var createHabitSection: some View {
        VStack(spacing: 0) {
            /*
             * WHITE CARD CONTAINER: Prominent visual emphasis
             * Contrasts with gray background to draw attention
             * Rounded corners (12px) for modern, friendly appearance
             */
            VStack(spacing: 20) {
                
                /*
                 * HEADER: Section title + action button
                 * Title uses same style as other sections for consistency
                 * Button is right-aligned for intuitive "add" interaction
                 */
                HStack {
                    Text("CREATE A CUSTOM HABIT")
                        .tracking(-1)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer() // Pushes button to right edge
                    
                    /*
                     * CREATE HABIT BUTTON: Opens TaskCreationView
                     * IMPORTANT: Preselects currently selected elderly profile
                     * This improves UX by reducing steps for families
                     */
                    Button(action: {
                        showingTaskCreation = true // Triggers sheet with profile preselection
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)  // Brighter add button
                                )
                            
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "5f5f5f"))
                        }
                    }
                }
                
                /*
                 * ILLUSTRATION LAYOUT: Birds center, Mascot right
                 * Creates visual interest and app personality
                 * Spacers ensure proper positioning across different screen sizes
                 */
                HStack {
                    Spacer() // Centers birds
                    
                    /*
                     * FLYING BIRDS: Two birds side by side
                     * Conveys themes of freedom, care, and gentle monitoring
                     * Mirrored and rotated for visual variety
                     */
                    HStack(spacing: 12) {
                        Image("Bird1")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 45.5, height: 36.4) // 1.3x bigger (35*1.3, 28*1.3)
                            .offset(y: -21) // Offset left bird higher than right
                        
                        Image("Bird1")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 45.5, height: 36.4) // 1.3x bigger
                            .scaleEffect(x: -1, y: 1) // Mirror horizontally
                            .rotationEffect(.degrees(15)) // Rotate 15° clockwise
                    }
                    
                    Spacer() // Balances layout
                    
                    /*
                     * MASCOT CHARACTER: App personality on right side
                     * Gentleman with top hat and briefcase represents reliable care
                     * Right alignment follows reading pattern and button placement above
                     */
                    Image("Mascot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120) // Prominent size for visual impact
                        .padding(.trailing, 20) // Prevents edge touch
                }
                .padding(.bottom, 10) // Spacing within card
            }
            .padding(.horizontal, 12) // Content padding within card
            .padding(.vertical, 24)
            .background(Color.white) // Prominent white background
            .cornerRadius(12) // Modern rounded appearance
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
        .padding(.bottom, 40) // Section spacing
    }
    
    // MARK: - ⏰ Upcoming Section
    /**
     * TODAY'S PENDING TASKS: What needs to be done today
     * 
     * CRITICAL FILTERING LOGIC:
     * - Only shows tasks for currently selected elderly profile
     * - Only shows today's tasks (not future days)
     * - Only shows pending tasks (not completed ones)
     * 
     * PURPOSE: Gives families clear visibility into what care tasks
     * are scheduled for today and still need completion
     * 
     * UI BEHAVIOR:
     * - No "view" buttons (tasks aren't completed yet)
     * - Each row shows profile photo, name, task title, and time
     * - Time format: 12-hour ("9AM", "2PM") for easy reading
     */
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            /*
             * TASK LIST: Profile-filtered, today-only pending tasks
             * Data source: viewModel.todaysUpcomingTasks (automatically filtered)
             * White card background for clarity and grouping
             */
            VStack(spacing: 0) {
                // Section title inside card
                HStack {
                    Text("UPCOMING")
                        .font(.custom("Inter", size: 15))
                        .fontWeight(.bold)
                        .tracking(-1)
                        .lineSpacing(33 - 15)
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Task rows
                ForEach(viewModel.todaysUpcomingTasks) { task in
                    TaskRowView(
                        task: task.task,
                        profile: task.profile,
                        showViewButton: false // No view button for pending tasks
                    )
                }
            }
            .background(Color.white) // Card background
            .cornerRadius(12) // Consistent rounded corners
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
        .padding(.bottom, 40) // Section spacing
    }
    
    // MARK: - ✅ Completed Tasks Section
    /**
     * TODAY'S FINISHED TASKS: What has been accomplished today
     * 
     * CRITICAL FILTERING LOGIC:
     * - Only shows tasks for currently selected elderly profile
     * - Only shows today's tasks (not previous days)
     * - Only shows completed tasks (with completion evidence)
     * 
     * PURPOSE: Provides families with reassurance that care tasks
     * have been completed and allows reviewing completion evidence
     * 
     * UI BEHAVIOR:
     * - Shows "view" buttons for reviewing completion details
     * - Buttons lead to photos/SMS responses from elderly person
     * - Same TaskRowView component as upcoming but with viewing enabled
     * 
     * COMPLETION EVIDENCE:
     * - Photos taken by elderly person showing task completion
     * - SMS responses confirming task completion
     * - Timestamp and location data (if available)
     */
    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            /*
             * COMPLETED TASK LIST: Profile-filtered, today-only completed tasks
             * Data source: viewModel.todaysCompletedTasks (automatically filtered)
             * 
             * KEY DIFFERENCE FROM UPCOMING:
             * - showViewButton: true enables reviewing completion evidence
             * - Families can see photos, SMS responses, timestamps
             * - Provides peace of mind that care tasks were actually completed
             */
            VStack(spacing: 0) {
                // Section title inside card
                HStack {
                    Text("COMPLETED TASKS")
                        .font(.custom("Inter", size: 15))
                        .fontWeight(.bold)
                        .tracking(-1)
                        .lineSpacing(33 - 15)
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Task rows
                ForEach(viewModel.todaysCompletedTasks) { task in
                    TaskRowView(
                        task: task.task,
                        profile: task.profile,
                        showViewButton: true // IMPORTANT: Enables viewing completion evidence
                    )
                }
            }
            .background(Color.white) // Card background for grouping
            .cornerRadius(12) // Consistent rounded appearance
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
        // No bottom padding - this is the last content section
    }
    
    // MARK: - 🧭 Bottom Tab Navigation
    /**
     * CUSTOM NAVIGATION DESIGN: Pill-shaped bottom navigation
     * 
     * DESIGN RATIONALE:
     * - Custom design instead of native TabView for exact Figma match
     * - Pill shape (94×43.19px) positioned precisely (10px right, 20px bottom)
     * - Only 2 visible tabs (home/gallery) for MVP simplicity
     * 
     * BUSINESS LOGIC:
     * - Home tab: Active state (black) - shows current screen (DashboardView)
     * - Gallery tab: Inactive state (gray) - links to photo archive
     * - Navigation logic handled by parent ContentView via TabView
     * 
     * VISUAL STATES:
     * - Active tab: Black icons/text
     * - Inactive tab: Gray icons/text
     * - White background with light gray border for definition
     * 
     * FUTURE EXPANSION:
     * - Hidden tabs ready (tags 2-5): Tasks, Profiles, Analytics, Settings
     * - Can be revealed by changing TabView visibility in ContentView
     */
    private var bottomTabNavigation: some View {
        HStack {
            Spacer() // Pushes navigation pill to right side
            
            /*
             * PILL-SHAPED NAVIGATION CONTAINER:
             * Exact dimensions from Figma specifications (94×43.19px)
             * Corner radius is exactly half the height for perfect pill shape
             */
            HStack(spacing: 20) {
                
                /*
                 * HOME TAB: Currently active (black)
                 * Icon: house.fill (filled to indicate active state)
                 * Text: "home" in small Inter font
                 * Color: Black indicates this is the current screen
                 */
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black) // Active state
                    
                    Text("home")
                        .font(.custom("Inter", size: 10))
                        .foregroundColor(.black) // Active state
                }
                
                /*
                 * GALLERY TAB: Inactive (gray)
                 * Icon: photo.on.rectangle (photo archive representation)
                 * Text: "gallery" in small Inter font
                 * Color: Gray indicates this is not the current screen
                 * Action: Navigation handled by parent ContentView TabView
                 */
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "9f9f9f")) // Inactive state
                    
                    Text("gallery")
                        .font(.custom("Inter", size: 10))
                        .foregroundColor(Color(hex: "9f9f9f")) // Inactive state
                }
            }
            /*
             * PILL CONTAINER STYLING:
             * - Exact width/height from questions.txt requirements
             * - Corner radius is half height for perfect pill shape
             * - White background with light border for definition
             * - Positioned exactly 10px from right, 20px from bottom
             */
            .frame(width: 94, height: 43.19) // Exact Figma dimensions
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 21.595) // Half of height = perfect pill
                    .stroke(Color(hex: "e0e0e0"), lineWidth: 1)
            )
            .padding(.trailing, 10) // 10px from right edge (Figma spec)
            .padding(.bottom, 20)   // 20px from bottom edge (Figma spec)
        }
    }
    
    // MARK: - 🔧 Helper Properties & Methods
    
    /**
     * SELECTED PROFILE ACCESSOR: Safe access to currently selected elderly profile
     * 
     * PURPOSE: Provides the ElderlyProfile object for the currently selected index
     * Used for preselecting profile in TaskCreationView and safety checks
     * 
     * SAFETY: Returns nil if selectedProfileIndex is out of bounds
     * This prevents crashes when profiles are loading or being modified
     */
    private var selectedProfile: ElderlyProfile? {
        guard selectedProfileIndex < viewModel.profiles.count else { return nil }
        return viewModel.profiles[selectedProfileIndex]
    }
    
    /**
     * DATA LOADING: Initialize dashboard data and set default profile selection
     * 
     * BUSINESS LOGIC:
     * 1. Load all dashboard data (profiles, tasks, etc.) from ViewModel
     * 2. Auto-select first profile (index 0) for immediate task filtering
     * 3. This ensures families see relevant tasks immediately upon app launch
     * 
     * CALLED: On view appearance (.onAppear)
     * TIMING: Critical to call selectProfile after profiles are loaded
     */
    private func loadData() {
        /*
         * Load dashboard data from ViewModel
         * This triggers network calls to fetch profiles, tasks, etc.
         */
        viewModel.loadDashboardData()
        
        /*
         * AUTO-SELECT FIRST PROFILE: UX improvement
         * Instead of showing empty task lists, immediately show first profile's tasks
         * This follows the principle of "sensible defaults" for better user experience
         */
        if !viewModel.profiles.isEmpty && selectedProfileIndex == 0 {
            viewModel.selectProfile(profileId: viewModel.profiles[0].id)
        }
    }
    
    /**
     * DEPRECATED: Task loading method no longer needed
     * 
     * LEGACY NOTE: This method previously handled manual task loading
     * Now handled automatically by profile tap gesture and ViewModel filtering
     * 
     * CURRENT APPROACH:
     * - Profile tap updates selectedProfileIndex
     * - Profile tap calls viewModel.selectProfile()
     * - ViewModel automatically filters @Published task properties
     * - UI updates reactively via @Published property changes
     */
    private func loadTasksForSelectedProfile() {
        // This method is now handled by profile tap gesture
        // ViewModel automatically filters tasks based on selectedProfileId
    }
}

// MARK: - Profile Image View Component
struct ProfileImageView: View {
    let profile: ElderlyProfile
    let profileSlot: Int // Position in profile array for consistent colors
    let isSelected: Bool
    
    // Fixed colors for profile slots 1,2,3,4
    private let profileColors: [Color] = [
        Color.blue.opacity(0.6),      // Profile slot 0 - brighter
        Color.red.opacity(0.6),       // Profile slot 1 - brighter
        Color.green.opacity(0.6),     // Profile slot 2 - brighter
        Color.purple.opacity(0.6)     // Profile slot 3 - brighter
    ]
    
    // Grandparent emojis with diverse skin tones
    private let profileEmojis: [String] = [
        "👴🏻", "👵🏻", "👴🏽", "👵🏽", "👴🏿", "👵🏿"
    ]
    
    private var borderColor: Color {
        if profile.status != .confirmed {
            // Grayed out for unconfirmed profiles
            return Color.gray.opacity(0.5)  // Slightly brighter for unconfirmed
        }
        
        let color = profileColors[profileSlot % profileColors.count]
        return isSelected ? color : Color(hex: "e0e0e0")
    }
    
    private var profileEmoji: String {
        // Consistent emoji based on profile slot + name hash for variety
        let emojiIndex = (profileSlot + abs(profile.name.hashValue)) % profileEmojis.count
        return profileEmojis[emojiIndex]
    }
    
    var body: some View {
        AsyncImage(url: URL(string: profile.photoURL ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // Placeholder with grandparent emoji
            ZStack {
                borderColor.opacity(0.2)  // Use profile color as background
                Text(profileEmoji)
                    .font(.system(size: 24))
            }
        }
        .frame(width: 45, height: 45)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: isSelected ? 2 : 0)  // No outline when unselected
        )
        .opacity(profile.status == .confirmed ? 1.0 : 0.5) // Gray out unconfirmed
    }
}

// MARK: - Task Row View Component
struct TaskRowView: View {
    let task: Task
    let profile: ElderlyProfile?
    let showViewButton: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image (smaller)
            AsyncImage(url: URL(string: profile?.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    // Use a light version based on profile ID hash
                    let colorIndex = abs((profile?.id ?? "").hashValue) % 4
                    let profileColor = [Color.blue, Color.red, Color.green, Color.purple][colorIndex]
                    profileColor.opacity(0.2)
                    Text(String(profile?.name.prefix(1) ?? "").uppercased())
                        .font(.custom("Inter", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            // Task Details
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.name ?? "")
                    .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                    .tracking(-0.25)  // Half of original -0.5 offset
                    .foregroundColor(.black)
                
                HStack(spacing: 4) {
                    Text(task.title)
                        .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                        .fontWeight(.regular)
                        .tracking(-0.5)  // Less tight tracking
                        .foregroundColor(.black)
                    
                    Text("•")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))
                    
                    Text(formatTime(task.scheduledTime))
                        .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                        .fontWeight(.regular)
                        .tracking(-0.5)  // Less tight tracking
                        .foregroundColor(.black)
                }
            }
            
            Spacer()
            
            // View Button (only for completed tasks)
            if showViewButton {
                Button(action: {
                    // View action (MVP - does nothing yet)
                }) {
                    Text("view")
                        .font(.custom("Inter", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "e8f3ff"))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 20)  // Increased by 4px more for better left spacing
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha" // This gives "5PM" or "8AM" format
        return formatter.string(from: date)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Views now in dedicated files
// ProfileCreationView -> ProfileViews.swift
// TaskCreationView -> TaskViews.swift

// MARK: - Preview Support
#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var
    previews: some View {
    
        
        Group {
            // SIMPLE FALLBACK PREVIEW (if comprehensive fails)
            VStack {
                Text("DashboardView Canvas Preview")
                    .font(.headline)
                Text("Canvas loading...")
                    .foregroundColor(.gray)
            }
            .previewDisplayName("📱 Simple Fallback")
            
            // COMPREHENSIVE DASHBOARD LAYOUT PREVIEW
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Header Section - Use shared header component
                        SharedHeaderSection()
                        
                        // Profiles Section  
                        PreviewProfilesSection()
                            .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                            .padding(.top, 8)
                        
                        // Create Custom Habit Section
                        PreviewCreateHabitSection(screenWidth: geometry.size.width)
                            .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                            .padding(.top, 20)
                        
                        // Upcoming Section
                        PreviewUpcomingSection()
                            .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                            .padding(.top, 20)
                        
                        // Completed Tasks Section
                        PreviewCompletedTasksSection()
                            .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                            .padding(.top, 20)
                        
                        // Bottom spacing for navigation
                        Spacer(minLength: 100)
                    }
                }
                .background(Color(hex: "f9f9f9"))
                .overlay(
                    // Bottom Navigation Overlay
                    PreviewBottomNavigation()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                )
            }
            .previewDisplayName("📱 Complete Dashboard Layout")
            
            // INDIVIDUAL SECTION PREVIEWS FOR EASY EDITING
            // Updated Header Section Preview - Uses shared component
            SharedHeaderSection()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("🏠 Header Section - UPDATED")
            
            PreviewProfilesSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("👥 Profiles Section")
            
            PreviewCreateHabitSection(screenWidth: 375)
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("✨ Create Habit Section")
            
            PreviewUpcomingSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("⏰ Upcoming Section")
            
            PreviewCompletedTasksSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("✅ Completed Tasks Section")
            
            PreviewBottomNavigation()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("🧭 Bottom Navigation")
        }
    }
}

// MARK: - Organized Preview Components

struct SharedHeaderSection: View {
    var body: some View {
        HStack(alignment: .center) {
            /*
             * MAIN LOGO: "halloo." brand text
             * Font: Inter Regular 37.5px with adjusted letter spacing (-3.1px)
             * Using custom period character for proper circular appearance
             */
            HStack(spacing: -2) { // Negative spacing to overlap slightly
                Text("halloo ")
                    .font(.custom("Inter", size: 37.5))
                    .fontWeight(.regular)
                    .tracking(-3.1) // Slightly reduced letter spacing for better readability
                    .lineSpacing(33 - 37.5)
                    .foregroundColor(.black)
                
                Text("•")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.black)
                    .offset(x: -5, y: 9) // Move closer to text and adjust vertical position
            }
            
            Spacer() // Pushes profile button to right edge
            
            /*
             * PROFILE SETTINGS BUTTON: Future account/settings access
             * Currently placeholder - will navigate to profile settings screen
             * Icon: SF Symbol person (outlined torso) for clean appearance
             */
            Button(action: {
                // TODO: Navigate to profile settings/account screen
                // This will handle user account management, not elderly profiles
            }) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        /*
         * HEADER PADDING: Generous spacing for prominence
         * Horizontal: 26px for alignment with profile cards below
         * Vertical: 20px top, 15px bottom for visual separation
         */
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// Removed unused duplicate header components - only SharedHeaderSection is used

struct PreviewProfilesSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockProfiles = [
        ("👴🏻", "Grandpa Joe", Color.blue.opacity(0.6), true),   // Show all outlines
        ("👵🏽", "Grandma Maria", Color.red.opacity(0.6), true),  // Show all outlines
        ("👴🏿", "Uncle Robert", Color.green.opacity(0.6), true)   // Show all outlines
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // White Card with Profiles - title inside card
            VStack(alignment: .leading, spacing: 12) {
                // Section Title inside the card
                Text("PROFILES:")
                    .tracking(-1)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
                
                // Profile circles
                HStack(spacing: 12) {
                    ForEach(Array(mockProfiles.enumerated()), id: \.offset) { index, profile in
                        ZStack {
                            profile.2.opacity(0.2)  // Use profile's color as background
                            Text(profile.0)
                                .font(.system(size: 20))
                        }
                        .frame(width: 44, height: 44) // ~44pt diameter
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(profile.2, lineWidth: profile.3 ? 2 : 2)  // All have 2px for preview
                        )
                    }
                    
                    // Add Profile Button - Figma specs
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "5f5f5f"))
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}

struct PreviewCreateHabitSection: View {
    let screenWidth: CGFloat
    
    var body: some View {
        ZStack {
            // White card background
            VStack(spacing: 0) {
                // Title at top of card
                HStack {
                    Text("CREATE A CUSTOM HABIT")
                        .tracking(-1)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12) // Closer to top
                
                Spacer()
            }
            .frame(width: screenWidth * 0.92) // 92% of screen width
            .frame(height: screenWidth * 0.314) // Proportional to 118px height
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
            
            // + Button positioned separately in middle-right
            HStack {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38) // Reduced by 1/4 (from 43 to 32)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)  // Brighter add button
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium)) // Reduced proportionally
                        .foregroundColor(Color(hex: "5f5f5f"))
                }
                .padding(.trailing, 25) // Moved right a bit
            }
            .frame(width: screenWidth * 0.92)
            .frame(height: screenWidth * 0.314)
            
            // Overlay illustrations on top
            HStack {
                Spacer()
                
                // Flying birds (center) - two Bird1 images with transformations
                HStack(spacing: 12) {
                    Image("Bird1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 45.5, height: 36.4) // 1.3x bigger (35*1.3, 28*1.3)
                        .offset(y: -21) //higher than right
                    
                    Image("Bird1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 45.5, height: 36.4) // 1.3x bigger
                        .scaleEffect(x: -1, y: 1) // Mirror horizontally
                        .rotationEffect(.degrees(15)) // Rotate 15° clockwise
                }
                .offset(y: 15) // Move birds down a bit
                
                Spacer()
                
                // Mascot (right side, extends below card but clipped)
                Image("Mascot")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: screenWidth * 0.43) // Taller than card
                    .offset(x: -50, y: screenWidth * 0.08) // Move left for button alignment, and down slightly more
                    .padding(.trailing, 20)
            }
            .frame(width: screenWidth * 0.92)
            .frame(height: screenWidth * 0.314)
            .clipped() // Clip mascot to card boundaries
        }
        .frame(height: screenWidth * 0.314) // Maintain card height
    }
}

struct PreviewUpcomingSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockTasks = [
        ("👴🏻", "Grandpa Joe", "Take Morning Medication", "9AM"),
        ("👴🏻", "Grandpa Joe", "Walk in Garden", "2PM"),
        ("👴🏻", "Grandpa Joe", "Call Family", "6PM")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // White Card with title inside
            VStack(alignment: .leading, spacing: 0) {
                // Section Title inside the card
                HStack {
                    Text("UPCOMING")
                        .tracking(-1)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Tasks list - seamless white
                ForEach(Array(mockTasks.enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 16) {
                        // Profile Image - 32pt diameter
                        ZStack {
                            // Consistent color mapping - Grandpa Joe always blue
                            let backgroundColor: Color = {
                                switch task.1 {
                                case "Grandpa Joe": return Color.blue
                                case "Grandma Maria": return Color.red  
                                case "Uncle Robert": return Color.green
                                default: return Color.purple
                                }
                            }()
                            backgroundColor.opacity(0.2)
                            Text(task.0)
                                .font(.system(size: 16))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        // Task Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.1)
                                .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                                .tracking(-0.25)  // Half of original -0.5 offset
                                .foregroundColor(.black)
                            
                            HStack(spacing: 4) {
                                Text(task.2)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from secondary to black
                                
                                Text("•")
                                    .font(.custom("Inter", size: 14))
                                    .foregroundColor(.secondary)  // Keep bullet gray
                                
                                Text(task.3)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from secondary to black
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)  // Increased by 4px more for better left spacing
                    .padding(.vertical, 12)
                    .background(Color.white) // Each task has white background
                    
                    if index < mockTasks.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, 32)  // Even shorter lines
                    }
                }
            }
            .background(Color.white) // Overall white card background
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}

struct PreviewCompletedTasksSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockCompletedTasks = [
        ("👴🏻", "Grandpa Joe", "Morning Exercise", "8AM"),
        ("👴🏻", "Grandpa Joe", "Breakfast", "8:30AM")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Tasks Card with title inside
            VStack(spacing: 0) {
                // Section Title - moved inside card
                HStack {
                    Text("COMPLETED TASKS")
                        .tracking(-1)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                ForEach(Array(mockCompletedTasks.enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 16) {
                        // Profile Image - 32pt diameter
                        ZStack {
                            // Consistent color mapping - Grandpa Joe always blue
                            let backgroundColor: Color = {
                                switch task.1 {
                                case "Grandpa Joe": return Color.blue
                                case "Grandma Maria": return Color.red  
                                case "Uncle Robert": return Color.green
                                default: return Color.purple
                                }
                            }()
                            backgroundColor.opacity(0.2)
                            Text(task.0)
                                .font(.system(size: 16))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        // Task Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.1)
                                .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                                .tracking(-0.25)  // Half of original -0.5 offset
                                .foregroundColor(.black)
                            
                            HStack(spacing: 4) {
                                Text(task.2)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from .secondary
                                
                                Text("•")
                                    .font(.custom("Inter", size: 14))
                                    .foregroundColor(.secondary)  // Match Upcoming
                                
                                Text(task.3)
                                    .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                                    .fontWeight(.regular)
                                    .foregroundColor(.black)  // Changed from .secondary
                            }
                        }
                        
                        Spacer()
                        
                        // View Button - solid blue with black text
                        Button(action: {}) {
                            Text("view")
                                .font(.custom("Inter", size: 13))
                                .fontWeight(.medium)
                                .foregroundColor(.black)  // Changed to black
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "B9E3FF"))  // Solid blue from Figma
                                .cornerRadius(8)
                        }
                        .frame(height: 28)
                    }
                    .padding(.horizontal, 20)  // Increased by 4px more for better left spacing
                    .padding(.vertical, 12)
                    
                    if index < mockCompletedTasks.count - 1 {
                        Divider()
                            .padding(.horizontal, 32)  // Even shorter lines
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}

struct PreviewBottomNavigation: View {
    var body: some View {
        // Pill-shaped navigation - exact specs
        HStack(spacing: 20) {
            // Home Tab (Active)
            VStack(spacing: 4) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                
                Text("home")
                    .font(.custom("Inter", size: 10))
                    .foregroundColor(.black)
            }
            
            // Gallery Tab (Inactive)
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                
                Text("gallery")
                    .font(.custom("Inter", size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 94, height: 43.19)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 21.595)
                .stroke(Color(hex: "e0e0e0"), lineWidth: 1)
        )
        .padding(.trailing, 10)
        .padding(.bottom, 20)
    }
}
#endif
