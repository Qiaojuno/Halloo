import SwiftUI

/**
 * SHARED HEADER SECTION: Universal app header used across all main views
 * 
 * PURPOSE: Provides consistent navigation and branding across Dashboard, Habits, and Gallery views
 * Contains Remi logo, profile circles for elderly family member selection, and settings access
 * 
 * KEY FEATURES:
 * - Responsive Remi logo with Poppins Medium font
 * - Profile circles (45x45) positioned between logo and settings icon
 * - Profile selection updates both local state and ProfileViewModel
 * - Settings button placeholder for future account management
 * 
 * USAGE: Shared across Dashboard, Habits, and Gallery views
 */
struct SharedHeaderSection: View {
    // MARK: - Environment & State
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var selectedProfileIndex: Int
    
    // MARK: - Initialization
    init(selectedProfileIndex: Binding<Int>) {
        self._selectedProfileIndex = selectedProfileIndex
    }
    
    var body: some View {
        HStack(alignment: .center) {
            /*
             * MAIN LOGO: "Remi" brand text
             * Font: Poppins Medium to match ProfileViews, scaled up for header
             * Letter spacing adjusted for proper appearance at larger size
             */
            Text("Remi")
                .font(AppFonts.poppinsMedium(size: 37.5))
                .tracking(-3.1) // Scaled tracking from ProfileViews (-1.9 to -3.1 for larger size)
                .foregroundColor(.black)
            
            Spacer()
            
            /*
             * PROFILE CIRCLES: Elderly family member selection
             * Moved to shared header for consistency across all views
             * Size: 45x45 (standardized across app)
             */
            HStack(spacing: 8) {
                ForEach(Array(profileViewModel.profiles.enumerated()), id: \.offset) { index, profile in
                    ProfileImageView(
                        profile: profile,
                        profileSlot: index,
                        isSelected: selectedProfileIndex == index,
                        size: .custom(45)
                    )
                    .onTapGesture {
                        selectedProfileIndex = index
                        // Note: selectedProfileIndex is used for local UI filtering only
                        // ProfileViewModel doesn't need to track selection state
                    }
                }
            }
            
            Spacer()
            
            /*
             * PROFILE SETTINGS BUTTON: Future account/settings access
             * Currently placeholder - will navigate to profile settings screen
             * Icon: SF Symbol person (outlined torso) for clean appearance
             */
            Button(action: {
                // Haptic feedback for navigation bar button
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // TODO: Navigate to profile settings/account screen
                // This will handle user account management, not elderly profiles
            }) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        /*
         * HEADER PADDING: Match Dashboard content padding
         * Horizontal: 26px to match typical Dashboard spacing
         * Vertical: 20px top, 10px bottom for visual separation
         */
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}