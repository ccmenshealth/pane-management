# Pane Management

A native macOS menu-bar app implementing the Windows snapping workflow: place a window, choose another open window for the next zone, and continue until the layout is filled.

**Early prototype — not a stable release or a complete Windows 11 clone.** It uses AppKit, Accessibility, and ScreenCaptureKit, with no third-party dependencies and no network requests. Previously called SnapBridge.

See [VERIFICATION.md](VERIFICATION.md) for the actual build/test results and remaining live-validation gaps.

## Build and run

Requires macOS 14+ and Swift 5.9+ (Xcode Command Line Tools are sufficient).

```sh
swift run --disable-sandbox --cache-path .build/cache SnapCoreChecks
bash scripts/build-app.sh
open "dist/Pane Management.app"
```

The build script makes an ad-hoc-signed application in `dist/Pane Management.app` and refuses to overwrite a running copy. This is suitable for local development; distribution needs a Developer ID signature and notarization. Rebuilding an ad-hoc signature may require removing and re-adding the app in Accessibility and Screen Recording settings. Keep the app at a consistent path.

If upgrading from SnapBridge, quit the old app before opening Pane Management. The original `local.snapbridge.app` bundle identifier is intentionally retained for preference continuity; the app name, executable, and package are renamed. Local ad-hoc permissions may still need refreshing after the update.

## Setup

1. Open Pane Management and use **Enable Accessibility**. In System Settings, grant the app access to move and resize windows.
2. Optionally use **Enable Previews** to check ScreenCaptureKit access and, if needed, allow Screen Recording. Without it, Snap Assist still works with app icons and window titles. The button reports the actual API result instead of always opening Settings. If macOS denies the running build, **Check Again**, the current bundle path, Settings/Finder links, and a quit action appear. If the permission switch is already on, quit and reopen the selected app; after a rebuild, a stale entry may need removal and re-adding. Quitting clears session-only groups.
3. In **Desktop & Dock → Windows**, turn off native drag-to-edge tiling, drag-to-menu-bar filling, Option-drag tiling, and drag-to-top Mission Control when those switches are present. Pause other window managers while testing. Pane Management does not change those settings automatically.
4. To start automatically after signing in, add the built app under **System Settings → General → Login Items & Extensions → Open at Login**. Keep the bundle at a consistent path and avoid starting another snapper alongside it. This is a per-Mac setting, not enabled automatically for other users.
5. Close Settings. The two-pane icon in the menu bar offers settings, pause/resume, snap groups, and quit.

## Controls

| Action | Gesture / shortcut |
|---|---|
| Snap left/right | Drag the title bar to the left/right edge; or hold Control–Option, choose with arrows, then release a modifier to place |
| Snap a quarter | Drag to a corner; or snap a half, then Control–Option–Up/Down |
| Maximize | Drag to the top edge, or Control–Option–Up from a floating window |
| Fill height only | Control–Option–Shift–Up; preserves width |
| Pick a layout | Drag toward top center; hover the green button; or Control–Option–Z |
| Fill the rest | After snapping, click a window in the remaining zone; use arrows and Return if preferred |
| Dismiss / skip | Escape dismisses; Space skips an Assist zone |
| Restore / minimize | Control–Option–Down moves a half/upper quarter to its lower quarter, then restores, then minimizes |
| Unsnap | Drag a snapped window away; recognized blank title bars restore during the drag, with an after-release fallback for other title bars |
| Move across monitors | Control–Option–Shift–Left/Right |
| Resize adjoining windows | Drag an internal window edge or the blue group handle |
| Recall a group | Menu bar → Snap groups, or Control–Option–G for the most recent group |
| Browse groups | Control–Option–Shift–G; choose with arrows/Return, a number, or a click |

Keyboard placement previews are cancellable with Escape before release. Opposite horizontal arrows restore a half to its floating position; quarter-to-quarter moves preserve the row. In the layout picker, type a layout number and then a position number, or use Tab, arrows, and Return. These are explicit app behaviors, not a claim of complete Windows shortcut parity.

## Implementation status

“Implemented” means the code exists; the verification record below distinguishes automated tests from desktop validation.

| Windows behavior | Current implementation / limit |
|---|---|
| Left/right edge snap and quarter corners | Implemented, with preview |
| Top-edge maximize | Implemented, within the usable desktop |
| Top-center layout bar | Six presets, filtered by usable logical display size (each zone at least 320 × 240 points); independently switchable |
| Hover maximize button layout flyout | Implemented using the accessible Mac green button; custom chrome may not expose it, and Apple's own hover menu may also appear |
| Snap Assist after ordinary edge snap | Implemented; does not require selecting a layout from the top bar first |
| Separate windows from the same app | Implemented; not restricted to one choice per app |
| Window thumbnails | ScreenCaptureKit; optional Screen Recording permission; ambiguous window IDs use icons |
| Arrow-key snapping | Control–Option previews a sequence and commits on modifier release; quarter transitions, restore/minimize, and height-only maximize |
| Restore size on drag-away | Guarded event-tap ownership for a preflighted, focused, blank standard title bar; other title bars use the native drag and restore after release |
| Shared resizing | Native single internal-edge linking plus the blue handle; throttled streaming writes, whole-group settling and verified rollback on release |
| Snap groups | In-memory menu/hotkey recall and an app-owned visual chooser; verified placement, including unminimizing members; no native Dock/Mission Control/Command–Tab integration |
| Multiple monitors | Per-monitor work area, picker placement, transfer shortcuts; advanced hot-plug restoration is not implemented |
| Full-screen Spaces | Excluded; exit native full screen to use normal desktop snapping |
| Apps with minimum sizes / denied AX actions | Verify and revert failed placement; show the observed/requested sizes and offer one explicit wider two-column retry when space permits; does not override app constraints |
| Restore groups after app restart / reopening documents | Not implemented |

