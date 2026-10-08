# Exhibit Trail — Implementation Plan

## Scope and Architecture
Build a standard single-screen native Swift iPhone app first. Museum visitors create a local Visit, import one user-provided map image or PDF page, place normalized (0–1) pins on the map, assign priority and order, and check exhibits off while a foreground budget shows remaining visit time. Exhibit notes and optional photo attachments stay local; exported backups carry a version and manifest. Domain model in a small pure-Swift `ExhibitTrailKit` package, persistence through GRDB/SQLite, SwiftUI shell with a `ExhibitWorkspaceLayout` container. No automatic routing or floor sensing. No account, server, ads, analytics, automatic map acquisition, geolocation, beacon scanning, copyrighted exhibition content bundle, or unconsented metadata upload. A user must have rights to the floor plan they import or export.

## Technology Choices
- Xcode 26.0.1 (17A400), Swift 6, iOS 26+ SDK. `toolchain.json` is a planning pin, not proof of an installed toolchain or CI result.
- iPhone only: `TARGETED_DEVICE_FAMILY = 1` in every app build configuration and project generator. Native iPad support is disabled. Apple CI must check built `UIDeviceFamily == [1]`.
- `com.infinityball.exhibittrail` is the exact bundle ID: `PRODUCT_BUNDLE_IDENTIFIER`, Info.plist, signing/provisioning, and any extension must match.
- SwiftUI/UIKit with Core Graphics for map rendering; Files / Photos picker for user-chosen source assets. GRDB/SQLite on-device for metadata; app-support file directory for copied owned assets with stable IDs. Use path validation on restore; file-provider grants are not durable storage.
- One deterministic, pure-Swift pacing reducer: explicit wall-clock deadline minus now and user-estimated transit buffer; no promise of physical route time, alerts, or actual closing time. No new dependency needed for this math. Saved visits use versioned schema and migration tests.
- No Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity. Android is out of scope; native iPad support requires explicit user opt-in. No unavailable fold APIs.

## Milestones and Dependency Order
1. Skeleton: Xcode project, pure-Swift domain package, minimal SwiftUI view, iOS 26 target, native Apple CI enforcing bundle/device/SDK/network contracts. No tablet mode.
2. Data: visit/stop/order/priority/attachment schema and migrations, unknown-safe state and file lifetime, tests.
3. Canvas: user-imported image or PDF first page; normalized pin placement and zoom; tests for rotation/resize/coordinate persistence. No automatic navigation.
4. Pace: foreground visit countdown, explicitly user-defined transit buffer, recompute on reordering/undo, overdue/empty states. Unit tests with injected clock; no local push notifications required.
5. Journal: notes, user-selected photo copies, reversible mark-viewed with an auditable history and deletion cleanup; accessible controls.
6. Portable export: versioned JSON archive and CSV with optional chosen assets, preview/rollback on restore, sandboxed path safety; `ExhibitWorkspaceLayout` adapts a single-screen queue/map switching view. iPhone Duo future target: map on one display, controls/notes on another once native APIs exist; no iPad assumption.
7. Release: review `AppStore/description.txt` against working capabilities; generate real `AppStore/icon.png` with `hermes-image-gen` using the fleet brief, wire Xcode asset catalog, then port release workflow and measure signed upload.

## Testing Strategy
- Unit tests for stop priority ordering, unknown/unavailable map state, normalized coordinates, time budgets at deadline and clock jumps, reversible completion, invalid/malicious restore archives, and round-trip exports.
- Apple CI on macos-26 measures exact Xcode 26.0.1/17A400, iOS 26+ SDK, iPhone simulator build, built `UIDeviceFamily == [1]` and real accessibility tests for map pins/voiceover labels/dynamic type/contrast. Linux-only source checks never claim an archive.
- Zero-network contract tests inspect linked frameworks and usage descriptions; manual offline airplane-mode QA for importing user-provided map and journal export. No venue-position claims without real test evidence.

## Packaging and Distribution
- Register `com.infinityball.exhibittrail` in App Store Connect: CREATED; four repository Actions secrets are already configured (names only): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID`.
- Packaging issue implements `.github/workflows/release.yml` by porting `rwrife/cook-console` (also green in rise-log, split-slip, catch-tally): `v*` tag/manual dispatch on macos-26, enforce iOS 26+ SDK, install ASC API key mode 600 without logging values, archive/export signed IPA, upload via App Store Connect API, await processing, publish GitHub release. No prose-only release completion and no fabricated TestFlight result.
- App Store listing copy lives in `AppStore/description.txt`; actual opaque square no-text icon goes to `AppStore/icon.png`, generated only via `hermes-image-gen` after inspecting the repo/listing and wired into Xcode app icon set. Missing model is a blocker for release, never a placeholder license.

## Risks and Non-Goals
- Map licensing: user-provided plans only; do not bundle copyrighted museum maps. Exports warn that imported material may be rights-controlled.
- Large PDFs and image ingestion: bound size/page count, reject dangerous paths, preserve original source and support explicit deletion.
- Unknown floor transit and opening hours: paced target is an estimate, not a routing or accessibility promise.
- No Bluetooth beacons, GPS location tracking, venue ticketing, cloud, AI tour narration, cross-platform runtime, Android or iPad release work.
