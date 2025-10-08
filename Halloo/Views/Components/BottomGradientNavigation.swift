import SwiftUI

/**
 * BOTTOM GRADIENT NAVIGATION - Reusable floating navigation component
 *
 * PURPOSE: Provides consistent bottom navigation with black gradient fade
 * across all main views (Dashboard, Habits, Gallery)
 *
 * FEATURES:
 * - Black gradient fade from transparent to 25% opacity
 * - Floating pill navigation (left-aligned)
 * - Optional create button (only shown on Dashboard)
 * - Extends to very bottom of screen (ignores safe area)
 * - Non-interactive gradient (doesn't block touches)
 *
 * USAGE:
 * - Dashboard: BottomGradientNavigation(selectedTab: $tab, createButton: createHabitButton)
 * - Habits/Gallery: BottomGradientNavigation(selectedTab: $tab)
 */
struct BottomGradientNavigation<CreateButton: View>: View {

    // MARK: - Properties
    @Binding var selectedTab: Int
    let createButton: CreateButton?

    // MARK: - Initializers

    /// Full initializer with optional create button
    init(selectedTab: Binding<Int>, @ViewBuilder createButton: () -> CreateButton) {
        self._selectedTab = selectedTab
        self.createButton = createButton()
    }

    var body: some View {
        VStack {
            Spacer()

            // Black gradient at bottom
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120) // Gradient height
            .allowsHitTesting(false) // Don't block touches
            .overlay(
                VStack {
                    Spacer()
                    HStack(spacing: 0) { // No alignment needed - both elements same height
                        // Navigation pill (left-aligned)
                        FloatingPillNavigation(selectedTab: $selectedTab, onTabTapped: nil)
                            .padding(.leading, 30) // Fixed left padding

                        Spacer()

                        // Optional create button (right-aligned)
                        if let createButton = createButton {
                            createButton
                                .padding(.trailing, 30) // Fixed right padding
                        }
                    }
                    .padding(.bottom, 40) // Doubled from 20 to 40
                }
            )
        }
        .ignoresSafeArea(edges: .bottom) // Extend gradient to very bottom of screen
    }
}

// MARK: - Convenience Initializer Extension

extension BottomGradientNavigation where CreateButton == EmptyView {
    /// Convenience initializer for views without create button (Habits, Gallery)
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        self.createButton = nil
    }
}
