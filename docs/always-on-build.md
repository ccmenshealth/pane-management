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

### Backend implementation sequence

- B1, `codex/always-on-engine`: pure testable recovery engine and typed fixed
  operations. No live process, filesystem journal, XPC, registration or app wiring.
  Dependencies model guarded telemetry, monotonic time, durable journal and
  bounded power IO. Tests must model late writes after a failed/timed-out call.
- B2a, `codex/always-on-native-io`: native protected journal and fixed bounded
  process/readback adapter, tested in disposable unprivileged fixtures. No daemon,
  app wiring, live power writes, installation or registration.
- B2b: authenticated SMAppService daemon, console/audit and telemetry monitoring,
  fixed XPC contract, admission-closed prepare/removal lifecycle and loopback tests.
  No live install/registration/activation. This split keeps native boundaries
  separately reviewable.
- B3: authenticated app client, setup/removal coordinator, monitoring, app wiring
  and signed packaging. Final installation/arming remains a distinct drill.

For B1 lock these state rules: startup first reads ownership journal; unresolved
records restore before accepting activation. Missing/corrupt ownership with a
true setting is an external conflict, never a silent takeover. Activation writes
durable intent before enable, confirms command plus both readbacks before active,
then commits active before replying. Every interruption after intent attempts
restore; failed restoration retains recovery and a retry action. An off record
may be cleared only after verified off. Any uncertain write outcome must be
treated as potentially applied. All operations serialize; stop/critical/expired
session events latch through in-flight activation so late success is restored.
Journal and power IO failures are separately injectable and bounded by adapters.

Bind generated tokens to authenticated non-root console UID/audit session.
Heartbeat expiry, connection loss, console change, Final battery warning,
Critical thermal, stale/failed telemetry, and externally cleared override stop
without automatic rearm. Caller-supplied values cannot alter deadlines/commands.
Initial absent root property is distinct from post-write verified off; require
explicit matching booleans for all successful writes. An external true write
while owned cannot be distinguished and remains a documented limitation.
Prepare-for-update/removal returns success only after verified restoration;
the eventual sole unregister coordinator must recheck before unregistering.

Use fake journal/power/clock/guard adapters in B1 tests, never live power calls.
Test failures after every await boundary, startup across each journal phase,
pending-enable cancellation, telemetry/heartbeat/session expiry, conflicting
ownership, invalid tokens/session identity, external clear, failed restoration
retry, and prepare-removal. Meaningful red behavior must compile against an
inert scaffold. Add an engine suite to CI and retain red evidence locally.

### B1 adapter and lifecycle handoff

The pure engine is implemented on `codex/always-on-engine`; executable regression
suite `AlwaysOnEngineChecks` is in CI. It does not replace the app's unavailable
backend. Security review of this typed contract is required; real native boundary
review and tests belong to B2/B3.

- Journal methods are synchronous and non-reentrant on the engine's main actor;
  durable intent precedes enable and durable active precedes reply. B2 must wrap
  records with schema, boot identity, generated UUID generation and prior baseline
  false, validating root ownership, regular-file type, link/mode protections and
  schema before returning a record. `corrupt` means only a malformed payload in
  an already security-validated file; security validation failures throw.
- Native journal syscalls/fsync are **not guaranteed bounded**. They can stall the
  daemon main executor. Telemetry collection/watchdog scheduling must be isolated
  from it; daemon/kernel/disk stalls still prevent recovery progress. This slice
  proves transition ordering, not survival of such stalls.
- Async power calls own fixed subprocess bounds and must quiesce every possible
  writer before returning or throwing. Timeout/cancellation must terminate/reap;
  throwing while a process can still write violates the contract. A write can
  apply before failure. Both explicit Boolean readbacks must agree; read/type
  errors throw and confirmed absence is nil. Initial preference must be false;
  only initial root absence is allowed. Postwrite nil never proves off.
- The service injects authenticated current console UID/audit session; callers do
  not supply asserted identities. UUID tokens bind that identity and generation.
  `retryRestore` is the explicit token-lost and pending-activation cancellation
  exit. Native transport must authenticate both directions and avoid logging tokens.
- Guards are cached samples with monotonic timestamps. B2 must schedule monitor
  on notifications and polling, forward disconnects and preserve unknown telemetry.
  Fixed freshness is five seconds and heartbeat lifetime is thirty seconds;
  callers cannot choose either. These are advisory deadlines, not emergency proof.
- Prepare removal is a verified snapshot, not a cross-process transaction. B2
  must close activation admission across prepare/unregister; B3's sole coordinator
  must recheck before unregistering. A coordinator alone cannot exclude a second
  connection. An identical external true write while owned is indistinguishable.
- A durable off record proves earlier restoration and has no remaining power
  ownership. Startup, retry and monitoring only clear it after strict dual-off
  evidence; a later true/unknown setting is a conflict and receives no write.
- Corrupt payload cleanup is possible only through explicit retry/removal after
  fresh strict dual-off evidence, with no power write. Unsafe filesystem metadata
  requires setup repair; no recovery method bypasses that boundary.

### Review ledger

