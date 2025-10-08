# 🧪 Test Data Injection Guide

## Overview
This guide shows you how to call `TestDataInjector.addTestHabits()` from different locations in your app.

---

## ✅ Option 1: From App Launch (Automatic on Startup)

**Best for:** One-time setup that runs automatically when you launch the app.

Add this to `/Halloo/Core/App.swift` in the `handleAppLaunch()` method:

```swift
private func handleAppLaunch() {
    print("📱 Hallo app launched")

    // Initialize critical services
    _Concurrency.Task {
        await initializeCriticalServices()

        // 🧪 DEBUG ONLY - Auto-inject test data on launch
        #if DEBUG
        await injectTestDataIfNeeded()
        #endif
    }
}

// Add this new method at the bottom of the HalloApp class
#if DEBUG
private func injectTestDataIfNeeded() async {
    let authService = container.resolve(AuthenticationServiceProtocol.self)
    let databaseService = container.resolve(DatabaseServiceProtocol.self)

    guard let user = try? await authService.getCurrentUser() else {
        print("❌ No user logged in - skipping test data injection")
        return
    }

    // Check if test data already exists
    let tasks = try? await databaseService.getTasksForUser(userId: user.id)
    if (tasks?.count ?? 0) > 0 {
        print("ℹ️ Tasks already exist - skipping test data injection")
        return
    }

    // Get first profile
    let profiles = try? await databaseService.getElderlyProfiles(for: user.id)
    guard let profileId = profiles?.first?.id else {
        print("❌ No profile found - skipping test data injection")
        return
    }

    print("🧪 Injecting test data...")
    let injector = TestDataInjector()
    try? await injector.addTestHabits(userId: user.id, profileId: profileId)
}
#endif
```

---

## ✅ Option 2: From DashboardView (Debug Button)

**Best for:** Manual trigger when you want to add test data.

Add this to `/Halloo/Views/DashboardView.swift` inside the `body` view:

```swift
var body: some View {
    GeometryReader { geometry in
        ZStack {
            ScrollView {
                VStack(spacing: 10) {

                    // 🧪 DEBUG ONLY - Test Data Button
                    #if DEBUG
                    debugTestDataButton
                    #endif

                    // ... rest of your existing code
                }
            }
        }
    }
}

// Add this computed property at the bottom of DashboardView
#if DEBUG
private var debugTestDataButton: some View {
    Button {
        Task {
            await addTestData()
        }
    } label: {
        HStack {
            Image(systemName: "flask.fill")
            Text("Add Test Habits")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.purple)
        .cornerRadius(8)
    }
    .padding(.horizontal, 26)
}

private func addTestData() async {
    let authService = container.resolve(AuthenticationServiceProtocol.self)

    guard let user = try? await authService.getCurrentUser() else {
        print("❌ No user logged in")
        return
    }

    guard let profileId = profileViewModel.profiles.first?.id else {
        print("❌ No profile found")
        return
    }

    let injector = TestDataInjector()
    do {
        try await injector.addTestHabits(userId: user.id, profileId: profileId)
        // Refresh the dashboard
        viewModel.loadDashboardData()
    } catch {
        print("❌ Error adding test data: \(error)")
    }
}
#endif
```

---

## ✅ Option 3: From Settings View (Future Location)

**Best for:** If you want a dedicated settings section for test data.

When you create a settings/debug view, add:

```swift
struct DebugSettingsView: View {
    @Environment(\.container) private var container
    @State private var isLoading = false
    @State private var statusMessage = ""

    var body: some View {
        List {
            Section("Test Data") {
                Button {
                    Task {
                        await injectTestData()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Add Test Habits")
                        Spacer()
                        Image(systemName: "flask.fill")
                    }
                }
                .disabled(isLoading)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func injectTestData() async {
        isLoading = true
        statusMessage = "Adding test data..."

        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let databaseService = container.resolve(DatabaseServiceProtocol.self)

        do {
            guard let user = try await authService.getCurrentUser() else {
                statusMessage = "❌ Not logged in"
                isLoading = false
                return
            }

            let profiles = try await databaseService.getElderlyProfiles(for: user.id)
            guard let profileId = profiles.first?.id else {
                statusMessage = "❌ No profile found"
                isLoading = false
                return
            }

            let injector = TestDataInjector()
            try await injector.addTestHabits(userId: user.id, profileId: profileId)

            statusMessage = "✅ Test data added successfully!"
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
```

---

## ✅ Option 4: From Xcode Breakpoint (No Code Changes)

**Best for:** One-time injection without modifying any code.

1. Set a breakpoint in `DashboardView.swift` in the `.onAppear` method
2. When breakpoint hits, open the LLDB console
3. Run these commands:

```lldb
expr -l Swift -- import Foundation
expr -l Swift -- import FirebaseFirestore
expr -l Swift -- let injector = TestDataInjector()
expr -l Swift -- Task { try await injector.addTestHabits(userId: "YOUR_USER_ID", profileId: "YOUR_PROFILE_ID") }
```

---

## ✅ Option 5: From ContentView (After Login)

**Best for:** Running right after successful login.

Add to `/Halloo/Views/ContentView.swift`:

```swift
.task {
    #if DEBUG
    await checkAndInjectTestData()
    #endif
}

#if DEBUG
private func checkAndInjectTestData() async {
    let authService = container.resolve(AuthenticationServiceProtocol.self)
    let databaseService = container.resolve(DatabaseServiceProtocol.self)

    guard let user = try? await authService.getCurrentUser() else {
        return
    }

    // Only inject if no tasks exist
    let tasks = try? await databaseService.getTasksForUser(userId: user.id)
    guard (tasks?.count ?? 0) == 0 else {
        return
    }

    let profiles = try? await databaseService.getElderlyProfiles(for: user.id)
    guard let profileId = profiles?.first?.id else {
        return
    }

    let injector = TestDataInjector()
    try? await injector.addTestHabits(userId: user.id, profileId: profileId)
}
#endif
```

---

## 🎯 Recommended Approach

**I recommend Option 2 (Debug Button in DashboardView)** because:
- ✅ Manual control (no automatic injection)
- ✅ Easy to trigger when needed
- ✅ Can see the button to know it's available
- ✅ Doesn't run on every app launch
- ✅ Only shows in DEBUG builds

---

## 📋 What Gets Added

When you call `TestDataInjector.addTestHabits()`, it creates:

1. **Completed Photo Habit** (2 hours ago)
   - Title: "Take medication with water"
   - Has photo response

2. **Completed Text Habit** (1 hour ago)
   - Title: "Drink water"
   - Has text response: "Done! Feeling refreshed 💧"

3. **Upcoming Habit** (in 3 hours)
   - Title: "Evening walk"
   - Not completed yet

4. **Late/Overdue Habit** (4 hours ago, past deadline)
   - Title: "Take vitamins"
   - Deadline was 3 hours ago

Plus 2 SMS responses for the completed habits.

---

## 🧹 Cleanup

To remove test data later, manually delete from Firebase Console:
1. Go to Firestore Database
2. Navigate to `users/{userId}/tasks`
3. Delete the test task documents
4. Navigate to `users/{userId}/smsResponses`
5. Delete the test response documents
