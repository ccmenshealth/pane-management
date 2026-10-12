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

- Coordinator PR #6, `7164b2e5a23cc9ab262c66f6f82f768a7ed0c7c8`: independent
  read-only code/manual-security fallback and lead reviews clear with no remaining
  actionable finding; reviewed worktree stayed clean. Inherited model used, exact
  metadata unavailable. CI `38288409516` passed including service347/0 and packaging.
  Final compiled inert347/162; two targeted eight-failure regressions fixed shared
  restoration settlement and strict final removal confirmation. B2b2 may start;
  native signed/auth/telemetry/installation/physical acceptance remain open.

- Native IO PR #5, `f54707554029284a7760746f897e5c12efb158a2`: fresh read-only
  independent code/manual-security fallback and lead reviews found no remaining
  actionable issue. ACL allocation ownership matched Apple's Libc filesec source.
  Reviewed worktree stayed clean; current inherited model used, exact metadata
  unavailable. CI `38284998731` passed including native114/0 and packaging/signature
  checks. Final compiled inert114/94 and focused pre-ACL114/9 evidence retained.
  Earlier process identity, read deadline and ACL sibling findings corrected.
  Root installation/power mutation/physical acceptance remain unverified; no merge
  or arming. B2b1 coordinator may proceed. CodeRabbit remains excluded.

- Engine PR #4: independent ownership/storage/token security fallback review of
  `4a99728` found R1: concurrent status could report off before initial readback.
  Fix `28eeffe` adds checking state before every unresolved ownership read;
  16 targeted pre-fix failures and final inert 176/102 versus implemented 176/0.
  Independent and lead delta reviews clear the source fix; final-head CI
  `38281961153` passed. Review worktree remained clean. Native IO build may start.
  The original review finding was at RecoveryEngine.swift:90/:145/:153/:190;
  cold status/activate/monitor/retry/prepare and unowned recheck siblings are covered.
  Original-head CI `38281301606` also passed. Other lead findings and red evidence
  are recorded in VERIFICATION.md. No live operation, install or merge occurred.

### B2a candidate handoff

`AlwaysOnNative` now implements the P1–P7 adapters without daemon/app wiring.
Native fixture checks are included in CI. Production construction fixes the
journal root, expected root UID and pmset arguments; fixture injection remains
in-process only and must never become IPC input. Use one journal/power adapter
pair for the daemon lifetime. No helper or native activation has been installed.

Early lead review identified a post-reap group signal (PID reuse hazard),
unbounded readback, and acceptance of a late read before a delayed timer callback.
The candidate reserves child identity with `waitid(WNOWAIT)` through group cleanup
and final reap, uses a bounded single-flight read worker, and checks monotonic
elapsed time on both read and process success paths. Unknown child-wait ownership
holds the writer slot indefinitely; it does not guess that a writer has stopped.
Formal independent/lead/security review remains a gate, not implied by this pass.

B2b must keep telemetry/watchdog collection separate from synchronous journal IO,
retain unknown/error read state, and map failed recovery to the existing retry UI.
A timed-out native read may still run but cannot queue another read or publish a
late result. A normal timeout/cancel terminates and reaps the sole fixed command
writer; kernel-stuck writers/disk calls remain outside recovery guarantees.
Readback proves persistent preference and root-domain receipt, not physical sleep.
Protected storage and trusted parents also reject nonempty extended ACLs;
114 native checks pass after a full inert 114/94 red and focused ACL 114/9 red.

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

### B2b1 locked service coordinator contract

B2b is split into a pure coordinator/wire-value slice and then the native
authentication/telemetry/daemon boundary. B2b1 starts only after B2a pinned code
and security review clear. Branch `codex/always-on-coordinator` is stacked on
native IO PR #5. No native adapter is invoked by its fixtures.

- C1: Transport-neutral version 1 values expose exactly status, activate,
  heartbeat(token), deactivate(token), retryRestore, and prepareForUpdateOrRemoval.
  Status never returns the internal lease/token. Only a genuinely new successful
  activation returns its token; duplicate/already-active results carry no token.
  No caller identity, command, path, preference key or timeout enters the wire.
  Malformed/version-mismatched requests must fail without state mutation.
- C2: A single MainActor coordinator fronts the engine. Immutable ConnectionKey
  contains a random ID and monotonic generation; captured ConsoleSession comes
  from the later trusted admission boundary. Inject current-session validation
  and telemetry ports for tests. Accepting a connection or reading status never
  changes the guard target. Start bootstrapping and prohibit activation until
  startup resolves exactly off; recovery/conflict retains status/retry exits.
