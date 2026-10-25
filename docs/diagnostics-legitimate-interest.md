# Diagnostics legitimate-interest assessment

Decision date: 25 October 2026. Controller: Cedric Ziel, contact
cedric.ziel@gmail.com. Applies to Flowmark Media diagnostics on iOS, tvOS, and
macOS. This records the controller's assessment, not a regulatory approval.

## Purpose

The interest is maintaining a reliable app: identifying crashes, finding
performance regressions, and locating failures in connection onboarding.
Diagnostics are not used for advertising, cross-service tracking, content
recommendations, or measuring viewing habits.

The selected basis is GDPR Article 6(1)(f). The assessment follows the purpose,
necessity, and balancing tests described in the
[EDPB legitimate-interest guidance](https://www.edpb.europa.eu/system/files/2024-10/edpb_guidelines_202401_legitimateinterest_en.pdf).
[GDPR Articles 6, 13, 17, and 21](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
address the basis, transparency, erasure, and objections. Apple's
[App Review Guideline 5.1.1(ii)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
allows a lawful legitimate-interest basis subject to applicable legal conditions.

## Necessity

Stack traces and exception details locate defects that aggregate counters cannot
explain. Launch, memory, and CPU measurements expose regressions across app and
OS versions. Onboarding step, discovery path, and authentication-method events
help locate connection failures without collecting server addresses or names.

A random app-owned installation ID distinguishes repeated reports from one
installation from faults affecting many installations. It is stored locally in
Keychain without iCloud synchronization. The redundant vendor identifier is
removed from the telemetry resource. The ID can survive reinstallation; it is
not an account identifier. Reports are treated as pseudonymous.

Local logs and voluntary reports alone miss unattended failures and provide no
consistent denominator for recurrent issues. Collection is limited to diagnostics
and the onboarding events listed above. Broader product analytics require a new
assessment; this decision does not authorize arbitrary event collection.

## Balancing and safeguards

Users benefit from stability, but may reasonably expect a media client to contact
only their configured servers. Earlier releases explicitly promised opt-in.
Preserve every saved disabled preference, including a legacy decline with missing
category values. Disclose the changed default in release notes, the privacy
policy, and Privacy settings. Do not infer permission to override an objection.

Persistent correlation and contextual crash messages create privacy risks.
Do not attach account names, credentials, media titles, or server addresses to
onboarding events. Crash exceptions can contain incidental context; do not claim
that all reports are anonymous or contain no personal information. Restrict
backend access to diagnostics work, prohibit joining with account or advertising
data, and review captured fields when instrumentation changes.

Crash and performance controls are independent, device-local, and available in
Server Management > Privacy & Diagnostics. Disabling a category stops new events
and drops its subsequent export batches. Requests already in flight may finish.
No durable offline span buffering is used. Disabling both does not impair media
functionality. Settings display the current Diagnostics ID, when available, so
users can include it in access, restriction, or erasure requests to the contact
above. Disabling reports does not itself erase uploaded data or the Keychain ID.

The controller confirms a 30-day backend retention period. This repository does
not configure or independently verify backend retention or access controls;
verify both operationally before release. Review deletion requests using the
installation ID without requesting unnecessary account details.

## Decision and review

The controller selects legitimate interest for this limited diagnostic purpose
with these safeguards and an unconditional Settings opt-out. The decision does
not rely on the data being anonymous. A privacy notice must describe the purpose,
recipients, retention, objection route, and access/deletion contact.

Reassess before adding payload fields, identifiers, destinations, purposes, or
retention. Reassess if children use the service, an objection reveals unexpected
impact, or backend practices change. Do not extend this assessment to advertising
or broader behavioral analytics.