- Engine PR #4: independent ownership/storage/token security fallback review of
  `4a99728` found R1: concurrent status could report off before initial readback.
  Fix `28eeffe` adds checking state before every unresolved ownership read;
  16 targeted pre-fix failures and final inert 176/102 versus implemented 176/0.
  Lead delta review clears the source fix; independent delta and final-head CI
  are pending while the B2a brief is prepared. No native IO builder starts until
  the independent delta clears. Other lead findings and targeted red evidence
  are recorded in VERIFICATION.md. No live operation, install or merge occurred.

### B2a locked native IO contract

- P1: Implement `RecoveryJournal` and `RecoveryPower` in a separate native module.
  Production constructors have fixed locations/commands. Test injection may use
  temporary user-owned directories and harmless executables but must not be
  exposed in the later IPC protocol. No test executes a power write, even false.
- P2: Production journal is `/var/db/local.snapbridge.alwayson`, directory 0700,
  regular files 0600, root owner and single link. Use descriptor-relative openat,
  O_NOFOLLOW/O_EXCL, validated parent/directory/file metadata, bounded decoding,
  atomic rename plus file/directory fsync, and a held process lock. No client path.
  Validate again before cleanup; absent files are distinct from permission or
  metadata failures. Malformed contents in validated storage may be corrupt;
  unsafe owner/mode/link/type must throw. New files use restrictive umask/modes.
- P3: Durable envelope includes schema version, UUID generation/token, console
  UID/audit ID, phase, boot identifier and prior baseline=false. Decode strictly;
  never resume a recorded lease. An old boot record still authorizes restoration
  of unresolved intent/active/restoring; off remains cleanup-only. Native journal
  serializes engine calls; disk stalls are not promised to have a timeout.
- P4: Production writes only `/usr/bin/pmset` with fixed argument arrays for
  disablesleep 1 or 0, no shell or caller environment/arguments. Run off the
  service executor, sanitize environment, cap/drain output, impose a monotonic
  deadline, terminate then kill and reap before returning a timeout/error.
  Do not start a second writer until the first is known quiescent. An unkillable
  kernel/process hang cannot honestly satisfy a bounded-completion guarantee;
  it must not permit a later conflicting writer or successful state report.
- P5: After successful command, require fresh synchronized CFPreferences and
  IOPMrootDomain SleepDisabled Boolean agreement within a fixed readback deadline.
  Use public CFPreferences APIs with `com.apple.PowerManagement`, key
  `SystemPowerSettings`, nested `SleepDisabled`, AnyUser/CurrentHost; require
  actual CFBoolean types. IORegistry lookup/enumeration failure, wrong type,
  synchronization failure, mismatch and missing post-write values are errors.
  A successfully absent key remains nil; never normalize read errors/absence
  into false. The native release may refuse absent initial preference/root;
  no unverified OS-default inference is required. This host publishes false/No.
- P6: Readback confirms persistent preference plus root-domain receipt/enqueue,
  not physical sleep or emergency timing. No brightness, display assertions,
  input interception or broad power-setting restore/change is allowed.
- P7: Fail-first native checks use real disposable filesystem objects and harmless
  subprocess fixtures plus injected power/readback transport. Cover safe round
  trip and restart, lock contention, symlinks/hardlinks/types/modes, corruption,
  before/after durable failures, strict Boolean/absent/error readback, timeout,
  cancellation, nonzero exit, output cap/draining and no delayed write after return.
  Fakes must model a writer that applied before failing. Verify temporary fixtures
  clean up without touching production paths. Native positive root installation,
  actual pmset mutation and physical sleep remain unverified until the arming drill.

P5 source evidence: Apple IOKitUser tag `IOKitUser-100231.120.3`,
`pwr_mgt.subproj/IOPMEnergyPrefs.c` (IOPMCopySystemPowerSettings) and
`IOPMLibPrivate.h` (constant strings); PowerManagement tag
`PowerManagement-1846.120.8.0.1`, `pmset/pmset.m` stores CFBoolean values.
These internal source names guide public CFPreferences reads; do not import
private IOKit functions or headers into the product.

- Engine PR #4, `4a99728180f364d6ee384a2b8ec6120ef7994b95`: independent
  review found only R1 (P2), false off during the first ownership read
  (`RecoveryEngine.swift:90`, `:145`, `:153`, `:190` at that head). Lead agreed.
  Fix: explicit checking initial state and checking before unresolved ownership
  reads. Cold status/activate/monitor/retry/prepare and unowned recheck siblings
  are covered; 16 focused assertions failed before the fix, then all 176 passed.
  Original-head CI run `38281301606` passed. Corrected-head CI and independent
  delta/lead/security acceptance remain pending. No live IO or installation.

- UI PR #3, `1923274f40256ea0be5060c48b922b6c680b11e9`: independent fresh
  read-only review and lead source review found no blocking code issue. Exact-head
  CI run `38278803917` passed. Worktree clean before/after review. Current inherited
  model used; exact reviewer metadata unavailable. Native render reviewed by both
  builder and lead; cross-Space/fullscreen, multiple-screen, VoiceOver and installed
  Dock acceptance remain open. Repeated labeled controller tests do not establish
  native menu wiring. Security boundary not implemented in UI-only slice; B2/B3
  require independent security review. CodeRabbit unavailable by repo restriction.

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
