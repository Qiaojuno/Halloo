---
name: Accessibility Checker for Elderly Care
description: Ensure all SwiftUI views meet iOS accessibility standards for the Halloo elderly care app. Use when creating or reviewing views, especially those involving elderly users, task displays, photo galleries, or critical workflows like medication reminders.
version: 1.0.0
---

# Accessibility Checker for Halloo

This skill ensures the Halloo app is accessible to elderly users and their family members, many of whom may have visual, motor, or cognitive challenges.

## Why Accessibility is Critical for Halloo

**Context:** Halloo is an elderly care coordination app where:
- **Elderly users** interact via SMS (need clear messages)
- **Family caregivers** (often 50+) use the iOS app daily
- **Time-sensitive tasks** like medication reminders require easy interaction
- **Photo responses** need to be viewable by users with vision challenges
- **Complex workflows** must be navigable by users of varying tech literacy

**Legal:** Apps in healthcare/elderly care must meet WCAG 2.1 Level AA standards.

---

## Core Accessibility Requirements

### 1. Minimum Text Sizes (Critical for Elderly Users)

**Rule:** All text must be readable by users with mild vision impairment.

```swift
// ❌ WRONG - Hardcoded small text
Text("Take medication")
    .font(.system(size: 12))  // Too small for elderly users

// ✅ CORRECT - Dynamic Type with minimum safe size
Text("Take medication")
    .font(.system(size: 17, weight: .regular))  // Minimum 17pt for body text
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // Cap at xxxLarge for layout stability
```

**Halloo Text Size Standards:**
- **Task titles**: Minimum 17pt (body text)
- **Task descriptions**: Minimum 15pt
- **Button labels**: Minimum 16pt (semibold)
- **Profile names**: Minimum 15pt
- **Headers**: Minimum 20pt
- **Navigation labels**: Minimum 14pt (absolute minimum)

**Supporting Dynamic Type:**
```swift
// ✅ CORRECT - Scales with user preferences
Text("Morning medication")
    .font(.body)  // Uses system body style, scales automatically

// ✅ CORRECT - Custom font with scaling
Text("Grandma's Tasks")
    .font(.system(size: 20, weight: .semibold))
    .dynamicTypeSize(.medium...DynamicTypeSize.xxxLarge)
```

---

### 2. Color Contrast (WCAG AA Standard)

**Rule:** Text must have 4.5:1 contrast ratio minimum, 7:1 for AAA (preferred for elderly).

**Halloo's Color System:**
```swift
// Current colors from App-Structure.md
let backgroundColor = Color(hex: "f9f9f9")  // Near white
let textPrimary = Color.black  // #000000
let textSecondary = Color(hex: "7A7A7A")  // Gray
let buttonPrimary = Color(hex: "B9E3FF")  // Light blue

// ✅ High Contrast Checks
// Black on white: 21:1 ✅ Excellent
// Black on #f9f9f9: 20:1 ✅ Excellent
// #7A7A7A on #f9f9f9: 3.9:1 ❌ FAILS AA (below 4.5:1)
```

**Fix for Secondary Text:**
```swift
// ❌ WRONG - Insufficient contrast
Text("Last completed 2 hours ago")
    .foregroundColor(Color(hex: "7A7A7A"))  // 3.9:1 contrast
    .font(.caption)

// ✅ CORRECT - Darker gray for better contrast
Text("Last completed 2 hours ago")
    .foregroundColor(Color(hex: "666666"))  // 5.7:1 contrast ✅
    .font(.caption)

// ✅ BEST - Use system colors that adapt
Text("Last completed 2 hours ago")
    .foregroundColor(.secondary)  // System adapts to dark mode
    .font(.caption)
```

**Button Contrast:**
```swift
// ❌ WRONG - Light text on light blue
Button("Send Reminder") { }
    .foregroundColor(.white)
    .background(Color(hex: "B9E3FF"))  // Insufficient contrast

// ✅ CORRECT - Dark text on light background
Button("Send Reminder") { }
    .foregroundColor(.black)
    .background(Color(hex: "B9E3FF"))
```

