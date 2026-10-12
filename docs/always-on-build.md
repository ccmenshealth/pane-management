# Always-on mode — authorized build

## Decisions locked October 12, 2026

The user explicitly instructed "Let's build it anyway" after the documented
investigation, and requested a centered always-on-top warning with a red triangle,
white exclamation mark, and deactivate button. This supersedes the earlier
closed-lid-only constraint and investigation-only status. The limitations recorded
in `closed-lid-plan.md` remain factual; do not present best-effort recovery as
preserving native emergency protection.

- A1: Opt-in broad manual always-on mode, off by default. It can keep the Mac awake
  with the lid open or closed. Existing menu-bar and Dock controls share one state.
- A2: Keep app-managed final-battery-warning and critical-thermal stop conditions.
  No arbitrary 20% or serious-thermal cutoff. These are advisory safeguards.
- A3: Prominent centered warning on usable connected screens across Spaces and
  fullscreen app spaces: red triangle, white exclamation, heading "Always-on mode
  is activated", clear explanation that the Mac will stay awake with its lid open,
  and large "Deactivate" button. No close/minimize/dismiss path. Do not repeatedly
  steal keyboard focus. OS login/secure UI cannot be promised to remain below it.
- A4: Only confirmed effective activation uses the activated heading. Pending and
  failed activation/restoration must use truthful copy. Deactivation keeps the
  warning until restoration is confirmed; failures expose "Retry deactivation".
- A5: Off, activation pending, active, stopping, recovery required, and unavailable
  states have explicit visible exits. All entry points use the same controller.
  Concurrent/repeated actions must not race. Opening Settings/reopening app may
  not hide the warning. Screen changes recenter/reconcile panels.
- A6: Explicit quit first deactivates; failed restoration keeps app and recovery UI
  available. A helper attempts restoration on lost/expired UI session and startup.
  No automatic reactivation after critical stop, crash, restart, or reboot.
- A7: Privileged operations use a narrow authenticated boundary, fixed operations,
  protected recovery records, readback verification, and explicit setup status.
  No arbitrary shell commands from IPC, security weakening, unrelated identity use,
  or silently overriding another app's preexisting sleep override.
- A8: Build and review are authorized. Live privileged installation and first
  activation are a separate, concrete arming drill after code/recovery gates.
  No power setting writes, helper installation, physical lid testing, or deliberate
  battery/heat stress during the build. Preserve running build 5 and its grants.
- A9: Use user-authorized current models. Lead writes planning docs only; native
  builder owns product code in its own worktree; independent review is read-only.

## Slices and dependencies

1. Dock PR #2 remains draft pending native acceptance. Runtime source `df33561`;
   documentation base `6fda8c1`. Existing installed build 5 remains the fallback.
2. **State/controller and warning UI**: branch `codex/always-on-ui`, worktree
   `/Users/ccmh/Developer/PaneManagement-worktrees/always-on-ui`, stacked on Dock
   branch. Implement testable state/controller boundary, menu controls, warning
   panels, and safe fixture rendering. Production capability may report setup
   unavailable until the backend slice lands; never report fake activation.
3. **Privileged backend and packaging**: sequential separate builder/worktree after
   the first slice and helper architecture are reviewed. Include applicable
   security review and concrete setup/uninstall/recovery paths. Stop if supported
   secure installation cannot be established; no build-around fallback.
4. **Installation and arming**: only after independent/lead review and local/CI
   checks; native permission refresh, overlay/Dock verification, ordinary failure
   recovery drill, then explicit first-use handoff. Physical tests remain distinct
   from simulated evidence. No merge while required native acceptance is red.

## Required gates per implementation slice

- New regression tests must produce meaningful assertion failures against the
  disabled/pre-implementation scaffold before implementation; retain red output.
  A compilation failure due only to missing symbols does not prove behavior.
- `swift run --disable-sandbox --cache-path .build/cache SnapCoreChecks`
- New feature-specific test suite, named in builder report and CI when added.
- `swift build --disable-sandbox --cache-path .build/cache`
- `swift build -c release --disable-sandbox --cache-path .build/cache`
- Lint: shell `bash -n` for scripts, `plutil -lint` for all relevant plists,
  `git diff --check` (no standalone Swift linter is configured).
