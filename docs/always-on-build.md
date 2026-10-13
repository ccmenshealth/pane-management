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

#### B3 sequential integration slices (locked 2026-10-12)

B3a implements the shared wire/signing target and bounded app-side client, with
injected transport/scheduler fixtures. B3b adds native setup/absence proof,
backend/controller/menu/Settings integration and preview acceptance. B3c supplies
signed staging/notarization instructions and any necessary packaging changes.
Each slice gets a fresh read-only code/security reviewer and lead acceptance
before the next writer starts. No slice installs, registers, arms or replaces
build 5. Missing Apple Developer identity blocks positive signed/native acceptance,
not these implementations. Current inherited model overrides old skill pins.

##### B3a client decisions K1–K8

- K1: Extract only shared fixed identifiers, AlwaysOnXPC, canonical codecs and
  reciprocal signing into a small target. Audit/telemetry/listener/runtime and
  native privileged ports stay daemon-side. Preserve existing server behavior
  and sibling tests; the GUI must not link the daemon implementation merely to
  obtain protocol declarations. App wiring belongs to B3b.
- K2: Reply decode enforces maximum 4096 bytes, exact fields/version, canonical
  sorted JSON, bounded reason, canonical UUID/permit fields, and valid semantic
  combinations. Only activated+active carries an activation token; prepared+off
  requires a permit, and sealed observed+off may carry one. Other combinations
  cannot carry either authority. Validate reply against the requested operation:
  status never yields a token; an activation succeeds only with its own fresh
  token. Unknown/malformed/contradictory replies never become safe off.
- K3: One authenticated NSXPC connection generation at a time; derive same-team
  peer requirement only from validated self and set before activation. One RPC
  in flight, exactly-once completion, fixed 5-second monotonic deadline including
  callback-time deadline validation; close on timeout/error/loss/malformed reply.
  Both loss callbacks fence synchronously before scheduling actor work. No PID,
  Team-ID configuration, ad-hoc bypass, private API, argv/env test mode, or logs
  containing tokens. In-process injected ports are allowed.
- K4: New connection may initially reject status while native console collection
  runs. Retry status only at 250 ms spacing within a fixed 5-second readiness
  budget; readiness never retries a mutation. Activation is sent at most once.
  Ambiguous activation invalidates, drops authority, then reconnects and attempts
  retryRestore with fresh authenticated status. Bounded attempts stop at visible
  recovery-required; a human retry starts another bounded attempt.
- K5: Activation token exists only in memory on the same generation. Heartbeat
  every 10 seconds, serialized with foreground operations. Interruption,
  invalidation, timeout, malformed reply or non-active heartbeat cancels renewal,
  drops token and starts bounded recovery. Off connections are monitored too;
  a configured helper loss must publish uncertainty, never retain stale off.
  Global active without this client's memory token is orphaned and restored,
  never adopted. Deactivate uses own token when available, otherwise retryRestore.
  User stop during activation waits for settlement and restores a late success.
- K6: Client observations carry a revision or equivalent stale-completion fence.
  Heartbeat/loss cannot be overwritten by an older foreground result. Coalesce
  background events during a foreground call and publish its conservative settled
  observation. Keep the client independent from UI setup policy; B3b combines
  these observations with registration/absence proof and controller quit rules.
- K7: Removal is a single serialized client operation: prepare, require off plus
  permit, then immediate same-connection status with the identical permit and
  strict off. Before calling an injected unregister closure, synchronously check
  that connection generation/fence is still valid. Failure aborts unregister and
  leaves recovery/reprepare available. A five-second unregister reporting deadline
  does not prove settlement: retain the lifecycle lane until actual OS completion,
  publish removalPending, and block B3b registration too. Marshal its callback to
  MainActor; reconcile late success/error. Never reuse permits across attempts or
  reconnection. Actual SMAppService call and UI belong to B3b. No pgrep inference.
- K8: AlwaysOnClientChecks covers strict wire shapes, negative native signing,
  readiness success/timeout, exactly-once and delayed callback deadlines, both
  loss forks, no token adoption, ambiguous activation, late-stop success,
  heartbeat and off-connection loss recovery, stale completions, prepare permit
  mismatch/incarnation/loss/unregister error and fresh reprepare. Use harmless
  injected peers, never a registered/root helper or real power writes. Overlay
  final tests on compiling pre-fix/inert source and retain behavioral red evidence.
  Run every prior suite, separate debug/release compilation, script/plist/diff
  lint, CI and fresh independent/manual-security plus lead review. No UI change
  or installed/signed acceptance claim. Aim near 800 changed code/test lines;
  report cohesive overage before expanding scope.

