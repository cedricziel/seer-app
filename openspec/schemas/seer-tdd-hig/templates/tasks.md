<!--
TDD discipline (REQUIRED): Tests group MUST come before Implementation.
Pure refactor / docs / config-only? Add: <!-- TDD-EXEMPT: <reason> -->
-->

## 1. Setup

- [ ] 1.1 <!-- Prep work, scaffolding, dependencies -->

## 2. Tests (red)

- [ ] 2.1 <!-- Failing test — covers Scenario: <name from spec> -->
- [ ] 2.2 <!-- Failing snapshot/UI test for iPhone compact -->
- [ ] 2.3 <!-- Failing snapshot/UI test for iPad regular (split-view) -->
- [ ] 2.4 <!-- Failing focus-engine test for tvOS (omit if iOS-only) -->

## 3. Implementation (green)

- [ ] 3.1 <!-- Minimum code to pass 2.1 — makes 2.1 pass -->
- [ ] 3.2 <!-- Compact-width layout — makes 2.2 pass -->
- [ ] 3.3 <!-- Regular-width / split-view layout — makes 2.3 pass -->

## 4. HIG verification

- [ ] 4.1 <!-- Dynamic Type AX5 on iPhone portrait + landscape -->
- [ ] 4.2 <!-- iPad split-view 1/3, 1/2, 2/3 + Stage Manager resize -->
- [ ] 4.3 <!-- tvOS focus path + safe zones (omit if iOS-only) -->
- [ ] 4.4 <!-- VoiceOver order, Reduce Motion, Increase Contrast -->

## 5. Refactor (optional)

- [ ] 5.1 <!-- Cleanup with tests staying green -->
