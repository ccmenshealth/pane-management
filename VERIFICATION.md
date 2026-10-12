# Verification record

September 14, 2026. Pane Management was originally developed as SnapBridge.

## B2a native recovery IO — October 12, 2026

The isolated `AlwaysOnNative` module implements protected journal and fixed power
adapters. It adds no daemon, XPC, app wiring, registration or installation. Native
checks only use temporary user-owned storage, harmless child executables and
injected power transport. No power mutation (including false) was executed.
Current inherited model used; exact model/effort metadata unavailable.

The exact final suite compiled against a scaffolding adapter with **114 assertions,
94 behavioral failures, exit 1**. The implemented suite passes **114 assertions,
zero failures** in debug and release. The scaffold provides only harmless fixture file setup so checks
reach unsafe-file and corruption cases; it has no recovery or security behavior.
Retained ignored evidence: `.build/evidence/NativeIO.final-inert.swift`,
`native-final-red.txt`, `run-inert.py`, and `native-green.txt`. The initial inert
attempt produced 46/38 but skipped later filesystem checks after its absent
fixture file; the final full-suite overlay supersedes that incomplete evidence.

Real disposable filesystem checks cover all phases across restart and old boot
IDs; held-lock contention; parent/record/directory/lock modes and owner validation;
symlinks, hardlinks, directory/FIFO records and replaced directory/lock identity;
strict schema, Boolean baseline, UUID/phase/UID/boot and duplicate-key corruption;
before/after commit failures, clear failures and absence; removal of temporary
records and the entire fixture root. Unsafe metadata throws, rather than being
classified as corrupt. The production path `/var/db/local.snapbridge.alwayson`
was observed absent after the checks. Positive root execution remains untested.

