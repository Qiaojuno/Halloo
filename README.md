# Halloo - Elderly Care SMS Reminder App

**Family-to-elderly SMS reminder system with photo confirmations**

---

## 📱 What is Halloo?

Halloo helps families stay connected with elderly parents through automated SMS reminders and photo-based check-ins. Family members create habits (medication, exercise, meals) that send scheduled SMS reminders to their elderly parent's phone. The elderly parent confirms completion by texting back photos or simple responses.

---

## 🚀 Quick Start

### Prerequisites
- Xcode 15+
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- Active Firebase project
- Twilio account (for SMS)

### Setup

```bash
# Clone and install
cd Halloo
npm install --prefix functions

# Configure Firebase
firebase login
firebase use <your-project-id>

# Deploy Cloud Functions
firebase deploy --only functions

# Run iOS app
open Halloo.xcodeproj
# Build and run in Xcode
```

### Environment Variables

Create `functions/.env`:
```
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

---

## 📚 Documentation

### Core Documentation
- **[Technical Documentation](Halloo/docs/TECHNICAL-DOCUMENTATION.md)** - E.164 phone formatting, data migrations, archived photos
- **[Recurring Task System](Halloo/docs/RECURRING-TASK-SYSTEM.md)** - How scheduled SMS reminders work (professional standard implementation)
- **[Firebase Schema](Halloo/docs/firebase/SCHEMA.md)** - Database structure and indexes
- **[Changelog](Halloo/docs/sessions/CHANGELOG.md)** - Feature history and updates

### Architecture
- **[App Structure](Halloo/docs/architecture/App-Structure.md)** - AppState pattern, dependency injection, architecture overview
- **[Dev Guidelines](Halloo/docs/architecture/Dev-Guidelines.md)** - Code standards and best practices
- **[UI Specs](Halloo/docs/architecture/UI-Specs.md)** - Design system and component specs

---

## 🏗️ Architecture

```
iOS App (SwiftUI)
    ↓
AppState (Single Source of Truth)
    ↓
Container (Dependency Injection)
    ↓
Firebase Services
    ├── Authentication (Google/Apple Sign-In)
    ├── Firestore (Real-time database)
    ├── Cloud Storage (Photo storage with 90-day archival)
    └── Cloud Functions
        ├── Scheduled SMS (every 1 minute via Cloud Scheduler)
        ├── Twilio Webhook (incoming SMS processing)
        └── Photo Archival (automatic cleanup)
```

### Key Features

**✅ Recurring Task Scheduling**
- Professional standard implementation (matches Google Calendar, iOS Reminders)
- Supports: One-time, Daily, Weekdays, Weekly, Custom days
- Automatic `nextScheduledDate` calculation
- Cloud Function updates after each SMS

**✅ SMS Integration**
- Twilio API for reliable delivery
- E.164 phone format compliance
- Webhook processing for responses
- Photo + text response handling

**✅ Multi-Device Sync**
- Real-time Firestore listeners
- DataSyncCoordinator for state propagation
- Optimistic UI updates with rollback

**✅ Photo Management**
- 90-day retention policy
- Automatic Cloud Storage archival
- Gallery view with event history

---

## 📁 Project Structure

```
Halloo/
├── Halloo/                          # iOS App
│   ├── Core/                        # App.swift, AppState.swift, DataSyncCoordinator.swift
│   ├── Services/                    # Firebase services, NotificationService
│   ├── ViewModels/                  # Business logic layer
│   ├── Views/                       # SwiftUI views
│   ├── Models/                      # Data models, Container (DI)
│   └── docs/                        # Documentation
│       ├── TECHNICAL-DOCUMENTATION.md
│       ├── RECURRING-TASK-SYSTEM.md
│       ├── architecture/            # Architecture docs
│       ├── firebase/                # Database schema
│       ├── sessions/                # Session logs (CHANGELOG only)
│       └── archive/                 # Historical docs
│
├── functions/                       # Firebase Cloud Functions
│   ├── index.js                     # Main functions file
│   ├── package.json
│   └── .env                         # Twilio secrets (not in git)
│
├── firestore.rules                  # Firestore security rules
├── firestore.indexes.json          # Database indexes
├── storage.rules                    # Cloud Storage security
└── firebase.json                    # Firebase config
```

---

## 🔧 Development

### Building the App

```bash
# Build iOS app
xcodebuild -scheme Halloo \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Run tests
xcodebuild test -scheme Halloo \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Testing Cloud Functions Locally

```bash
# Start emulators
firebase emulators:start

# Test sendScheduledTaskReminders
curl http://localhost:5001/your-project/us-central1/debugAllHabits

# Watch logs
firebase emulators:start --only functions
```

### Deploy

```bash
# Deploy everything
firebase deploy

# Deploy specific function
firebase deploy --only functions:sendScheduledTaskReminders

# Deploy Firestore rules only
firebase deploy --only firestore:rules
```

---

## 🧪 Testing

### End-to-End SMS Flow

1. Launch iOS app
2. Create elderly profile with valid phone number
3. Create habit scheduled 2 minutes from now
4. Monitor Cloud Function logs:
   ```bash
   firebase functions:log --only sendScheduledTaskReminders --follow
   ```
5. Verify SMS received on elderly parent's phone
6. Reply with photo/text to test webhook

### Recurring Tasks

See **[RECURRING-TASK-SYSTEM.md](Halloo/docs/RECURRING-TASK-SYSTEM.md)** for comprehensive testing guide.

---

## 📊 Current Status

| Component | Status |
|-----------|--------|
| iOS App Build | ✅ Working |
| Authentication | ✅ Working (Google/Apple) |
| Profile Creation | ✅ Working |
| Habit Creation | ✅ Working |
| Scheduled SMS | ✅ Working (Cloud Scheduler) |
| Recurring Tasks | ✅ Working (Professional standard) |
| Photo Uploads | ✅ Working |
| 90-Day Archival | ✅ Working |
| Multi-Device Sync | ✅ Working |

---

## 🐛 Known Issues

None at this time. See [CHANGELOG.md](Halloo/docs/sessions/CHANGELOG.md) for recent fixes.

---

## 📝 Contributing

1. Read [Dev Guidelines](Halloo/docs/architecture/Dev-Guidelines.md)
2. Check [App Structure](Halloo/docs/architecture/App-Structure.md)
3. Review [CHANGELOG.md](Halloo/docs/sessions/CHANGELOG.md)
4. Create feature branch
5. Submit PR with tests

---

## 📄 License

Proprietary - All rights reserved

---

**Last Updated:** October 16, 2025
**Version:** MVP (Pre-launch)