##### B3b sequential split and setup decisions S1–S9

B3b1 is a headless read-only native/setup coordinator slice. B3b2 then adapts the
controller, warning/menu/Settings UI and app lifecycle to it. This keeps native
filesystem/ServiceManagement policy independently reviewable before UI wiring.
No installed application or service changes occur in either build slice.

- S1: Extract `AlwaysOnReadOnly` containing the existing strict public power
  decoder and bounded reader, shared fixed journal-directory name and trusted
  parent/ACL validation, plus a new absence-only probe. NativeRecoveryPower and
  NativeRecoveryJournal reuse those implementations. Keep mkdir/lock/records/
  writes/process execution in AlwaysOnNative. GUI dependency graph must exclude
  AlwaysOnNative, AlwaysOnDaemon and audit code. Preserve earlier suite evidence
  with extraction regression checks; no rewrite of already reviewed policies.
- S2: Absence traverses `/private/var/db` from `/` with descriptor-relative
  O_DIRECTORY/O_NOFOLLOW/O_CLOEXEC opens and root-owner/non-group-or-other-writable/
  valid empty-or-absent ACL checks. fstatat of the fixed child with
  AT_SYMLINK_NOFOLLOW accepts only -1/ENOENT. Existing child of any type, permission
  denial, unsafe parent, malformed ACL and all other failures are uncertainty.
  Never open/create the child. Test-only temporary-parent injection is allowed,
  not a production path/UID option. Run filesystem reads off MainActor with a
  fixed bounded report deadline and single-flight worker retained through stalls;
  late results cannot overwrite newer state or create a growing work queue.
- S3: Optional unavailable requires a fresh ordered bracket: notRegistered,
  strict dual-false power receipt, secure directory absence, notRegistered again.
  No cache/persisted proof; fresh at launch/wake/setup transitions. Any uncertainty
  means visible setupRequired/unknown. Snapshot races/root interference remain
  limitations. Successful removal may yield same-process quiet unavailable from
  its verified live permit; next launch/wake repeats proof and the retained root
  directory intentionally produces conservative repair. No storage cleanup here.
- S4: Add one MainActor setup coordinator with injected client, service and
  read-only ports. Publish a single increasing revision with state, fixed remedy,
  and lifecycle-pending flag. Remint client observations; newer loss/heartbeat/
  setup events must defeat an older probe/foreground completion. Expose headless
  startup/refresh, explicit setup, activate, deactivate, remove and explicit
  approval-navigation methods. Constructor and startup never register, activate,
  open Settings, perform direct/native power IO or create journal storage. Startup
  may invoke the reviewed authenticated recovery path to restore an existing
  orphan/uncertain override; it never activates.
- S5: SMAppService uses only daemon(plistName: fixed filename). Model status
  notRegistered/enabled/requiresApproval/notFound distinctly. Only explicit setup
  on notRegistered validates trusted app identity then registers once; enabled
  reconnects/recovers without duplicate registration; requiresApproval offers
  a separately clicked Open Login Items Settings action; notFound explains that
  the signed installation needs repair and offers recheck. Never unregister/
  reregister as a repair shortcut. Re-read status after register success/error
  to resolve already-registered/denied races. Missing signature stays quiet only
  after S3 proof; otherwise warning-visible. No ad-hoc/legacy/VCMC fallback.
- S6: Registration runs on a dedicated non-main serial executor. A reporting
  deadline may show pending but cannot cancel, retry or release a registration
  slot while it may still apply. Read-only service status is bounded/single-flight
  independently; stuck OS reads cannot block UI or queue unlimited jobs. Removal
  uses the B3a sole prepare/final-recheck flow and immediate callback-based
  SMAppService.unregister; marshal global completion to MainActor. Preserve
  client removalPending until actual settlement. All setup/register/activation/
  removal mutations are excluded throughout an existing lifecycle operation,
  including its preparation phase. Expected unregister loss cannot erase success.
- S7: Recoverability values support Set Up for fresh safe state; Open Login Items
  for approval; Check Again plus signed-install repair explanation for notFound/
  signing failure; Retry deactivation AND Repair setup for configured uncertainty;
  Deactivate for active; Retry removal after failed removal with fresh permit.
  Pending OS operation visibly says waiting and excludes competing mutations.
  off alone enables activation. setupRequired/unknown are not quit-safe. No
  silent auto-resume after process restart, reconnect, wake or repair.
