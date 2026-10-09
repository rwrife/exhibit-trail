# Exhibit Trail

Offline iPhone museum companion: pin a shortlist onto your own floor plan, pace a time-limited visit, and keep exhibit notes without accounts or location tracking.

## Overview and Pitch
Exhibit Trail is an offline, local-first iPhone companion for museum and gallery visitors who want to see their priority works without museum fatigue, crowd panic, or invasive venue apps. It turns any user-provided floor-plan photo or brochure PDF into a visual exhibit canvas, anchors a bounded priority shortlist, and computes an honest pacing budget against your available time—entirely on-device with zero runtime network access and no background location tracking.

## Motivation
Visiting a large museum usually breaks down into two bad experiences: wandering aimlessly until closing time cuts off the two things you came to see, or installing a proprietary venue app that demands an account, pushes Bluetooth beacons, tracks indoor location, and relies on flaky venue Wi-Fi. Exhibit Trail solves this by letting the visitor own the map, the shortlist, and the clock. You snap a picture of the paper museum guide or load an official PDF map, drop pins for your must-see exhibits, set your available visit duration, and follow a clear, glanceable trail.

## Target Users
- Travelers and museum members with 45 to 180 minutes who want to see specific galleries without rushing or getting lost.
- Parents, educators, and small groups managing scheduled entry times, museum fatigue, and timed exits.
- Art and history lovers who want private, self-contained journals of what they saw with their own photos and thoughts.
- Privacy-conscious cultural visitors who reject mandatory venue accounts, Bluetooth beacon telemetry, and indoor location tracking.

## Concrete Use Cases
1. **The Two-Hour Wing Visit:** You have 90 minutes before an exhibition hall closes. You import the museum map PDF, pin five key sculptures, mark their galleries, and allocate 12 minutes per stop. The planned foreground pacing view helps you decide whether to shorten the next stop; it does not know corridor travel times or venue opening hours.
2. **Special Exhibition Checklist:** You enter a temporary blockbuster show with a paper room pamphlet. You snap a photo of the room layout, tap to pin six numbered display cases in your target sequence, and check them off as you reach each room.
3. **Personal Cultural Journal:** While standing in front of an ancient manuscript, you jot down two sentences of impressions and attach an on-device photo. When your visit ends, you export a clean, self-contained Markdown/JSON visit dossier or CSV summary to keep forever.

## How to Use / Intended End-to-End Workflow
1. **Create a Visit:** Name the venue (e.g. *Metropolitan Museum — European Paintings*), choose optional scheduled entry and exit times, and pick an available target visit duration.
2. **Load the Floor Plan:** Select an on-device floor-plan photo or browse an imported PDF brochure page. The image renders locally as an inspectable, zoomable canvas.
3. **Pin Your Shortlist:** Tap locations on the floor plan to drop numbered or labeled exhibit pins. Mark each pin as `must-see`, `interested`, or `bonus`.
4. **Pace the Trail:** Exhibit Trail calculates a pacing budget: time per remaining priority exhibit, recommended transit buffers between rooms or floors, and a calm countdown to your planned departure.
5. **Log Impressions:** As you view each exhibit, tap to mark it viewed, record private impressions, and optionally attach local photos.
6. **Export Your Visit:** Export a portable visit archive (JSON with photo references, or CSV summary) to Files or share sheet.

## MVP Feature List and Non-Goals
### MVP Features
- Pure on-device visit ledger: venue name, date, target duration, entry/exit time targets.
- Local floor-plan viewer supporting user-imported images and single-page PDF maps.
- Interactive shortlist pins with priority tiers (`must-see`, `interested`, `bonus`) and optional gallery/room tags.
- Deterministic pacing budget: calculates remaining time per unviewed exhibit and warns when scheduled time is slipping.
- Lightweight exhibit notes with optional local photo attachments picked by the user.
- Reversible check-off flow: mark exhibits visited, undo accidents, and track visit completion.
- Portable, user-owned exports: complete JSON visit export and CSV shortlist summaries.
- Zero-network architecture: app contains zero analytics, trackers, ad SDKs, or cloud synchronization.

