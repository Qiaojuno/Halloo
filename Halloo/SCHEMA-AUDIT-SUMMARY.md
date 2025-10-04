# 🎯 Firebase Schema Audit - Quick Reference
**Date:** 2025-10-03
**Status:** ⚠️ 5 Critical Violations Found

---

## 📊 Current vs Desired Architecture

### ❌ CURRENT (Flat Collections)
```
Firestore Root
├── /users/{uid}
├── /profiles/{id}           ← ❌ Should be nested under user
├── /tasks/{id}              ← ❌ Should be nested under profile
├── /responses/{id}          ← ❌ Should be nested under profile
└── /gallery_events/{id}
```

### ✅ DESIRED (Hierarchical Subcollections)      
```
Firestore Root
└── /users/{firebaseUID}                       ← Firebase Auth UID
    ├── /profiles/{phoneNumber}                ← Subcollection (use phone as ID)
    │   ├── /habits/{uuid}                     ← Subcollection (UUID)
    │   └── /messages/{uuid}                   ← Subcollection (UUID or Twilio SID)
    └── /gallery_events/{uuid}                 ← Subcollection (optional)
```

---

## 🚨 Top 5 Critical Violations

### 1. **Flat Architecture Instead of Nested** 🔴
- **File:** `FirebaseDatabaseService.swift:16-24`
- **Issue:** All collections at root level, not nested under user
- **Impact:** Cannot use native cascade delete, complex security rules
- **Fix Effort:** 8-12 hours (breaking change + migration)

### 2. **Inconsistent ID Generation** 🔴
- **File:** `ProfileViewModel.swift:557`
- **Issue:** Using UUID for profile ID instead of phone number
- **Impact:** Cannot do upsert logic, unpredictable IDs
- **Fix Effort:** 4-6 hours (create IDGenerator utility)

### 3. **User Model Missing Fields** 🟡
- **File:** `User.swift:4-14`
- **Issue:** Model missing `profileCount`, `taskCount`, `updatedAt`
- **Impact:** Database writes fail silently
- **Fix Effort:** 2-3 hours (additive change)

### 4. **Manual Cascade Delete Logic** 🟡
- **File:** `FirebaseDatabaseService.swift:118-151`
- **Issue:** Manually querying and deleting subcollections
- **Impact:** Error-prone, batch size limits, race conditions
- **Fix Effort:** 3-4 hours (create recursive delete)

### 5. **Duplicate User Creation Code** 🟢
- **File:** `FirebaseAuthenticationService.swift:173-206`
- **Issue:** Manual Firestore writes instead of using DatabaseService
- **Impact:** Code duplication, maintenance burden
- **Fix Effort:** 2 hours (refactor to use service)

---

## 📋 Quick Fix Checklist

### Immediate (Can Do Now - Non-Breaking)
- [x] **TODO #3:** Add missing fields to User model (2-3 hrs)
- [x] **TODO #5:** Centralize user creation in DatabaseService (2 hrs)
- [x] **TODO #6:** Document Firestore indexes (1-2 hrs)

### Short-Term (Requires Testing)
- [x] **TODO #2:** Create IDGenerator utility + standardize IDs (4-6 hrs)
- [x] **TODO #4:** Implement recursive delete helper (3-4 hrs)
- [x] **TODO #7:** Add schema validation tests (6-8 hrs)
- [x] **TODO #8:** Add SwiftLint rules for schema (2-3 hrs)

### Long-Term (Breaking Changes - Requires Migration)
- [ ] **TODO #1:** Migrate to nested subcollections (8-12 hrs + migration)
  - Write migration script
  - Test with emulator
  - Schedule maintenance window
  - Run migration
  - Verify data integrity

**Total Estimated Effort:** 30-40 hours

---

## 🎯 Recommended ID Strategy

| Entity | Current ID | Desired ID | Rationale |
|--------|-----------|-----------|-----------|
| **User** | Firebase UID ✅ | Firebase UID ✅ | Matches authentication |
| **Profile** | UUID ❌ | Phone number | Predictable, allows upserts |
| **Habit/Task** | UUID ✅ | UUID ✅ | Unique per creation |
| **Message** | UUID ✅ | UUID or Twilio SID ✅ | Unique, traceable |

### Implementation:
```swift
// Create new utility: IDGenerator.swift
enum IDGenerator {
    static func userID(firebaseUID: String) -> String {
        return firebaseUID
    }

    static func profileID(phoneNumber: String) -> String {
        return phoneNumber.normalizedE164() // +15551234567
    }

    static func habitID() -> String {
        return UUID().uuidString
    }

    static func messageID(twilioSID: String? = nil) -> String {
        return twilioSID ?? UUID().uuidString
    }
}

// Extension for phone normalization
extension String {
    func normalizedE164() -> String {
        // Remove all non-digits
        let digits = self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Add +1 if not present (US numbers)
        if digits.count == 10 {
            return "+1" + digits
        } else if digits.count == 11 && digits.hasPrefix("1") {
            return "+" + digits
        }
        return self // Return as-is if already formatted
    }
}
```