- S8: Tests cover every triple-proof receipt/status/error fork; real temporary
  filesystem file/dir/symlink/writable/wrong-owner/ACL parent and ENOENT-only
  policy; stalled/late read; zero startup mutations/navigation; full registration
  status/error/identity matrix; newer observation defeating older proof; pending
  register/unregister exclusions; late actual settlement; expected removal loss
  and retry. Use fake ServiceManagement/client ports and temporary user storage;
  never call real register/unregister or construct production journal/writer.
  Preserve compiling pre-fix/inert red evidence. A public read-only live probe is
  allowed but is not required and proves only its instantaneous observation.
- S9: Add AlwaysOnSetupChecks to CI; run all prior suites and new setup checks,
  separate debug/release build/typecheck, bash/plist/diff lint, remote CI, fresh
  independent/manual-security plus lead review. No new UI in B3b1; B3b2 must
  render all new warning/actions in the native inert preview. No merge/install/
  registration/arming. Prefer a cohesive ~800-line slice; modest extraction/test
  overage must be reported, not hidden. Signing/native acceptance remain open.

##### S-R4 — preserve the removal exit across reconnect (locked 2026-10-12)

Lead and read-only architecture review confirmed that a failed unregister leaves
daemon admission preparing/sealed while the engine reports off. The old wire
lost that distinction, so a new client or wake refresh offered Activate, which
could never succeed until removal completed. An app-only latch would lose the
exit on restart and is rejected.

- Add required canonical Boolean `requiresRemoval` to the pre-release v1 reply.
  Coordinator derives it from preparing/sealed admission on replies. It is status
  metadata, not authority. Rejected/invalid replies never establish safe off.
  Prepared replies and every permit require true; activated replies forbid it.
  Decoder must reject a missing/malformed/contradictory field. This paired
  pre-release app/helper schema change ships together; no installed helper exists.
- Distinguish verifiedOff (off + observed) from usableOff (verifiedOff and false
  requiresRemoval). Final removal check needs verifiedOff plus true flag and the
  same permit; do not break the valid sealed confirmation path by reusing a
  usableOff predicate there. Prepare remains available in this state.
- Add explicit ClientState/SetupState removalRequired. All positive off paths
  (status, recovery, deactivation, reconnect/new client) propagate the flag into
  that state. Activation refuses locally before sending when readiness requires
  removal; it must not loop activate/recover/off. No token adoption or auto-rearm.
- A settled authenticated removalRequired state means normal sleep verified off
  but activation unavailable. It is quiet and quit-safe when no operation is
  pending; Settings offers Finish helper removal. It never exposes Activate.
  Non-off/ambiguous results keep recovery warnings. Actual pending removal stays
  quit-unsafe and excludes lifecycle competition. Completing removal resets this
  state only through the already reviewed callback-based flow.
- A new app/connection against the same daemon rediscovers the state. A new daemon
  incarnation may reopen after startup recovery, as already locked; no durable
  marker or new privileged cleanup is added. Audit status/retry/prepare/final read/
  disconnect and every client off publication sibling. Reproduce the original
  failure with a compiling pre-fix overlay; add coordinator, codec, client and
  setup fixtures including an in-process real-coordinator/client loop where
  practical. Run affected suites, full regression gates and one delta independent
  code/manual-security review before repinning acceptance.

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


### B3b2 integration decisions U1–U8 (locked 2026-10-12)

- U1: Replace the placeholder backend wholesale with a thin AlwaysOnSetup adapter
  into AlwaysOnCore presentation types. App composes native client, setup ports,
  coordinator and adapter. Core never imports Setup/Client/native code; GUI never
  links AlwaysOnNative/Daemon. Preview remains entirely inert. Retain increasing
  revision, state, remedy, lifecyclePending and quitSafe through the adapter.
- U2: Controller consumes pushed observations and method completions through one
  revision fence. Reserve local operation identity before awaits; an older return
  cannot clear newer stop/quit or progress. Trust coordinator/client ownership:
  ordinary refresh of this client's owned active session preserves it; startup
  orphan recovery belongs to client, not unconditional UI deactivation. Never
  auto-activate after wake/reconnect/restart/repair. Deactivate/quit during pending
  activation records stop intent and queues stop; late active stays stopping until
  settled. Do not cancel a call that can apply later.
- U3: Only current fresh quitSafe and no unresolved foreground/lifecycle operation
  permits termination. Wake/focus revalidation revokes stale safe snapshots before
  suspension. A pending quit receives one actual settled decision; unresolved OS
  register/unregister cannot be presumed complete. Pending activation with remedy
  Deactivate remains actionable; do not blanket-disable lifecyclePending. Preserve
  recovery warning until safe observation, and never dismiss it with close/Escape.