---

### 3. Touch Targets (Critical for Motor Impairment)

**Rule:** Minimum 44×44 points for all interactive elements (Apple HIG).

**Halloo Components:**

```swift
// ✅ Profile circles in SharedHeaderSection
// Current: 44pt circles - GOOD ✅

// ✅ Bottom navigation pill
// Current: 94×43pt - GOOD (height meets minimum)

// ⚠️ Check CardStackView swipe targets
struct CardStackView: View {
    var body: some View {
        // Ensure cards have adequate hit area
        VStack {
            // Card content
        }
        .frame(minWidth: 300, minHeight: 200)  // ✅ Large enough
        .contentShape(Rectangle())  // ✅ Makes entire area tappable
    }
}

// ❌ WRONG - Small button
Button(action: { }) {
    Image(systemName: "plus")
        .frame(width: 30, height: 30)  // Too small!
}

// ✅ CORRECT - Adequate touch target
Button(action: { }) {
    Image(systemName: "plus")
        .frame(width: 44, height: 44)  // Minimum size
        .contentShape(Rectangle())  // Entire frame is tappable
}
```

**Spacing for Accidental Taps:**
```swift
// ✅ Adequate spacing between profile circles
HStack(spacing: 12) {  // Good spacing to prevent mis-taps
    ForEach(profiles.prefix(4), id: \.id) { profile in
        ProfileImageView(profile: profile)
            .frame(width: 44, height: 44)
    }
}
```

---

### 4. VoiceOver Support (Screen Reader)

**Rule:** All interactive elements must have descriptive labels and hints.

**Profile Images:**
```swift
// ❌ WRONG - No VoiceOver label
Image("Mascot")
    .resizable()
    .frame(width: 100, height: 100)

// ✅ CORRECT - Descriptive label
Image("Mascot")
    .resizable()
    .frame(width: 100, height: 100)
    .accessibilityLabel("Halloo mascot character")
    .accessibilityHidden(true)  // Decorative only, hide from VoiceOver

// ✅ Profile photo with context
ProfileImageView(profile: profile)
    .accessibilityLabel("\(profile.name)'s profile photo")
    .accessibilityAddTraits(.isButton)  // If tappable
    .accessibilityHint("Double tap to view \(profile.name)'s details")
```

**Task Cards:**
```swift
// ✅ Rich accessibility for task rows
TaskRowView(task: task, profile: profile)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(task.title) for \(profile.name)")
    .accessibilityValue(task.isCompleted ? "Completed" : "Pending")
    .accessibilityHint("Double tap to view task details")
```

**Buttons:**
```swift
// ❌ WRONG - Generic label
Button(action: sendReminder) {
    Image(systemName: "bell.fill")
}
.accessibilityLabel("Send")  // Too vague

// ✅ CORRECT - Descriptive and contextual
Button(action: sendReminder) {
    Image(systemName: "bell.fill")
}
.accessibilityLabel("Send medication reminder to \(profile.name)")
.accessibilityHint("Sends an SMS reminder immediately")
```

**Navigation Tabs:**
```swift
// ✅ Clear tab labels
TabView(selection: $selectedTab) {
    DashboardView()
        .tabItem {
            Label("Dashboard", systemImage: "house.fill")
        }
        .accessibilityLabel("Dashboard")
        .accessibilityHint("View today's tasks and responses")

    GalleryView()
        .tabItem {
            Label("Gallery", systemImage: "photo.fill")
        }
        .accessibilityLabel("Photo Gallery")
        .accessibilityHint("View all photo responses from your loved ones")

    HabitsView()
        .tabItem {
            Label("Habits", systemImage: "list.bullet")
        }
        .accessibilityLabel("All Habits")
        .accessibilityHint("Manage scheduled tasks and reminders")
}
```

---

### 5. Grouped Elements (Reduce VoiceOver Noise)

**Rule:** Group related elements to reduce VoiceOver verbosity.

