# Verification record

September 14, 2026. Pane Management was originally developed as SnapBridge.

## Automatic fitting (build 5)

The explicit wider-split card action has been replaced by a shared automatic placement path for both the first snapped window and subsequent Assist selections. It verifies every member of the current placement transaction, retries a wider two-column layout after a real candidate refusal, and restores the same baseline on failure. Successful adjusted widths are hints for that specific AX window during this process only; they are not saved to disk or declared as minimum sizes. Narrower manual resizing or a failed hint causes fresh fitting. At most three distinct attempts are made; cancellation or incomplete restoration stops further attempts.

The release build passes **60 automated scenarios, zero failures**. Nine new scenarios cover a single-call automatic pair fit, first-window adjustment on either side, skipping a rejected half-width using a verified hint, hint invalidation, recovery from changed constraints, impossible-pair restoration, cancellation, failed-rollback termination, and not inventing a width constraint from a move failure. The 51 prior scenarios still pass. The package passes strict signature verification, plist lint, and whitespace checks.

Only this app's existing Accessibility and Screen Recording registrations were refreshed for the new executable. Both are recognized by the running app. No VPN connection or security settings were changed.

Live checks on build 5:

- A single actual NordVPN card press completed a verified 900/570 split and dismissed Assist automatically. There was no recovery button or second press. The Blue fixture independently reported Cocoa `(0, 0, 570, 923)`.
- A repeat snap of the same NordVPN window also completed from one card press. The regression checks separately establish that a usable width hint skips the refused half-width attempt; live timing alone is not used to prove which AX writes were skipped.
- Blue was temporarily given a 900-point minimum and zoomed to a legal 1470 × 923 baseline. Snapping it first automatically produced a 900 × 923 window and the remaining-space picker. This exercises production first-window accommodation, not just the pure geometry helper.
- Selecting NordVPN beside that constrained Blue window tested an impossible 900+900 pair on a 1470-point-wide work area. The app verified `rolledBack`, Blue remained 900 × 923, and Nord's card became unavailable for that zone with restoration feedback. The fixture's normal 160-point minimum was restored afterward, followed by a manual 735-point fixture size to invalidate its learned width.

First-window accommodation on the right, physical drag/shortcut delivery, and other app-specific constraints retain automated or earlier-build coverage; they were not all retested live in this pass. The older two-click results below are historical.

## Wider-split recovery (build 4)

A fresh live NordVPN failure reported AX resize success but an unchanged 900 × 702 frame against a requested 735 × 923 zone. This proves the requested placement did not occur; it does not prove a 900-point minimum or that a wider request will succeed.

The recovery update builds and passes **51 automated scenarios, zero failures**. Six new scenarios cover left/right and reversed zone assignments, negative-origin/rounded geometry, insufficient neighbor space or height, unsupported/invalid layouts, successful placement with a simulated width constraint, and verified restoration when the neighbor refuses. Existing cancellation/rollback scenarios still pass. Packaging and strict ad-hoc signature verification succeed. No changes were made to VPN settings, network behavior, credentials, or permissions for other apps.

The picker now shows per-card failure details and one explicit wider two-column retry, where feasible. Repeated unsuccessful cards become unavailable for that zone; hints reset with the session. A developer-only entry point, visible while the disposable fixture is running, can start Assist with a disposable first window and permit selecting another open app for cross-app validation.

After the user approved Touch ID, only Pane Management's stale Accessibility and Screen Recording entries were replaced. The running build reports **Running in the menu bar** and **ScreenCaptureKit access verified**. Removing those registrations did not delete the app or source files, and both permissions were restored for the same bundle path.

**The new recovery action passed a live NordVPN test.** The other-app test first snapped the disposable Blue window on the primary display. Pressing the actual NordVPN card reproduced the refused 735 × 923 placement; the card visibly changed to “Stayed 900×702; zone 735×923” and “Try wider split (900 pt).” Pressing that action completed the verified transaction, dismissed Assist, and reported “Snap group ready · Adjusted split · 900 pt for NordVPN.” Independent fixture UI inspection confirmed Blue at Cocoa `(0, 0, 570, 923)`, and NordVPN's window was visually confirmed in its taller, wider zone. Its connection was not changed. This establishes a working 900-point retry for this NordVPN window, not a universal minimum-size measurement or compatibility guarantee for every app. The successful test pair was left visible.

