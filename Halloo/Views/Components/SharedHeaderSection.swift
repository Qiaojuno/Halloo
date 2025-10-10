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
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Binding var selectedProfileIndex: Int

    // MARK: - UI State
    @State private var showingAccountSettings = false

    // MARK: - Initialization
    init(selectedProfileIndex: Binding<Int>) {
        self._selectedProfileIndex = selectedProfileIndex
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 0) {
                /*
                 * MAIN LOGO: "Remi" brand text
                 * Font: Poppins Medium to match ProfileViews, scaled up for header
                 * Letter spacing adjusted for proper appearance at larger size
                 */
                Text("Remi")
                    .font(AppFonts.poppinsMedium(size: 37.5))
                    .tracking(-3.1) // Scaled tracking from ProfileViews (-1.9 to -3.1 for larger size)
                    .foregroundColor(.black)
                    .fixedSize() // Prevent text truncation/clipping
                    .layoutPriority(1) // Ensure logo gets full space before profile circles

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
                            // Update DashboardViewModel's selected profile to trigger task filtering
                            viewModel.selectProfile(profileId: profile.id)
                        }
                    }
                }
                .padding(.leading, 16) // Increased spacing from logo (was 8)
            
            Spacer()
            
            /*
             * 🧪 DEBUG TEST DATA BUTTON: Inject test habits (DEBUG ONLY)
             */
            #if DEBUG
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                _Concurrency.Task {
                    await injectTestData()
                }
            }) {
                Image(systemName: "flask.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
            }
            #endif

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

    // MARK: - Debug Test Data Injection
    #if DEBUG
    private func injectTestData() async {
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let databaseService = container.resolve(DatabaseServiceProtocol.self)

        do {
            // Get current user from AuthService
            guard let currentUser = authService.currentUser else {
                print("❌ No user logged in")
                return
            }

            let profiles = try await databaseService.getElderlyProfiles(for: currentUser.uid)
            guard let profileId = profiles.first?.id else {
                print("❌ No profile found for this user")
                return
            }

            print("🧪 Injecting test data for user: \(currentUser.uid), profile: \(profileId)")

            let injector = TestDataInjector()
            try await injector.addTestHabits(userId: currentUser.uid, profileId: profileId)

            print("✅ Test data injection complete! Refresh the app to see changes.")

            // Trigger haptic success feedback
            await MainActor.run {
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
            }

        } catch {
            print("❌ Error injecting test data: \(error.localizedDescription)")

            // Trigger haptic error feedback
            await MainActor.run {
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    #endif
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
