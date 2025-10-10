# Phone Number Format Fix - E.164 Compliance

## Issue
Twilio SMS was failing with error `21211: Invalid 'To' Phone Number` because phone numbers were stored in display format (e.g., "+1 (778) 814-3739") instead of E.164 format required by Twilio.

## Root Cause
The `formattedPhoneNumber` extension in `String+Extensions.swift` was designed for UI display, adding parentheses, spaces, and dashes. When ProfileViewModel used this for creating profiles, the formatted phone numbers were incompatible with Twilio's E.164 requirement.

**E.164 Format Requirements:**
- Start with `+` and country code
- Only digits after `+` (no spaces, dashes, parentheses)
- Example: `+17788143739`

## Solution
Created new `e164PhoneNumber` extension property specifically for Twilio SMS compatibility.

### Files Changed

#### 1. `/Halloo/Core/String+Extensions.swift`
**Added:** New `e164PhoneNumber` computed property (lines 67-96)

```swift
/// E.164 format phone number for Twilio SMS (e.g., +17788143739)
///
/// Converts any phone number format to E.164 standard required by Twilio.
/// This format has no spaces, dashes, or parentheses - just + and digits.
var e164PhoneNumber: String {
    let cleaned = phoneNumberDigitsOnly

    // Handle different phone number lengths
    switch cleaned.count {
    case 10:
        // US/Canada 10-digit number → add +1 country code
        return "+1\(cleaned)"

    case 11 where cleaned.hasPrefix("1"):
        // Already has country code 1 → just add +
        return "+\(cleaned)"

    default:
        // International or other format → just add + if needed
        if cleaned.count > 10 {
            return "+\(cleaned)"
        } else if cleaned.count == 10 {
            // Assume US/Canada if exactly 10 digits
            return "+1\(cleaned)"
        } else {
            // Invalid or too short
            return "+\(cleaned)"
        }
    }
}
```

**Purpose:**
- `formattedPhoneNumber`: Display format for UI (e.g., "+1 (778) 814-3739")
- `e164PhoneNumber`: SMS-compatible format for Twilio (e.g., "+17788143739")

#### 2. `/Halloo/ViewModels/ProfileViewModel.swift`
**Changed:** All phone number processing to use `.e164PhoneNumber`

**Line 672:** `createProfileAsync()` - Profile creation
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 810:** `updateProfileAsync()` - Profile updates
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 1535:** `createTemporaryProfileForSMS()` - Onboarding flow
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 1293:** `validatePhoneNumber()` - Duplicate phone check
```swift
// Before
else if profiles.contains(where: { $0.phoneNumber == phone.formattedPhoneNumber && $0.id != selectedProfile?.id }) {

// After
else if profiles.contains(where: { $0.phoneNumber == phone.e164PhoneNumber && $0.id != selectedProfile?.id }) {
```

## Testing
1. Create a new elderly profile with phone number (e.g., "778-814-3739")
2. Verify profile.phoneNumber is stored as "+17788143739" (E.164)
3. Send SMS confirmation - should succeed without Twilio error 21211
4. Check Twilio logs - should show valid "To" phone number

## Impact
- **Fixes:** Twilio SMS delivery failures
- **Ensures:** All phone numbers stored consistently in E.164 format
- **Maintains:** Display formatting for UI using `formattedPhoneNumber`
- **Backward Compatible:** Existing profiles will be converted to E.164 on next update

## Related Files
- `Halloo/Core/String+Extensions.swift` - Phone number formatting utilities
- `Halloo/ViewModels/ProfileViewModel.swift` - Profile management and SMS
- `Halloo/Views/ProfileViews.swift` - Profile creation UI (uses formatted display)
- `functions/index.js` - Twilio SMS Cloud Function (validates E.164)

## References
- [Twilio E.164 Documentation](https://www.twilio.com/docs/glossary/what-e164)
- [E.164 Wikipedia](https://en.wikipedia.org/wiki/E.164)
- Twilio Error 21211: Invalid 'To' Phone Number