- U4: All surfaces share the same presentation/action mapping. Off: Activate;
  active/activation: Deactivate; fresh unavailable/setUp: Set Up; missing signing:
  Check Again; approval: Check Again plus explicit Open Login Items in Settings;
  notFound: Check Again plus repair explanation. Unknown: Retry deactivation plus
  Repair setup in Settings; failed removal: retry deactivation plus Retry helper
  removal in Settings. removalRequired is quiet/quit-safe when settled, offers
  Finish helper removal in Settings, never Activate. Wait is disabled progress.
  Warning primary invokes its displayed action, not a hardcoded deactivate.
- U5: Settings is the sole actual helper-removal surface. Menu/Dock/warning repair
  or finish-removal actions only open Pane Settings. Only explicit approval action
  opens OS Login Items. Refresh/setup checks never automatically open either UI.
  Keep existing snap controls, Dock/menu refresh callbacks and chooser exclusions.
- U6: Wire one startup and coalescing app-focus/workspace-wake refresh driver,
  maximum one in-flight plus one dirty follow-up. Reconcile nonactivating warning
  separately. Preserve active 520x390 geometry, red triangle/white exclamation,
  red border, centered panels per display, all-Spaces/fullscreen behavior and
  no recurring focus steal. Render new setup/approval/removal states in the native
  inert fixture; primary and secondary buttons must remain legible and usable.
- U7: Fail-first checks cover old late-activation/stop/quit behavior; owned active
  startup/wake/focus; backend orphan recovery; stale/equal revision and older
  completions; usable pending stop; fresh quit decisions; refresh coalescing;
  zero implicit registration/navigation; label/action correspondence; explicit
  approval; Settings-only removal. Preserve prior suites; debug/release builds,
  all regression executables, bash/plist/diff lint and CI. Native fixture evidence
  is required; screenshots do not claim physical sleep/signed IPC or unobserved
  cross-Space/VoiceOver/installed Dock acceptance. No stable-path packaging.
- U8: One isolated builder followed by fresh read-only code/manual-security and
  lead review. Current inherited model per user instruction. Aim ~800 lines;
  report material overage. No merge/install/sign/register/unregister/actual power
  mutation/root journal construction/arming. B3c signed staging follows after
  code gates; missing identity and native acceptance remain external blockers.

B3b1 review ledger: PR #9 head83598e7e8d8ce43ec1ce88d86037bcc755839dd1
cleared by independent read-only delta and lead source/manual-security review;
S-R3 fresh-proof quit safety and S-R4 removal continuity resolved. Reviewer clean
before/after, no edits or execution. CI38296296320 green. Local suites
60/34/176/114/355/118/166/122; retained pre-fix and inert evidence in VERIFICATION.
Initial unchanged UI fixture CI failure was not reproduced locally; bounded
observable-condition waits now pass local and final CI, without claiming its
original cause was proven. Current model inherited; exact metadata unavailable.
CodeRabbit prohibited; literal security tool unavailable, manual fallback used.


#### U9 — background heartbeat scheduling

Apple documents App Nap timer/I/O throttling and user-initiated activities as an
opt-out. The ten-second client heartbeat cannot rely on a thirty-second lease
margin while hidden. Add an injected balanced activity owner to AlwaysOnClient,
using only ProcessInfo.userInitiatedAllowingIdleSystemSleep in production.
Exclude idleSystemSleepDisabled, idleDisplaySleepDisabled and latencyCritical;
no global App Nap preferences or extra power assertions. Acquire for executing
client work before suspension/native RPC; retain through owned token/heartbeat,
stop/recovery/removal settlement. Transient unknown/loss must not end an activity
while recovery is executing. Release at settled no-token state, including failed
unknown, off and removalRequired; queued stale completions cannot release active
work. Serialized lane ownership plus token retention is preferable to UI state
heuristics. Balance on disposal/process death; OS scheduling remains best effort.
Test fake begin/end lifecycle across activation/refresh/loss/late stop/removal/
failed recovery and check production option flags. This scheduling correction is
part of B3b2 integration, with separate red evidence; report its size if over target.
Local SDK NSProcessInfo.h defines allowing-idle option by removing system-sleep
flag, independently of display-sleep flag. No native activity need be held in tests.


B3b2 U6 clarification: Settings uses a fixed bottom actions footer, also present
in the inert 580x700 preview. Its compact rows expose primary/approval and
Settings-only repair/removal without placing the actionable controls under the
centered 520x390 warning. Native current-laptop geometry must be inspected.
The 320x300 warning minimum is not a full Settings reachability claim.

