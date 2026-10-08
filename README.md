# Exhibit Trail

Offline iPhone museum companion: pin a shortlist onto your own floor plan, pace a time-limited visit, and keep exhibit notes without accounts or location tracking.

## Overview and Pitch
Exhibit Trail is an offline, local-first iPhone companion for museum and gallery visitors who want to see their priority works without museum fatigue, crowd panic, or invasive venue apps. It turns any user-provided floor-plan photo or brochure PDF into a visual exhibit canvas, anchors a bounded priority shortlist, and computes an honest pacing budget against your available time—entirely on-device with zero network access and no background location tracking.

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
- **Local Storage:** SQLite backed by GRDB stores visits, maps, pins, and notes on-device in the app's sandboxed document container.
- **Export & Backup:** Complete user data can be exported as standard JSON or CSV files through the iOS share sheet at any time.

## Platform and Toolchain Policy
- Target platform: Native Swift (SwiftUI / UIKit) iPhone-only iOS app.
- Platform constraints: `TARGETED_DEVICE_FAMILY = 1` in all targets; native iPad support is disabled.
- Toolchain: Pinned to Xcode 26.0.1 (Build 17A400), iOS 26+ SDK, and Swift 6.
- Bundle Identifier: The iOS bundle identifier is `com.infinityball.exhibittrail` and matches `PRODUCT_BUNDLE_IDENTIFIER`. App Store Connect bundle ID is registered as `com.infinityball.exhibittrail`.
- Prohibited Frameworks: Prohibited frameworks include Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, and Unity.

## iPhone Duo Dual-Screen Design Target
Under the Apple iPhone Duo focus, Exhibit Trail is designed around the future dual-screen phone experience:
- When unfolded, the persistent visual floor-plan canvas lives on one display while the active shortlist queue, pacing countdown, and note-taking deck occupy the second display.
- Current Implementation: In the current single-screen iPhone build, this architecture is isolated behind a single clean abstraction seam: the `ExhibitWorkspaceLayout` view container.
- No fold SDK dependency: The app relies exclusively on standard SwiftUI presentation primitives today and does not import or depend on unavailable foldable SDK APIs.

## Current Status and Milestones
- **Status:** Documentation-only scaffold. No Xcode project, app code, tests, icon, release Action, archive or TestFlight build exists yet. Features below describe intended behavior, not available functionality. Backlog defines implementation gates.
- **M1 (Project Skeleton & CI):** Native Swift package / Xcode project structure, Swift 6 compiler flags, zero-network CI contract gate, and iPhone-only device enforcement.
- **M2 (Domain & Storage):** `ExhibitTrailKit` pure-Swift domain layer and SQLite / GRDB persistent store for visits, floor plans, pins, and pacing math.
- **M3 (Floor Plan Canvas & Pinning):** Zoomable floor plan renderer, coordinate-mapped pin placement, and shortlist prioritization.
- **M4 (Visit Pacing Engine):** Monotonic pacing timer, remaining-time calculation, room transition buffers, and visit progress tracking.
- **M5 (Exhibit Journal & Local Attachments):** Impression notes, local image attachments, and unviewed/viewed toggle states.
- **M6 (iPhone Duo Seam & Export):** Single-screen navigation with the `ExhibitWorkspaceLayout` dual-screen abstraction seam, plus JSON/CSV export.
- **M7 (Packaging & App Store Connect):** App Store listing copy review, real generated icon at `AppStore/icon.png`, and automated TestFlight release workflow.

## Development Quickstart
This repository currently contains planning files only. After issue #1 lands, clone with `gh repo clone rwrife/exhibit-trail`, open the generated Xcode project on a Mac with Xcode 26.0.1 (17A400), and run the documented iPhone simulator scheme. `toolchain.json` states the target; it does not install Xcode. No build command works yet.

## iOS Signing and TestFlight Release Plan
Packaging issue #7 must implement `.github/workflows/release.yml`, porting the proven template from `rwrife/cook-console` (also verified in `rwrife/rise-log`, `rwrife/split-slip`, and `rwrife/catch-tally`).
- Triggered by `v*` tag push or manual `workflow_dispatch`.
- Runs on GitHub-hosted `macos-26` runner with iOS 26+ SDK enforcement.
- Configures credentials securely using GitHub Actions repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, and `ASC_TEAM_ID`.
- Exports signed IPA archive with `TARGETED_DEVICE_FAMILY = 1` and uploads to TestFlight using the official App Store Connect API.
- Generates a matching GitHub release with build artifacts.