- C3: Keep independent admission and ownership states. Admission is bootstrapping,
  open, preparing(epoch,key), or sealed(epoch,key). Ownership is none,
  pending(epoch,key,session,baseline-or-activating), active(epoch,key,lease), or
  restoring(epoch,key,lease?). Allocate an operation epoch and reserve ownership
  synchronously BEFORE the first baseline status await. A second activation is
  rejected while reserved. Do not hold an async mutex across awaits that prevents
  stop/critical/disconnect events from entering the coordinator.
- C4: After baseline await, recheck exact epoch/key/stage, open admission, live
  connection, current console and exactly off. Bind the guard to that session and
  advance to activating without another await before engine.activate. Every
  completion checks its original epoch/key/admission before publishing or clearing.
  The engine may return an existing active lease on refusal; never adopt it or
  treat it as new activation. Stale completion clears only its own reservation.
- C5: The coordinator-owned guard binding has epoch and target session. Compose
  its snapshot from separately cached telemetry and session-validity facts; the
  timestamp is the oldest required successful sample. Unknown/stale components
  remain unknown/nil. Retain the target through active/restoring; clear only a
  matching epoch. Connection acceptance/status cannot select a different target.
  Critical/session-change monitor events remain reentrant during power awaits.
- C6: Heartbeat/deactivate require the bound exact live ConnectionKey and token;
  reconstruct the lease from service ownership. Reconnect with identical UID/ASID
  gets a new key and cannot inherit a token; retryRestore is the token-loss exit.
  Both interruption and invalidation are idempotent disconnect events by key.
  Ignore late invalidation of an old key after a newer activation. Baseline
  invalidation cancels the reservation; activating invalidation marks restoring
  and latches engine.disconnected. Never cancel the in-flight engine Task or
  release ownership before its writer/restoration settles.
- C7: Prepare synchronously closes admission before ANY await. Cancel pending
  activation, retain its target while settling restoration, then bind the
  preparing authenticated caller and invoke engine.prepare. On success seal
  admission and return a permit containing daemon incarnation UUID and epoch,
  bound to the same live connection. A final status recheck returns that permit
  only to that connection while sealed and verified off. B3 must compare it before
  unregistering; interruption/restart invalidates it and requires new preparation.
  This is a snapshot, not atomic exclusion of crash/restart/external mutation.
- C8: Failed preparation stays recovery-only/preparing; failed unregister stays
  sealed. Status, retry and re-prepare remain available; activate stays rejected.
  Retry must never silently reopen admission. No cancel-removal operation is
  added: finish/retry removal, or an explicit later service restart, is the exit.
  Re-prepare creates a fresh epoch/permit after the previous operation settles;
  concurrent preparation cannot overwrite an in-flight reservation.
- C9: Recoverability fixtures cover every suspension fork: baseline reservation,
  activation stages, disconnect/critical stops, prepare races, stale completions,
  same-session reconnect and late old invalidation. Assert no token leakage or
  active reply after a stop. Prove failed recovery can retry to off and that
  checking/unknown never maps to off. Use the real pure engine with injected
  journal/power/clock/guard adapters where practical; fakes must match its refusal
  and reentrant semantics. No live power, filesystem journal or process invocation.

B2b1 required commands: all existing SnapCoreChecks, AlwaysOnChecks,
AlwaysOnEngineChecks and AlwaysOnNativeChecks, plus AlwaysOnServiceChecks, each
via `swift run --disable-sandbox --cache-path .build/cache`; separate debug and
release `swift build` commands; script `bash -n`, resource `plutil -lint`, and
`git diff --check`. Add the new suite to CI. Keep compiling inert-scaffold red
evidence and exact final green evidence. Independent code/security fallback and
lead reviews are required. No UI change means no new render gate for this slice;
existing native acceptance remains open. Do not package over a running app.

### B2b1 candidate handoff

Pure coordinator and wire values implement C1–C9; 347 checks pass after a compiled
inert overlay failed 162 assertions. Shared restoration-settlement and strict
final-removal observation races have separate eight-failure pre-fix evidence.
Independent code/security fallback, lead review and CI remain required; no
native boundary or app wiring is included. The fixed six requests preserve
connection-only token ownership and epoch/incarnation-bound removal permits.

Final status uses the **same** injected `RecoveryPower` instance as the engine
for one strict dual-false receipt; absence/mismatch/error revokes the permit and
retains recovery-only admission. It never writes power or rebinds the guard.
Native B2b2 must drive `start`, `monitor`, `accept` and idempotent key-specific
`disconnected` calls, supplying trusted cached environment facts. Do not cancel
engine tasks, accept caller identity from payloads, or configure a separate reader.

Later B3 setup is optional/unavailable only after fresh triple proof:
SMAppService notRegistered, strict public dual-false readback, and securely
verified absence of the fixed journal directory through canonical trusted
parents, descriptor-relative nofollow lookup and ACL validation (only ENOENT).
Unreachable/configured helper, unsafe/existing journal or unknown read means
setup repair/unknown warning. Setup registers/authenticates only, never activates.