```swift
// ❌ WRONG - Each element read separately
HStack {
    Text("Task:")
    Text(task.title)
    Text("Due:")
    Text(task.scheduledTime, style: .time)
}

// ✅ CORRECT - Combined into single announcement
HStack {
    Text("Task:")
    Text(task.title)
    Text("Due:")
    Text(task.scheduledTime, style: .time)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Task: \(task.title), Due: \(task.scheduledTime.formatted(date: .omitted, time: .shortened))")

// ✅ SharedHeaderSection example
SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Select profile: \(profiles[selectedProfileIndex].name)")
    .accessibilityHint("Swipe up or down to change profiles")
```

---

### 6. Images and Photos (Critical for Gallery)

**Rule:** All meaningful images need descriptions, decorative images should be hidden.

**Gallery Photos:**
```swift
// ✅ CORRECT - Contextual photo description
AsyncImage(url: URL(string: galleryEvent.photoURL)) { image in
    image
        .resizable()
        .scaledToFit()
        .accessibilityLabel("Photo response from \(profile.name) for \(task.title)")
        .accessibilityHint("Double tap to view full screen")
} placeholder: {
    ProgressView()
        .accessibilityLabel("Loading photo")
}

// ✅ Task response photo
Image(uiImage: responsePhoto)
    .resizable()
    .scaledToFit()
    .accessibilityLabel("\(profile.name)'s photo showing \(task.title) completed")
    .accessibilityAddTraits(.isImage)
```

**Decorative Images:**
```swift
// ✅ Mascot illustrations are decorative
Image("Mascot")
    .accessibilityHidden(true)  // Don't announce to VoiceOver

Image("Bird1")
    .accessibilityHidden(true)

// Exception: If mascot provides context
Image("Mascotcooking")
    .accessibilityLabel("Cooking illustration")  // Relevant to cooking task
```

---

### 7. Form Inputs (Profile & Task Creation)

**Rule:** All text fields need labels and validation feedback.

**Profile Creation Form:**
```swift
// ✅ CORRECT - Accessible form
VStack(alignment: .leading, spacing: 20) {
    // Name field
    VStack(alignment: .leading, spacing: 8) {
        Text("Name")
            .font(.headline)
        TextField("Enter name", text: $name)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Profile name")
            .accessibilityHint("Enter your loved one's name")
    }

    // Phone number field with validation
    VStack(alignment: .leading, spacing: 8) {
        Text("Phone Number")
            .font(.headline)
        TextField("+1 555 123 4567", text: $phoneNumber)
            .keyboardType(.phonePad)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Phone number")
            .accessibilityHint("Enter phone number with country code")

        if !phoneNumber.isEmpty && !phoneNumber.isValidE164PhoneNumber {
            Text("Phone number must be in format: +1 XXX XXX XXXX")
                .foregroundColor(.red)
                .font(.caption)
                .accessibilityLabel("Error: Invalid phone number format")
        }
    }

    // Relationship field
    VStack(alignment: .leading, spacing: 8) {
        Text("Relationship")
            .font(.headline)
        TextField("e.g., Grandmother", text: $relationship)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Your relationship")
            .accessibilityHint("For example, grandmother, father, friend")
    }
}
.accessibilityElement(children: .contain)  // Keep field structure
```

**Task Time Picker:**
```swift
// ✅ Accessible time selection
DatePicker("Reminder Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
    .accessibilityLabel("Select reminder time")
    .accessibilityHint("Choose when to send the daily reminder")
    .accessibilityValue(scheduledTime.formatted(date: .omitted, time: .shortened))
```

---

### 8. Error Messages (Critical for Elderly Users)

**Rule:** Errors must be clearly announced and easy to understand.

