# Twilio SMS Integration - Implementation Plan
**Created:** 2025-10-09
**Status:** 🚧 In Progress
**Priority:** High - Critical for Production Launch

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Compliance Requirements](#compliance-requirements)
3. [Architecture Changes](#architecture-changes)
4. [Implementation Phases](#implementation-phases)
5. [File Changes Checklist](#file-changes-checklist)
6. [Testing Plan](#testing-plan)
7. [Deployment Checklist](#deployment-checklist)

---

## 🎯 Overview

### Goal
Integrate Twilio SMS API to send habit reminders to elderly users via SMS with full TCPA compliance and safety protections.

### Current State
- ✅ Twilio account configured (.env credentials present)
- ✅ SMSServiceProtocol defined (20+ methods)
- ✅ MockSMSService working for development
- ❌ No production Twilio implementation
- ⚠️ Missing TCPA compliance fields in models
- ⚠️ No opt-out/unsubscribe handling

### Target State
- ✅ TwilioSMSService.swift production-ready
- ✅ Full TCPA compliance (opt-in, opt-out, disclosures)
- ✅ Quiet hours protection (category-based)
- ✅ SMS quota management (monthly + daily limits)
- ✅ Duplicate phone number prevention
- ✅ STOP keyword auto-handling

---

## ⚖️ Compliance Requirements

### TCPA (Telephone Consumer Protection Act)

#### ✅ Required Elements in Consent Message:
```
"Hello [Name]! Your family member wants to send you helpful daily reminders via text.

Reply YES to receive up to [X] messages/day. Reply STOP to unsubscribe or HELP for info.

Message & data rates may apply.
- Hallo Family Care"
```

#### ✅ Auto-Handled Opt-Out Keywords (by Twilio):
- Current: STOP, UNSUBSCRIBE, CANCEL, END, QUIT, STOPALL
- New (Apr 29, 2025): REVOKE, OPTOUT

#### ✅ Required Fields in Database:
- `smsOptInDate: Date?` - When user consented
- `smsOptedOut: Bool` - Current opt-out status
- `optOutDate: Date?` - When user opted out
- `optOutMethod: String?` - How they opted out

### A2P 10DLC Registration
- **Status:** Required for production
- **Phone Number:** +17759816048
- **Action:** Register with Twilio before launch
- **Timeline:** 1-2 weeks processing time

---

## 🏗️ Architecture Changes

### 1. Data Model Updates

#### `ElderlyProfile.swift` - Add Opt-Out Tracking
```swift
// ADD THESE FIELDS:
var smsOptedOut: Bool = false
var optOutDate: Date?
var optOutMethod: String? // "STOP_KEYWORD", "MANUAL_REQUEST"
var dailySMSLimit: Int = 10
var lastSMSDate: Date?
var dailySMSCount: Int = 0
```

#### `User.swift` - Add Quota Tracking
```swift
// ADD THESE FIELDS:
var smsQuotaLimit: Int = 500        // Based on subscription tier
var smsQuotaUsed: Int = 0
var smsQuotaPeriodStart: Date
var smsQuotaPeriodEnd: Date
```

#### `TaskCategory.swift` - Add Quiet Hours Extension
```swift
extension TaskCategory {
    var allowedHourRange: ClosedRange<Int> {
        // Medication: 6 AM - 10 PM
        // Exercise: 8 AM - 8 PM
        // Social: 9 AM - 9 PM
        // etc.
    }

    func isTimeAllowed(_ date: Date, in timezone: TimeZone) -> Bool
}
```

### 2. New Service Implementation

**File:** `Halloo/Services/TwilioSMSService.swift`

**Key Methods:**
- `sendSMS()` - Send via Twilio REST API
- `handleIncomingWebhook()` - Process STOP keywords
- `checkQuotaBeforeSending()` - Validate limits
- `adjustForQuietHours()` - Category-based validation

### 3. ViewModel Updates

**ProfileViewModel.swift**:
- Update confirmation message (TCPA compliance)
- Implement `handleStopKeyword()` method
- Add opt-out status tracking

**TaskViewModel.swift**:
- Add quiet hours validation during creation
- Add per-profile daily limit check
- Show warnings for 9+ habits per day

---

## 📅 Implementation Phases

### **Phase 1: Critical Compliance** (8-12 hours)
**Status:** 🚧 In Progress

#### Tasks:
- [ ] Add opt-out fields to ElderlyProfile
- [ ] Add quota fields to User model
- [ ] Update Firestore schema migration
- [ ] Create TwilioSMSService.swift
- [ ] Implement STOP keyword handler
- [ ] Update consent message (TCPA compliant)
- [ ] Block duplicate phone numbers

#### Success Criteria:
- ✅ Send test SMS via Twilio API
- ✅ STOP keyword auto-blocks future SMS
- ✅ Consent message includes all TCPA elements
- ✅ Duplicate phone number throws error

---

### **Phase 2: Safety & Reliability** (6-8 hours)
**Status:** ⏳ Pending

#### Tasks:
- [ ] Add quiet hours validation (category-based)
- [ ] Implement per-profile daily limit (10 SMS/day)
- [ ] Add monthly quota tracking
- [ ] Show quota warning at 80%
- [ ] Add SMS retry logic with exponential backoff
- [ ] Timezone conversion for scheduled SMS

#### Success Criteria:
- ✅ SMS blocked outside quiet hours
- ✅ Cannot create 11th habit for same profile
- ✅ Warning shown at 400/500 quota
- ✅ SMS auto-retries on temporary failures

---

### **Phase 3: Polish & UX** (4-6 hours)
**Status:** ⏳ Pending

#### Tasks:
- [ ] Add "Manage SMS Preferences" screen
- [ ] Family notification on SMS failures
- [ ] Subscription upgrade flow (quota increase)
- [ ] A2P 10DLC registration
- [ ] Comprehensive logging for compliance audits
- [ ] Analytics dashboard (delivery rates)

#### Success Criteria:
- ✅ User can view SMS usage stats
- ✅ Push notification on persistent failures
- ✅ Upgrade path increases quota
- ✅ All SMS events logged for auditing

---

## 📝 File Changes Checklist

### Models (3 files)
- [ ] `Halloo/Models/ElderlyProfile.swift` - Add 6 opt-out/rate-limit fields
- [ ] `Halloo/Models/User.swift` - Add 4 quota tracking fields
- [ ] `Halloo/Models/TaskCategory.swift` - Add quiet hours extension

### Services (3 files)
- [ ] `Halloo/Services/TwilioSMSService.swift` - **NEW FILE** (production SMS)
- [ ] `Halloo/Services/FirebaseDatabaseService.swift` - Block duplicate phones
- [ ] `Halloo/Services/FirebaseAuthenticationService.swift` - Set default quota

### ViewModels (2 files)
- [ ] `Halloo/ViewModels/ProfileViewModel.swift` - STOP handler + TCPA message
- [ ] `Halloo/ViewModels/TaskViewModel.swift` - Quiet hours + daily limit validation

### Views (2 files)
- [ ] `Halloo/Views/DashboardView.swift` - Quota warning banner
- [ ] `Halloo/Views/TaskViews.swift` - Category picker + time validation

### Configuration (2 files)
- [ ] `firestore.rules` - Update rules for new fields
- [ ] `.env` - Verify Twilio credentials

### Documentation (2 files)
- [ ] `docs/TWILIO-INTEGRATION-PLAN.md` - This file
- [ ] `docs/SESSION-STATE.md` - Update with SMS implementation status

---

## 🧪 Testing Plan

### Unit Tests
```swift
// TwilioSMSServiceTests.swift
func testSendSMSWithinQuota()
func testSendSMSQuotaExceeded()
func testSTOPKeywordBlocksProfile()
func testQuietHoursBlocksSMS()
func testDuplicatePhoneNumberThrows()
```

### Integration Tests
```swift
// SMSIntegrationTests.swift
func testEndToEndSMSDelivery()
func testQuotaIncrementOnSend()
func testOptOutPersistsToFirestore()
```

### Manual Testing Checklist
- [ ] Send SMS to test number (+17788143739)
- [ ] Reply STOP and verify profile blocked
- [ ] Create habit at 11 PM, verify time validation error
- [ ] Create 10 habits for one profile, verify 11th blocked
- [ ] Use 400 SMS, verify warning appears
- [ ] Use 500 SMS, verify blocking
- [ ] Try creating duplicate phone number profile

---

## 🚀 Deployment Checklist

### Pre-Launch (Development)
- [ ] All Phase 1 tasks completed
- [ ] Unit tests passing
- [ ] Manual testing complete
- [ ] .env credentials verified (test mode)

### Production Preparation
- [ ] A2P 10DLC registration approved
- [ ] Firestore schema migrated (new fields added)
- [ ] SMS quota limits configured per tier
- [ ] Twilio production credentials in .env
- [ ] Quiet hours tested across timezones

### Launch Day
- [ ] Switch from MockSMSService to TwilioSMSService in Container
- [ ] Monitor first 100 SMS deliveries
- [ ] Check error logs for failures
- [ ] Verify STOP keywords work in production
- [ ] Test quota warnings with real user

### Post-Launch (Week 1)
- [ ] Review SMS delivery rates (target >95%)
- [ ] Check opt-out rate (should be <5%)
- [ ] Verify no quiet hours violations
- [ ] Monitor quota usage patterns
- [ ] Gather user feedback on SMS frequency

---

## 💰 SMS Quota Recommendations

### Subscription Tiers

| Tier | Monthly Quota | Price | Target User |
|------|--------------|-------|-------------|
| Free Trial | 50 SMS | $0 | New users (7 days) |
| Starter | 500 SMS | $9.99 | 1-2 profiles, 2-3 habits each |
| Family | 1500 SMS | $19.99 | 3-4 profiles, 3-5 habits each |
| Premium | 5000 SMS | $49.99 | Care facilities, 5+ profiles |

### Safety Limits (Always Enforced)

| Limit | Value | Purpose |
|-------|-------|---------|
| Max SMS/day per profile | 10 | Prevent elderly SMS overload |
| Max SMS/hour per profile | 3 | Rate limiting |
| Min interval between SMS | 5 min | Burst protection |

---

## 📊 Success Metrics

### Technical Metrics
- **SMS Delivery Rate:** >95%
- **API Response Time:** <2s average
- **Quota Accuracy:** 100% (no overages)
- **Opt-Out Processing:** <1 minute

### User Metrics
- **Opt-Out Rate:** <5% of profiles
- **SMS Completion Rate:** >70% (elderly responds)
- **Quota Warnings:** <10% of users hit 80%
- **Support Tickets:** <2% related to SMS

---

## 🔗 Related Documentation

- **TCPA Compliance Guide:** [Twilio Regulatory Guidelines](https://www.twilio.com/en-us/guidelines/sms)
- **Twilio REST API Docs:** [Send SMS API](https://www.twilio.com/docs/sms/api/message-resource)
- **A2P 10DLC Registration:** [Twilio A2P Guide](https://www.twilio.com/docs/sms/a2p-10dlc)
- **Firebase Schema:** `docs/firebase/SCHEMA.md`
- **Session State:** `docs/SESSION-STATE.md`

---

## ⚠️ Known Issues & Limitations

### Current Limitations
1. **No MMS Support:** Photo attachments not implemented yet
2. **US-Only:** International SMS not tested
3. **Manual Quota Reset:** No automatic monthly reset (needs Cloud Function)
4. **No SMS History UI:** Users can't see sent SMS log

### Future Enhancements
1. Add MMS support for photo reminders
2. International phone number support
3. Auto-quota reset via Cloud Function
4. SMS history view in app
5. Analytics dashboard for families

---

## 📞 Support & Troubleshooting

### Common Issues

**SMS Not Sending:**
1. Check Twilio credentials in .env
2. Verify A2P 10DLC registration status
3. Check quota not exceeded
4. Verify phone number not opted out

**STOP Keyword Not Working:**
1. Check webhook configured in Twilio Console
2. Verify ProfileViewModel.handleStopKeyword() called
3. Check Firestore smsOptedOut field updated

**Quota Warning Showing Incorrectly:**
1. Verify User.smsQuotaUsed incrementing
2. Check quota period dates not expired
3. Confirm 80% calculation correct

---

**Last Updated:** 2025-10-09
**Next Review:** After Phase 1 completion
**Owner:** Development Team
