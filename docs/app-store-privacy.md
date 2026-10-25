# App Store privacy disclosures

Diagnostics are enabled by default under the controller's documented
[legitimate-interest assessment](diagnostics-legitimate-interest.md). Existing
opt-outs remain disabled. There is no upfront consent sheet. Users can disable
crash and performance reporting independently in Server Management > Privacy &
Diagnostics, without losing app functionality.

## Data collected

| App Store category | Fields | Purpose | Tracking |
| --- | --- | --- | --- |
| Crash Data | Stack traces, exception details, crash signals, MetricKit diagnostic payloads | App Functionality | No |
| Performance Data | Launch time, hang information, memory and CPU measurements | App Functionality | No |
| Other Diagnostic Data | Device model, OS, app/build and SDK versions | App Functionality | No |
| Device ID | Random installation UUID, local Keychain, no iCloud sync | App Functionality | No |
| Product Interaction | Onboarding step, discovery path, authentication method | App Functionality | No |

Answer **Yes** to data collection. The installation ID links diagnostics to a
particular installation/device. Declare that linkage rather than claiming the
data is anonymous or unlinked merely because names are absent. No account names
or server addresses are attached to onboarding events. Crash messages can contain
incidental context.

[Apple's disclosure guidance](https://developer.apple.com/app-store/app-privacy-details/)
distinguishes diagnostic collection from advertising tracking. No ATT prompt is
introduced by this change. App Store Connect answers must cover each shipping
platform and must be updated by the release operator; this document does not
change the account's answers automatically.

## Retention and rights

The controller confirms backend retention of 30 days. The backend configuration
is outside this repository and must be verified before release. The installation
ID remains in local Keychain and may survive reinstallation. Disabling reports
does not delete the ID or already-uploaded reports.

Privacy settings show the current Diagnostics ID when available. Users can email
cedric.ziel@gmail.com for access, restriction, or deletion requests, including the
ID if available. The public privacy policy describes objection and complaint
rights. Settings opt-outs take effect for new events and subsequent export
batches; requests already in flight may finish.

## Verification

- Fresh preferences enable both categories without a modal prompt.
- Saved disabled values and legacy declines stay disabled across launches.
- Each Settings switch persists independently.
- Disabled categories drop exporter batches and flush requests.
- Re-enabling crash reports initializes the bridge without installing handlers twice.
- Onboarding and privacy links remain usable on each shipping platform.
- The privacy policy, store description, and release notes describe the default,
  identifier, and Settings opt-out consistently.
