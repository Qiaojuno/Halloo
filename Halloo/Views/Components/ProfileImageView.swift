import SwiftUI

/// Unified Profile Image Component - ZERO DUPLICATES
/// 
/// This component consolidates ProfileImageView and ProfileImageViewLarge
/// into a single, reusable component with configurable sizing.
/// 
/// Usage:
/// - Small: ProfileImageView(profile: profile, profileSlot: 0, isSelected: true, size: .small)
/// - Large: ProfileImageView(profile: profile, profileSlot: 0, isSelected: false, size: .large)
/// - Custom: ProfileImageView(profile: profile, profileSlot: 0, isSelected: false, size: .custom(80))
struct ProfileImageView: View {
    // MARK: - Properties
    let profile: ElderlyProfile
    let profileSlot: Int // Position in profile array for consistent colors
    let isSelected: Bool
    let size: ProfileImageSize
    
    // MARK: - Size Configuration
    enum ProfileImageSize {
        case small      // 45x45 (original ProfileImageView)
        case large      // 60x60 (original ProfileImageViewLarge) 
        case custom(CGFloat)
        
        var dimension: CGFloat {
            switch self {
            case .small: return 45
            case .large: return 60
            case .custom(let size): return size
            }
        }
        
        var emojiSize: CGFloat {
            switch self {
            case .small: return 24
            case .large: return 32
            case .custom(let size): return size * 0.53 // ~24/45 ratio
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .small: return 2
            case .large: return 2.5
            case .custom(let size): return size > 50 ? 2.5 : 2
            }
        }
    }
    
    // MARK: - Profile Configuration
    // Fixed colors for profile slots 0,1,2,3,4
    private let profileColors: [Color] = [
        Color(hex: "B9E3FF"),         // Profile slot 0 - default light blue
        Color.red,                    // Profile slot 1 - red
        Color.green,                  // Profile slot 2 - green
        Color.purple,                 // Profile slot 3 - purple
        Color.orange                  // Profile slot 4 - orange (for 5+ profiles)
    ]
    
    // MARK: - Computed Properties
    private var hasProfilePhoto: Bool {
        // Check if profile has a valid photo URL
        guard let photoURL = profile.photoURL, !photoURL.isEmpty else {
            return false
        }
        return true
    }

    private var profileColor: Color {
        if profile.status != .confirmed {
            return Color.gray.opacity(0.5) // Grayed out for unconfirmed profiles
        }

        // Always return the profile's assigned color
        return profileColors[profileSlot % profileColors.count]
    }

    private var borderColor: Color {
        if profile.status != .confirmed {
            return Color.gray.opacity(0.5) // Grayed out for unconfirmed profiles
        }

        // Show profile color border only when selected, otherwise neutral gray
        return isSelected ? profileColor : Color(hex: "e0e0e0")
    }

    private var profileInitial: String {
        // First letter of name, uppercased
        return String(profile.name.prefix(1)).uppercased()
    }

    // MARK: - Environment
    @EnvironmentObject private var appState: AppState

    // MARK: - Body
    var body: some View {
        // Try to get cached image first (no flicker!)
        if let cachedUIImage = appState.imageCache.getCachedImage(for: profile.photoURL) {
            // Use cached image directly - synchronous, no placeholder
            Image(uiImage: cachedUIImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.dimension, height: size.dimension)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: isSelected ? size.borderWidth : 0)
                )
                .opacity(profile.status == .confirmed ? 1.0 : 0.5)
        } else {
            // Fallback to AsyncImage (first load or cache miss)
            AsyncImage(url: URL(string: profile.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                // Placeholder with initial letter (no emoji)
                ZStack {
                    profileColor // Always use profile color for background (full opacity)
                    Text(profileInitial)
                        .font(.system(size: size.emojiSize, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .frame(width: size.dimension, height: size.dimension)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: isSelected ? size.borderWidth : 0)
            )
            .opacity(profile.status == .confirmed ? 1.0 : 0.5) // Gray out unconfirmed
        }
    }
}

// MARK: - Convenience Initializers
extension ProfileImageView {
    /// Small profile image (45x45) - Default Dashboard size
    static func small(profile: ElderlyProfile, profileSlot: Int, isSelected: Bool) -> ProfileImageView {
        ProfileImageView(profile: profile, profileSlot: profileSlot, isSelected: isSelected, size: .small)
    }
    
    /// Large profile image (60x60) - Enhanced Dashboard size
    static func large(profile: ElderlyProfile, profileSlot: Int, isSelected: Bool) -> ProfileImageView {
        ProfileImageView(profile: profile, profileSlot: profileSlot, isSelected: isSelected, size: .large)
    }
    
    /// Custom size profile image
    static func custom(profile: ElderlyProfile, profileSlot: Int, isSelected: Bool, size: CGFloat) -> ProfileImageView {
        ProfileImageView(profile: profile, profileSlot: profileSlot, isSelected: isSelected, size: .custom(size))
    }
}

// MARK: - Preview
#Preview("Profile Image Sizes") {
    let mockProfile = ElderlyProfile(
        id: "preview-profile",
        userId: "preview-user", 
        name: "Grandma Smith",
        phoneNumber: "+1234567890",
        relationship: "Grandmother",
        isEmergencyContact: false,
        timeZone: TimeZone.current.identifier,
        notes: "Preview profile",
        photoURL: nil,
        status: .confirmed,
        createdAt: Date(),
        lastActiveAt: Date(),
        confirmedAt: Date()
    )
    
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            // Small size examples
            ProfileImageView.small(profile: mockProfile, profileSlot: 0, isSelected: true)
            ProfileImageView.small(profile: mockProfile, profileSlot: 1, isSelected: false)
            ProfileImageView.small(profile: mockProfile, profileSlot: 2, isSelected: false)
        }
        
        HStack(spacing: 15) {
            // Large size examples
            ProfileImageView.large(profile: mockProfile, profileSlot: 0, isSelected: true)
            ProfileImageView.large(profile: mockProfile, profileSlot: 1, isSelected: false) 
            ProfileImageView.large(profile: mockProfile, profileSlot: 2, isSelected: false)
        }
        
        HStack(spacing: 15) {
            // Custom size examples
            ProfileImageView.custom(profile: mockProfile, profileSlot: 0, isSelected: true, size: 80)
            ProfileImageView.custom(profile: mockProfile, profileSlot: 1, isSelected: false, size: 100)
        }
    }
    .padding()
    .background(Color(hex: "f9f9f9"))
}