```swift
// ❌ WRONG - Vague error
if showError {
    Text("Error")
        .foregroundColor(.red)
}

// ✅ CORRECT - Clear, actionable error
if let errorMessage = viewModel.errorMessage {
    HStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
        Text(errorMessage)
            .foregroundColor(.red)
            .font(.body)
    }
    .padding()
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Error: \(errorMessage)")
    .accessibilityAddTraits(.isStaticText)
}

// ✅ Field-specific validation
if !phoneNumber.isValidE164PhoneNumber && !phoneNumber.isEmpty {
    Label {
        Text("Phone number must start with + and country code")
            .font(.caption)
    } icon: {
        Image(systemName: "exclamationmark.circle.fill")
    }
    .foregroundColor(.red)
    .accessibilityLabel("Invalid phone number. Must start with plus sign and country code")
}
```

---

### 9. Loading States (Don't Leave Users Guessing)

**Rule:** Always provide feedback during async operations.

```swift
// ❌ WRONG - Silent loading
Button("Create Profile") {
    viewModel.createProfile(profile)
}

// ✅ CORRECT - Clear loading state
Button("Create Profile") {
    viewModel.createProfile(profile)
}
.disabled(viewModel.isLoading)
.overlay {
    if viewModel.isLoading {
        ProgressView()
            .accessibilityLabel("Creating profile")
    }
}

// ✅ Full screen loading with context
if appState.isLoading {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your tasks...")
                .font(.body)
        }
        .padding(32)
        .background(Color.white)
        .cornerRadius(16)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading tasks, please wait")
}
```

---

### 10. Swipe Gestures (Provide Alternatives)

**Rule:** Never require swipe gestures without alternative navigation.

**CardStackView Accessibility:**
```swift
// ✅ Swipe cards with button alternatives
struct CardStackView: View {
    @State private var isVoiceOverRunning = false

    var body: some View {
        VStack {
            // Card content with swipe gesture
            ForEach(tasks) { task in
                TaskCard(task: task)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if !isVoiceOverRunning {
                                    handleSwipe(value)
                                }
                            }
                    )
            }

            // Alternative buttons for VoiceOver users
            if isVoiceOverRunning {
                HStack(spacing: 20) {
                    Button("Request Clarification") {
                        handleSwipeLeft()
                    }
                    .accessibilityHint("Ask for more details about this task")

                    Button("Approve Response") {
                        handleSwipeRight()
                    }
                    .accessibilityHint("Mark this task as completed")
                }
                .padding()
            }
        }
        .onAppear {
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
    }
}
```

**Tab Navigation Alternative:**
```swift
// ✅ Tab swipe with alternative
.gesture(
    DragGesture()
        .onEnded { value in
            if !UIAccessibility.isVoiceOverRunning {
                handleTabSwipe(value)
            }
        }
)
// VoiceOver users use standard tab navigation automatically
```

---

## Halloo-Specific Accessibility Patterns

### SMS Message Clarity (for Elderly Recipients)

**Context:** Your elderly users receive SMS messages. These must be crystal clear.

**SMS Message Templates:**
```swift
// ❌ WRONG - Confusing, no context
"Task due. Reply YES or NO."

// ✅ CORRECT - Clear, contextual, actionable
"""
Hi \(profile.name)! 👋

Time for your morning medication.

Reply with:
• DONE - if you've taken it
• PHOTO - to send a photo
• HELP - if you need assistance

- Love, your family
"""
```

**Message Length:**
- Maximum 320 characters (2 SMS segments)
- Use emojis for visual cues: 👋 💊 📸
- Always include profile name for personalization
- Clear call-to-action

### Profile Photo Accessibility

**Context:** Profile circles are key navigation elements.

```swift
// ✅ Accessible profile circles
ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
    Button {
        selectedProfileIndex = index
    } label: {
        ProfileImageView(profile: profile)
            .frame(width: 44, height: 44)
    }
    .accessibilityLabel("\(profile.name)'s profile")
    .accessibilityHint("Double tap to view \(profile.name)'s tasks")
    .accessibilityAddTraits(selectedProfileIndex == index ? [.isButton, .isSelected] : .isButton)
}
```

### Task Priority Visual Indicators

**Context:** Don't rely on color alone for urgency.

