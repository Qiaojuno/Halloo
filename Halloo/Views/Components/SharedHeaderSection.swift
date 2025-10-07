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
    @Environment(\.container) private var container
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var selectedProfileIndex: Int

    // MARK: - UI State
    @State private var showingAccountSettings = false   
    @State private var serviceType: String = ""

    // MARK: - Initialization
    init(selectedProfileIndex: Binding<Int>) {
        self._selectedProfileIndex = selectedProfileIndex
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // DEBUG: Show service type
            Text("DB: \(serviceType)")
                .font(.system(size: 10))
                .foregroundColor(.red)
                .padding(.horizontal, 26)
                .onAppear {
                    let dbService = container.resolve(DatabaseServiceProtocol.self)
                    serviceType = String(describing: type(of: dbService))
                }

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
            
            /*
             * PROFILE CIRCLES: Elderly family member selection
             * Positioned immediately after logo like original design
             * Max 2 profiles only, Size: 45x45 (standardized across app)
             */
            HStack(spacing: 8) {
                ForEach(Array(profileViewModel.profiles.prefix(2).enumerated()), id: \.element.id) { index, profile in
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
            .padding(.leading, 16) // Add space between logo and profiles
            
            Spacer()
            
            /*
             * PROFILE SETTINGS BUTTON: Account/settings access
             * Shows account settings sheet with logout option
             * Icon: SF Symbol person (outlined torso) for clean appearance
             */
            Button(action: {
                // Haptic feedback for navigation bar button
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                showingAccountSettings = true
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
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView()
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Account Settings View
struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container

    var body: some View {
        VStack(spacing: 20) {
            Text("Account Settings")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 20)

            Spacer()

            Button {
                performSignOut()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 18))
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    private func performSignOut() {
        _Concurrency.Task.detached {
            do {
                let authService = self.container.resolve(AuthenticationServiceProtocol.self)
                try await authService.signOut()
                await MainActor.run {
                    self.dismiss()
                }
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
}
