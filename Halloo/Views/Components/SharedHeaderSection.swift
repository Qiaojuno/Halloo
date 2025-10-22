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

    // PHASE 3: Single source of truth for shared state
    @EnvironmentObject private var appState: AppState
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
                 * PHASE 3: Read from AppState (single source of truth)
                 */
                HStack(spacing: 8) {
                    ForEach(Array(appState.profiles.prefix(2).enumerated()), id: \.element.id) { index, profile in
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
        .fullScreenCover(isPresented: $showingAccountSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(profileViewModel)
        }
    }

}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    @State private var notificationsEnabled = true
    @State private var smsRemindersEnabled = true
    @State private var showingEditName = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var newDisplayName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            headerSection

            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    profileSection

                    // Notifications Section
                    notificationsSection

                    // Account Management Section
                    accountManagementSection

                    // About Section
                    aboutSection

                    // Sign Out Button
                    signOutButton
                }
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "f9f9f9"))
        .alert("Edit Display Name", isPresented: $showingEditName) {
            TextField("Display Name", text: $newDisplayName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                // TODO: Implement update display name
            }
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // TODO: Implement account deletion
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                performSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Spacer()
            HStack {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .light))
                    }
                    .foregroundColor(.gray)
                }

                Spacer()

                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)

                Spacer()

                // Invisible spacer for centering
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16, weight: .light))
                }
                .opacity(0)
            }
            .frame(width: 347)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color(hex: "f9f9f9"))
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 12) {
                settingsRow(
                    icon: "person.circle",
                    title: "Display Name",
                    subtitle: appState.currentUser?.displayName ?? "Not set",
                    showChevron: true
                ) {
                    newDisplayName = appState.currentUser?.displayName ?? ""
                    showingEditName = true
                }

                settingsRow(
                    icon: "envelope",
                    title: "Email",
                    subtitle: appState.currentUser?.email ?? "Not set",
                    showChevron: false
                ) {}
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "bell.fill",
                    title: "Push Notifications",
                    subtitle: "Receive app notifications",
                    isOn: $notificationsEnabled
                )

                Divider()
                    .padding(.leading, 52)

                settingsToggleRow(
                    icon: "message.fill",
                    title: "SMS Reminders",
                    subtitle: "Send SMS to family members",
                    isOn: $smsRemindersEnabled
                )
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Account Management Section
    private var accountManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 12) {
                settingsRow(
                    icon: "key",
                    title: "Change Password",
                    subtitle: nil,
                    showChevron: true
                ) {
                    // TODO: Implement change password
                }

                settingsRow(
                    icon: "trash",
                    title: "Delete Account",
                    subtitle: nil,
                    showChevron: true,
                    destructive: true
                ) {
                    showingDeleteAccountConfirmation = true
                }
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 12) {
                settingsRow(
                    icon: "info.circle",
                    title: "Version",
                    subtitle: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    showChevron: false
                ) {}

                settingsRow(
                    icon: "doc.text",
                    title: "Terms of Service",
                    subtitle: nil,
                    showChevron: true
                ) {
                    // TODO: Open terms of service
                }

                settingsRow(
                    icon: "hand.raised",
                    title: "Privacy Policy",
                    subtitle: nil,
                    showChevron: true
                ) {
                    // TODO: Open privacy policy
                }
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Sign Out Button
    private var signOutButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingSignOutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 18))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Views
    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String?,
        showChevron: Bool,
        destructive: Bool = false,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(destructive ? .red : .black)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(destructive ? .red : .black)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
        }
    }

    private func settingsToggleRow(
        icon: String,
        title: String,
        subtitle: String?,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(16)
    }

    // MARK: - Actions
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
