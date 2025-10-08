# 🧪 Quick Start: Add Test Habits

## ✅ What I Did

I added a **purple flask button** (🧪) to the top-right of every screen in your app (next to the person icon).

**This button only appears in DEBUG builds** - it won't show in production.

---

## 🚀 How to Use It

1. **Launch your app** (make sure you're logged in to `nicholas0720h@gmail.com`)
2. **Look at the top-right** - you'll see a purple flask icon (🧪) next to the person icon
3. **Tap the flask button** once
4. **Wait a moment** - you'll feel a haptic vibration when it's done
5. **Close and reopen the app** to see the new test data

---

## 📊 What Gets Added

When you tap the flask button, it creates:

### ✅ Completed Habits (2)
1. **"Take medication with water"** (completed 2 hours ago)
   - Has a photo response
   - Shows in gallery with photo icon

2. **"Drink water"** (completed 1 hour ago)
   - Has text response: "Done! Feeling refreshed 💧"
   - Shows in gallery with text bubbles

### ⏰ Upcoming Habit (1)
3. **"Evening walk"** (scheduled in 3 hours)
   - Not completed yet
   - Shows as upcoming task

### ⚠️ Late/Overdue Habit (1)
4. **"Take vitamins"** (4 hours ago, deadline passed)
   - Overdue by 3 hours
   - Shows as late task

---

## 🎯 Where to See the Data

**DashboardView:**
- Late task: "Take vitamins" (red/overdue)
- Upcoming task: "Evening walk"
- Completed tasks: "Take medication" and "Drink water"

**GalleryView:**
- Mini text bubble card for "Drink water"
- Mini photo card for "Take medication"
- (Or the example card if no data exists)

**HabitsView:**
- All 4 habits listed with their schedules

---

## 🧹 How to Remove Test Data

**Option 1: Firebase Console**
1. Go to Firebase Console
2. Navigate to Firestore Database
3. Find `users/{your-user-id}/tasks`
4. Delete the test task documents
5. Find `users/{your-user-id}/smsResponses`
6. Delete the test response documents

**Option 2: Add a "Clear Test Data" button**
(Let me know if you want this!)

---

## 🔧 Technical Details

**Files Modified:**
1. `/Halloo/Helpers/TestDataInjector.swift` - **NEW FILE** with injection logic
2. `/Halloo/Views/Components/SharedHeaderSection.swift` - Added debug button

**The button:**
- Only shows in `#if DEBUG` builds
- Uses purple color to indicate it's a debug feature
- Provides haptic feedback on success/error
- Automatically finds your user ID and profile ID
- Safe to tap multiple times (creates new test data each time)

---

## ❓ Troubleshooting

**Button doesn't appear:**
- Make sure you're running a DEBUG build (not RELEASE)
- The button is right next to the person icon in the top-right

**No data appears after tapping:**
- Check the Xcode console for error messages
- Make sure you're logged in
- Make sure you have at least one profile created
- Try closing and reopening the app

**Error in console:**
- If you see "No user logged in" - log in first
- If you see "No profile found" - create a profile first
- If you see Firebase errors - check your Firebase configuration

---

## 📚 More Options

See `/INJECT_TEST_DATA_GUIDE.md` for alternative ways to inject test data:
- From app launch (automatic)
- From different views
- Using Xcode breakpoints
- And more!