---

## 🔍 Key Files to Review

### Models (Schema Definitions)
- ✅ `User.swift` - Add missing fields
- ✅ `ElderlyProfile.swift` - Already correct
- ✅ `Task.swift` - Already correct (rename to Habit?)
- ✅ `SMSResponse.swift` - Already correct (rename to Message?)

### Services (Database Operations)
- 🔴 `FirebaseDatabaseService.swift` - **MAJOR REFACTOR NEEDED**
  - Lines 16-24: Collection enum → CollectionPath with nesting
  - Lines 84-151: Profile CRUD → use nested paths
  - Lines 185-320: Task CRUD → use nested paths
  - Lines 324-422: Response CRUD → use nested paths
- 🟡 `FirebaseAuthenticationService.swift` - Use DatabaseService
  - Lines 173-206: Google sign-in user creation
  - Lines 120-153: Apple sign-in user creation

### ViewModels (Business Logic)
- 🟡 `ProfileViewModel.swift` - Use IDGenerator
  - Line 557: Change to `id: IDGenerator.profileID(phoneNumber: formattedPhone)`

### Security Rules
- 🟡 `firestore.rules` - Update for nested structure
  - Lines 28-58: Simplify with subcollection inheritance

---

## 🧪 Testing Strategy

### Unit Tests (Create New File: `FirebaseSchemaTests.swift`)
```swift
class SchemaValidationTests: XCTestCase {
    // Test 1: Verify User model matches Firestore writes
    func testUserModelCompleteness() { }

    // Test 2: Verify profile IDs use phone numbers
    func testProfileIDUsesPhoneNumber() { }

    // Test 3: Verify cascade delete removes all nested data
    func testCascadeDeleteWorks() { }

    // Test 4: Verify no orphaned documents after user delete
    func testNoOrphanedDocuments() { }

    // Test 5: Verify nested paths are correct
    func testFirestorePathStructure() { }
}
```

### SwiftLint Rules (Add to `.swiftlint.yml`)
```yaml
custom_rules:
  no_uuid_for_profiles:
    regex: 'ElderlyProfile\([\s\S]*?id:\s*UUID\(\)'
    message: "Use IDGenerator.profileID() instead"
    severity: error

  no_flat_firestore_collections:
    regex: 'collection\("(profiles|tasks|responses)"\)'
    message: "Use nested paths: users/{uid}/profiles/..."
    severity: error
```

---

## 📈 Migration Roadmap

### Week 1-2: Preparation
- [ ] Complete TODO #2-#8 (non-breaking changes)
- [ ] Add all tests
- [ ] Set up Firebase emulator
- [ ] Write migration script

### Week 3: Testing
- [ ] Test migration script with emulator
- [ ] Verify all queries work with new structure
- [ ] Load test with production data volume
- [ ] Plan rollback strategy

### Week 4: Migration
- [ ] Schedule 2-hour maintenance window
- [ ] Enable dual-write mode (write to both old & new)
- [ ] Run migration script
- [ ] Verify data integrity
- [ ] Switch reads to new structure
- [ ] Monitor for 48 hours

### Week 5: Cleanup
- [ ] Remove dual-write code
- [ ] Delete old collections
- [ ] Update documentation
- [ ] Close migration tickets

---

## ⚠️ Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss during migration | Low | Critical | Full backup + rollback plan |
| Downtime >2 hours | Medium | High | Practice migration 3x with emulator |
| Breaking existing users | Low | High | Dual-write period + gradual rollout |
| Query performance degradation | Low | Medium | Pre-create all Firestore indexes |
| Orphaned data after delete | Medium | Medium | Recursive delete + verification tests |

---

## 🎓 Schema Best Practices Applied

✅ **Hierarchical Data Model**
- User → Profile → Habits/Messages (logical nesting)

✅ **Predictable IDs**
- Phone number for profiles (allows upserts)
- UUIDs for ephemeral entities (habits, messages)

✅ **Native Cascade Deletes**
- Subcollections automatically scoped to parent

✅ **Simplified Security Rules**
- Inheritance from parent user document

✅ **Type Safety**
- Models match Firestore schema exactly

✅ **Testability**
- Schema validation in unit tests
- Linter rules prevent violations

---

## 📚 Next Steps

1. **Review this document** with team (30 min)
2. **Prioritize TODOs** based on risk/effort (1 hour)
3. **Start with TODO #3** (add User fields - low risk)
4. **Create IDGenerator** utility (TODO #2)
5. **Set up Firebase emulator** for migration testing
6. **Schedule weekly check-ins** during migration

---

**🎯 Confidence Score: 8/10**

**YARRR!** - Schema audit complete with actionable plan.

---

**Full Details:** See `FIREBASE-SCHEMA-CONTRACT.md`
