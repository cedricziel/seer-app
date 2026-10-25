## 1. Setup

- [x] 1.1 Inspect transfer, player, Downloads, persistence, and isolated verification paths.
- [x] 1.2 Define the offline-downloads scenarios and implementation ownership.
- [x] 1.3 run `make lint` and `make format`

## 2. Tests (red)

- [x] 2.1 Add cellular-policy tests for fresh and resumed background requests.
- [x] 2.2 Add HTTP rejection and successful-response preservation tests.
- [x] 2.3 Add completed movie and episode playback destination tests, including server identity and incomplete states.
- [x] 2.4 Add progress save, local resume, watched completion, failed sync, server isolation, and concurrent-save tests.
- [x] 2.5 run `make lint` and `make format`

## 3. Implementation (green)

- [x] 3.1 Enforce request cellular policy and reconcile resumed transfers, makes 2.1 pass.
- [x] 3.2 Validate HTTP responses before media finalization, makes 2.2 pass.
- [x] 3.3 Wire completed rows to native playback with stored server identity, makes 2.3 pass.
- [x] 3.4 Persist local progress and retry synchronization on reconnect, activation, and credential configuration, makes 2.4 pass.
- [x] 3.5 run `make lint` and `make format`

## 4. Verification

- [ ] 4.1 Run regression tests on an isolated simulator and build iOS and tvOS.
- [ ] 4.2 Check iPhone compact portrait and landscape, including Dynamic Type AX5.
- [ ] 4.3 Check iPad regular and split-view widths at 1/3, 1/2, and 2/3.
- [ ] 4.4 Check tvOS focus and remote playback activation and dismissal.
- [ ] 4.5 Check VoiceOver labels and order, Reduce Motion, and Increase Contrast.
- [x] 4.6 Update the project verify skill with offline coverage and validate this OpenSpec change.
- [x] 4.7 run `make lint` and `make format`

## 5. tvOS compilation repairs

- [x] 5.1 Reproduce unsupported Spotlight and MetricKit API failures in the native tvOS build.
- [x] 5.2 Isolate iOS system integrations and verify entity conformances against both SDKs, makes 5.1 pass.
- [x] 5.3 Verify unavailable control APIs against the tvOS SDK and add platform guards, native playback adaptation, and deletion alternatives, makes 5.1 pass.
- [ ] 5.4 Rebuild tvOS and rerun iOS regression tests with the platform repairs.
- [ ] 5.5 run `make lint` and `make format`