B3b2 U-R2: unknown state with absent registration and a retained recovery journal
must offer explicit Repair helper setup in Settings. It invokes existing guarded
setup, which registers only when notRegistered; startup recovery then belongs to
the helper/client. It never unregisters/reregisters or autoactivates. Missing
bundle/signing remains actionable installation diagnosis and Check again.

U9 sources: [Apple App Nap](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html),
[prioritizing app work](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheAppLevel.html),
[allowing idle system sleep](https://developer.apple.com/documentation/foundation/processinfo/activityoptions/userinitiatedallowingidlesystemsleep).
Each client operation acquires an independently owned, idempotent activity hold
before lane suspension. A separate token hold covers the owned session; loss
transfers to recovery before releasing it. One underlying activity spans all
holds, and actual unregister completion, not its reporting deadline, releases
that operation. Tests inject inert activity ports, including real loopbacks.


### B3c signed staging decisions V1–V8 (locked 2026-10-12)

- V1: Add scripts/build-signed-staging.sh and a small implementation/helper as
  needed, with concise README instructions. Preserve existing stable-path ad-hoc
  packager and running guards unchanged. Never open/install/move/replace/register/
  unregister/launch/kill apps or helpers, read/write power settings, or change
  privacy/security settings. This is preparation only, no arming.
- V2: Require clean committed source and explicit --identity forty-hex certificate
  fingerprint, --team-id ten uppercase-alphanumeric Team ID, --notary-profile
  existing Keychain profile. Reject missing/invalid/duplicate arguments and '-'
  identity before building. No identity auto-selection, credentials/secret input,
  store-credentials, enrollment, VCMC or ad-hoc fallback. --preflight without an
  identity checks only source/layout/fixed plists/tool availability, creates no
  artifact and performs no signing/keychain/network operation.
- V3: Before build require exact fingerprint in security find-identity -v -p
  codesigning with Developer ID Application label and expected team. This is a
  selection guard, not trust proof. Use argument arrays/quoted shell, no eval.
  Build into task-local paths. Assemble in a newly owned private temporary
  directory under dist/signed-staging, then publish a unique full-commit/UTC/UUID
  candidate only after all verification succeeds. Never reuse or overwrite an
  existing destination; cleanup own partial output on failure, preserve installed
  build5. Recheck source clean/head before final publication.
- V4: Fixed app ID local.snapbridge.app, executable PaneManagement; nested helper
  ID/Mach service/launchd label local.snapbridge.alwayson.service, executable
  PaneAlwaysOn and BundleProgram Contents/MacOS/PaneAlwaysOn. Copy established
  assets/plists. Sign nested helper then outer app with explicit fingerprint,
  fixed identifiers, --options runtime and --timestamp. No deep signing or
  permissive/preserved entitlements. Verify both individually, outer deep/strict;
  reject get-task-allow, absent hardened runtime or secure timestamp.
- V5: Evaluate explicit codesign --verify -R requirements (inline requirements
  use '=' prefix per tool syntax) on BOTH app/helper: anchor apple generic AND
  certificate1 Developer ID CA OID1.2.840.113635.100.6.2.6 exists AND leaf
  Developer ID Application OID1.2.840.113635.100.6.1.13 exists AND leaf subject.OU
  exact expected Team ID AND fixed own identifier. Verify reported TeamIdentifiers
  match expected. Use codesign APIs/CLI, not custom certificate trust parsing.
- V6: Ditto submission ZIP, xcrun notarytool submit with existing keychain profile,
  --wait --output-format json; require Accepted and nonempty valid submission ID.
  Staple and validate ticket; reverify signatures/requirements and spctl --assess
  --type execute. Recreate final ZIP from stapled app. Emit nonsecret manifest
  with exact source, fixed IDs, selected fingerprint/team, submission ID/status,
  verification outcomes and SHA256 final ZIP/app/helper executables. Do not call
  notarization success installation or physical acceptance.
- V7: Tests run with fully injected synthetic command results and disposable
  directories; no actual signing/timestamp/notary submission/stapling or service
  execution. Verify missing/invalid args/identity, dirty source, existing output,
  plist drift, wrong identity/team/runtime/timestamp/entitlements, rejection or
  malformed notary response, verification failures, cleanup and final publish
  ordering. Fail-first compiling/runnable pre-fix or inert overlay with retained
  red evidence; don't let test shims fall through to real side effects. Actual
  read-only --preflight allowed only once committed clean. Positive signed run
  blocked by missing Developer ID; report that without claiming synthetic proof.
- V8: Shell/Python syntax or equivalent typecheck/lint, new packaging checks in
  CI, separate Swift debug/release builds and full existing regression suite,
  fresh independent code/manual-security and lead review plus final CI. No stable
  app packaging locally while build5 runs. No merge/install/arming; final concrete
  handoff includes source candidate, evidence, signing prerequisite and unresolved
  native acceptance. Keep scope about800lines; current inherited model. CodeRabbit
  prohibited. Actual future notarization submission/installation stays gated.

Primary references: Apple TN3127 Inside Code Signing Requirements and Notarizing
macOS Software Before Distribution, inspected October12. Developer ID Application
requirements include Apple anchor, Developer ID issuer/leaf OIDs and expected team;
notarization requires runtime, timestamp and absence of true get-task-allow.
https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

B3b2 review ledger: PR10 head495f6635dca37aca951926bc3d0ac23a6e529b67 cleared
fresh independent read-only code/manual-security plus lead source review; clean
before/after. CI38298900984 green. U-R1 coalescing and U-R2 missing explicit repair
exit resolved with actual pre-fix assertions; hot-polling replaced with settlement
latch. Current model inherited, exact metadata unavailable. No actionable findings.
Lead CUA observed all11 inert states and native action routing. Final waiting-copy
preview SHA dbe68fadc8254cc3089b6b70f686d6c63521dcbc0192beaee9f3fd4c9a0f00f1
also checked. Normal preview quit fromoff confirmed by process absence; onlybuild5
PID96007 remains. Screenshots are window-only, so global stacking/occlusion,
Dock, Spaces/fullscreen, multidisplay/VoiceOver and physical signed acceptance
remain open. First fixture SIGTERM was testcleanup only. No installation or power
operation occurred. B3c may start; merges remain blocked on required native gates.

### Final B3c review and handoff ledger — 2026-10-12

PR #11 at `048e6c174e27ebdf5383459baf334ee7f4846112` (product `3ced098`)
cleared fresh independent read-only code/manual-security and lead source review;
no actionable findings, worktree clean before/after. Reviewer inherited the
current model; exact model/effort metadata unavailable. Literal security-review
tool unavailable; independent manual security review used. CodeRabbit prohibited.
CI `38300113172` passed; clean-source read-only preflight passed at the final pin.
Lead's earlier tool-path, argument-abbreviation, notary-shape and diagnostic
findings are resolved with retained pre-fix evidence. Sibling audit covers both
signed binaries and pre/post-stapling checks, all cleanup/publication paths and
malformed argument/receipt branches. Later handoff edits are Markdown only.

All feasible implementation work is complete. PRs #2–#11 remain draft/unmerged;
missing Developer ID and outstanding native acceptance prevent installation and
arming. No positive native signing/notarization or real helper/power operation
was attempted. Original installed build 5 and clean primary checkout preserved;
no helper journal or preview/helper process at final read-only check. The next
prerequisite is a Developer ID Application certificate and existing notarization
profile; then signed staging, installation/approval and real native/recovery
acceptance need their separate authorization. Enrollment/purchase and alternate
privileged fallbacks are not authorized. No additional feature slice is pending.

### Local signing authentication — locked L1–L6 (2026-10-12)

L1. Validate the executable's intact signature and fixed own identifier before
reading its leaf certificate. Derive an exact 40-hex SHA-1 DER certificate pin
solely for Apple's requirement language; revalidate own identity with that pin,
then require the peer's fixed identifier and the same leaf certificate. No Apple
anchor, Team ID, certificate common-name trust, peer-provided certificate, runtime
configuration fallback or ad-hoc acceptance. Installed helper signing authority
is the trust root; rotation requires coordinated off/removal/reinstallation.

L2. Adapt the injectable SigningAuthority and tests for local certificates without
Team IDs, both fixed roles, strict pins, missing/ad-hoc metadata, ordered self
validation and failed revalidation. Retain runnable pre-fix red evidence. Native
positive certificate acceptance is a later probe, not established by fakes.

L3. Preserve engine, service, DTO, lease, privilege, setup and reciprocal NSXPC
requirement-before-activation ordering. Correct obsolete Apple-only failure copy
and document the pending local route. Preserve the paid staging packager.

L4. Required separate gates: `swift build -c debug`, `swift build -c release`,
`.build/debug/AlwaysOnDaemonChecks`, `.build/debug/AlwaysOnClientChecks`,
`.build/debug/AlwaysOnSetupChecks`, `.build/debug/AlwaysOnChecks`,
`bash -n scripts/*.sh`, `git diff --check`. No stable packaging while build 5 runs.

L5. Fresh independent code/manual-security review, lead review and CI required.
CodeRabbit is prohibited by repository policy. No real certificate generation,
keychain writes, root journal, helper execution/registration/removal, installed
bundle, privacy or power writes. No merge, install or arming.

L6. Commit and push clean; draft PR based on `codex/always-on-staging`. Record
exact pins and evidence. Local signing packaging and native acceptance are
separate slices. Sources: Apple's Code Signing Requirement Language and TN2206.

Recovery: authentication failure remains a setup/check-again state; explicit
Settings repair/removal flow is unchanged. Missing/changed certificates cannot
auto-enroll or authorize a peer. This slice introduces no durable state.

### Harmless local signing probe — locked P1–P8 (2026-10-12)

P1. Fixed probe IDs `local.snapbridge.signingprobe` and
`local.snapbridge.signingprobe.service`; nonce echo only. No power, journal or
production runtime dependency. Root/self validation before daemon listener;
reciprocal exact-own-leaf requirements before connections activate. Shared
identifier helper strictly validates identifiers; production wrapper stays fixed.
P2. Explicit Register, Open Login Items, Ping, Remove, Check status and Quit. No
automatic service action. Serialize lifecycle work until actual completion; ping
is five seconds, exactly once, with connection invalidation. Failures offer retry,
status or removal. Signature absence is a visible setup result.
P3. Separate clean-source staging with explicit forty-hex identity. No selection
or certificate creation. Unique output; hardened runtime, timestamp none, no
weakening entitlements; helper then app; exact pins/IDs verified. Preflight has no
keychain/artifact side effect. No network, notary, trust changes, install or launch.
P4. Probe-only negative clients: wrong-ID same certificate, ad-hoc client, wrong
expected helper pin. Positive pings before/after each negative are required.
Actual dedicated certificate and administrator drill wait for review.
P5. Fail-first pure protocol, lifecycle, timeout and synthetic staging tests; no
real-command fallthrough. Separate debug/release builds; probe/daemon/client/setup
checks; shell/Python/plist/diff lint. No stable app packaging locally.
P6. Lead coordinates any native launch; preview is missing-identity only. Fakes
do not prove SMAppService acceptance. P7. Fresh independent code/manual-security,
lead review and CI; CodeRabbit prohibited. No merge, install, arming, real key
use, credentials, root helper execution or settings writes. P8. Clean draft PR
on local-signing-auth with evidence and exact remaining administrator steps.

Recovery: idle/missing signature offers Check status/Quit; failed registration
offers Check status/Register or Remove; approval offers Login Items/Check status;
failed ping offers Ping/Check status/Remove; failed removal offers Remove/Check
status. Pending registration/removal holds its slot until real completion. P-R1 updates
the probe-only exit: Quit always works and explains that OS work may continue;
relaunch offers Check status/Remove. Quit is not cleanup or operation completion.
No durable app state. Production quit safeguards remain unchanged.

Lead approved about 900–1,000 lines for the cohesive probe, negative fixtures,
packager and inert failure checks; separating these would leave an incomplete
acceptance workflow. External examples contradict themselves on local root-daemon
acceptance; only the future real harmless drill can establish support.

### Probe final review ledger — 2026-10-12

PR14 reviewed/runtime pin `9458b946982589b0b25a5f8e9e26d755018ceff3`, base `37dad17`,
cleared fresh independent read-only code/manual-security and lead code/security
reviews; no actionable findings and worktree clean before/after. CI38305835875
passed. P-R1 pending-Quit recovery and P-R2 explicit untrusted identity discovery
are resolved; P-R2 actual pre-fix failure evidence retained. Current model
inherited, exact metadata unavailable. CodeRabbit prohibited; literal security
review unavailable, independent manual fallback used. Sibling audit and all
local/red evidence are in VERIFICATION.md; final closure is Markdown only.

Lead CUA verified unsigned missing-signature Check status content fits without
scrolling and Quit exits; no service action was invoked. Preview process absent,
installed build5 PID96007 remains. No certificate/signing/registration/installation
or power action occurred. Next is user creation of the dedicated Pane Management
Local Signing credential in Keychain Access Certificate Assistant, then separately
approved signed staging and harmless service acceptance/removal drill. No trust
change or paid membership is required by this planned experiment; whether macOS
accepts its local signature is still unproven. No production local package or
arming until that result is established.

### Native signing evidence — 2026-10-12

User-created dedicated identity `EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F` signed the
reviewed probe successfully from clean source `12baca95bd552dc0926bc784af4bb85586a7e657`. Packager exited0,
strict own-leaf/ID/hardened-runtime/no-entitlement gates passed; no trust mutation
or blocking Keychain prompt. Candidate/manifest and all binary hashes recorded in
VERIFICATION.md. Product/review pin9458b946 unchanged; this update is Markdown only.
No install, register, signed-helper launch, power or production operation occurred.
Next is explicit user confirmation for the new ping-only administrator-service
access and positive/negative/removal drill. Local SMAppService acceptance remains
unproven; no production package or arming is authorized by this signing result.

### Approved native service drill ledger — 2026-10-12

User explicitly approved run-and-remove; personally completed administrator Login
Items approval. Two registrations reached enabled, but three bounded GUI positive
pings timed out across the initial attempt and one three-minute retry. Both root
xpcproxy incarnations stayed pre-exec; delayed BTM fetchItemWithUUID logs support
an unresolved startup/resolution delay, not a demonstrated certificate rejection.
No negative fixture ran because positive controls failed. No source/auth changes.

Both native removals completed with explicit status not registered; final job and
probe processes absent. Installed probe copy moved to Finder Trash, original path
absent; signed candidate retained. Original build5/hash and primary main preserved.
No power, production helper or trust mutation. Details/timestamps in VERIFICATION.
Next targeted root-launch diagnosis needs separate human administrator handoff if
privileged sampling is required; no privileged sample obtained in this drill.
Reviewed product9458b946 and signed source12baca95 remain unchanged. This closure is
Markdown only; no further drill, signing, build or production activation performed.

### Native local-signing acceptance PASS — 2026-10-12

Authorized diagnostic rerun of identical signed source12baca95 at the same path
succeeded: launchctl root daemon8385 execs1/trampolined1, four positive GUI pings
surrounding wrong-ID/ad-hoc/wrong-pin rejections, with explicit signature-rejection
logs and PID mapping in VERIFICATION.md. No privileged trace/password/Terminal,
source workaround, rebuild or resigning. Earlier BTM delay remains unexplained;
it was not proof of certificate rejection. Native harmless acceptance passes on
this Mac. Actual Remove+Check status/Quit, job/process absence and installed-copy
Finder Trash verified; signed candidate retained, baseline build5 unchanged.

Product/review9458b946 and signed source12baca95 unchanged. This Markdown closure
unblocks subsequent integration/local product staging work, not production arming.
Real product installation, Dock/warning/lid/recovery acceptance and first activation
remain separate gates. No power or production helper action occurred in the probe.

### Local production staging — locked R1–R7 (2026-10-12)

R1. Integrate reviewed warning branch2636ff1 with probe/auth baseb70efed; preserve
chronological native evidence, audit shared copy and packaging siblings, and make
no power semantics change. R2. Separate explicit forty-hex local identity or
read-only preflight; reuse verified staging mechanisms, clean committed source,
fixed production IDs and current artwork/Dock metadata. Publish only production
app/helper/resources under unique dist/local-signed-staging; no probe fixtures.
R3. Release build, helper then app exact certificate signing, hardened runtime,
timestamp none, no entitlements or ad-hoc fallback; strict own pin/ID checks on
both binaries, public source/pin/SHA256 manifest. No paid identity, Team ID,
notary/network or trust change; explicit self-signed identity lookup permits the
reviewed untrusted suffix. Never replace the stable bundle.
R4. Reject invalid inputs/paths/metadata; clean only owned partial/output, preserve
existing/racing candidates. Failures publish no usable candidate and explain the
failed prerequisite with retry. Native effects and permissions remain separate.
R5. Inject every external command and forbid subprocess fallback. Fail-first
synthetic tests cover failure positions, identity/pins/IDs, missing key, dirty
source, races, symlinks, entitlements, cleanup and retry.
R6. Separate debug/release builds; debug SnapCore/AlwaysOn/Engine/Native/Service/
Daemon/Client/Setup/SigningProbe checks; release AlwaysOn/Daemon checks; all three
staging Python suites; Python/shell/plist/diff lint. Independent read-only code
and manual-security, lead review and CI precede any real production signing.
CodeRabbit prohibited. Current model inherited; exact model/effort unavailable.
R7. Draft PR on local-signing-probe, clean runtime pin for review, no merge,
install, launch, register, activate, power, keychain or trust action. Production
staging requires the lead's separate release of the signing gate; installation,
physical acceptance and first arming remain separately gated. Scope under800 new
lines excluding already reviewed merged changes.

Recovery: prerequisite failures offer correcting the named prerequisite/retry;
command failures offer retry after correcting the named operation; publication
conflict preserves the existing candidate and retry selects a new UUID; handled
failures remove owned partial output; forced termination can leave unpublished
.partial directories but no installed state. Tests exercise each exit and retry.