- Packaging/signature checks after a separately coordinated app quit; do not
  bypass the running-app packaging guard or replace the installed bundle now.
- Real native warning render through an isolated preview/fixture that performs
  no power operation. Screenshot only the task's own window; no unrelated content.
- Independent and lead pinned-head review; security review for helper/auth/storage.
  CodeRabbit unavailable by explicit repo restriction. Sibling entry points and
  recovery states audited, exact evidence in `VERIFICATION.md` and PR body.

## Recovery checks

| State/event | User-visible exit and required check |
| --- | --- |
| Off or missing helper | Activate/setup explains capability; cancel remains off |
| Activation pending | Deactivate cancels and serially restores; late success cannot re-arm |
| Active | Dock/menu/warning Deactivate share state; warning remains until confirmed off |
| Critical warning | Stop then require explicit new activation, never automatically resume |
| Restore failure | Persistent warning and retry; no false off or successful quit |
| App quit/reopen | Quit restores before exit; reopen cannot hide active/recovery warning |
| App/helper crash, hang, reboot | Helper recovery protocol tested where feasible; limits remain disclosed |
| Screen/Space/fullscreen change | Warning remains on reachable screens with an enabled deactivate action |

## Findings and handoff

- UI/controller slice implemented; local regression/build/lint/fixture gates pass.
  Inert scaffold compiled with 34 assertions/31 failures; implemented controller
  passes 34/0. Actual CUA warning active/pending/stopping/recovery renders and
  deactivate/retry/failed-quit behavior inspected. See `VERIFICATION.md` for
  exact evidence and remaining cross-Space/multi-screen acceptance gaps.
- Builder sibling audit fixed duplicate-launch termination before power lifecycle
  initialization; duplicate processes must not wait for an uninstalled callback
  or restore another instance's session. No main-app native launch was performed.
- Independent/lead pinned-head review and remote checks remain pending at handoff.
  CodeRabbit unavailable by repository restriction. Helper security architecture
  is recorded below; implementation remains a separate slice.
- No live power state or installed application was changed to start this build.

## Backend handoff (design only; separate slice)

Use an SMAppService LaunchDaemon with dedicated Apple-issued matching app/helper
signatures and notarization. Do not add a legacy/ad-hoc privileged fallback or
reuse the unrelated VCMC identity. Missing signing blocks registration and
installation, not isolated development/loopback tests. Plan any eventual install
path migration explicitly; do not move installed build 5 during development.

The app and helper must set reciprocal public NSXPC code-signing requirements
before resuming a connection: exact identifiers, Apple anchor and Team ID.
Validate the non-root current console UID/audit session and bind the session token.
Only fixed operations are allowed: status, activate, heartbeat, deactivate,
retryRestore, prepareForUpdateOrRemoval. Accept no caller commands, paths,
preference keys, or timeouts. Root-only protected `/var/db` recovery records need
intent plus fsync before enable; serialize generation ownership. Unresolved
startup records restore before new sessions. Fixed bounded asynchronous
`/usr/bin/pmset` arguments must be followed by agreement between persistent
preference and IOPMrootDomain `SleepDisabled` Boolean readbacks. This confirms a
setting receipt, not physical sleep or emergency timing.

Heartbeat expiry, connection loss, console switch, final battery warning and
critical thermal warning restore and remain off. Use notifications plus polling;
None/Nominal can disguise unknown telemetry and remain a documented limit.
Refuse an existing true override with no owned recovery record, never reassert an
externally cleared false value, and disclose that an identical external true
write cannot be distinguished. The sole unregister/update/removal lifecycle must
restore and recheck first. Unknown restoration keeps warning/retry visible.

For the UI protocol, `.unavailable` asserts no owned override exists and no
activation is available. It is valid for this slice's never-implemented backend,
not for a configured-but-unreachable helper. Such startup/disconnect ambiguity
must be `.unknown`; the controller attempts restoration and retains recovery UI
on uncertainty. Replace the unavailable adapter wholesale in the backend slice.
No automatic resume is permitted. Do not add display-on assertions, brightness
writes, or keyboard/trackpad interception. Closed-lid darkness and actual hardware
behavior require the separately authorized physical drill.