### Non-Goals
- No indoor Bluetooth beacon or Wi-Fi triangulation indoor positioning.
- No GPS tracking or background location services.
- No third-party museum ticketing, ticketing API integration, or audio guide rights management.
- No cloud accounts, social feeds, crowd heatmaps, or public leaderboards.
- No cross-platform or hybrid frameworks: no Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity.
- Native iPad support is disabled by default (no iPad multitasking, split view, or iPad App Store assets in MVP).

## Privacy, Permissions, and Data-Storage Behavior
- **Zero Network:** All data remains strictly on your iPhone. There are no remote servers, analytics beacons, or advertising frameworks.
- **Minimal Permissions:** Only standard system photo-picker / document-picker access is used to import floor plans and attach user-chosen photos. No background location or CoreLocation usage.
- **Local Storage:** SQLite backed by GRDB stores visits, maps, pins, and notes on-device in the app's sandboxed application-support directory.
- **Export & Backup:** JSON/CSV export through the iOS share sheet is planned for issue #6.

## Platform and Toolchain Policy
- Target platform: Native Swift (SwiftUI / UIKit) iPhone-only iOS app.
- Platform constraints: `TARGETED_DEVICE_FAMILY = 1` in all targets; native iPad support is disabled.
- Toolchain: Pinned to Xcode 26.0.1 (Build 17A400), iOS 26+ SDK, and Swift 6.
- Bundle Identifier: The iOS bundle identifier is `com.infinityball.exhibittrail` and matches `PRODUCT_BUNDLE_IDENTIFIER`. App Store Connect bundle ID is registered as `com.infinityball.exhibittrail`.
- Prohibited Frameworks: Prohibited frameworks include Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, and Unity.

## iPhone Duo Dual-Screen Design Target
Under the Apple iPhone Duo focus, Exhibit Trail is designed around the future dual-screen phone experience:
- When unfolded, the persistent visual floor-plan canvas lives on one display while the active shortlist queue, pacing countdown, and note-taking deck occupy the second display.
- Planned seam: Issue #6 introduces `ExhibitWorkspaceLayout`. The current skeleton uses one ordinary SwiftUI view; no dual-screen behavior exists.
- No fold SDK dependency: The app relies exclusively on standard SwiftUI presentation primitives today and does not import or depend on unavailable foldable SDK APIs.

## Current Status and Milestones
- **Status:** M1 skeleton landed. The repo now carries `ExhibitTrail.xcodeproj`, the pure-Swift `Packages/ExhibitTrailKit` package, a minimal SwiftUI shell, and CI enforcing the toolchain pin, iPhone-only device family, zero-network and native-only contracts. M2 now provides versioned GRDB local storage and bounded asset copying, initialized by the app. The shell has no editing/import controls yet; map canvas, pacing, journal UI, export, icon and release Action remain issues #3–#7. Features below describe intended behavior, not available functionality.
- **M1 (Project Skeleton & CI):** Native Swift package / Xcode project structure, Swift 6 compiler flags, zero-network CI contract gate, and iPhone-only device enforcement.
- **M2 (Domain & Storage):** `ExhibitTrailKit` visit/ordered-stop models and versioned GRDB storage for normalized pins, notes and owned PDF/PNG/JPEG attachments. Pacing math remains M4.
- **M3 (Floor Plan Canvas & Pinning):** Zoomable floor plan renderer, coordinate-mapped pin placement, and shortlist prioritization.
- **M4 (Visit Pacing Engine):** Monotonic pacing timer, remaining-time calculation, room transition buffers, and visit progress tracking.
- **M5 (Exhibit Journal & Local Attachments):** Impression notes, local image attachments, and unviewed/viewed toggle states.
- **M6 (iPhone Duo Seam & Export):** Single-screen navigation with the `ExhibitWorkspaceLayout` dual-screen abstraction seam, plus JSON/CSV export.
- **M7 (Packaging & App Store Connect):** App Store listing copy review, real generated icon at `AppStore/icon.png`, and automated TestFlight release workflow.

