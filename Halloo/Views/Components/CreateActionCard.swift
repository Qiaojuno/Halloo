import SwiftUI

// MARK: - Create Action Card Component
/**
 * CREATE ACTION CARD: Custom white card popup for create actions
 *
 * PURPOSE: Replaces iOS confirmationDialog with custom design matching shadow card reference
 * DESIGN: White rounded card with shadow, slides up from bottom
 * OPTIONS: New Habit, New Profile with icons and descriptions
 *
 * USAGE:
 * ```swift
 * .overlay(
 *     CreateActionCard(
 *         isPresented: $showingCreateActionSheet,
 *         onCreateHabit: { showingTaskCreation = true },
 *         onCreateProfile: { showingDirectOnboarding = true }
 *     )
 * )
 * ```
 */
struct CreateActionCard: View {
    @Binding var isPresented: Bool
    let onCreateHabit: () -> Void
    let onCreateProfile: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background overlay (tap to dismiss)
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
            }

            // White card popup
            VStack {
                Spacer()

                if isPresented {
                    cardContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            Spacer() // Push card to bottom

            // Card options
            VStack(spacing: 0) {
                // New Habit Option
                CreateActionOption(
                    icon: "🏋️",
                    title: "New Habit",
                    description: "Create a new habit for your member"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                    // Delay action slightly to allow card to dismiss smoothly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onCreateHabit()
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color(hex: "f0f0f0"))
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                // New Profile Option
                CreateActionOption(
                    icon: "👴🏻",
                    title: "New Profile",
                    description: "Add another profile you want to monitor"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                    // Delay action slightly to allow card to dismiss smoothly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onCreateProfile()
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
            .padding(.horizontal, 16)
            .padding(.bottom, 90) // Position right above tab bar (70pt tab bar + 20pt spacing)
        }
    }
}

// MARK: - Create Action Option Row
/**
 * CREATE ACTION OPTION: Individual option in the create action card
 *
 * DESIGN: Icon circle + title + description in a tappable row
 */
struct CreateActionOption: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color(hex: "B9E3FF"))
                        .frame(width: 50, height: 50)

                    Text(icon)
                        .font(.system(size: 28))
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)

                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "7A7A7A"))
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(hex: "f9f9f9")
            .ignoresSafeArea()

        CreateActionCard(
            isPresented: .constant(true),
            onCreateHabit: { print("Create Habit") },
            onCreateProfile: { print("Create Profile") }
        )
    }
}