All 51 automated checks were rerun successfully. Wider-retry refusal and rollback are covered by simulated tests; an actual second app refusing the narrower neighbor slot has not been tested in this live pass. The previous 11-check live fixture suite below belongs to build 3, not this new executable. Open at Login was verified to list the current Pane Management bundle after packaging; no reboot was performed.

## Additional acceptance and repository preparation

The 45 automated scenarios were rerun with zero failures. Both packaged app signatures still pass strict verification. Only the disposable fixture was rebuilt in this follow-up; the running Pane Management executable and its approved permissions were not replaced.

The fixture now displays foreground/key-window state and counts of key presses and drag events delivered to that fixture alone. It does not record text or listen to another process's input. Its explicit focus button did not make it foreground through the desktop tool, so global shortcut delivery was not attempted against an uncertain foreground target. Keyboard state/geometry coverage remains automated, not verified physical shortcut delivery.

An additional large-minimum test set Amber to a 900-point minimum width. From a valid 900 × 923 starting frame, a 735-point half-screen request was refused, the app reported the mismatch, and the fixture remained at the valid baseline. The normal 160-point minimum was restored afterward and the disposable helper was restarted. An earlier setup attempt was interrupted before a settled result and is not counted as a pass.

After restart, the fixtures appeared on a display left of the primary display (Amber's starting Cocoa frame was `(-1710, 500, 650, 452)`). The complete **11-check live suite passed again there**, including thumbnails, three paired placements, shared resize, recall/unminimize, three-column/stack/three-member-quarter layouts, refused-size rollback, and visible starting-frame restoration. This adds negative-origin display placement coverage; it does not verify monitor-transfer shortcut delivery or hot-plug behavior.

The publication set contains project source, tests, documentation, scripts, configuration, and the supplied artwork. A targeted credential/private-key pattern scan found no matches. The artwork files were checked as SVG/PNG/PDF/JSON plus the supplied generator script; the generator was inspected, not executed. Build directories, app bundles, logs, environment files, and signing-key formats remain ignored. Pattern scanning is not a guarantee against every possible sensitive value. GitHub Actions is configured for build/regression/bundle checks with read-only repository permission, pinned checkout code, no persisted credentials, and no artifact uploads. Remote results are recorded in [GitHub Actions](https://github.com/ccmenshealth/pane-management/actions/workflows/checks.yml); configuration alone is not evidence of a passing run.

Before publication, a separate clean checkout of the implementation commit built successfully and passed all 45 scenarios. The temporary checkout was then removed; the project and running application were unchanged. After the user completed GitHub's fresh verification prompt, the installed CodeRabbit app was rechecked: “Only select repositories” remained selected, with the same 17 repositories and no Pane Management entry. No repository-access settings were changed and the pending request for expanded CodeRabbit permissions was not approved. Commits use the account's GitHub noreply address.

## Current build: 45 automated scenarios and 11 live checks passed

The latest release build passes **45 automated scenarios, zero failures**, strict ad-hoc signature verification, source/bundled plist lint, build-script syntax, and whitespace checks. It includes the user's app icon and menu glyph.

The user explicitly authorized removing and re-adding only Pane Management's Accessibility and Screen Recording entries, then completed the Touch ID prompt. Those entries were refreshed for each rebuilt executable. The current running build reports **Running in the menu bar** and **ScreenCaptureKit access verified**. No other app's permissions were changed. Only stale permission registrations were removed; the app/source files were not deleted, and both grants have been restored. A file chooser with a disabled Open button accepted the bundle after the new executable had first been launched, quit, and selected again.

Live diagnostics caught a second-window grow stage returning AX success while the actual frame was `(686, 37, 735, 919)` instead of `(735, 33, 735, 923)`. It stopped before final alignment. Placement now permits a bounded align/grow/align correction, with regression tests for recovery and permanent refusal. Whole-frame verification and rollback still apply; no security/accessibility protections were weakened.

The next live run passed three half-screen pairs and 60/40 resizing, but exposed an immediate-read error in the test's minimize check: the window minimized after the test had stopped. Both test setup/cleanup and production group recall now confirm state changes asynchronously, treating unavailable reads as unknown, not false. Three regression scenarios cover delayed/transient observations, refused/unknown states, and cancellation. Cleanup now confirms visibility as well as geometry.

The latest fixture-only integration run completed **all 11 live checks**:

- Actual ScreenCaptureKit thumbnails for all three fixtures.
- Three consecutive two-window Assist flows with matching half-screen frames.
- Verified linked group resize to 60/40.
- Group recall after moving one member and minimizing another.
- Three-column and left-plus-two stacked layouts through sequential Assist.
- Three members in the four-zone layout (not four-window coverage).
- Refused 100 × 100 size followed by verified transaction rollback.
- Restoration of the three starting frames and confirmation that all fixtures are visible.

The runner invokes production controller methods directly; it does **not** simulate mouse drags, shortcut delivery, or card clicks. A separate accessible card press completed a two-window group on both the preceding 42-scenario build and the latest 45-scenario build. On the latest build, pressing the actual Green card produced “Snap group ready · 2 windows,” and the Green fixture reported Cocoa `(735, 0, 735, 923)` with its normal 160 × 160 minimum. The additional input check leaves a disposable pair snapped for the remaining title-bar test.

Desktop automation rejected title-bar drag attempts with `windowNotFoundAtPosition((1185.0, 49.0))` before delivering a gesture. Refreshing the app handle, raising the window, and selecting its title did not resolve this. The fixture frame remained unchanged; these failures are not evidence that Pane Management received or mishandled a drag.

The user then dragged the Green fixture from its snapped right half to the left screen edge. The user reported that the remaining-space selector appeared and dismissed when they returned here to type. Subsequent inspection confirmed Green at Cocoa `(0, 0, 735, 923)` with its normal 160 × 160 minimum, and Pane Management reported “Snapped Pane Management Test Windows · Two equal.” The picker was no longer present. This verifies one actual drag-to-left-edge snap, user-observed Assist presentation, and outside-interaction dismissal. It does not establish the timing of size restoration while the pointer was held, repeated daily-use reliability, every edge/corner, native resize input, custom app chrome, or cross-monitor behavior. No new commit or push was made in this pass.

The sections below are chronological historical results; their permission blocks and unverified runner results are superseded by this section.

## Continued live acceptance and picker accessibility

After the user's permission refresh, the icon/permission build reported both Accessibility enabled and “ScreenCaptureKit access verified.” A controlled first snap displayed **actual Green and Blue fixture thumbnails**, visually confirmed in Snap Assist. Read-only WindowServer inspection confirmed the first window at `(0, 33, 735, 923)` and the Assist panel in the other half. A process check found only the intended Pane Management and its fixture running among the checked window-manager process names.

Second-window card selection was still not verified. The accessibility tree exposed an unknown wrapper around each card's button; indexed/coordinate attempts did not produce a completed group. Native title-bar drag attempts likewise produced no changed fixture frame. The fixture's ordinary minimum-width button did respond, and its temporary 900-point test minimum was restored to 160 points. These input results do not establish whether all failed gestures reached the app.

The next local build makes each picker card a single accessibility button with an explicit press action, and preserves active choosers when the application receives a reopen request. It also adds a fixture-only live integration runner covering production placement, sequential Assist, group resizing/recall, actual thumbnails, refused-size rollback, and cleanup. **This new runner has not yet completed a live run.** The updated build compiles, passes all 40 automated scenarios, and is packaged with the supplied artwork. Those tests do not exercise the new AppKit button dispatch or live runner.

Rebuilding invalidated the current executable's Accessibility recognition again. Desktop auto-review rejected removal of its stale Accessibility entry because removal was not specifically approved. That rejected action did not remove the entry. Explicit approval to refresh only Pane Management's Accessibility and Screen Recording registrations is required before continuing live testing. No permission change was made to another app, no code was pushed, and physical input/second-placement acceptance remains open.

## Icon integration and preview-permission feedback

The subsequent icon/permission update builds and passes **40 regression scenarios, zero failures**. The bundle passes strict ad-hoc signature verification, plist lint, build-script syntax, and whitespace checks. Six new permission-state scenarios cover explicit opt-in when preflight is false, no unsolicited startup request, retries, distinct service errors, duplicate checks, and denial after verification.

The supplied `Icons/` artwork is preserved. Packaging creates `Contents/Resources/AppIcon.icns` from the supplied iconset, declares it in Info.plist, and copies the vector menu glyph unchanged. AppKit loads the glyph as a 14 × 18-point template in a variable-width status item. The full-color app artwork was visually confirmed in the running setup window. The supplied layers have not been compiled into a Liquid Glass icon; this build uses the flat fallback on all supported macOS versions.

The old preview button ignored `CGRequestScreenCaptureAccess`’s result and always opened Settings. The new button explicitly checks `SCShareableContent`, shows checking/success/denial/service-error states, and offers retry, the exact bundle path, Settings/Finder links, and a quit action. Only a positive preflight permits an automatic startup check; an explicit user check can proceed even when preflight is false. The check enumerates shareable content without taking or retaining screenshots. Actual capture denial clears the verified state.

Live testing confirmed a real ScreenCaptureKit permission denial despite the existing Screen Recording switch being on. The stale entries for this app alone were removed. Accessibility was re-registered and enabled, and the running updated app confirmed “Running in the menu bar.” The screen-capture request did not recreate its entry. The Screen Recording Add dialog was opened for the current bundle, but desktop automation could not reliably complete the file selection; the user was asked to finish adding/enabling the exact app and use Quit & Reopen and Check Again. **Screen Recording and actual thumbnails remain unverified in this update.** No other app’s permissions were changed. Removing the stale permission registrations did not delete any app or source files; they can be re-added through Settings.

The earlier snapping acceptance gaps below remain open. These local changes have not been committed or pushed in this pass.

## Reliability and parity implementation pass

The subsequent implementation pass builds successfully in release configuration and passes **34 regression scenarios, zero failures**. The app and fixture pass strict ad-hoc signature verification; property-list lint, build-script syntax, and `git diff --check` pass. After the repository-folder rename, the stale debug and release `ModuleCache` directories were moved to `ModuleCache-before-folder-rename` inside their respective ignored build directories so the compiler could regenerate them.

New coverage includes adaptive layout filtering, keyboard quarter transitions and custom-layout restore-before-minimize, height-only maximize, live-restored cursor anchoring across displays, native internal-edge classification, configurable near-edge targeting, and all-window transaction settling, rollback, cancellation, and incomplete-baseline rejection. Additional tests simulate independent size/move animations replacing one another, shrink-before-monitor-transfer, cancellation between placement stages, and late drift of a previously placed group member.

New app paths include a guarded live-restoration drag filter on a dedicated input thread, native internal-edge group resizing, verified group recall/rollback, a visual group chooser, modifier-release keyboard placement, numbered layout selection, and separate top-bar/near-edge toggles. The event-tap callback uses only a small locked preflight record; AX reads and writes run outside it. Native/custom title bars that fail the preflight retain the after-release restore fallback.

**Desktop acceptance is not yet complete for this pass.** The rebuilt app launches and displays the new settings. Its stale Accessibility entries were refreshed for the rebuilt signatures, and the current app visibly reports “Running in the menu bar.” The user reports Screen & System Recording is enabled, but the current process still shows the Enable Previews button; thumbnail access needs a confirmed refresh/restart. No new physical-drag, linked-resize, or group-chooser desktop success is claimed here. The controlled results in the pre-rename section below belong to the earlier build.

A controlled test reproduced failed placement with successful AX return codes: actual `(0, 406, 650, 452)` versus requested `(0, 33, 735, 923)`. A diagnostic fixture then resized itself locally to Cocoa `(0, 0, 735, 923)`, with minimum size `160 × 160`, establishing that this requested size was legal for the fixture. Pre-positioning it locally allowed the initial snap and the icon-based Assist picker to appear, but this did not validate external resizing or completion of the second placement. The implementation was subsequently changed to settle individual shrink/move/grow/alignment stages, and picker targets were changed to real AppKit buttons. This animation-interference hypothesis is regression-tested, not yet established as the sole cause of the original desktop error.

After that change, a read-only WindowServer check confirmed the initially unsnapped Amber fixture reached `(0, 33, 735, 923)`, and the app reported a successful first snap. A subsequent controlled run displayed the remaining-space picker with Green and Blue as real accessible buttons. Automated click/Return attempts did not establish a second placement: a later WindowServer read still showed the other two windows at `650 × 452`, and no group-ready status was confirmed. Subsequent attempts sometimes remained at the initial test status. The cause of the interrupted flow is unresolved; a hands-on drag-and-pick check has been requested. These observations establish first-window placement and picker presentation only, not end-to-end reliability.

## Automated checks

The pre-rename snapping fix built with Swift 6.3.2 / Command Line Tools on macOS 26.5.1 (Apple Silicon), with no external packages. All 16 executable regression scenarios passed:

- Layout coverage, non-overlap, and shared-boundary rounding.
- Edge/corner targeting and reversible coordinates on negative-origin displays.
- Sequential Snap Assist, skipping, duplicate exclusion, and multiple windows from one app.
- Restore geometry and clamped shared-divider resizing.
- Release-position rechecking, edge hysteresis, and distinguishing a move from text selection or resizing.
- Delayed animation without restarting it, bounded retries after stalled writes, two-frame confirmation, cancellation, refused sizes, invalid geometry, and no-op placement.

At the time of the rename, the `PaneManagement` and `PaneManagementTestWindows` release targets also built successfully. All 16 regression scenarios passed again. Both renamed app bundles passed strict ad-hoc signature verification, both property lists passed linting, and both build scripts passed shell syntax checks. The pre-rename app was initially left running to avoid interrupting its authorized test session. The subsequent renamed-build UI and permission tests are recorded above.

## Live results before the rename

- Accessibility and Screen Recording were enabled with explicit user permission, followed by macOS Quit & Reopen.
- Native edge tiling, menu-bar filling, Option-drag tiling, and top-edge Mission Control were disabled with explicit permission. Other Mission Control settings were unchanged.
- Three consecutive controlled two-window flows completed. Each showed the remaining-space picker, then reported a two-window snap group after selection. Actual fixture thumbnails were visually confirmed, without a placement-failure toast.
- A read-only WindowServer check confirmed paired frames `(0, 33, 735, 923)` and `(735, 33, 735, 923)` on a 1470 × 956 display: the exact two halves of the usable desktop.

These controlled tests use the app's fixture-test button. They do not establish that the drag hook works reliably in daily use.

## Remaining acceptance gaps

- One user-performed drag-to-left-edge passed on the current build, with the resulting half-screen frame independently confirmed. Repeated physical gestures, other edges/corners, and varied applications still need broader acceptance testing. The desktop tool cannot reliably target title-bar drags.
- Controller-driven group resizing and recall pass on the disposable fixtures. Native edge/handle input, cross-display transfers, custom window chrome, and varied real-application minimum sizes still need live testing.
- Live restoration now has a guarded app-owned drag path, with after-release fallback for unrecognized title bars. Both need desktop acceptance testing in this build.
- The intermittent error reported by the user was not reproduced during the earlier successful controlled tests. The later placement failure and staged-write results are recorded above. Fixed-delay verification and overlapping native drag gestures were identified as fragile paths, but the exact original trigger is not proven.
- Full-screen Spaces, persistent groups, and native Dock/Mission Control snap-group integration are not supported.

## Fixes under test

Each placement stage observes two matching frames, with up to 16 samples 75 ms apart and bounded corrective writes, followed by whole-frame verification. It avoids restarting a moving animation, verifies rollback before claiming restoration, and commits snap metadata only after success. A new gesture cancels outstanding placement.

Drop targets use the release event's coordinates with a small exit hysteresis. The source window is not programmatically resized while its app owns a native drag; linked resizing may update its neighbors. Candidates exclude utility windows and explicitly read-only sizes. Dismissal cancels pending placement and skipping cannot race with selection.

## Repeating the controlled test

```sh
swift run --disable-sandbox --cache-path .build/cache SnapCoreChecks
bash scripts/build-app.sh
bash scripts/build-fixture.sh
open "dist/Pane Management Test Windows.app"
open "dist/Pane Management.app"
```

While the fixture app runs, settings show **Test Snap Assist with disposable windows**. That entry point restricts both the initial placement and subsequent choices to the fixture app.

Rebuilding changes the ad-hoc signature. If a privacy switch is on but the app reports no access, remove and re-add only this app in the relevant privacy pane, selecting its current bundle. Use macOS Quit & Reopen after refreshing Screen Recording. A proper signing identity is required before distribution. No security protections or signing requirements should be weakened to avoid this development limitation.