## Development Quickstart
Clone with `gh repo clone rwrife/exhibit-trail`. On a Mac with Xcode 26.0.1 (17A400), open `ExhibitTrail.xcodeproj` and run the `ExhibitTrail` scheme on an iPhone simulator.

```sh
swift test --package-path Packages/ExhibitTrailKit
python3 scripts/check_contract.py
bash scripts/check_zero_network.sh
bash scripts/check_native_only.sh
# Apple toolchain only; unsigned simulator build, not an archive or UI run:
xcodebuild -project ExhibitTrail.xcodeproj -scheme ExhibitTrail \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Release CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath DerivedData build
python3 scripts/check_contract.py DerivedData/Build/Products/Release-iphonesimulator/ExhibitTrail.app
```

Linux requires `apt-get update && apt-get install -y libsqlite3-dev` in `swift:6.2-noble` before running `swift test --scratch-path /tmp/exhibit-build --package-path /src/Packages/ExhibitTrailKit`; it cannot build SwiftUI or validate the simulator app. CI tests the package on Linux and the exact Apple toolchain, builds the iPhone simulator app, then measures its Info.plist and linked frameworks. No launch/UI test, archive, signing or TestFlight evidence is claimed by this bootstrap. The icon is intentionally absent until issue #7 supplies real generated artwork; no placeholder is shipped.

## iOS Signing and TestFlight Release Plan
Packaging issue #7 must implement `.github/workflows/release.yml`, porting the proven template from `rwrife/cook-console` (also verified in `rwrife/rise-log`, `rwrife/split-slip`, and `rwrife/catch-tally`).
- Triggered by `v*` tag push or manual `workflow_dispatch`.
- Runs on GitHub-hosted `macos-26` runner with iOS 26+ SDK enforcement.
- Configures credentials securely using GitHub Actions repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, and `ASC_TEAM_ID`.
- Exports signed IPA archive with `TARGETED_DEVICE_FAMILY = 1` and uploads to TestFlight using the official App Store Connect API.
- Generates a matching GitHub release with build artifacts.

Storage uses one `VisitStore` actor per app-support directory. Canonical lowercase UUIDs identify visits, stops and attachments. Array order is explicit and independent of priority. Missing completion evidence remains `unknown`; a missing owned file throws `missingAttachment` without changing a stop. Migration v1 stores visits/stops; v2 adds unknown-safe notes/completion and attachments.

Selected local regular files are streamed in 64 KiB chunks, capped at 20 MiB, checked for PDF/PNG/JPEG magic, and copied to generated immutable sandbox filenames. The signatures identify types; decoding/rendering belongs to the canvas issue. Optional dimensions must be finite and positive, at most 100,000. Traversal and symlink paths are rejected. Provider grants and source paths are never persisted. Attachment replacements commit a new file reference transactionally before retiring the old file. Deletion queues durable file cleanup in the same DB transaction; cleanup is best effort after commit, with failed deletions retained in the durable queue. Explicit `cleanup()` reports errors and can retry after restart. Mutation methods throw only before commit, preserving the prior state on write failure. Files copied just before a process crash may remain unreferenced; no viewed state is inferred from files or their absence.

GRDB is pinned to 7.11.1 / `b83108d10f42680d78f23fe4d4d80fc88dab3212` in both package and app workspace lockfiles. Its local manifest/changelog review confirms Swift 6.1+ support and system SQLite on Linux, compatible with Swift 6.2 and Xcode 26.0.1. Runtime source gates remain unchanged; dependency retrieval is a build-time operation.