The group chooser is Pane Management’s own overlay, not an extension of the native Dock or app switcher. Groups remain session-only. Full Windows shell parity is not claimed.

Drag ownership is deliberately conservative: a recent blank-title-bar hit test, an already focused snapped window, an unmodified single click, and actual cursor movement are required. No AX calls happen inside the event-tap callback. Buttons, document icons, tabs, double clicks, and unrecognized title bars stay native. If the event tap is unavailable, ordinary snapping and after-release restoration still work. Disable restore-on-drag in Settings to use only native drags.

Native group resizing links a single internal edge only. Outer-edge and corner resizing are left native. A window’s minimum size cannot be overridden: a refused group change rolls back the group, with an explicit warning if restoration also fails. Starting a new gesture cancels outstanding writes instead of moving windows back underneath the new gesture.

If a Snap Assist candidate refuses a narrow zone, its card shows the size mismatch. For a two-column layout, **Try wider split** can use its observed width while leaving at least 320 points for the neighboring window. This is a proposed retry, not a claim that the observed width is the app's minimum. The neighboring window is resized only when that card is selected again; both frames must verify, or both are restored. A failed wider retry disables that candidate for the current zone to avoid repeating the same error. Starting a new snap resets these session-only hints. Stacked layouts and windows taller than the display do not get a wider retry.

## Architecture

- `SnapCore/Layout.swift`: normalized layouts, monitor coordinate transforms, drag targeting, shared-divider geometry, and the Snap Assist state machine. No UI or permission dependencies.
- `SnapCore/Placement.swift`: cancellable frame-settling verification with bounded retries and an injectable clock for regression tests.
- `SnapCore/Keyboard.swift`: pure, tested keyboard placement transitions and geometry recognition.
- `SnapCore/PreviewPermission.swift`: tested permission-check state, explicit retries, and revocation handling.
- `PreviewAccess.swift`: ScreenCaptureKit access verification and actionable permission/error feedback; preflight is only a startup hint, not a hard veto on explicit checks.
- `AppArtwork.swift`: bundled app icon and 14 × 18-point template menu glyph.
- `RestoredDragMonitor.swift`: conservative pointer-event ownership for live restoration, with no keyboard capture.
- `Windows.swift`: public Accessibility access, window identity/eligibility, frame updates, visible-window filtering, optional thumbnails.
- `Overlays.swift`: nonactivating AppKit layout, placement, Assist, and divider panels.
- `Controller.swift`: drag lifecycle, placement verification, keyboard shortcuts, snap groups, and runtime settings.
- `App.swift`: menu bar and setup UI.

Window coordinates use logical points in the Quartz convention: primary display top-left origin. AppKit panel frames are converted with the primary display's height, including monitors with negative coordinates. Layout boundaries are rounded together so thirds do not leave one-pixel seams.

Previews are captured while the Assist picker is open, kept in memory, and cleared on dismissal. The explicit live fixture checks also capture only their disposable test windows to verify thumbnail delivery. The group chooser uses layout diagrams and titles, not additional screen captures. No screenshots, window titles, or group membership are saved to disk. Only the user's feature toggles are persisted in the app's preferences.

## Verification

Automated checks cover layout area and non-overlap, edge targeting on monitors above/left of the primary display, coordinate conversion, sequential Assist choices, same-app window identity, skipping and duplicate exclusion, restore geometry, and shared-divider clamping. The runner uses plain Swift so it also works with Command Line Tools installations that lack XCTest.

GitHub Actions builds both app bundles, runs the regression checks, and validates signatures and metadata on pushes to `main` and pull requests. The workflow has read-only repository permission, does not persist checkout credentials, and does not upload app bundles or screenshots. It does not grant macOS privacy permissions or replace live desktop acceptance testing.

The 45 regression scenarios include delayed animations, stalled writes, cancellation, minimum-size rejection, transient frame matches, whole-group rollback, adaptive layouts, native-edge classification, modifier-sequence geometry, custom-layout restore-before-minimize, and live-restore cursor anchoring. Staged-placement tests cover size/move animation replacement, shrink-before-monitor-transfer, cancellation between stages, late drift in an already-placed group member, recoverable grow-stage origin constraints, and permanent size refusal. State-confirmation tests cover delayed/transient minimized states, unknown reads, refusal, and cancellation. Preview tests cover opt-in checks, false preflight with successful actual access, retry after denial, distinct service errors, duplicate suppression, and revocation. Run them with the command in **Build and run**. Pure geometry/transaction/state tests do not prove desktop gesture reliability or an actual OS permission grant.

