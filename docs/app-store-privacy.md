# App Store Privacy Nutrition Label Guide

This document outlines the privacy disclosures required for the App Store Connect privacy questionnaire.

## Overview

Seer collects diagnostic data to improve app stability and performance. All data collection requires explicit user consent and is fully opt-in.

## Data Types Collected

### 1. Crash Data

- **Category**: Diagnostics
- **Data Type**: Crash Data
- **Collection**: Only when user opts in via DiagnosticsConsentSheet
- **Linked to User**: No
- **Used for Tracking**: No
- **Purpose**: App Functionality

**What's collected:**

- Stack traces
- Exception types and codes
- Termination reasons

### 2. Performance Data

- **Category**: Diagnostics
- **Data Type**: Performance Data
- **Collection**: Only when user opts in via DiagnosticsConsentSheet
- **Linked to User**: No
- **Used for Tracking**: No
- **Purpose**: App Functionality

**What's collected:**

- App launch time
- Hang duration
- Memory usage (peak)
- CPU usage (cumulative)

### 3. Device Information

- **Category**: Diagnostics
- **Data Type**: Other Diagnostic Data
- **Collection**: Included with crash/performance reports when opted in
- **Linked to User**: No
- **Used for Tracking**: No
- **Purpose**: App Functionality

**What's collected:**

- Device model identifier (e.g., "iPhone15,2")
- iOS version
- App version and build number
- Locale and timezone

## App Store Connect Questionnaire Answers

When submitting to the App Store, answer the privacy questionnaire as follows:

### Do you or your third-party partners collect data from this app?

**Yes** (only if user opts in to diagnostics)

### Crash Data

- [x] Crash Data
- Purpose: **App Functionality**
- Linked to user identity: **No**
- Used for tracking: **No**

### Performance Data

- [x] Performance Data
- Purpose: **App Functionality**
- Linked to user identity: **No**
- Used for tracking: **No**

### Other Diagnostic Data

- [x] Other Diagnostic Data (device info)
- Purpose: **App Functionality**
- Linked to user identity: **No**
- Used for tracking: **No**

## User Consent Flow

1. **First Launch**: After authentication and What's New, users see `DiagnosticsConsentSheet`
2. **Opt-in Required**: Diagnostics are OFF by default
3. **Settings Access**: Users can change preferences anytime via:
   - Server Management → Privacy & Diagnostics
4. **Consent Versioning**: If privacy policy changes significantly, users are re-prompted

## Privacy Policy Requirements

Your privacy policy (<https://seer.app/privacy>) should include:

1. **What data is collected**: Crash reports, performance metrics, device info
2. **Why it's collected**: To fix bugs and improve app performance
3. **How long it's retained**: Specify retention period
4. **Third-party sharing**: State that data is not sold or shared with advertisers
5. **User rights**: How to opt out, request deletion, etc.
6. **Contact information**: How users can reach you about privacy concerns

## Implementation Details

### Files Involved

- `Packages/SeerCore/Sources/SeerCore/Services/DiagnosticsConsent.swift` - Consent state management
- `Packages/SeerCore/Sources/SeerCore/Services/MetricsReporter.swift` - MetricKit subscriber (respects consent)
- `Features/Feedback/DiagnosticsConsentSheet.swift` - First-time consent UI
- `Features/Feedback/PrivacySettingsView.swift` - Settings UI for managing consent

### Consent States

```swift
DiagnosticsConsent.shared.crashReportsEnabled      // Bool
DiagnosticsConsent.shared.performanceMetricsEnabled // Bool
DiagnosticsConsent.shared.needsConsentPrompt       // Bool (first launch or policy update)
```

### Checking Consent Before Data Processing

```swift
// In MetricsReporter
guard DiagnosticsConsent.shared.crashReportsEnabled else {
    // Discard crash data
    return
}
```

## Third-Party SDKs

Currently, Seer uses only Apple's native MetricKit framework. If you add third-party crash reporting (Sentry, Crashlytics, etc.):

1. Update this document with their data practices
2. Add them to your privacy policy
3. Ensure they're initialized AFTER consent is granted
4. Add their data types to App Store Connect questionnaire

## GDPR/CCPA Compliance

- **Lawful Basis**: Consent (opt-in)
- **Right to Access**: Data stays on-device (logged via os.log) unless backend is added
- **Right to Deletion**: `DiagnosticsConsent.shared.resetConsent()` clears preferences
- **Right to Object**: Users can disable at any time in Privacy settings

## Testing Checklist

- [ ] Fresh install shows consent prompt after authentication
- [ ] Declining consent → diagnostics are not logged
- [ ] Accepting consent → diagnostics are logged
- [ ] Settings toggle works and persists across app restarts
- [ ] Consent version change triggers re-prompt
- [ ] Privacy Policy link works