```swift
// ❌ WRONG - Color only
Text(task.title)
    .foregroundColor(task.isOverdue ? .red : .black)

// ✅ CORRECT - Color + icon + text
HStack {
    if task.isOverdue {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
            .accessibilityLabel("Overdue")
    }
    Text(task.title)
        .foregroundColor(task.isOverdue ? .red : .black)
    if task.isOverdue {
        Text("OVERDUE")
            .font(.caption)
            .foregroundColor(.red)
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(task.isOverdue ? "Overdue task: " : "")\(task.title)")
```

---

## Testing Checklist

### Manual Testing

- [ ] Test with **Dynamic Type** enabled (Settings → Accessibility → Display & Text Size)
- [ ] Test with **Larger Text** sizes (up to xxxLarge)
- [ ] Test with **VoiceOver** enabled (triple-click side button)
- [ ] Test with **Reduce Motion** enabled (animations disabled)
- [ ] Test with **Increase Contrast** enabled
- [ ] Test with **Button Shapes** enabled (adds underlines to buttons)
- [ ] Test in **both light and dark mode**
- [ ] Test all **touch targets are minimum 44×44 points**

### Automated Testing

```swift
func testAccessibilityLabels() {
    let app = XCUIApplication()
    app.launch()

    // Verify critical elements have labels
    XCTAssertTrue(app.buttons["Send medication reminder"].exists)
    XCTAssertTrue(app.buttons["Create new profile"].exists)
    XCTAssertTrue(app.images["Profile photo"].exists)
}

func testVoiceOverNavigation() {
    let app = XCUIApplication()
    app.launch()

    // Verify VoiceOver can navigate to all interactive elements
    XCTAssertTrue(app.buttons.firstMatch.isHittable)
    XCTAssertTrue(app.textFields.firstMatch.isHittable)
}
```

### Contrast Testing Tools

Use online contrast checkers:
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/
- Minimum ratio: 4.5:1 (AA)
- Preferred ratio: 7:1 (AAA) for elderly users

---

## Common Violations to Flag

### Critical Issues (Must Fix)

- ❌ Touch targets smaller than 44×44 points
- ❌ Text contrast below 4.5:1 ratio
- ❌ No VoiceOver label on interactive elements
- ❌ Hardcoded font sizes (no Dynamic Type support)
- ❌ Color as only indicator of state/urgency
- ❌ Swipe gestures with no alternative
- ❌ Images without accessibility labels
- ❌ Form inputs without labels
- ❌ Error messages not announced to VoiceOver

### Medium Issues (Should Fix)

- ⚠️ Generic accessibility hints ("Tap for more")
- ⚠️ Excessive VoiceOver verbosity (not grouping elements)
- ⚠️ Missing loading state feedback
- ⚠️ Decorative images not hidden from VoiceOver
- ⚠️ Button labels don't describe action ("OK" vs "Save Profile")

---

## Code Review Checklist

When reviewing code, verify:

- [ ] All `Button` elements have descriptive `.accessibilityLabel()`
- [ ] All `Image` elements have `.accessibilityLabel()` or `.accessibilityHidden(true)`
- [ ] Text uses `.font(.body)` or system styles, not hardcoded sizes
- [ ] Interactive elements are minimum 44×44 points
- [ ] Color contrast meets 4.5:1 minimum (check with tool)
- [ ] Forms have proper labels and error announcements
- [ ] Loading states provide feedback
- [ ] Swipe gestures have button alternatives
- [ ] Related elements are grouped with `.accessibilityElement(children: .combine)`
- [ ] VoiceOver hints are helpful and concise

---

## When to Apply This Skill

This skill should be invoked when:
- Creating new SwiftUI views or components
- Adding interactive buttons, gestures, or navigation
- Displaying photos or images (gallery, profile photos, task responses)
- Creating forms (profile creation, task creation)
- Showing error messages or validation feedback
- Implementing loading states
- Adding animations or transitions
- Reviewing code for accessibility compliance
- Testing on physical devices
- Preparing for App Store submission
- Receiving accessibility feedback from users
- Working on elderly-facing features (SMS templates, task displays)