Final placement settles shrink, move, grow, and alignment separately, with one further grow/alignment phase for a size clamped by a shifted origin. Back-to-back AX size/position writes can interfere with independent window animations. Permanent constraints still fail whole-frame verification and trigger rollback; bounded retries can take several seconds. Group recall confirms unminimized states before placement rather than assuming the request finished immediately. It does not disable Enhanced Accessibility or change VoiceOver settings. The live-drag/resize paths still need cross-app acceptance testing.

## Artwork

The build script converts the supplied `Icons/AppIcon.iconset` to a bundled `AppIcon.icns` and copies the vector menu glyph. AppKit renders the menu glyph as a monochrome template at 14 × 18 points, so it follows the menu bar appearance. The same app artwork appears in setup. Original source art, alternate designs, and Icon Composer layers are preserved in `Icons/`; no regeneration is needed to build. The current command-line build uses the flat icon on all supported macOS versions. Layered Liquid Glass rendering needs a finished Icon Composer `.icon` document and a compatible asset-compilation pipeline; it is not claimed here.

For disposable windows:

```sh
bash scripts/build-fixture.sh
open "dist/Pane Management Test Windows.app"
```

Then use **Test Snap Assist with disposable windows** in the app's settings. This tests placement and the picker, but bypasses drag detection.

**Run live fixture checks** uses three windows from the separate fixture app, restricted by its bundle identifier. It checks actual thumbnails, three two-window Assist placements, 60/40 group resizing, recall after moving/minimizing a member, thirds/stack/quarter placements, minimum-size refusal, and restoration of the starting frames. Results appear in Settings. A new gesture interrupts placement; canceled checks do not move windows back underneath that gesture. Test groups are cleared on cleanup. This exercises the production controller and Accessibility writes, but does not simulate physical dragging, keyboard delivery, or clicking a picker card; those remain separate acceptance checks. Do not equate the existence of this runner with a passing live run; see the verification record.

Each fixture displays its own Cocoa frame and minimum size. **Fit left half (fixture control)** resizes locally inside the helper, deliberately bypassing Pane Management; it distinguishes a legal target size from an external-placement failure. **Toggle 900pt minimum width** exercises refusal/rollback on narrow zones. Neither control is evidence that the actual snap gesture works.

**Focus this test window** requests foreground focus, and a live indicator reports whether the helper actually became the foreground app and that window became key. Input diagnostics count only key presses and drag events delivered to the disposable window; they do not record typed text, inspect other apps' input, or save anything to disk. Do not send global test shortcuts unless the foreground indicator confirms the intended target.

Desktop acceptance checks (require granting Accessibility, plus Screen Recording for previews):

- Drag a normal window left. The first window fills half, and the other half immediately offers open windows.
- Select a second window from the same app. Both remain on the current desktop and the picker closes.
- Repeat with quarters and the top-center three-column layout; fill each remaining zone in order.
- Escape halfway through a layout. Already placed windows stay put; no later asynchronous picker reappears.
- Drag text, a tab, and a window resize edge. None should trigger a window snap preview.
- Drag a snapped blank standard title bar away. Confirm it restores while following the pointer. Also test buttons, title icons, double clicks, tabs, rapid clicks before hover preflight, and custom title bars; these must remain native and use after-release restoration where appropriate.
- Try a fixed-size window and an app with a large minimum width. Do not leave an overlap after a refused snap.
- Hover the green button, choose a zone, and verify the same Assist flow.
- Resize a group with a native internal edge and with the blue divider handle; check minimum-size rejection and rollback. Outer-edge and corner resizing must not move neighbors.
- Hold Control–Option through an arrow sequence; release to commit. Escape before release must not move the window or reopen Assist.
- Use numbered layout selection, height-only maximize, the group chooser, and recall with a minimized/closed group member.
- Test negative-origin displays, different scaling factors, Dock positions, monitor disconnection, and separate Spaces.

## CodeRabbit policy

Automatic CodeRabbit reviews, incremental reviews, unprompted chat replies, and issue enrichment/planning are disabled in the root `.coderabbit.yaml`. Do not enable them or request CodeRabbit reviews for this project without the maintainer's approval.

The maintained `ccmenshealth/pane-management` repository is also excluded from CodeRabbit's installed-app **selected repositories**. The YAML stays in place as a fallback if installation settings change. Being public, the source can still be read by anyone; this exclusion prevents the installed app from being enabled for this repo, not public access to the code.

For forks or other installations, YAML alone does not revoke GitHub App access or prevent explicit manual review commands. Exclude that repository from the app's selected repositories as well. Do not uninstall CodeRabbit or change its access to unrelated repositories.

See [CodeRabbit's automatic-review controls](https://docs.coderabbit.ai/configuration/auto-review) for the distinction between automatic and manual reviews.

## References

- [Microsoft's Windows Snap behavior](https://support.microsoft.com/en-us/windows/experience/snap-your-windows)
- [Apple Accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement)
- [ScreenCaptureKit window capture](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [Screenshot capture API](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
