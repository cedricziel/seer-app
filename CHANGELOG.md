# Changelog

## [0.6.0](https://github.com/cedricziel/seer-app/compare/v0.5.0...v0.6.0) (2026-05-03)


### Features

* **telemetry:** enable OTLP shipping in TestFlight builds ([441dd01](https://github.com/cedricziel/seer-app/commit/441dd01ecbb6c9a52a814d5ebc6eda3581747970))

## [0.5.0](https://github.com/cedricziel/seer-app/compare/v0.4.1...v0.5.0) (2026-05-03)


### Features

* **library:** add Jellyfin person details screen ([#30](https://github.com/cedricziel/seer-app/issues/30)) ([f432fa5](https://github.com/cedricziel/seer-app/commit/f432fa5c56dc314b02489554f3d14690df90a2fe))

## [0.4.1](https://github.com/cedricziel/seer-app/compare/v0.4.0...v0.4.1) (2026-05-03)


### Bug Fixes

* **playback:** nonisolated MPMediaItemArtwork handler to stop SIGTRAP ([#28](https://github.com/cedricziel/seer-app/issues/28)) ([939acec](https://github.com/cedricziel/seer-app/commit/939acecdab4aaf3609563860f33ac565fb78d7b3))

## [0.4.0](https://github.com/cedricziel/seer-app/compare/v0.3.0...v0.4.0) (2026-05-03)


### Features

* **app-intents:** AppEntity foundation ([#19](https://github.com/cedricziel/seer-app/issues/19)) ([4751d3c](https://github.com/cedricziel/seer-app/commit/4751d3ceeef814397f74bffd1578e82591d0c4ce))
* **app-intents:** AppShortcutsProvider + Spotlight + URL router ([#24](https://github.com/cedricziel/seer-app/issues/24)) ([56cdf75](https://github.com/cedricziel/seer-app/commit/56cdf75683aa6efcdd5107fc7c632f442411bce7))
* **app-intents:** proposal + setup foundation ([#18](https://github.com/cedricziel/seer-app/issues/18)) ([3204f96](https://github.com/cedricziel/seer-app/commit/3204f969172b9c469b100d3dcaf4d61ae4d7ccdc))
* **app-intents:** Tier 1 verb intents — Request, Search, Resume ([#21](https://github.com/cedricziel/seer-app/issues/21)) ([1e3b075](https://github.com/cedricziel/seer-app/commit/1e3b075a08188cb65f8041ffe87a2241c744bc50))
* **app-intents:** Tier 2 verb intents + RequestsViewModel cache writer ([#23](https://github.com/cedricziel/seer-app/issues/23)) ([a1498c2](https://github.com/cedricziel/seer-app/commit/a1498c2f92bc5b4ac77a0ed9786ce75386a58963))
* **app-intents:** Tier 3 — INPlayMediaIntent donation + Focus Filter ([#25](https://github.com/cedricziel/seer-app/issues/25)) ([f5d1bb1](https://github.com/cedricziel/seer-app/commit/f5d1bb14841fe0bbc4d781a3b5adcc918c1bf486))
* **app-intents:** wire production seams from SeerApp.setupServices ([#27](https://github.com/cedricziel/seer-app/issues/27)) ([a6d80c3](https://github.com/cedricziel/seer-app/commit/a6d80c3c35fb11d7cf4ef2675223fa6059a22786))


### Bug Fixes

* **playback:** drive Now Playing time updates from VM observer ([#20](https://github.com/cedricziel/seer-app/issues/20)) ([1019269](https://github.com/cedricziel/seer-app/commit/101926932bd88263d0ab85492bae1b523fa31a66))

## [0.3.0](https://github.com/cedricziel/seer-app/compare/v0.2.5...v0.3.0) (2026-05-02)


### Features

* address five quick-win user workflow improvements ([#14](https://github.com/cedricziel/seer-app/issues/14)) ([2ff0752](https://github.com/cedricziel/seer-app/commit/2ff075266b509fcb5750f1d39c6f562f27ffd4b6))
* **fastlane:** manage App Store metadata via deliver ([6cdafe0](https://github.com/cedricziel/seer-app/commit/6cdafe0a6549bb13778ffc3d3beeadf9cb6f6a70))
* **jellyfin-client:** add BonjourDiscovery and QuickConnectSession ([ce50f3c](https://github.com/cedricziel/seer-app/commit/ce50f3cb54bcdbe9a8045f402b17077631d0946e))
* **jellyseerr:** defer connect to on-demand prompts ([afb2525](https://github.com/cedricziel/seer-app/commit/afb252515303734df12daa47f312c11488c8da76))
* **onboarding:** adapt WelcomeView for landscape and iPad split ([ac5eca5](https://github.com/cedricziel/seer-app/commit/ac5eca5ce9c89522480c4e288a2031db02623c1d))
* **onboarding:** add Bonjour entitlement + streamlined-onboarding flag ([0f298da](https://github.com/cedricziel/seer-app/commit/0f298da4a853931cd64f40a05943273cba328589))
* **onboarding:** add WelcomeView, QuickConnectView, ManualServerEntryView ([2c89ff0](https://github.com/cedricziel/seer-app/commit/2c89ff0a4769c650c295211afe92197c4e41dd59))
* **onboarding:** cutover — flip flag default + docs update ([8c26426](https://github.com/cedricziel/seer-app/commit/8c264263cb77eb2ba770c113346d397e9651c292))
* **onboarding:** HIG audit pass + accessibility fixes ([59408fe](https://github.com/cedricziel/seer-app/commit/59408fe62263c8b7596b891b8d386a41575146c0))
* **onboarding:** tvOS adaptation + cross-platform color cleanup ([850ea63](https://github.com/cedricziel/seer-app/commit/850ea636aca0cc7e31ef716ed6d00f58e7169cf7))
* **onboarding:** wire OnboardingViewModel + flag-gated ContentView ([f2e679b](https://github.com/cedricziel/seer-app/commit/f2e679bde244790122b67c4ceedf7b1861cbf683))
* **playback:** enable AirPlay routing + Now-Playing metadata ([#17](https://github.com/cedricziel/seer-app/issues/17)) ([8c73a37](https://github.com/cedricziel/seer-app/commit/8c73a37bcac4a2a4be715346210e5d20a706ac23))
* **screenshots:** add fastlane snapshot setup driving the demo Jellyfin server ([67de04b](https://github.com/cedricziel/seer-app/commit/67de04bd02131ce996dc06b1e2a2344ff8552b52))
* **screenshots:** add local Jellyfin Docker instance for screenshot runs ([75a8828](https://github.com/cedricziel/seer-app/commit/75a8828bd42f6a16639a64745cad5b1a05e6c590))
* **screenshots:** make UI test parametric and dismiss Save Password ([0fdeada](https://github.com/cedricziel/seer-app/commit/0fdeadaf1675bbcc6d71b5c51e3b022faf00c4ef))
* **seer-core:** add ServerInfoFetcher and reachability fallback ([3bfef9c](https://github.com/cedricziel/seer-app/commit/3bfef9c94bf5d46c95b5da60580d2dcdea8df3e2))
* **seer-ui:** add JellyseerrConnectSheet with snapshot coverage ([b3bf7cd](https://github.com/cedricziel/seer-app/commit/b3bf7cd6822e0c067d3e8535edb142181229adde))
* **site:** publish privacy policy and landing page via GitHub Pages ([e2e2cda](https://github.com/cedricziel/seer-app/commit/e2e2cdab13f68681cf53baab7ed05cc032a2a178))
* **telemetry:** onboarding funnel events + gitignore housekeeping ([0119e89](https://github.com/cedricziel/seer-app/commit/0119e8965faaa8682da7e27495d985a9e632d052))


### Bug Fixes

* **auth:** never show raw HTTP response bodies in auth error alerts ([7d9c9b1](https://github.com/cedricziel/seer-app/commit/7d9c9b1b1be9b454af4eec1614578e6cd6b37382))
* **fastlane:** clear stray hex-dump content from demo_password.txt ([4595b14](https://github.com/cedricziel/seer-app/commit/4595b1412cdac4359b20bb6b502d538a5bd08569))
* **screenshots:** work around iOS 26.4.1 simulator destination mismatch ([8a0dbfb](https://github.com/cedricziel/seer-app/commit/8a0dbfb3c2c2bd62ff1eadd4436c340e07c058be))

## [0.2.5](https://github.com/cedricziel/seer-app/compare/v0.2.4...v0.2.5) (2026-05-02)


### Bug Fixes

* **release:** drop bogus upload_symbols calls ([a369590](https://github.com/cedricziel/seer-app/commit/a369590d763ba25a5c1bd82026d5a2a573a351a2))

## [0.2.4](https://github.com/cedricziel/seer-app/compare/v0.2.3...v0.2.4) (2026-05-02)


### Bug Fixes

* **release:** call setup_ci to unblock codesign on GitHub runners ([a088aca](https://github.com/cedricziel/seer-app/commit/a088aca2d1a27ecbdaf10a10b7a3e6216bede444))

## [0.2.3](https://github.com/cedricziel/seer-app/compare/v0.2.2...v0.2.3) (2026-05-02)


### Bug Fixes

* **release:** pin manual signing settings in project.yml ([3ec2ae9](https://github.com/cedricziel/seer-app/commit/3ec2ae9f18ce9256880f62e3801ae8ce741f0d96))

## [0.2.2](https://github.com/cedricziel/seer-app/compare/v0.2.1...v0.2.2) (2026-05-02)


### Bug Fixes

* **release:** sync both dev and appstore signing in beta lane ([ccf54b3](https://github.com/cedricziel/seer-app/commit/ccf54b3c1797336939c12198fe349bb1b6582518))

## [0.2.1](https://github.com/cedricziel/seer-app/compare/v0.2.0...v0.2.1) (2026-05-02)


### Bug Fixes

* **release:** restrict archive to iOS + split GitHub environments ([eafb1a9](https://github.com/cedricziel/seer-app/commit/eafb1a9c3a0d16afd73a1642c7cc5c9f42348d63))

## [0.2.0](https://github.com/cedricziel/seer-app/compare/v0.1.0...v0.2.0) (2026-05-01)


### Features

* **accessibility:** add VoiceOver support and reduce motion compliance ([8786f54](https://github.com/cedricziel/seer-app/commit/8786f54798ca5ed587e26d126427cdd6c1b51de7))
* add app icon with orange/gold eye design ([a517185](https://github.com/cedricziel/seer-app/commit/a5171852f72f64351bf513b887368370f420ff1c))
* add iCloud Keychain sync for cross-device credentials ([063882c](https://github.com/cedricziel/seer-app/commit/063882cbd363c63f12ecfd5e5651f50a2ee9b0c0))
* add multi-server support with iCloud sync ([ba0a2a9](https://github.com/cedricziel/seer-app/commit/ba0a2a9c06fb1a03fc5c5d40c1302d9ff7ddcc93))
* **build:** add automatic build number incrementing for App Store/TestFlight ([65187f2](https://github.com/cedricziel/seer-app/commit/65187f22d27b6c35e2060b62575ba9401729f8e7))
* **ci:** add fastlane pipeline with match and GitHub Actions ([dc3455e](https://github.com/cedricziel/seer-app/commit/dc3455e59854dc080a42fa1e2647b21079bffa36))
* **discover:** add Jellyseerr-powered content discovery ([36a68ae](https://github.com/cedricziel/seer-app/commit/36a68aef17f12cd0a9a07d1f9ed30d1a62f4a7ed))
* **downloads:** add thumbnail images to download list ([5c704bd](https://github.com/cedricziel/seer-app/commit/5c704bd10418d1e21641c63989d3713a352e9176))
* initial Jellyfin + Jellyseerr iOS MVP implementation ([9bab0a2](https://github.com/cedricziel/seer-app/commit/9bab0a2e2b6f1853a4bf66e764851e77070ac8a9))
* **library:** add loading states and empty states to library sections ([74ce47e](https://github.com/cedricziel/seer-app/commit/74ce47e658d5321e84842be8e5458af5aa73efa9))
* **library:** add season/episode breakdown and fix request button visibility ([a58ef9f](https://github.com/cedricziel/seer-app/commit/a58ef9f5153c1fe5def43b68498b34febb6d18bd))
* **media:** add format info display and Errata SDK integration ([e7e4cb6](https://github.com/cedricziel/seer-app/commit/e7e4cb63fcb4774661bc8156076d7c81155c7e56))
* **network:** add internal URL per server and WiFi-only download enforcement ([4789ad4](https://github.com/cedricziel/seer-app/commit/4789ad47b693d8450505905c76e4bb62d78742ad))
* **notifications:** add local notification system for downloads and requests ([9af796c](https://github.com/cedricziel/seer-app/commit/9af796cee6c471b47c9288383c0e55032c74d796))
* **offline:** add offline library browsing with SwiftData caching ([c2dffca](https://github.com/cedricziel/seer-app/commit/c2dffcaa341d10d917abb3571b8c0e78a55f14ad))
* **offline:** add offline media storage with background downloads ([f497ba5](https://github.com/cedricziel/seer-app/commit/f497ba5e13a9baf4c5efec20c2477d0c530bedb7))
* **onboarding:** add What's New modal and first-time user guidance ([95e9855](https://github.com/cedricziel/seer-app/commit/95e9855c3b41003e50a3c950e2c5687cdc93b628))
* **playback:** add double-tap to seek gesture for HIG compliance ([b6442e5](https://github.com/cedricziel/seer-app/commit/b6442e5275d327ede4f4bdf68d8f6872b1a891fb))
* **playback:** add HLS transcoding fallback for incompatible formats ([f9f6aaa](https://github.com/cedricziel/seer-app/commit/f9f6aaad28e6a4d317854d88612217c9a260682a))
* **playback:** add video playback support for iOS/iPadOS ([8190366](https://github.com/cedricziel/seer-app/commit/819036685efa7039561be937a89e8914ccde76da))
* **privacy:** add MetricKit diagnostics and in-app feedback with consent ([3798740](https://github.com/cedricziel/seer-app/commit/3798740604da3b0aa4cb3c9d84c3ae0d21b21d99))
* **release:** consolidate full release flow into release-please ([6cbf25e](https://github.com/cedricziel/seer-app/commit/6cbf25e094a118630451794431820907ab868f6c))
* **release:** graduate-to-App-Store via GitHub release flag ([95f7441](https://github.com/cedricziel/seer-app/commit/95f7441e2362f3d0675cfa9d80038751b5cacc39))
* **requests:** add media availability status and fix permissions loading ([1fa1edd](https://github.com/cedricziel/seer-app/commit/1fa1edda43c60d40f581540d562ad4db071358a9))
* **requests:** add OpenAPI client and enhanced request management ([b4c0857](https://github.com/cedricziel/seer-app/commit/b4c0857260801916214a24aebad39189660278ad))
* **storage:** migrate server configs from KVS to SwiftData + CloudKit ([0029587](https://github.com/cedricziel/seer-app/commit/00295871f0a39216ccbdcb21a7b6e31f634b9463))
* **sync:** add CloudKit sync status debugging ([3500b3b](https://github.com/cedricziel/seer-app/commit/3500b3b898dcb866939f4257b48a82fd030f8682))
* **telemetry:** add automatic HTTP request tracing ([215e00d](https://github.com/cedricziel/seer-app/commit/215e00d7fca9a52cc0ca63282a460e50182cfd6e))
* **telemetry:** add SignPost, Swift Logging, and offline persistence ([a8b8587](https://github.com/cedricziel/seer-app/commit/a8b85879434d48a5e1506fc61bc6f4c2bf38539b))
* **ui:** add context menus to media tiles and list items ([bbf5848](https://github.com/cedricziel/seer-app/commit/bbf5848ba78780140c13919d2a3130c0f3451015))


### Bug Fixes

* **accessibility:** ensure 44pt minimum touch targets per HIG ([4fd2179](https://github.com/cedricziel/seer-app/commit/4fd21791e137303f8a49f54ac2bc088657b29f2e))
* App Store release readiness improvements ([66dbc45](https://github.com/cedricziel/seer-app/commit/66dbc45b0c7978c0fcdc9dbff8069620ea782de3))
* **auth:** pass correct AppState to AuthViewModel ([03704af](https://github.com/cedricziel/seer-app/commit/03704afa8342c7aee5beadfcbe4210441f67132a))
* **build:** add CFBundleShortVersionString to framework targets ([298ef2f](https://github.com/cedricziel/seer-app/commit/298ef2fda295751a805e8beacf551a7b816ef08e))
* **build:** add encryption compliance declaration to Info.plist ([328cd77](https://github.com/cedricziel/seer-app/commit/328cd773b392492e35600457cdfc33db91b36c90))
* **ci:** drop unnecessary xcodegen step from lint job ([537964e](https://github.com/cedricziel/seer-app/commit/537964e4b1a777d52c7389ec60eb5291f46df9c7))
* **deps:** drop Dependabot entry for Xcode-managed SPM ([1d3381a](https://github.com/cedricziel/seer-app/commit/1d3381a4725c18864234a4f03309cc2590af9738))
* **deps:** use string-literal path in eval_gemfile ([cf2335a](https://github.com/cedricziel/seer-app/commit/cf2335aba38ec3c7be045e82f6f68e9f4b369b25))
* download buttons ([1095471](https://github.com/cedricziel/seer-app/commit/10954712583b7b2cff468e2d2c49a2dda119d041))
* **downloads:** configure DownloadManager when credentials become available ([e58d279](https://github.com/cedricziel/seer-app/commit/e58d279ceef63ab0c17b828b5caa16d7cb9091ac))
* **downloads:** create URLSession with delegate to enable callbacks ([e34181b](https://github.com/cedricziel/seer-app/commit/e34181b08f4300a6769eadc966dd54ccf4005b14))
* **downloads:** register DownloadManager as BackgroundSessionManager delegate ([b19cac5](https://github.com/cedricziel/seer-app/commit/b19cac53d630b2900323a713ebab3368a9e79f25))
* **downloads:** resolve race conditions and prevent duplicate background tasks ([2262b50](https://github.com/cedricziel/seer-app/commit/2262b500aaaab4c0e28cd9d8e5bf9e0605c95c4f))
* **downloads:** resolve temp file race condition at 100% completion ([958cd91](https://github.com/cedricziel/seer-app/commit/958cd9159bad5b44f420748f314b956060015df7))
* **library:** add task cancellation to prevent cancelled request errors ([054fd77](https://github.com/cedricziel/seer-app/commit/054fd770019d1f00bcca155c37024ed0e553b299))
* **library:** fix pull-to-refresh scroll position not resetting ([d9a19aa](https://github.com/cedricziel/seer-app/commit/d9a19aa39bfb3eb0f92bc0c8771ff18679a40a5a))
* **library:** resolve tap gesture not triggering playback in Continue Watching ([7ceebb9](https://github.com/cedricziel/seer-app/commit/7ceebb98132ebbf888dde0d7a8d917b959d9b7ae))
* **library:** resolve TV show seasons infinite loading state ([0d0c0cb](https://github.com/cedricziel/seer-app/commit/0d0c0cb73511d92b4fa8514583416930ef1a47f8))
* **playback:** make PiP restoration state testable ([328125d](https://github.com/cedricziel/seer-app/commit/328125d76e0986c902cc65f4eefaabdcaa5156d1))
* **playback:** resolve PiP navigation and restoration issues ([c609273](https://github.com/cedricziel/seer-app/commit/c6092735b918d0e551661dd1933a806e8ef62963))
* **playback:** resolve task cancellation error for recently added items ([96e4f09](https://github.com/cedricziel/seer-app/commit/96e4f0980ee2dc5eb9c2560bf3f272914b8229e9))
* **playback:** retain PiP delegate to enable UI restoration ([1d5f268](https://github.com/cedricziel/seer-app/commit/1d5f2688602c680b0fcda30e52b76a8013e88d59))
* resolve AppState issues and improve UI display ([f7531c0](https://github.com/cedricziel/seer-app/commit/f7531c03b502c9ecea2ba99452cdb719ded51362))
* resolve compiler warnings across multiple modules ([829f7a5](https://github.com/cedricziel/seer-app/commit/829f7a52044f9ee69d169452243102e6eb3418ce))
* **safety:** replace force unwraps with safe optional handling ([4227ba1](https://github.com/cedricziel/seer-app/commit/4227ba15569665193e05ecc07e80d0c9d9150a2c))
* **ui:** improve HIG layout and organization compliance ([0625149](https://github.com/cedricziel/seer-app/commit/062514967382333e37f29d64dfb1f3d92ebecc28))


### Performance Improvements

* **downloads:** add O(1) lookup for episode download states ([ad48f9d](https://github.com/cedricziel/seer-app/commit/ad48f9dc3cf9740cfc3b018a7053f640f88d2d4e))
