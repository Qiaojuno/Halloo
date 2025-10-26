import SwiftUI

// MARK: - Standard Tab Bar Component
/**
 * STANDARD TAB BAR: iOS-style bottom navigation bar
 *
 * PURPOSE: Replaces custom pill navigation with professional standard tab bar
 * DESIGN: Matches iOS system tab bar appearance (white background, gray border)
 * TABS: Home, Gallery, Habits, Create
 *
 * USAGE:
 * ```swift
 * StandardTabBar(
 *     selectedTab: $selectedTab,
 *     isCreateExpanded: $isCreateExpanded,
 *     onCreateTapped: { showingCreateActionSheet = true }
 * )
 * ```
 */
struct StandardTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isCreateExpanded: Bool
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Super light grey line at top with opacity
            Rectangle()
                .fill(Color(hex: "f0f0f0").opacity(0.5))
                .frame(height: 1)

            HStack(spacing: 0) {
                // Home Tab
                TabBarItem(
                    icon: "house.fill",
                    title: "Home",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                    isCreateExpanded = false // Close create if switching tabs
                }

                // Gallery Tab
                TabBarItem(
                    icon: "photo.fill",
                    title: "Gallery",
                    isSelected: selectedTab == 1
                ) {
                    // Post notification for gallery tab tap (even if already selected)
                    NotificationCenter.default.post(name: .galleryTabTapped, object: nil)
                    selectedTab = 1
                    isCreateExpanded = false // Close create if switching tabs
                }

                // Habits Tab
                TabBarItem(
                    icon: "bookmark.fill",
                    title: "Habits",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                    isCreateExpanded = false // Close create if switching tabs
                }

                // Create Tab - Special toggle button
                CreateTabItem(isExpanded: $isCreateExpanded) {
                    isCreateExpanded.toggle()
                    if isCreateExpanded {
                        onCreateTapped()
                    }
                }
            }
            .frame(height: 70)
            .padding(.top, 0) // No top padding
            .background(Color.white) // White background behind the tabs
        }
        .background(Color.white) // White background extends to bottom
        .padding(.bottom, -20) // Move entire bar down 20pt
        .edgesIgnoringSafeArea(.bottom)
    }
}

// MARK: - Create Tab Item Component (Special Toggle)
/**
 * CREATE TAB ITEM: Special animated toggle button for create actions
 *
 * FEATURES:
 * - Animates from "+" to "×" when tapped
 * - Black circle background appears on expansion
 * - Text label disappears when expanded
 */
struct CreateTabItem: View {
    @Binding var isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Black circle background (animated) - spans from top of icons to bottom of text
                if isExpanded {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 50, height: 50) // Larger circle to encompass icon + text area
                        .scaleEffect(isExpanded ? 1.0 : 0.0) // Scale from 0 to 1
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                }

                VStack(spacing: 4) {  // Reduced from 6 to 4 to match other tabs
                    // Icon: "+" rotates to become "x"
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .light)) // Bigger (30pt) and thinner (.light)
                        .foregroundColor(isExpanded ? .white : Color(hex: "9f9f9f"))
                        .rotationEffect(.degrees(isExpanded ? 45 : 0)) // Rotate 45° clockwise
                        .offset(y: isExpanded ? 8 : 0) // Move down to center of circle when expanded
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)

                    // Text: disappears when expanded
                    if !isExpanded {
                        Text("Create")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "9f9f9f"))
                            .transition(.opacity)
                    } else {
                        // Invisible spacer to maintain layout when text is gone
                        Text("Create")
                            .font(.system(size: 11))
                            .opacity(0)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }
}

// MARK: - Tab Bar Item Component
/**
 * TAB BAR ITEM: Standard tab button with icon and label
 *
 * DESIGN:
 * - Black when selected, light gray (#9f9f9f) when unselected
 * - 26pt icons, 11pt text
 * - 4pt spacing between icon and text
 */
struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {  // Reduced from 6 to 4 for tighter spacing
                Image(systemName: icon)
                    .font(.system(size: 26))  // Increased from 24 to 26 for better visibility

                Text(title)
                    .font(.system(size: 11))  // Increased from 10 to 11 for readability
            }
            .foregroundColor(isSelected ? .black : Color(hex: "9f9f9f")) // Black when selected, light gray when not (matches pill navigation)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)  // Add vertical padding inside each tab
        }
    }
}

// MARK: - Preview
#Preview {
    StandardTabBar(
        selectedTab: .constant(0),
        isCreateExpanded: .constant(false),
        onCreateTapped: { print("Create tapped") }
    )
}
