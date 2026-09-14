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
2. Optionally use **Enable Previews** to allow Screen Recording. Without it, Snap Assist still works with app icons and window titles. macOS may ask you to quit and reopen the app after enabling capture.
3. In **Desktop & Dock → Windows**, turn off native drag-to-edge tiling, drag-to-menu-bar filling, Option-drag tiling, and drag-to-top Mission Control when those switches are present. Pause other window managers while testing. Pane Management does not change those settings automatically.
4. Close Settings. The two-pane icon in the menu bar offers settings, pause/resume, snap groups, and quit.

## Controls

| Action | Gesture / shortcut |
|---|---|
| Snap left/right | Drag the title bar to the left/right edge, or Control–Option–Left/Right |
| Snap a quarter | Drag to a corner; or snap a half, then Control–Option–Up/Down |
| Maximize | Drag to the top edge, or Control–Option–Up from a floating window |
| Pick a layout | Drag toward top center; hover the green button; or Control–Option–Z |
| Fill the rest | After snapping, click a window in the remaining zone; use arrows and Return if preferred |
| Dismiss / skip | Escape dismisses; Space skips an Assist zone |
| Restore / minimize | Control–Option–Down restores a snapped window; from a floating window it minimizes |
| Unsnap | Drag a snapped window away; its original size is restored after release |
| Move across monitors | Control–Option–Shift–Left/Right |
| Resize adjoining windows | Hover a shared edge of a group and drag the blue handle |
| Recall a group | Menu bar → Snap groups, or Control–Option–G for the most recent group |

## Implementation status

“Implemented” means the code exists; the verification record below distinguishes automated tests from desktop validation.

| Windows behavior | Current implementation / limit |
|---|---|
| Left/right edge snap and quarter corners | Implemented, with preview |
| Top-edge maximize | Implemented, within the usable desktop |
| Top-center layout bar | Implemented: halves, wide-left, thirds, left-plus-two, quarters, wide-center |
| Hover maximize button layout flyout | Implemented using the accessible Mac green button; custom chrome may not expose it, and Apple's own hover menu may also appear |
| Snap Assist after ordinary edge snap | Implemented; does not require selecting a layout from the top bar first |
| Separate windows from the same app | Implemented; not restricted to one choice per app |
| Window thumbnails | ScreenCaptureKit; optional Screen Recording permission; ambiguous window IDs use icons |
| Arrow-key snapping | Implemented with Control–Option instead of the Windows modifier; not a complete Windows shortcut-state clone |
| Restore size on drag-away | Restores after release, to avoid resizing against an app's active native drag; not continuous Windows-style restoration |
| Shared resizing | App-provided divider handle; direct resizing through an application's own edge is not synchronized |
| Snap groups | In-memory recall via app menu/hotkey; no native Dock, Mission Control, or Command–Tab integration |
| Multiple monitors | Per-monitor work area, picker placement, transfer shortcuts; advanced hot-plug restoration is not implemented |
| Full-screen Spaces | Excluded; exit native full screen to use normal desktop snapping |
| Apps with minimum sizes / denied AX actions | Verify placement and revert a failed snap; does not override app constraints |
| Restore groups after app restart / reopening documents | Not implemented |

macOS exposes window geometry and window capture, but its native Dock/app switcher do not provide a public Snap Groups integration point. Those shell features would need a separate app-owned switcher, and still would not be literally identical to Windows.

## Architecture

- `SnapCore/Layout.swift`: normalized layouts, monitor coordinate transforms, drag targeting, shared-divider geometry, and the Snap Assist state machine. No UI or permission dependencies.
- `SnapCore/Placement.swift`: cancellable frame-settling verification with bounded retries and an injectable clock for regression tests.
- `Windows.swift`: public Accessibility access, window identity/eligibility, frame updates, visible-window filtering, optional thumbnails.
- `Overlays.swift`: nonactivating AppKit layout, placement, Assist, and divider panels.
- `Controller.swift`: drag lifecycle, placement verification, keyboard shortcuts, snap groups, and runtime settings.
- `App.swift`: menu bar and setup UI.

Window coordinates use logical points in the Quartz convention: primary display top-left origin. AppKit panel frames are converted with the primary display's height, including monitors with negative coordinates. Layout boundaries are rounded together so thirds do not leave one-pixel seams.

Previews are captured only while the Assist picker is open, kept in memory, and cleared on dismissal. No screenshots, window titles, or group membership are saved to disk. Only the user's feature toggles are persisted in the app's preferences.

## Verification

Automated checks cover layout area and non-overlap, edge targeting on monitors above/left of the primary display, coordinate conversion, sequential Assist choices, same-app window identity, skipping and duplicate exclusion, restore geometry, and shared-divider clamping. The runner uses plain Swift so it also works with Command Line Tools installations that lack XCTest.

The placement checks also simulate delayed animations, stalled writes, cancellation, minimum-size rejection, and transient frame matches. Run all 16 scenarios with the command in **Build and run**.

For disposable windows:

```sh
bash scripts/build-fixture.sh
open "dist/Pane Management Test Windows.app"
```

Then use **Test Snap Assist with disposable windows** in the app's settings. This tests placement and the picker, but bypasses drag detection.

Desktop acceptance checks (require granting Accessibility, plus Screen Recording for previews):

- Drag a normal window left. The first window fills half, and the other half immediately offers open windows.
- Select a second window from the same app. Both remain on the current desktop and the picker closes.
- Repeat with quarters and the top-center three-column layout; fill each remaining zone in order.
- Escape halfway through a layout. Already placed windows stay put; no later asynchronous picker reappears.
- Drag text, a tab, and a window resize edge. None should trigger a window snap preview.
- Drag a snapped title bar away. Confirm it follows the pointer without programmatic resizing during the drag, then restores its original size after release in Finder, Safari, and a Chromium/Electron app.
- Try a fixed-size window and an app with a large minimum width. Do not leave an overlap after a refused snap.
- Hover the green button, choose a zone, and verify the same Assist flow.
- Resize a group with the blue divider handle; check minimum-size rejection and rollback.
- Test negative-origin displays, different scaling factors, Dock positions, monitor disconnection, and separate Spaces.

## CodeRabbit policy

Automatic CodeRabbit reviews, incremental reviews, unprompted chat replies, and issue enrichment/planning are disabled in the root `.coderabbit.yaml`. Do not enable them or request CodeRabbit reviews for this project without the maintainer's approval.

The YAML setting does not revoke GitHub App access or prevent explicit manual review commands. For complete exclusion, remove this repository from CodeRabbit's **selected repositories** in GitHub's installed-app settings. Do not uninstall CodeRabbit or change its access to unrelated repositories.

See [CodeRabbit's automatic-review controls](https://docs.coderabbit.ai/configuration/auto-review) for the distinction between automatic and manual reviews.

## References

- [Microsoft's Windows Snap behavior](https://support.microsoft.com/en-us/windows/experience/snap-your-windows)
- [Apple Accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement)
- [ScreenCaptureKit window capture](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [Screenshot capture API](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