### B2b2 native boundary handoff

#### N1–N8 implementation lock

- N1: B2b2 on `codex/always-on-daemon` adds the supported native boundary only
  after B2b1 code/security/CI acceptance. Fixed executable target `PaneAlwaysOn`,
  signing identifier/Mach service/launchd label `local.snapbridge.alwayson.service`.
  App identifier remains `local.snapbridge.app`. BundleProgram is
  `Contents/MacOS/PaneAlwaysOn`; launchd plist lives at
  `Contents/Library/LaunchDaemons/local.snapbridge.alwayson.service.plist`.
  Use SMAppService daemon packaging, RunAtLoad/KeepAlive, no legacy installation.
  Do not launch/register the production daemon or perform native power writes.
- N2: Validate self via SecCodeCopySelf, SecRequirementCreateWithString and
  SecCodeCheckValidity with Apple generic anchor and fixed own identifier BEFORE
  reading trusted kSecCodeInfoTeamIdentifier. Require a bounded safe Team ID and
  revalidate self with certificate leaf subject OU equal to that team. Peer uses
  same derived team + Apple generic anchor + fixed peer identifier. No configurable
  team, PID authentication, ad-hoc/CDHash fallback or unrelated VCMC identity.
  Listener setConnectionCodeSigningRequirement and client setCodeSigningRequirement
  must precede activation/resume. Shared code may expose the app-side requirement
  constructor for B3; app client itself remains B3.
- N3: Kernel-provided effective UID/audit session are the only peer identity
  inputs. Public audit_get_sinfo_addr must confirm same ASID and audit user equal
  to non-root effective/console UID; reject default/invalid IDs, remote sessions,
  missing authenticated/graphic/console flags. Double-read console UID around
  audit lookup. A small public-lib bsm C shim is allowed if Swift imports require
  it. No private API. Acceptance and subsequent validation use fresh cached facts;
  neither status nor connection acceptance rebinds coordinator ownership.
- N4: Fixed NSXPC protocol bridges only the six ServiceRequest operations. Bound
  request/reply sizes and validate version/shape before invoking the coordinator.
  No arbitrary commands, paths, identities or deadlines. Exact ConnectionKey is
  captured per exported bridge; interruption AND invalidation idempotently call
  disconnected for that key, including loss while admission is pending. Never
  cancel an engine operation to discard a connection. Do not log lease tokens.
- N5: Independent native collection caches battery, thermal and per-session
  validation with monotonic timestamps. Use documented power/thermal/console
  notifications plus a one-second poll/watchdog, below five-second freshness.
  Watchdog scheduling cannot depend on a synchronous journal or telemetry read
  completing; monitor still receives stale/unknown cache when collection stalls.
  Avoid accumulating queued telemetry jobs. Unknown/enumeration/type/registration
  failures remain unknown. Validate presence/type of an internal battery; don't
  infer a healthy laptop from a failed/empty enumeration. Use OS Final battery
  warning and Critical thermal only, no percentage or Serious cutoff. OS None/
  Nominal internal-error ambiguity remains explicitly unprovable.
- N6: Production entry verifies root and trusted self identity before constructing
  fixed native journal/power. One lifetime instance of each is shared with the
  coordinator, including strict final removal reads. Bootstrap resolves recovery
  before listener accepts activation; status/retry remain available for recoverable
  states. Never auto-activate/resume. No command-line/env fixture or bypass mode in
  the production executable. In-process test injection belongs to library/tests.
- N7: Unprivileged fixtures exercise strict DTO rejection, signing-requirement
  construction/negative self validation, audit policy, telemetry failure/staleness,
  bridge invalidation races, and coordinator/native-port composition with fake
  power/journal. Public read-only identity/telemetry inspection is allowed; no
  production journal constructor or native power write. Anonymous NSXPC negative
  auth tests may run without Apple signing; positive signed reciprocal acceptance
  remains unverified until the required identity exists. Never label mocked auth
  as real signed acceptance. Preserve meaningful compiled pre-fix red evidence.
- N8: Add AlwaysOnDaemonChecks to CI and run every prior suite plus it; separate
  debug/release builds and script/plist/diff lint. Embed helper in clean-runner
  packaging, sign nested code before outer app, verify both; local packaging must
  refuse overwrite while PaneManagement OR PaneAlwaysOn runs. CI ad-hoc packaging
  is not an installable/trusted helper. B3 supplies validated Apple signing and
  notarization workflow. Existing installed build5/path/grants remain untouched.
  Independent code/manual-security fallback + lead review are mandatory. No merge,
  install, registration, permission changes or arming. A cohesive native boundary
  may exceed the ~800-line guideline modestly; report scope rather than splitting
  authentication from its enforcement just to meet a line count.