ACL hardening has an additional pre-fix run: **114 assertions / 9 failures**,
retained in `native-acl-red.txt` beside `NativeRecoveryJournal.before-acl.swift`.
Real temporary ACLs on the record, directory and parent are rejected by load,
save and clear, then removed. Metadata validation also covers lock ACLs through
the shared validator. SDK declarations and Darwin man pages were inspected;
Apple's [ACL wrapper source](https://github.com/apple-oss-distributions/Libc/blob/main/posix1e/acl_file.c)
shows why nil alone cannot distinguish absent ACL from failure. The adapter uses
successful public `fstatx_np` plus explicit `filesec_query_property` presence,
then validates any returned ACL and rejects nonempty entries; the
[property implementation](https://github.com/apple-oss-distributions/Libc/blob/main/gen/filesec.c)
confirms this separation. Unknown/read-error cases fail closed.

Real child fixtures cover success, nonzero exit, output larger than the cap,
exact sanitized environment through `/usr/bin/env`, CoreFoundation's runtime-added
text-encoding key, ignored TERM followed by KILL, timeout and cancellation,
`kill(pid, 0) == -1 / ESRCH` after reap, no marker write 650 ms after return, and
successful reuse after termination. A queued second command also cannot complete
until the first TERM-resistant child is reaped. The runner reserves child identity with
`waitid(WNOWAIT)` until group cleanup and `waitpid` completes; it sends no signals
after reap. Production only executes fixed `/usr/bin/pmset disablesleep 1/0`;
fixture executable/arguments are not an IPC surface. Process code ran off the
main executor. Actual pmset execution and privileged recovery remain unverified.

Strict readback tests reject numeric NSNumber 0/1, strings, nulls and collections
as Booleans, preserving successful absence as nil. Injected transport covers
matching on/off, delayed agreement, mismatch, errors and a write that applies
before throwing. A blocked native read returns an error on its deadline; further
reads fail promptly until that worker ends, and its late result is discarded.
A deterministic monotonic-clock jump proves a late success cannot beat a delayed
timer callback. Cancellation after a read starts is bounded by this read timeout.

Recoverability/native boundary matrix:

| Boundary | Result and exit |
| --- | --- |
| Valid intent/active/restoring after restart, including old boot | Return owned record; engine restores, never resumes activation |
| Off record | Engine requires fresh explicit dual-off, then durable cleanup only |
| Malformed validated payload | Corrupt; engine exposes retry cleanup only after dual-off |
| Unsafe owner/link/type/mode or replaced storage/lock | Throw; setup repair required before retry; never overwrite unsafe target |
| Save/clear failure before or after commit | May have applied; engine retains recovery and retries from durable state |
| Command timeout/cancel/nonzero/output cap | Writer settled and reaped before error; engine can serially restore |
| Read failure, absence after write or mismatch | Error; engine retains recovery and exposes retry |
| Stalled native read | Deadline error, no queued reads/late result; subsequent restore may write but cannot claim verified off until fresh read succeeds |
| Kernel-stuck writer or lost child-wait ownership | Keep writer slot occupied; no success/second writer; outside bounded-recovery guarantee |
| Disk/root syscall stall | Synchronous journal may stall service; separate watchdog scheduling cannot guarantee recovery progress |

Sibling audit: load/save/clear all validate directory and lock identity; existing
record validation is shared. Both power directions use the same fixed writer and
strict dual readback; initial reads also use the bounded worker. Process and read
completion both check actual monotonic deadlines. Lead early findings on PID reuse,
unbounded reads and delayed callbacks were fixed before the review candidate.

Local commands are the separate `swift run --disable-sandbox --cache-path
.build/cache` invocations for SnapCoreChecks **60/0**, AlwaysOnChecks **34/0**,
AlwaysOnEngineChecks **176/0**, and AlwaysOnNativeChecks **114/0**. Separate debug
and release build/typecheck passed; every `scripts/*.sh`
syntax check, all three source plists and whitespace checks passed. The read-only
host public-API probe returned explicit preference=false and rootDomain=false;
this is read evidence only, not a command or physical-sleep test.
The native suite is in CI; clean CI also packages the app and fixtures. Local
main-app packaging was skipped to preserve running build 5, observed at PID 96007
and its original executable path. No UI tools, bundle replacement or permissions
were used. This module has no UI change requiring a new render.

Independent, lead and native filesystem/process security review remain required.
CodeRabbit is unavailable under the explicit repository exclusion. No merge or
arming is authorized by simulation results. Root installation, actual power
writes, physical sleep/emergency timing and B2b/B3 lifecycle remain separate gates.

## B1 pure recovery engine — October 12, 2026

`RecoveryEngine` adds fixed typed service operations with injected journal,
power, monotonic-clock and cached-guard contracts. It is not connected to the
app. No native command, filesystem journal, XPC, registration, permission,
installed-app or live power change is included. Build 5 remains the installed
baseline. Current inherited model used; exact model/effort metadata unavailable.

Fail-first: the final `AlwaysOnEngineChecks` suite compiled with the inert engine
and produced **176 assertions, 102 failures, exit 1**. The implemented engine
passes **176 assertions, zero failures**. Negative refusal assertions that already
pass on an inert engine are paired with activation/recovery success assertions.
The ignored `.build/evidence/RecoveryEngine.inert.swift` and `engine-red.txt`
retain the scaffold and full red run; `engine-green.txt` retains the green run.
A corrupt-record cleanup regression separately produced four failures before its
fix (`corrupt-cleanup-red.txt`). Removing the revalidation reset reproduced one
security-boundary assertion failure (`corrupt-security-red.txt`): stale corrupt
classification must not authorize clearing after a later journal-load failure.
The off-record ownership and slow-intent guard tests produced nine failures on
the earlier implementation (`off-ownership-red.txt`) before their fixes. A busy
heartbeat regression produced one failure before its fix
(`heartbeat-busy-red.txt`): an expired lease must not reply active while a power
read is suspended. Independent-review R1 then reproduced **16 assertion failures**
on the pre-fix engine across cold status/activate/monitor/retry/prepare paths and
an unowned recheck (`R1-startup-red.txt`). Only the additive enum case was supplied
to let these checks compile; initial state/read behavior remained unchanged.
The fix starts in `checking` and enters it before every unresolved ownership
read. All 176 assertions now pass; delta review remains pending.

Valid heartbeat metadata renews synchronously; invalid heartbeat metadata latches a stop while power/journal work remains serialized.

The fake writer can suspend, apply and then throw; no fake writes after its call
has completed. Read failures are injected at all activation reads and the restore
confirmation. Journal load failures and before/after-persistence failures at
intent, active, restoring, off and clear are injected. Tests cover every restart
phase, invalid token/console/root, heartbeat deadline/renewal, critical/final/unknown/stale/future
telemetry, clock regression, disconnect during inspection and failed restoration,
cancellation during each activation read/write stage, external clear/conflict,
failed cleanup retry and removal proof. These are adapter-contract simulations.

Recoverability and await/failure matrix:

| State or boundary | Exit / tested result |
| --- | --- |
| Checking ownership | Concurrent status stays checking until read completes; resulting off/conflict/recovery is evidence-based |
| Missing journal, initial read failure | Recovery; Retry deactivation reloads ownership, never writes without intent |
| Unowned true/disagreeing setting | Conflict; resolve external owner, retry; never silently take over |
| Corrupt validated payload, strict dual off | Retry durably clears invalid record without a power write |
| Corrupt true/unknown or unsafe journal validation | Refuse cleanup; resolve owner/setup issue, then retry |
| Intent/active save throws before or after persistence | Preserve local ownership, serial restore; no active reply |
| Enable/readback awaits or throws | Stop latch survives; settle possible write then disable and verify |
| Active inspection awaits | Recheck stop/guards/deadline after read; external false never reasserts |
| Restoring save fails | Still attempt disable for safety; retain recovery until retry durably finishes |
| Disable/confirmation/off-save/clear fails | Recovery with retry; no successful removal/false off |
| Restart at intent/active/restoring | Restore and durably clear before a new explicit activation |
| Durable off record, including failed clear | Cleanup only with strict dual off; true/unknown conflicts, never writes power |
| Verified off | Explicit new activation only; monitor never resumes automatically |
| Prepare update/removal | Wait for pending writer, restore, fresh strict dual-off read; failure blocks removal |

Sibling audit: token deactivation, token-lost/pending retry, disconnect, guard
monitor, status inspection, startup and prepare-removal converge on the same
serialized restore. All successful writes require both explicit Boolean receipts;
only the initial root-domain property may be absent. No preference-absence
normalization is implemented. Unknown/malformed read values must throw.

Local gates: `SnapCoreChecks` **60/0**, `AlwaysOnChecks` **34/0**, and new
`AlwaysOnEngineChecks` **176/0**, each via its separate `swift run --disable-sandbox
--cache-path .build/cache` command. Separate debug and release build/typecheck,
script syntax, all three source plists and whitespace checks passed. CI includes
the new engine suite and clean-runner packaging.
Main-app packaging was intentionally not run locally because the running-app
guard preserves build 5. This slice has no UI change or live hardware proof.

Independent review of `4a99728` reported only R1, startup false-off. Lead review
agreed; the correction and full final-head delta review remain acceptance gates.
Applicable ownership/storage/token security review remains required. CodeRabbit is unavailable
under the repository exclusion. No live activation or merge is authorized by
these checks. B2/B3 native timing, auth, protected-file handling and lifecycle
proof remain separate gates; UI/native acceptance gaps below remain open.

## Always-on UI/controller candidate — October 12, 2026

This is the UI/state slice stacked on Dock PR #2. The actual production backend
is `UnavailableAlwaysOnBackend`: no simulated activation, `pmset`, power API,
privileged installation, brightness write, keyboard/trackpad hook, persistence or
network operation is added. A separate in-memory fixture executable shares the
warning/controller code under bundle ID `local.snapbridge.alwaysonpreview`.
Readback states mean setting observations, never proof of physical sleep/lid or
emergency behavior. Configured-but-unreachable helper status must be unknown,
not unavailable; the future backend owns authentication, bounded operations,
telemetry, heartbeat expiry and durable recovery.

Fail-first evidence: `AlwaysOnChecks` compiled against the disabled controller
scaffold with no-op actions and produced **34 assertions, 31 failures** (exit 1).
Failures included startup off verification, shared action activation/deactivation,
serialization, cancellation/late completion, critical stop, missing backend,
unknown activation, stale/ambiguous startup restoration, failure/retry and quit
completion. Three negative quit assertions already passed because the inert
scaffold always refused quit; their successful-completion partners failed. This
was a behavior failure, not a missing-symbol compile failure. The exact red log
and scaffold are retained locally under ignored `.build/evidence/` as
`always-on-red.txt` and `AlwaysOnController.disabled.swift`. Restoring the
implementation yields **34 assertions, zero failures**. The four named entry
labels exercise the shared controller API; they do not simulate actual Dock,
status-menu, Settings or warning event dispatch. Native evidence is separate.

Local gates:

- `swift run --disable-sandbox --cache-path .build/cache SnapCoreChecks`:
  **60 scenarios, zero failures**.
- `swift run --disable-sandbox --cache-path .build/cache AlwaysOnChecks`:
  **34 assertions, zero failures**; new named CI step added.
- Separate debug/typecheck and release `swift build` commands with
  `--disable-sandbox --cache-path .build/cache`: passed.
- `bash -n scripts/build-app.sh scripts/build-fixture.sh scripts/build-always-on-preview.sh`,
  source plist lint (including `AlwaysOnPreviewInfo.plist`) and
  `git diff --check`: passed. No standalone Swift linter is configured.
- Preview and disposable-window fixture packaging, strict deep code-signature
  verification and bundled plist lint: passed in the isolated worktree.
- Main-app packaging/installation intentionally not run; its existing running-app
  guard remains unchanged and installed build 5 was preserved. CI must package
  and verify the main bundle on its clean runner.

Native CUA acceptance, using only the isolated preview:

- Actual app-only warning screenshots show red triangle/white exclamation,
  prominent exact activated heading, explanation and large red Deactivate button.
  The final 520 × 390-point layout is fully legible with no clipping. The warning
  has no close/minimize affordance; AX exposes a system dialog, heading and button.
- Closing preview controls left the active warning visible. Escape did not
  dismiss it. A Command-H attempt did not dismiss it, but this does not prove a
  successful app-hide action, since controls were already closed.
- Return on the warning invoked Deactivate. The live stopping warning remained,
  changed copy truthfully and disabled its pending button. It disappeared only
  after the simulated off observation. A later native click passed the same path.
- Simulated restore failure on Quit kept the process alive and showed Recovery
  with Retry deactivation. Native Retry entered stopping then confirmed off.
- Simulated critical stop went active → stopping → off and stayed off. It tests
  an explicit controller event, not actual battery or heat telemetry.
- Preview fullscreen entry/exit was exercised, but CUA captures its selected
  window only; the control-window render alone does not establish overlay
  stacking on fullscreen Spaces. Cross-app/fullscreen/Space, multi-display and
  hot-plug behavior, Hide All, user-observed absence of focus stealing, and
  VoiceOver traversal remain acceptance gaps. `canHide=false`, nonactivating
  panels, `hidesOnDeactivate=false`, all-Spaces/fullscreen-auxiliary collection
  behavior, screen reconciliation and scrollable small-screen content are
  implemented and source-audited, not a claim of completed physical acceptance.
- Preview ended **off and quit**. `pgrep -x AlwaysOnPreview` returned no process;
  original `PaneManagement` PID **96007** remained. No private desktop screenshot
  was saved or uploaded. CUA captures were app-only and emitted in the builder
  session; there is no documented local image artifact save API in that tool.

The lead independently inspected the final preview via CUA and reported the
red/white triangle, active text, explanation and large Deactivate clearly rendered
without clipping. Its click showed Restoring/disabled button before removal; the
lead then quit the preview and confirmed PID 96007 remained. This is lead visual
review, not a substitute for the separate pinned-head code review.

Sibling-path source audit: Dock and status menus share the item factory and
retain explicit action intent; Settings uses the same state/action mapping;
warning Deactivate calls the same controller. Pending items cannot initiate a
second activation. Settings/reopen reconciles warnings without suppressing the
existing snap-chooser exclusions. All normal app/menu/Settings quits pass the
application termination delegate; restore failure sends a negative quit reply.
A duplicate-launch audit caught the early termination path preceding callback
installation: the final code exits duplicates immediately before starting a
power lifecycle, so they neither hang nor restore another instance's session.
No direct native duplicate-launch claim is made for the new main app.

CodeRabbit is unavailable under the repo restriction. Independent/lead review
remains required for this UI/backend boundary; helper/auth/storage security
review belongs to the separate backend slice. Nothing is merged, armed or
presented as dependable backpack operation.

## Dock presence candidate — October 12, 2026

Build 6 adds running Dock presence and a retained custom Dock menu with Settings
and pause/resume snapping. Source audit covers the launch policy and bundle
metadata together; launch with missing Accessibility or `--settings`, application
menu, menu-bar menu, Dock menu, and Dock reopen all retain the existing Settings
handler. Reopen still refuses to cover Assist, layout, or group choosers.
Dock and menu-bar menus rebuild their labels from the same `Preferences.enabled`
used by the Settings toggle; the controller's existing cancellation and hotkey
registration paths are unchanged. Each menu owns separate item instances and the
delegate retains the Dock menu for its lifetime.

Independent review caught a menu lifecycle contract violation at the first
candidate head: structure was rebuilt from `menuWillOpen`. The local SDK's
`NSMenu.h:279–281` explicitly prohibits menu/item mutation in that callback.
R1 moves both the Dock and menu-bar rebuild paths to `menuNeedsUpdate`; the Dock
delegate callback still refreshes immediately before returning its menu. A source
audit found no remaining `menuWillOpen`/`menuDidClose` mutation callbacks anywhere
in the app. No timer workaround was added. The 60 regressions, separate debug
and release builds, shell/plist lint, and whitespace check all passed again after
this fix. Independent delta and lead review cleared R1 at
`df335612a036637624eace16e4cdbcf64b7de013`; the reviewed worktree was verified
clean. [Final code-head CI](https://github.com/ccmenshealth/pane-management/actions/runs/38272646660)
passed, including packaging and signature checks. Exact model/effort metadata is
unavailable in the builder session; the user authorized the current model.

Local checks in the isolated candidate worktree:

- `swift run --disable-sandbox --cache-path .build/cache SnapCoreChecks`:
  **60 scenarios completed; 0 failures**.
- `swift build --disable-sandbox --cache-path .build/cache`: passed, including
  the AppKit target (separate Swift typecheck/debug-build gate).
- `swift build -c release --disable-sandbox --cache-path .build/cache`: passed.
- `bash -n scripts/build-app.sh scripts/build-fixture.sh`,
  `plutil -lint Resources/Info.plist Resources/TestWindowsInfo.plist`, and
  `git diff --check`: passed.
- `bash scripts/build-fixture.sh`, helper `codesign --verify --deep --strict`,
  and packaged-helper plist lint: passed. The helper was not launched.
- `bash scripts/build-app.sh`: initially stopped at the running-app guard;
  after the authorized scoped quit, packaging, strict deep signature verification,
  and packaged plist lint passed. The guard was not bypassed.

No automated tests were added: this slice changes AppKit activation/menu wiring,
which the pure SnapCore executable does not exercise. Existing regression checks
are required; no fail-first claim is made. Native acceptance is a distinct gate.

Reviewed build 6 was installed at the unchanged primary
`dist/Pane Management.app` path and retained `local.snapbridge.app`. The packaged
and installed executable SHA-256 both equal
`ac23c484f5d574da35fb8fc73b0dd0a9676d04a3c6ccf30cc7b2db3bccd4c793`;
installed strict deep signature verification passed. A signed build 5 rollback
copy is retained locally in the ignored builder path
`.build/dock-acceptance-rollback/Pane Management build5.app`.

Native acceptance used CUA only. An app-only Settings screenshot and AX tree
confirmed the render. The Settings snapping preference changed 1 → 0 → 1;
the original enabled value was restored. The application-menu Settings route
preserved its current state. A close-button action left the same process running,
but subsequent CUA inspection showed Settings again, so this does not establish
visible closure or a Dock-click reopen. Reacquiring the installed app reused the
same PID. Quit removed the process; relaunch succeeded with enabled=1.

Acceptance remains **incomplete**. CUA Dock targets by name, bundle identifier,
and exact system app path timed out. The actual Dock icon/context menu, status
icon/menu, cross-menu pause/resume synchronization, and Dock-click reopen are
unverified. The exposed `Pane Management` menu was the application menu
(Settings/Quit), not the status-item menu. No private desktop screenshot was
saved or published.

The new ad-hoc build is not recognized by the prior Accessibility/preview grants.
Its actual UI reports “Accessibility access is needed to snap windows” and shows
Enable Accessibility and Enable Previews. No permission button was pressed and
no system privacy setting was changed. Live chooser/reopen preservation is
blocked by Accessibility; unchanged guard logic is source-reviewed only. The
lead owns the scoped permission-renewal handoff and remaining native acceptance.

Because native Dock acceptance was blocked, the lead directed a rollback. CUA
Quit removed build 6, the signed build 5 backup was restored to the same stable
path, and strict signature verification passed. The restored executable matches
its original SHA-256:
`3367ecbfc6d95a54bde086348d4c67988c8be8089042ba30a4c853f6634e978a`.
CUA relaunch/reopen confirmed “Running in the menu bar,” the Accessibility
checkmark, “ScreenCaptureKit access verified,” and enabled=1. Build 5 was left
running as PID 96007. No permission change was needed for this restoration.

The verified build 6 candidate remains at
`/Users/ccmh/Developer/PaneManagement-worktrees/dock-presence/dist/Pane Management.app`.
Next acceptance is a lead-coordinated installation at the stable primary path,
with renewal of only the app's existing grants if required, followed by an actual
user/native check of both icons, Dock right-click Settings/pause/resume, shared
menu-bar/Settings state in both directions, repeated menu opens, Settings closure
with residency, Dock-click reopening, chooser preservation, and Quit/relaunch.
Retain the build 5 rollback until those checks pass. No merge/release-ready claim
is made while those native gates remain open.

CodeRabbit is unavailable by explicit repository restriction and was not
requested. Security review is not applicable: no new data access, persistence,
IPC, network behavior, permission flow, or privileged operation is introduced.
This candidate does not implement or validate closed-lid operation.

## Build 5 follow-up acceptance and review-policy preparation

A clean isolated checkout of the review-cadence branch built in release mode
and passed all **60 regression scenarios**. YAML parsing and assertions confirmed
that every pre-existing CodeRabbit setting is preserved; automatic reviews,
chat replies, and issue automation remain disabled. Shell syntax, source plist
lint, existing app/helper strict signature verification, and whitespace checks
passed. No running app bundle was replaced, no permission was refreshed, and
no CodeRabbit review was requested.

The currently running build 5 recognizes Accessibility and ScreenCaptureKit.
After restarting only the disposable helper to recreate its three windows,
the production live fixture runner passed **all 11 checks** on the display left
of the primary screen: actual thumbnails, three exact half-screen pairs,
60/40 linked resizing, group recall after move/minimize, thirds, stacked layout,
three members of a four-zone layout, refused-size rollback, and restoration of
starting frames/visibility. This refreshes the older full-suite result for
build 5; it still bypasses physical input delivery.

The helper's focus control now confirmed foreground/key-window status. A
synthetic Control–Option–Right increased its delivered-key count but did not
produce a snap or change Pane Management's status. This is not a physical-key
pass and does not establish whether the automation reaches the global hotkey
registration. Title-bar drags were attempted on both the negative-origin and
primary displays; desktop automation returned `windowNotFoundAtPosition` before
delivery, with zero fixture drag events and no changed frame. Physical shortcut,
drag/unsnap, native resize, and monitor-transfer acceptance remain open.

The additional primary-display setup moved only a disposable window. The helper
was quit after testing; no other app's window, network, or security settings were
changed. System Settings was inspected read-only and still lists Pane Management
under **Open at Login**. No reboot was performed. Developer ID signing and
notarization remain prerequisites for distributing an installable release.

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