#### B2b2 implementation handoff

- `AlwaysOnDaemon` uses a canonical JSON `Data` request (maximum 1,024 bytes),
  bounded reply (4,096 bytes, reason at most 2,048 UTF-8 bytes), and only the six
  version 1 operations. B3 should use `BoundaryPolicy.encode` and `AlwaysOnXPC`.
  Wire size limits apply after Foundation decodes Data; they do not claim a bound
  on the transport's initial allocation. No identifiers/tokens are logged.
- `TrustedIdentity.peerRequirement(own: .app)` supplies B3's derived helper
  requirement. Set it on the connection before activation. Server sets both the
  listener and per-connection requirement before activation. Actual matching
  Apple-issued authentication is unverified; no account exists yet.
- New connections are tracked before async collection. Initial request may return
  checking/rejected until cached console/audit validation arrives. Retry status
  on that same connection with a fixed deadline; readiness is not activation.
  Each connection admits once to a unique opaque key, permits one in-flight
  request, and closes irreversibly on either interruption or invalidation.
- Power collection, console/audit collection and the monitor watchdog each have
  independent scheduling and coalescing. Lead finding N-R1 split the shared power/
  session queue after six pre-fix failures for stuck battery/thermal readers. Final
  suite is 118/0; exact compiled inert overlay 118/86. Recovery
  requests require fresh console authentication, while unknown battery/thermal
  denies activation. Final/Critical restoration uses the real coordinator.
- B3 must not interpret `pgrep` as unregistration proof: a registered service can
  lack a PID during crash throttling. Replacement requires the sole prepared,
  strictly rechecked and unregistered path even when the build-script guard passes.
- Independent/lead code and native-auth security review, CI, and the documented
  signing/install/physical/UI acceptance gates remain open at builder handoff.

#### B3 fresh setup state

An optional never-configured launch may report unavailable without an alarm only
after a fresh read-only triple proof: SMAppService notRegistered, strict public
preference/root-domain false/false, and securely absent fixed journal directory.
Traverse trusted canonical parents with owner/mode/ACL checks; use descriptor-
relative no-follow lookup and accept only ENOENT. Bracket the observation with
service status checks and recheck after wake/setup transitions. No persisted proof.
This relies on durable intent remaining inside the stable directory before every
true write; root interference and changes after a snapshot remain limitations.
Existing/unverifiable directory, configured service or true/unknown receipt means
setup-repair/unknown, never unavailable. Setup registers/authenticates only; it
does not activate. Missing signing can leave a freshly proven safe optional setup
diagnostic; it cannot hide an uncertain existing override. B3 must expose setup/
repair alongside retry, and never map configured-unreachable to safe off.

Use public reciprocal NSXPC code-signing requirements before connection/listener
activation. Derive Team ID only after self validation against Apple generic anchor
and the fixed own identifier, then validate again with that Team ID. Peer requires
the same Team ID, Apple anchor and fixed peer identifier. Missing/ad-hoc/unrelated
signatures fail closed; no caller-configurable team or PID lookup authentication.
Missing signing blocks positive signed acceptance/installation, not code or tests.

Capture NSXPC effective UID and audit session ID. Validate through public
SCDynamicStoreCopyConsoleUser and audit_get_sinfo_addr, with UID double-read around
audit query: returned ASID must match; audit user equals effective/non-root console
UID; require authenticated/graphic/console flags and reject remote/default IDs.
There is no atomic public UID-to-unique-ASID mapping; notifications and polling
reduce the race but do not remove it. No claimed identity from client payload.

Collect battery, thermal and console facts on a queue separate from engine/journal
IO; documented notifications plus polling below the five-second freshness limit.
Final battery and Critical thermal stop; serious thermal and arbitrary20% do not.
Registration/enumeration/type/scheduling errors are unknown. None/Nominal can hide
internal OS telemetry failure, and disk/kernel stalls remain documented limits.
Startup restores unresolved records before accepting activation; never resume.
Native daemon composes one protected journal/power pair and the B2b1 coordinator,
fixed six-operation DTO bridge, exact-key invalidation, and generation-safe guards.
No app registration or live activation in this slice. B3 owns the bounded client,
heartbeat, setup/removal UI and final app wiring. Packaging must refuse replacement
while app OR helper runs; no legacy/ad-hoc privileged fallback. Preserve build5.

P5 source evidence: Apple IOKitUser tag `IOKitUser-100231.120.3`,
`pwr_mgt.subproj/IOPMEnergyPrefs.c` (IOPMCopySystemPowerSettings) and
`IOPMLibPrivate.h` (constant strings); PowerManagement tag
`PowerManagement-1846.120.8.0.1`, `pmset/pmset.m` stores CFBoolean values.
These internal source names guide public CFPreferences reads; do not import
private IOKit functions or headers into the product.

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
