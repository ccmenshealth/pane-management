## Quiet startup warning presentation — build evidence (2026-10-14)

The startup retry introduced October 13 was running during the reported reboot:
app858 started 07:23:48.775 Pacific, retried 07:23:56.604 and terminated
07:24:01.161; helper532's listener began 07:24:48.758. The app exited about 47.6
seconds before the helper was ready. The presentation incorrectly treated pending
startup as a mandatory recovery emergency. The helper's initialization delay is
not explained by this evidence.

Implementation adds explicit startup-unverified provenance and a quiet shared UI
state. Quiet does not mean OFF or quit-safe. Authenticated active/recovery, either
positive override receipt, ordinary client loss and uncertain manual operations
retain the mandatory warning. Explicit Check again bypasses scheduled backoff
through the status-only startup path; focus/wake do not. Quiet approval/missing
helper rechecks retain provenance. A denied quiet quit opens ordinary Settings.
All root/helper power, IPC authentication and journal code remain unchanged.

**Fail-first:** archived untouched production `4b91728` into ignored
`.build/startup-warning-pre-fix`, overlaid only final setup/UI tests and the test
manifest dependency on AlwaysOnUI. Compiled with `-DSTARTUP_WARNING_PRE_FIX`; its
API-only test shim forwards the newly named `checkAgain` to the old `refresh`,
which was the prior Check again behavior. Production sources were untouched.
Setup267 assertions/**27 failures**; UI85/**1 failure**, both exit1. Failures cover
initial flash, delayed/permanent helper unavailability, startup approval rechecks,
quiet denied quit, immediate explicit check, proof failures and safe wake flash.
No missing-symbol/compile failure is counted as regression evidence.

**Green local gates:** separate debug and release builds passed. All nine suites
passed in both configurations: Snap60 scenarios, UI85, Engine176, Native114,
Service355, Daemon266, Client181, Setup267, SigningProbe114, all zero failures.
Shell syntax checked each `scripts/*.sh`; all six Resource plists passed lint;
`git diff --check` passed. Evidence logs are preserved locally in ignored
`.build/startup-warning-evidence` (red/green build and per-suite logs).

Setup regressions exercise the production controller → presentation adapter →
coordinator → client with virtual time: >90-second helper delay, permanent failure,
quiet constructor/first refresh, bounded status probes, no App Nap hold, visible
Check again/Repair, denied quit with ordinary Settings, authoritative foreign
active/recovery, either positive/missing/disagreeing power receipt, stale probe
completion, startup/focus/wake, setup/removal cancellation and queued-timer fences.
Explicit recheck after a fired timer cannot clear its replacement or publish a
stale observation. Manual activation/deactivation/lifecycle and client-loss paths
retain existing warning/quit tests; no safety proof was relaxed.

**Native preview PASS (lead CUA):** isolated ad-hoc signed preview rendered the
new Startup checking, Startup unavailable and Startup approval fixtures as ordinary
controls without a warning panel. Quit from Startup unavailable left ordinary
controls accessible. Active showed the mandatory warning; Deactivate reached OFF.
Unknown recovery showed the mandatory warning; Retry reached OFF. The stripes,
red triangle and contents were visible without clipping. Preview then quit. These
are actual native renders with an in-memory backend, not a live power/reboot test.

**Review PASS:** independent code and manual security review and lead review of
`fbeb2173a67e96143eb61b79c4d9cb7baccdb360` reported no findings. The independent
reviewer reran affected debug/release suites successfully and verified a clean tree.
Literal `/security-review` was unavailable; the named fallback is independent
manual review of presentation provenance, quit proof, cancellation and risk-state
siblings. All roles inherited current model/effort; exact labels unavailable.
CI38583821202 is in progress. CodeRabbit remains unavailable under the repository
exclusion. This ledger update is Markdown only; `git diff --check` and remote
workflow inspection are its local gates. Final-head CI and installation remain.

Lead authorized isolated local signing with the existing dedicated certificate
`EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F` after these gates. No production app/helper
launch/stop, installation, registration, permission, trust or power change occurred
during the build or preview. Actual reboot timing, helper delay cause, physical
thermal/battery safety and backpack use remain unproven.

## Startup recovery update — installed OFF acceptance (2026-10-13)

Lead completed the authorized update at the stable primary `dist/Pane Management.app`.
Steve superseded the separate installation-confirmation gate for Pane Management
updates; that authority does not cover unrelated software. This closeout only
records lead-supplied evidence; its builder performed no new build, test, staging,
installation, process or native UI action.

Installed source: `b613570dc02bc18cfb3484143e5071cfa86e3cad`.

| Artifact | SHA256 |
| --- | --- |
| App executable | `dc8e22b7fe63ddad26cc708c62663971d4fb3c1a38920f043da54ca71187a8db` |
| Helper executable | `bb54b7a33e13ef3e96961f35daf7332787d6a9f0a862d92c29f6c2585a48f53c` |
| Staging manifest | `b87396bb9fd221e9bc4ac4da7e918da9a83f9cd1a6422749e9752f6dc9bec43c` |

Rollback bundle preserved at primary
`dist/backups/before-startup-recovery-278bcb69-a5cc-4338-a039-3f7ec21bb161/Pane Management.app`.
The exact candidate and manifest remain in PR21's staging evidence. Strict/deep
signature verification and executable hashes matched before and after installation.
Dedicated identity and bundle identifiers remained unchanged.

Native sequence, distinct from automated regression evidence:

- Old app PID852/helper PID564 began OFF. Native Remove helper completed with the
  service and helper absent. Refresh with the retained root directory brought back
  the expected unregistered recovery warning; lead terminated only the old GUI
  with SIGTERM after fresh dual OFF and service-absent evidence.
- With neither app nor helper running, lead used `ditto` into a unique `.update`
  bundle and renamed the existing app to the backup before installing the candidate.
- New app PID42729 showed expected unregistered recovery; native Repair helper
  setup registered it. At 11:21:43 Pacific the initial launch failed with AMFI -423
  (unknown certificate chain) / OS_REASON_CODESIGNING, under prior BTM UUID
  `938CFF54-A9D5-45AA-A964-5326F18A89F9`.
- Lead changed only Pane Management's background Login Items toggle OFF; Steve
  approved the OS authentication prompt. At Steve's request to remove the popup,
  lead terminated GUI PID42729 only after fresh dual OFF. Toggling Pane's entry ON
  required no further authentication and started helper PID43721 (execs1), with
  fresh BTM UUID `2E069386-D803-4AE9-8D6E-A514C6A5D17D`. No trust/global security
  setting was loosened. The launch-failure cause beyond these observations is not
  established; registration refresh success is not a root-cause proof.
- Reopened app PID43906 showed Settings OFF with no warning, verified by actual
  accessibility state and an app-only screenshot. Accessibility/ScreenCaptureKit
  indicators were green and snapping was enabled. This is not a new snapping
  functional test. Settings was closed as the final native action; no screenshot
  file was published.

At **11:25:02 Pacific**, lead confirmed app PID43906/helper PID43721, pmset
SleepDisabled0 and root SleepDisabledNo, lid open, strict/deep signature success
and both exact executable hashes above. **Always On was never activated during
the update. Native OFF-state acceptance passed**, with no remaining required check
for that scope. No new physical reboot or native >90-second helper-delay drill is
claimed; delayed recovery remains proven by virtual regressions. No general claim
about unrelated idle-sleep settings, backlight or emergency protection is inferred.

Runtime `dd7fee3` passed independent code/manual security and lead review at
`b02ecf9`, with P2 fully resolved. Installed-source CI38440877868 passed (1m53s).
PR21 merged at 11:29:28 Pacific as `d5ab7ce88d23b97f3b85350896995ed07f4e50e0`.
Final head `914c912` passed CI38446787298 (1m59s) and lead documentation review.
Installed source `b613570` and its verified hashes remain unchanged; no runtime or
installation work remains. This milestone record performs no further local build,
test, signing or native action. CodeRabbit stays excluded; historical evidence follows.

## Startup helper delay reconciliation — build evidence (2026-10-13)

### Review follow-up — queued retry fence

Independent code/manual security review of `4880b8c` requested changes for one P2:
`SetupCoordinator.swift:63–66` queued an untracked generic refresh after clearing
its timer. Manual recovery/activation/setup/removal could finish before that Task
ran; the obsolete Task could then enter ordinary status (including its existing
mutating recovery path) and replace the settled observation.

Runtime fix `dd7fee38c3a2de7b3771abe096b3749cf8eeb3ce` captures the startup epoch and
checks both epoch and unresolved startup at timer callback and queued Task entry.
The first guard also prevents a stale callback from clearing a newer timer.
No dispatcher abstraction or other product path changed.

Deterministic regression fires the fake timer synchronously without draining the
actor, completes each manual operation on its valid immediate-completion path,
then drains the queued Task. On untouched `4880b8c` production, it compiled and
reported **237 assertions, 8 runtime failures** (ordinary status replay and state
overwrite for all four manual paths). Fixed debug/release setup suites each pass
**237/0**. It also proves an intervening fresh probe's newer timer survives and
runs once. No sleeps or production scheduling hooks are used.

Separate debug/release builds, shell syntax, six plist files and whitespace lint
passed after the fix. Unchanged suites retain the earlier all-nine/both-config
results below; the affected setup suite was rerun in both configurations. Race red,
green and build logs are preserved as `.build/startup-recovery-evidence/pane-queued-retry-*.log`;
initial pre-fix evidence is preserved separately. Initial CI38439449506 passed;
CI38440556739 remains in progress, with metadata and synthetic staging checks passed.
Independent code/manual security delta review and lead review PASS at
`b02ecf99ff3a906cf9e0b27634a460113f6af09a`, covering runtime `dd7fee3`: P2 resolved,
no new findings. Reviewer independently reran both setup suites (237/0 each) and
confirmed a clean worktree. All roles inherited the current model/effort; exact
runtime labels unavailable. Literal security-review remains unavailable; the
independent manual security pass is the fallback. Lead authorized only isolated
local signed staging of the subsequent clean documentation head, using dedicated
identity `EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F`. Candidate manifest/hash evidence
will be added to PR21 without changing its staged source. No installation, native
OFF-state acceptance, reboot or other new native proof is claimed.

### Initial implementation evidence

Lead observed app attempts ending 10:04:38.503 Pacific after a 10:03:24 reboot,
helper listener beginning 10:05:48.916, and no fresh client request until manual
Retry at 10:11:30.834 immediately confirmed OFF. That establishes the missing
startup retry; the helper's initial delay cause is not established.

The coordinator's first real controller/adapter refresh now probes authenticated
status and retries unresolved startup failures at 2/5/10/30s, capped at 30s without
permanent expiry. Each client readiness attempt is bounded at five seconds; native
registration/power-proof reads retain their existing bounded readers. No process
activity is held for a background probe or retry. One probe/timer at a time; weak
closures release unused coordinators. Manual actions cancel the retry and advance
an epoch so late probe results cannot replace activation, stop or lifecycle state.
Subsequent probes preserve the warning's actionable Retry/Repair controls.

Status-only means no explicit mutation RPCs or client mutation replay. It does NOT
mean the helper cannot write: its existing status path may restore unsafe owned
state or clean the journal. Production ServiceCoordinator/RecoveryEngine loopback
checks prove a healthy lease on another connection survives a startup probe, while
critical telemetry still permits existing helper-owned restoration to verified OFF.
No daemon, engine, trust, identity, audit, freshness or ownership policy changed.

Fail-first evidence: archived exact pre-fix production `06873169f210fc2619b70f284c97558bf229d5ea`
into ignored `.build/startup-pre-fix`, overlaid only the three setup test files,
and ran `swift run --package-path .build/startup-pre-fix --disable-sandbox
--cache-path .build/cache -Xswiftc -DPRE_FIX AlwaysOnSetupChecks`. The transparent
PRE_FIX convenience initializer only accepts/ignores the new scheduler argument;
it delegates to the old initializer and changes no production behavior. Compile
passed; **218 assertions, 11 runtime failures**. Failures include no automatic
recovery after >90 virtual seconds, missing backoff, process activity, foreign
active mutation, lost-probe recovery, and blocked lifecycle recovery. Fixed setup
suite: **218 assertions, 0 failures**, including actual controller startup wiring,
long delay, persistent unavailable, hung deadline, no explicit mutation requests,
manual setup/removal/activation/Retry supersession, stale replies, transport loss,
setup/removal-required termination and weak timer cleanup.

Recoverability and sibling audit:

| Path/state | Visible exit and evidence |
| --- | --- |
| Startup helper unavailable/hung | Existing recovery warning; Retry deactivation/Repair remain available during later probes; eventual authenticated OFF clears it |
| Genuine recovery or foreign active | Stop background retry; explicit Retry/Repair; production loopback preserves another healthy lease |
| Approval/missing signed helper | Existing Login Items/Set Up exits; no automatic registration; retries stop |
| Removal required | Existing Finish removal exit; no autoactivation; removal loopback verifies final permit/unregister |
| Manual activate/deactivate/Retry | Startup cancelled first; client FIFO serializes with any bounded probe; late replies cannot erase resulting state |
| Manual setup/removal | Epoch fences old status; real registration/removal lifecycle unchanged; failed removal retains its specific retry exit |
| Startup/focus/wake | App uses existing controller/adapter refresh; coalesced probe and capped backoff prevent overlapping attempts |
| Owned active/ordinary refresh/client loss | Existing status, heartbeat and mutating safety-recovery paths unchanged; startup probe refuses to disturb owned token, closes its connection, and fences its loss callbacks |

Both separate `swift build --disable-sandbox --cache-path .build/cache` and
`swift build -c release --disable-sandbox --cache-path .build/cache` passed.
All nine executables passed in BOTH configurations: SnapCore 60 scenarios,
AlwaysOn/UI 84 assertions, engine 176, native 114, service 355, daemon 266,
client 181, setup 218, signing 114, all zero failures. `bash -n scripts/*.sh`
(each file), `plutil -lint Resources/*.plist` (six files) and `git diff --check`
passed. Logs are retained locally in ignored `.build/startup-recovery-evidence`.
Warning UI source is unchanged;
existing 84 UI assertions run in both configurations. No new native render, reboot,
installation or production power drill is claimed by this builder. Current review
status is in the follow-up ledger above; literal security-review is unavailable
and CodeRabbit is excluded by Steve. Installed build is unchanged.

## Lid-close display check — 2026-10-13

Steve explicitly approved a brief Always On test on a hard surface, ending OFF.
The read-only sampler was running before activation and before requesting closure.
From 07:15:27 Pacific it recorded 186 samples with no errors and a maximum 1.280s
gap. Lid CLOSED was sampled 82 times from 07:17:02.887 through 07:18:24.267
(81.379s); reopening was captured at 07:18:25.275. SleepDisabled stayed true in
every closed sample, and the sampler continued running throughout.

The internal AppleCLCD2 service (registry ID4294969358) reported
`IOMFBBrightnessLevel` 11145342 before closure, **0 in all 82 closed samples**,
and 12511380 on reopening. The built-in display disappeared from the online
CoreGraphics display list while closed and returned awake on reopening; transient
display-ID churn occurred during reconfiguration. This open/closed/open contrast
supports the built-in screen turning off with the lid, not merely a saved brightness
setting. It is software evidence, not a direct physical light measurement.
AppleARMBacklight `CurrentNits` remained zero even while open and is not evidence
of the backlight state. Its other saved brightness parameters also stayed constant.
No keyboard-backlight reading, backpack/thermal stress or emergency-sleep claim.

After Steve reported reopening, lead clicked the actual Deactivate button. Native
Settings showed OFF; pmset SleepDisabled0, root SleepDisabledNo and lid OPEN were
confirmed. No warning or recovery failure returned. Installed build unchanged;
no software installed. Raw local samples are preserved in the primary checkout's
ignored `.build/lid-display-evidence/2026-10-13-071527.jsonl`; no raw data is published.

## Console recovery fix installed; native OFF acceptance — 2026-10-13

Lead-reported native evidence, all times Pacific. Steve explicitly approved the
update and scoped Login Items stop/restart while keeping Always On OFF.

- Around 06:57, Pane Management background OFF with Steve's Touch ID left app and
  helper absent and both SleepDisabled receipts OFF. Ordinary system authentication
  changed audit flags `0x2030`→`0x6030`; native acceptance therefore does not exercise
  the missing-bit state. Re-enabling the old helper and opening the old app showed
  authenticated OFF. Existing Remove helper succeeded: “Helper removed. Normal
  sleep was verified.” Normal quit followed; CLI confirmed app/helper and launchd
  service absent and dual override OFF.
- Replaced the entire bundle with new files/inodes at
  `/Users/ccmh/Developer/PaneManagement/dist/Pane Management.app`; helper inode
  changed 347410186→348233807. Preserved rollback bundle:
  `/Users/ccmh/Developer/PaneManagement/dist/backups/before-console-recovery-c94c4c20-efd8-4ef8-a40b-8e7b49c1485b/Pane Management.app`.
  Signed source `9f133fe39573b310787bdac0d953250ca4218059`, existing dedicated leaf
  `EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F`; strict/deep and exact certificate/ID
  verification passed. Installed SHA256: app
  `e479f07dc08a77580991ab7382ad76211fd34ac0dc83f4a00c8b13970cf4c2c0`; helper
  `74ced24b025be5f714ad68fe612cd89a320c6b13036357bcf3bcac7564f6786f`.
- Updated startup initially showed expected recovery with the helper unregistered.
  Repair helper setup registered it, but its 06:59:21 launch failed with AMFI -423
  (unknown certificate chain) and OS_REASON_CODESIGNING launch constraint. The lead
  closed the app after confirming dual OFF to remove the warning. A scoped Login
  Items OFF/ON refreshed registration without another prompt or trust/global
  change. Root helper PID70090 launched at 07:00:34, running with execs1. These are
  observations, not proof of the first launch failure's underlying cause.
- The updated app then showed OFF in an actual CUA Settings render, without the
  warning and with both Accessibility/ScreenCaptureKit checkmarks. Normal Command-Q
  left the app absent and helper running OFF; reopen passed. Final 07:02:14 readback:
  app PID70254, helper PID70090 UID0, unchanged installed hashes, dual override OFF
  and lid OPEN. Always On was never activated during this installation.

Runtime `509687c` passed independent code/manual security and lead review with no
findings; lead approved the Markdown-only `9f133fe` delta. PR18 CI38402208309 passed;
merged `8cd8f789f3779a7040de9405cac24e6f352cf701` main
[CI38402496439](https://github.com/ccmenshealth/pane-management/actions/runs/38402496439)
passed. CodeRabbit remains excluded. Missing-bit behavior remains synthetic
266/37 pre-fix → 266/0 fixed; native signed OFF startup/quit/reopen is separately
proven above. No physical-backlight claim or new activation/closed-lid guarantee.
No further native request is needed for the approved OFF scope. This follow-up
changes Markdown only; its gates are diff lint and remote check inspection.

## Console-session recovery regression — 2026-10-13

Scope: `BoundaryPolicy.auditValid` changes only required mask `0x6010` to
`0x2010`; `0x4000` is mutable credential history. Exact signature requirements,
kernel UID/ASID, returned ASID/AUID, before/after console UID, remote rejection,
non-root/non-unset IDs, freshness and ownership/removal fences remain unchanged.
See incident rules R1–R6 and primary Apple sources in `docs/always-on-build.md`.

Fail-first used the new test overlay on unmodified production source at base
`be00ea36b8b18373c9b08b6a8c4fa10c7551efb3` (product diff empty at red run).
`swift build -c debug --product AlwaysOnDaemonChecks` compiled successfully; `.build/debug/AlwaysOnDaemonChecks` exited 1: **266 assertions, 37 failures**.
Representative runtime failures: observed `0x2030` status, manual activation,
heartbeat, deactivation, reconnect retry, strict removal preparation; credential
flag clearing during a lease; actual restore-error/Retry exit. This was not a
compile failure or merely reversing the old missing-auth-bit assertion.
Local full red output: `/tmp/pane-console-recovery-red.log`; build output:
`/tmp/pane-console-recovery-red-build.log`.

The fixed test composes the real policy → telemetry cache → managed connection →
service coordinator/recovery engine with in-memory journal/power. Both `0x2030`
and `0x6030` cover all six operations, no-autoarm status, wrong-token/other-connection
rejection and sealed removal. A midlease `0x6030`→`0x2030` transition preserves
renewal and deactivation. Twelve invalid/stale cases still reject every operation
on existing and new connections and restore an owned override. Failed power
restoration remains recovery-required; existing Retry reaches verified OFF after
the fault clears. These fixtures perform no native power writes and do not prove
installed signed XPC acceptance.

Separate debug and release builds passed. All nine suites passed in both configurations: SnapCore 60, SigningProbe
114, AlwaysOn 84, Engine 176, Native 114, Service 355, Daemon 266, Client 181,
Setup 178; zero failures. Diff/shell/Python/plist lint passed. Synthetic staging
suites passed: Developer ID 17, probe 11, local production 13. After strengthening the invalid-ID controls, the exact final test overlay
again failed 266/37 on base production; both builds and daemon suites were rerun.
[CI38401709446](https://github.com/ccmenshealth/pane-management/actions/runs/38401709446/job/115310709103)
passed in 1m32s on runtime head `509687c16a6c2cd57363dff2253928f53b2275f3`. No UI change: new browser/native visual rendering is not applicable;
installed recovery acceptance requires a separately approved update.

Sibling audit: native session collection has one production `auditValid` caller;
all six service operations share admission and revalidation. No alternate auth-bit
predicate was found in production. Independent reviewer
`/root/console_session_recovery_reviewer` passed code/manual security review of
`509687c16a6c2cd57363dff2253928f53b2275f3` with no findings; lead review passed the
same head, including all six operations, ownership and removal. Lead verified the
reviewed worktree clean. Reviewer inherited current model/effort; exact runtime
metadata unavailable. The preserved identity policy proves an existing GUI audit
session matching the current console UID; it does not independently prove the
foreground ASID or an unlocked screen. No new stronger guarantee is claimed.

Literal security-review tool is unavailable; independent manual security review
is the fallback. CodeRabbit remains unavailable under the user's repository
exclusion. This closure is Markdown only; final CI and lead delta review remain.
Lead authorized staging with the existing dedicated local certificate after the
review passes. Staging is a separate artifact, not installation: installed native
recovery remains pending Steve's explicit update approval. No registration, launch,
permission or live power change is included.

## Observed merge and release closeout — 2026-10-12

- [PR16](https://github.com/ccmenshealth/pane-management/pull/16) squash-merged at
  2026-10-13T04:59:43Z (October12 21:59:43 Pacific) as
  `db8fbbb1b64f0d3324ce168d3bf009a59a4073fb`.
- Merged tree `4d13f57fc26ee315a21516bdb7ff6795f157dd66` exactly equals reviewed
  head `7138ee92897cf7f39934759d45b7ae23470ecca3`; lead tree diff exited0.
  [Post-merge main CI38349154813/job115137348864](https://github.com/ccmenshealth/pane-management/actions/runs/38349154813/job/115137348864)
  passed in1m48s on the exact merged commit.
- Lead closed PRs2–15 as superseded after green main CI, without deleting branches
  or posting comments. Open-PR list was empty before this separate documentation
  closeout PR. Per-slice review history remains preserved.
- Primary main fast-forwarded clean; no installed bundle replacement. Installed
  signed source remains `ddba40d66222b360d52124a09bffe87d5bd11629`, final setup
  runtime/review `762ed6600c4495d1352ebfd5be480119426ddbeb`. Executable hashes remain
  app `403ccdf93075829887f16c93bd7704b21efcd09e7d9a5debe3159980f509e7e3` and
  helper `80ff1843e22f59571f6cc6bfe57d6cdf63fca546d7ee7647fe19f1e9ae0a9d6f`.
- Lead's final CLI readbacks: pmset SleepDisabled0, IOPMrootDomain SleepDisabledNo,
  AppleClamshellStateNo. Requested acceptance passed as detailed below, explicitly
  distinguishing human reports from CUA/CLI and the lid-sampler handoff gap.
- Helper-crash/reboot, physical critical thermal/battery stress, prolonged backpack
  use and VoiceOver remain unproven. No extrapolation to legacy snapping behavior
  or guarantee of emergency sleep/temperature protection. All old worktrees,
  signed candidates and rollback backups are retained.

This fresh-main closeout changes only this record and the current bookmark. No
runtime/test/build/signing/install/native/merge action by its builder. Diff lint
and remote CI are its checks; new fail-first/security review is not applicable to
this evidence-only delta. CodeRabbit remains prohibited. This record does not
claim the separate documentation closeout PR itself has already merged.

## Final requested visual acceptance PASS; final OFF verified — 2026-10-12

Steve answered **“all works”** to the requested check: activate through the Dock
right-click action, open Pane Management Settings, switch desktops, enter a
fullscreen app, confirm the warning remains above those surfaces, then deactivate
through the menu bar. These results are **USER-REPORTED native acceptance**, not
CUA observations of the Dock/Spaces/fullscreen interactions.

After that answer, the lead independently confirmed dual OFF and lid open through
CLI readbacks. Native CUA Settings showed Always-on mode OFF with manual activation
required, recognized permission checkmarks, and unchanged appPID8366/helperPID8607.
This closes the pending human visual check and verifies final OFF after user
activity, rather than assuming the requested deactivation succeeded.

The requested Always On/Dock/warning acceptance gates now pass through the
combination of individually recorded native lead observations and human reports.
This does not establish helper-crash/reboot recovery, physical critical thermal or
battery protection, prolonged backpack use, VoiceOver, or unasked legacy snapping
actions. No extrapolation or emergency-protection guarantee is made.

Installed signed source remains ddba40d66222b360d52124a09bffe87d5bd11629; final setup
runtime/review pin remains762ed6600c4495d1352ebfd5be480119426ddbeb, with earlier
component review pins preserved below. Installed path, signatures and executable
hashes are unchanged. This update changes documentation only; builder performed
no runtime, build, signing, candidate, native or merge action.

PR16 is already retargeted to main as the integrated release. Merge is still
PENDING final docs CI and lead check. Planned closure is one squash of PR16, then
close PRs2–15 as superseded while preserving their review history. Prior integrated
CI38348582654 passed; final closure checks are reported separately. No merge or
superseded-PR closure is claimed until observed.

## Native app-hang, app-crash and removal/reinstall recovery PASS — 2026-10-12

User authorized continuing recovery drills and release closure. This supersedes
prior drill-specific no-further-activation handoffs. Lead performed the following
native tests against the unchanged installed signed source ddba40d (runtime/review
762ed660). Times below are Pacific on October 12; dual ON/OFF means agreement of
pmset SleepDisabled and IOPMrootDomain SleepDisabled, not physical sleep proof.

- **App hang:** exact app PID95172 received SIGSTOP at 21:48:28.703267, after
  confirming dual ON and lid open. Last sampled ON was 20.704 seconds after stop;
  first sampled OFF was 21.742 seconds. Both remained OFF through the 41.565-second
  resume point. After SIGCONT, native CUA showed OFF/manual activation. Restoration
  is bounded by those sample observations, not asserted at an exact instant.
- **App crash:** after native reactivation and dual ON, exact app PID95172 received
  SIGKILL at 21:49:35.834286. First sampled dual OFF was 1.063 seconds later and
  stayed OFF through 11.517 seconds. Old PID was absent. Native reopen produced
  app PID8366, OFF/manual activation, with existing permissions still recognized.
- **Verified helper removal:** native Remove helper around 21:50 reported
  “Helper removed. Normal sleep was verified.” The exact launchctl service and
  root helper process were absent; both readings OFF and lid open. The protected
  recovery directory remained root:wheel0700; it was NOT deleted.
- **Explicit reinstall:** native Set Up reused existing user approval without a
  new prompt. UI again reported authenticated OFF; new root helper PID8607,
  runs1/execs1, with both readings OFF. Strict/deep signatures passed and installed
  executable hashes remained:
  app `403ccdf93075829887f16c93bd7704b21efcd09e7d9a5debe3159980f509e7e3`,
  helper `80ff1843e22f59571f6cc6bfe57d6cdf63fca546d7ee7647fe19f1e9ae0a9d6f`.

Thermal state was fair before these drills. No helper crash, reboot, physical
critical thermal/battery stress, or long-duration/backpack test was performed.
No automation or automatic arming was introduced. These results establish only
the observed app-hang/crash restoration and explicit removal/reinstall paths.

**Pending human visual check:** activate through the Dock, inspect warning above
Settings/across Spaces/fullscreen, then deactivate through the menu bar. This has
not been reported complete. Last lead-verified state after reinstall was OFF;
final state after pending user activity must be rechecked, not assumed.

All merges remain pending. Planned release closure, once applicable gates pass:
lead reviews the integrated diff, retargets PR16 to main and checks final CI,
squash-merges once, then closes PRs2–15 as superseded while preserving their
review history. No source rewrite is required or authorized by this docs work.
This commit changes Markdown/PR evidence only; builder performed no native action,
build, test, signing, installation, helper/power operation or merge. Prior docs
CI38347362302 passed; this closure's checks are reported separately. Runtime
reviews remain pinned to762ed660; CodeRabbit is prohibited and new security review
is not applicable to this evidence-only delta.

## Brief native closed-lid execution and reopen acceptance PASS — 2026-10-12

User separately approved a 30-second closed-lid test on the same open hard
surface, finishing OFF. Lead used unchanged signed source ddba40d (runtime
762ed660), started a read-only one-second sampler, then explicitly activated.

First sampled closed state was 21:32:02.203758 and reopened state 21:33:41.731504
Pacific on October 12. There were 67 closed samples across two monitor segments.
The initial 180-second monitor expired after five closed samples; switching to a
second 90-second monitor left a **31.969995737-second gap**. The full interval was
NOT continuously sampled. The second segment alone contains **62 closed samples
across 62.441519 seconds**, maximum gap **1.027101 seconds**, all with the override
ON. The at-least-30-second observed process-execution target while lid-closed
PASSED; useful coding-agent progress and the unobserved gap were not established.

Lead parsed zero Sleep/Wake/DarkWake events from `pmset -g log` during the sampled
drill interval. On detecting reopen, lead immediately used native Deactivate.
Final UI off, pmset SleepDisabled0, IOPMrootDomain SleepDisabledNo and
AppleClamshellStateNo confirmed the drill finished OFF. `pmset therm` recorded no
warning; this was not a thermal stress or critical-event recovery test.

User-reported native acceptance, distinct from lead CUA/CLI observations: Steve
replied **“Yes—screen/input work and the Dock action is there”** when asked whether
screen/keyboard returned normally after reopening and right-clicking the Pane
Management Dock icon showed Activate always-on mode. These checks passed by human
report; CUA could not inspect the Dock. No Dock activation click was tested.

Raw samples remain local only:
`/var/folders/dr/c980wd_57l5gsqhpm4_dcv6m0000gn/T/pane-lid-drill-1dkzfsp2/samples.jsonl`.
No screenshot files or PHI were saved/published. Backpack use, longer duration,
critical/crash/removal recovery, global Spaces/stacking and VoiceOver remain
unproven. This result guarantees neither safe temperature nor emergency sleep
protection. No further activation is authorized; the app was left OFF.

This closure changes Markdown/PR evidence only. Signed/installed source, runtime
pin and hashes remain unchanged; all feature PRs remain unmerged. Prior docs
CI38346358836 passed; latest closure CI is checked separately. No builder native
operation, code edit, build, signing or candidate change occurred.

## Native first activation and warning Deactivate PASS — 2026-10-12

User explicitly approved a brief activate/deactivate drill with the laptop out
of the backpack, on an open hard surface, lid open, finishing OFF. Lead used the
unchanged installed candidate: signed source ddba40d66222b360d52124a09bffe87d5bd11629,
runtime/review762ed6600c4495d1352ebfd5be480119426ddbeb, at the original stable path.
AppPID95172 and roothelperPID93989 remained the same throughout.

1. Lead clicked native Settings Activate. UI reported active; read-only pmset
   showed SleepDisabled1 and IOPMrootDomain showed SleepDisabledYes.
2. Lead closed Settings to inspect the actual active warning directly: red border,
   red triangle with white exclamation mark, faded black/yellow diagonal stripes,
   fitting text and Deactivate button, no scroll area/bar. CUA's window image was
   1040×600 pixels; this is not a logical-point or screen-size measurement. No
   screenshot was saved or published.
3. Lead clicked the warning's Deactivate button. The warning disappeared (CUA
   noWindowsAvailable was expected), pmset returned SleepDisabled0 and
   IOPMrootDomain SleepDisabledNo. Reopened native Settings confirmed Always-on
   mode is off, normal sleep available and activation must be manual.

The brief native activation/explicit-warning-stop drill PASSED and finished OFF;
no sleep override was left on. This proves this observed manual path and setting
readbacks, not physical sleep, safe backpack use or macOS emergency protection.
Physical lid, critical-event, crash and production removal tests were not
user-authorized or performed. Dock visual/right-click remains unverified because
CUA Dock is unavailable; global Spaces/stacking and VoiceOver remain unproven.
No further activation is authorized by this documentation handoff.

Only Markdown/PR evidence changes here. Source, signed candidate and installed
hashes are unchanged; all feature PRs remain unmerged. Prior docs CI38346017881
passed; latest closure CI is checked separately. Independent/manual-security and
lead code review remain pinned to762ed660; no new product behavior was added.

## Native installed helper setup and off-state acceptance PASS — 2026-10-12

Lead's user-authorized native acceptance installed the exact signed candidate at
`/Users/ccmh/Developer/PaneManagement/dist/Pane Management.app`. Signed source
`ddba40d66222b360d52124a09bffe87d5bd11629`; runtime/review pin
`762ed6600c4495d1352ebfd5be480119426ddbeb`. Pre-install candidate and installed
strict/deep exact-certificate/identifier verification passed. Installed hashes
were rechecked unchanged after the final native restart:

- App: `403ccdf93075829887f16c93bd7704b21efcd09e7d9a5debe3159980f509e7e3`.
- Helper: `80ff1843e22f59571f6cc6bfe57d6cdf63fca546d7ee7647fe19f1e9ae0a9d6f`.

Native notFound warning offered Set up always-on helper; clicking it progressed
to requiresApproval. User approved the specific Pane Management Login Items
administrator prompt. Its background switch became ON. App Check again then
reported authenticated **Always-on mode is off**, normal sleep available and
manual activation required. This proves the repaired native setup path and live
authenticated off observation, not physical sleep or emergency protection.

- launchctl showed the fixed production service running as UID0, PID93989,
  execs1/trampolined1/runs1, no exit. Protected `/var/db/local.snapbridge.alwayson`
  exists as root:wheel0700 from normal daemon startup. Final app PID95172.
- Normal app Quit succeeded; reopening the same installed bundle again showed
  off without activation. The later system Quit & Reopen also succeeded.
- User authenticated scoped Accessibility and Screen Recording refreshes for
  only Pane Management and the exact current stable bundle. Final native Settings
  displayed the Accessibility checkmark and “ScreenCaptureKit access verified.
  Previews stay in memory.” No unrelated permission entry was changed; private
  screenshots/window contents were not saved or published.
- Final read-only observations: pmset SleepDisabled0 and IOPMrootDomain
  SleepDisabledNo. No activation or sleep override occurred. Primary main stayed
  clean; build5 backup remains preserved. Builder performed only documentation
  work during this native lead-owned acceptance sequence.
- Actual ddba40d setup warning was actionable and fitted its content. Earlier
  d12f18a installed warning visually demonstrated faded stripes, red/white icon
  and no scrollbar; the warning implementation is unchanged between them.
- Native Dock visual/right-click remains unverified because CUA could not obtain
  the Dock surface. Reviewed regular app policy, LSUIElement=false metadata and
  shared menu/Dock action code are not substituted for physical acceptance.
- First activation, deactivation/restoration drill, closed-lid behavior, critical
  battery/thermal recovery and production removal remain unperformed and gated.
  Current user approval covers installation/helper setup with Always On OFF only.
  First activation is NOT authorized: ask Steve to confirm the laptop is out of
  the backpack, on an open hard surface, lid open. The proposed brief drill is
  Activate → inspect native active warning and both SleepDisabled receipts true
  → click warning Deactivate → verify UI off and both receipts false, finish OFF.
  It includes no physical lid, critical-event or crash test. Failed activation
  goes to deactivation/recovery, without blind retries or force quit while
  uncertain. Never auto-arm or claim guaranteed macOS emergency sleep protection.

All feature PRs remain unmerged. Reviewed code, signed candidate and installed
hashes are unchanged by this Markdown-only native-evidence closure. Prior docs
CI38343298496 passed; final closure CI is checked separately. CodeRabbit remains
prohibited; independent code/manual-security and lead review of runtime762ed660
remain clear. No new runtime/security behavior is introduced by this record.

## Patched local candidate signed — 2026-10-12

Signed source `ddba40d66222b360d52124a09bffe87d5bd11629` (runtime/review pin
762ed660), after final docs-head CI38342796841/job115117333554 passed. Authorized
isolated staging exited0/signed:true without prompt/error. Candidate:
`/Users/ccmh/Developer/PaneManagement-worktrees/setup-notfound-repair/dist/local-signed-staging/ddba40d66222b360d52124a09bffe87d5bd11629-a1eb1514-4ab6-45c9-8067-f5f9ecc9c91c/artifacts/Pane Management.app`.

- App SHA256 `403ccdf93075829887f16c93bd7704b21efcd09e7d9a5debe3159980f509e7e3`.
- Helper SHA256 `80ff1843e22f59571f6cc6bfe57d6cdf63fca546d7ee7647fe19f1e9ae0a9d6f`.
- Both signatures independently passed strict/deep exact identifier and leaf
  EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F requirements, hardened runtime and no
  entitlements. Manifest hashes match; expected production-only contents and
  LSUIElement=false confirmed. Source stayed clean through staging.
- Local ignored evidence: `.build/evidence/notfound-native-stage.json`,
  `notfound-native-verification.log`; `notfound-native-stage-error.log` empty.
- No installed-state, helper, power, permission or arming action by builder.
  Candidate handed to lead for user-authorized replacement and native explicit
  setup acceptance with Always On OFF. This is packaging evidence, not evidence
  that real registration, Accessibility recognition or physical sleep works.

## Fresh notFound explicit setup repair — 2026-10-12

Runtime/review pin `762ed6600c4495d1352ebfd5be480119426ddbeb`, PR16; base
c2f7782; isolated codex/setup-notfound-repair. Native lead observed the exact
signed production bundle report notFound/BTM record-not-found before registration;
Check again and Settings Repair were inert. The helper was not running/registered,
the recovery directory absent and both public sleep-disabled receipts false.
Lead stopped the installed app after scoped Accessibility refresh; no override or
activation occurred. Patched native acceptance is still pending.

The shared coordinator now offers explicit setup for a valid signed notFound
bundle, registers only after a click and identity validation, and re-inspects real
status. notFound remains setupRequired/quit-unsafe, and the exact notRegistered
absence proof is unchanged. Invalid signatures offer signed-install repair and
Check again; failed registration offers a named setup retry. Pending registration
continues excluding competing actions until actual completion.

- Final tests overlaid on the actual c2f7782 coordinator (no API/inert shims):
  **178 assertions / 27 failures**. Restored final coordinator: **178 / 0**.
  Ignored local logs: `.build/evidence/notfound-final-prefix-red.log`,
  `notfound-final-prefix-build.log`, `notfound-setup-final-green.log`.
  Initial red was28/178: one changed expectation incorrectly ignored the older
  adapter fixture's retained unsigned identity. Restoring its correct Check again
  expectation yielded the authoritative exact final red27/178 above.
- `swift build -c debug` compile/typecheck and separate `swift build -c release`
  passed. Debug Setup178/0, Client181/0, UI84/0, Daemon149/0; release Setup178/0
  and UI84/0. Final debug rebuild after the red overlay passed. Existing probe
  Swift concurrency warnings are unchanged and outside the production delta.
- `git diff --check` passed. No plist, script, workflow, dependency or package
  change; plist/bash/Python checks not applicable to this delta.
- Regression exercises startup without registration/proof borrowing, both shared
  primary action and Settings Repair, invalid signing, error/repeated-notFound
  retry, pending exclusion and late enabled/approval/active settlement without
  activation. Existing enabled/approval no-duplicate and exact bracket tests pass.
- Recoverability: Set up always-on helper/Repair helper setup for notFound; signed
  installation repair then Check again for invalid identity; retry Set Up for
  failure/repeated notFound; wait while pending; Open Login Items after approval;
  separate Activate only from observed off, Deactivate for observed active.
- Sibling audit: App.swift menu and Dock both use alwaysOnMenuItem/alwaysOnAction;
  warning/Settings primary action delegates to the same controller, Settings
  Repair calls its same backend setup, and SetupPresentationAdapter preserves
  the remedy. Harmless probe Register already validates identity and explicitly
  registers independent of its status with a busy lifecycle guard; no analogous
  notFound admission blocker. No sibling runtime change needed.
- Fresh independent read-only code/manual-security and lead code/security reviews
  clear at762ed660 with no actionable findings; lead verified clean tree. All roles
  inherited current model; exact metadata unavailable. Literal security-review
  unavailable, independent manual fallback used. CodeRabbit prohibited by repo.
  Original runtime CI38342598768 was pending when docs closure was requested;
  latest docs-head CI must pass before signing. Runtime code remains unchanged.
  No merge, real signing, install, helper action, permission or power change by
  this builder. Native rendering/repair acceptance belongs to lead after reviews,
  CI and separately authorized local restaging. First activation remains gated.


## Native local production staging PASS — 2026-10-12

Reviewed runtime pin ed480e204e5b8503c7be3cd9f768f9d28beabd02; signed source
d12f18a8dfbeb4e647dfe903e123f544bf7ed4cd (docs-only closure). Runtime CI38333954926
and pre-signing docs CI38334359619 passed. Lead explicitly authorized staging
only with dedicated public certificate EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F.
The native staging command exited0, signed:true, with no signing prompt or error.

Candidate artifacts: `/Users/ccmh/Developer/PaneManagement-worktrees/local-signed-release/dist/local-signed-staging/d12f18a8dfbeb4e647dfe903e123f544bf7ed4cd-e1791ea0-0f8e-49ad-bf5f-d137ca780c74/artifacts`.

- App executable SHA256: `5ad0411004e05d42311f34c674c46f0cb2ebe24a12d3a6d556212ec87be4648d`.
- Helper executable SHA256: `a52fdee888a1d41c876b3693006186e8acb6e6778625d0ef06c201085a172cda`.
- Packager gates and separate read-only codesign strict/deep verification passed
  for BOTH fixed production identifiers and the exact selected leaf fingerprint.
  Actual metadata shows hardened runtime, Authority Pane Management Local Signing,
  TeamIdentifier not set. Entitlement output is absent/empty for both.
- Bundle contains only Info.plist, the two production executables, production
  LaunchDaemon plist, current icon/menu glyph and signing resource seal. No probe/
  negative/check executables. Info is build6, LSUIElement=false (Dock metadata).
- Candidate hashes independently match its manifest. Local evidence is retained
  in `.build/local-staging-evidence/native-stage.json` and
  `native-verification.log`; native-stage-error.log is empty.
- Original build5 remains PID96007 with SHA256
  3367ecbfc6d95a54bde086348d4c67988c8be8089042ba30a4c853f6634e978a. Production
  launchctl service, PaneAlwaysOn process and /var/db/local.snapbridge.alwayson
  remain absent. No helper has launched during packaging. No install, launch,
  registration, root-journal, power, trust/keychain ACL or arming action occurred.

This proves local candidate signing and packaging, not native production service
acceptance, warning/Dock global behavior, critical recovery or physical lid use.
Installation/approval and first activation remain separate gates. This evidence
commit is Markdown only; reviewed runtime and signed-source pins remain distinct.

## Local production staging candidate — 2026-10-12

Branch codex/local-signed-release integrates probe closureb70efed and reviewed
warning2636ff1. Warning production/test/preview files match the reviewed warning
branch byte-for-byte; IPC/app/daemon runtime matches the probe base. No fresh
native UI evidence is claimed. Prior native warning sizing/stripes evidence and
probe root-launch/authentication/removal evidence below remain distinct.

The production packager reuses source/layout checks and exact leaf-pin signature
verification, while selecting only production app/helper/assets. Both signatures
are mandatory; no probe fixtures, paid-account requirement, ad-hoc fallback,
notarization, service operation, trust mutation or power operation occurs.

Evidence is retained in ignored `.build/local-staging-evidence/`:

- Final inert API-compatible staging overlay executes the final13-test suite:
  20 assertion failures and7 expected missing-output errors, restored in finally.
  `run-red.py`, `inert-local-staging.py` and `red.log` preserve the recipe/result.
  Existing shared argument guards remain functional in the inert overlay.
- Actual pre-fix imported probe help text fails the focused production-help test
  once (`help-prefix-red.log`). Shared parser now accepts an optional description;
  verifier accepts an optional diagnostic label, preserving probe defaults.
- Correct implementation:13 tests pass, including all17 external-command failure
  positions followed by successful retry, both ID/certificate/runtime/entitlement
  boundaries, absent identity/key, dirty/changed source, metadata, linked paths/
  binaries, unexpected build path, exclusive publication and racing output.
- Native subprocess fallback is forbidden by the test fixture; every external
  command is injected. Paid17 and probe11 synthetic suites pass unchanged.
- Python compile, per-script bash syntax, all Resource plists and diff lint pass.
- Separate debug (193.36s) and release (276.91s) builds passed. Debug suites
  SnapCore60, UI84, Engine176, Native114, Service355, Daemon149, Client181,
  Setup141 and Probe114 all passed with zero failures. Release UI84 and Daemon149
  passed. A premature attempt before the release alias existed did not run any
  tests; the recorded passing runs followed completed release compilation.
- Clean committed-source read-only preflight passed at
  ed480e204e5b8503c7be3cd9f768f9d28beabd02 with signed:false.
- Existing probe-only concurrency warnings remain in Probe.swift:52 and
  Native.swift:42 (plus suggested preconcurrency import). Those sources are
  unchanged and probe binaries are not included in the production candidate.
  No claim of warning-free compilation is made.
- Fresh independent read-only code/manual-security and lead reviews cleared the
  same runtime pin with no findings and clean worktree. Runtime CI38333954926
  passed. This evidence closure is Markdown only; its CI is tracked separately.

Recovery: preflight failure offers the named prerequisite and retry; signing/
verification/build failure publishes nothing and cleans owned partial files;
existing/racing output is preserved; publication failure removes only the newly
reserved destination and a fresh retry succeeds. Forced termination may leave
unpublished .partial files, never installed state. Sibling audit covers both
production signatures and cleanup branches, local probe identity discovery and
shared verifier defaults, paid route isolation and stable packager guard. The
stable script's obsolete Apple-only comment is corrected without behavior change.

Current model inherited; exact model/effort unavailable. Independent read-only
code/manual-security, lead review and runtime CI passed. CodeRabbit prohibited;
literal security-review unavailable, independent manual fallback applies. No real
production signing, native launch, helper install/register, power or arming.

## Native local-signing acceptance PASS — 2026-10-12, Pacific

The user explicitly authorized the same-helper diagnostic rerun. The unchanged
signed source12baca95 candidate was recopied to the same
`/Users/ccmh/Applications/Local Signing Probe.app` location and exact app/helper
certificate requirements reverified. Register reached enabled. At18:37:47,
launchctl showed root SigningProbeDaemonPID8385 running, execs1/trampolined1.
GUI8284 and scoped logs verified these ordered controls:

| Pacific time | Action and result |
| --- | --- |
| 18:37:54 | GUI positive nonce ping SUCCESS |
| 18:38:14.925 | Wrong-ID same-cert fixturePID8752; daemon logged “Dropping check-in message due to code signing requirement”; CLI exit0 NO SUCCESS |
| 18:38:23 | Fresh GUI positive nonce ping SUCCESS |
| 18:38:32.249 | Ad-hoc fixturePID8968; daemon logged the same code-signing rejection; CLI exit0 NO SUCCESS |
| 18:38:35 | Fresh GUI positive nonce ping SUCCESS |
| 18:38:42.453 | Wrong-pin fixturePID9100 using forty zeroes; client logged “Received message forbidden due to code signing requirement”; CLI exit0 NO SUCCESS |
| 18:38:47 | Fresh GUI positive nonce ping SUCCESS |

CUA visually confirmed each success. Because the successful message text can stay
unchanged, scoped logs confirmed fresh connections for subsequent pings. Negative
fixtures share an identical executable image and appear under process name
`wrong-id` in logs; the explicit invocation and PID mapping above identifies each
scenario. Positive controls surround every rejection. This demonstrates actual
root launch and reciprocal certificate/identifier enforcement for this harmless
probe on this Mac; failures alone are no longer the basis for acceptance.

Remove completed; explicit Check status returned not registered, then Quit.
Final launchctl job, daemonPID8385 and probe GUI/daemon processes were absent.
Finder moved only the installed probe copy to Trash; the signed staging candidate
and manifest remain. Original Pane Management build5PID96007 and executable hash
`3367ecbfc6d95a54bde086348d4c67988c8be8089042ba30a4c853f6634e978a`
unchanged. No power, production helper or trust operation occurred.

The rerun succeeded without a root trace, Terminal or password. Diagnostic output
directory `/tmp/pane-probe-diagnostic-b9jmjchi` remained empty. Earlier delayed
BTM pre-exec failures remain unexplained transient behavior, not a demonstrated
local-certificate rejection. No workaround/source change was introduced between
attempts. Reviewed productpin9458b946 and signed source12baca95 remain unchanged;
this closure is Markdown only. Native acceptance unblocks the next integration
and local product packaging slice; production install/UI/lid/recovery testing
and first always-on activation remain distinct gates.

## Earlier approved native service drill — 2026-10-12, Pacific

**Outcome: registration/approval and removal verified; root executable launch and
successful authenticated communication remain inconclusive.** The user explicitly
authorized “run and remove test helper” and personally completed the Login Items
administrator approval. No negative fixture was run because no successful positive
control was available. This is not proof that macOS rejects local certificates.

- Lead copied the exact signed source12baca95 candidate to
  `/Users/ccmh/Applications/Local Signing Probe.app`, reverified exact certificate
  requirements on app/helper, and launched via CUA. Initial status was notFound;
  Register returned generic error1, subsequent Check status correctly reported
  requiresApproval. User approval followed; explicit Check status reached enabled.
- First launchd submission18:05:36.949; root xpcproxyPID85425 remained pre-exec with
  execs0/trampolined0 and inactive endpoint. Two five-second GUI Ping requests
  timed out. At18:06:44.149, xpcproxy logged BTMManager.fetchItemWithUUID (~67 seconds
  after spawn); BTM accepted its connection18:06:47.729 and activated peer
  18:06:59.592, just before removal18:06:59.611. No daemon self-signature/listener
  code ran according to the observed pre-exec launch state.
- One bounded retry registered successfully/enabled without another approval
  prompt at about18:08. Root xpcproxyPID86598 remained pre-exec for three minutes;
  a third Ping timed out. Its BTMManager.fetchItemWithUUID log was18:10:45.801,
  about164 seconds after submission. No executable launch or scoped certificate
  denial was observed. No further retries or negative fixtures were attempted.
- Read-only source/filesystem investigation: BundleProgram matches the actual
  executable, file and bundle-directory modes are755, and linked dependencies
  are system frameworks/libraries. BTM effectiveItemDisposition explicitly names
  the installed `/Users/ccmh/Applications` bundle, which argues against selection
  of the unsigned preview in this attempt. Apple DTS's working example uses the
  same BundleProgram/Label/MachServices layout without ProgramArguments:
  https://developer.apple.com/forums/thread/799910 . These checks do not establish
  why BTM resolution stalled or exclude an OS policy issue.
- Scoped launchd/BTM logs identify slow pre-exec resolution; targeted
  amfid/syspolicyd/kernel/taskgated output contained no relevant rejection.
  Absence of a diagnostic is not evidence of full signature-policy acceptance.
  Ordinary root-process sampling was denied; read-only sudo-n sample required a
  password, so no privileged sample was collected and no password was supplied.
- GUI Remove completed and explicit Check status said not registered after each
  attempt. Final launchctl job absent; PIDs85425/86598 and SigningProbeApp/Daemon
  processes absent. Quit worked. Finder moved only the selected installed probe
  app to Trash; item removal and filesystem path absence confirmed. Signed staging
  candidate remains intact. Installed build5PID96007 retained executable SHA256
  `3367ecbfc6d95a54bde086348d4c67988c8be8089042ba30a4c853f6634e978a`;
  primary main clean. No power/production helper/global trust change occurred.

Next investigation should gather a targeted privileged xpcproxy/BTM diagnostic
with explicit human administrator approval, or separately scope a same-binary
shared-/Applications location comparison. Do not change authentication based only
on these timeouts. Local signing/strict static verification remains passed, but
production local installation and always-on arming remain blocked on a successful
harmless root-service drill. This update is Markdown only; reviewed productpin
9458b946 and signed source12baca95 unchanged. Prior docs CI38329202819 passed.

## Native local probe signing succeeded — 2026-10-12

The user created the dedicated credential after the handoff and reported it
ready. The reviewed packager ran once on clean source `12baca95bd552dc0926bc784af4bb85586a7e657` with
explicit fingerprint `EE48D3317B0AFBC3615CD0CA27331EDEAE2CA81F` and exited0,
`signed:true`. No blocking Keychain prompt observed. Signature requirements,
fixed IDs, hardened runtime and absence of entitlements passed for the signed
app/helper and negative fixtures; the ad-hoc fixture was also verified as such.
The self-signed identity's untrusted listing diagnostic did not prevent these
actual signing/strict-verification checks. No trust settings were changed.

Candidate relative to this isolated worktree:
`dist/signing-probe/12baca95bd552dc0926bc784af4bb85586a7e657-aca17390-5763-4862-9cc2-f5433c98984d/artifacts`.
The candidate contains `manifest.json` with only public source/fingerprint/hashes.

| Executable | SHA256 |
| --- | --- |
| `Local Signing Probe.app/Contents/MacOS/SigningProbeApp` | `8a5c32f6c53fc6aa0acdb54c0a04601d75c7f4ebe34fb406fe328c906f0dd20e` |
| `Local Signing Probe.app/Contents/MacOS/SigningProbeDaemon` | `e776ba5b7db94755c284b4c8a1b575d6dc645abac1e01245072b172a80ed9474` |
| `wrong-id` | `8798d577cea4f621e0b3ddc19d74a95abef8dc13e8d5c2bb40f41a3a5cc04667` |
| `wrong-pin` | `c88ea60708989ad229d8be11951189f73448c95f80b9223527655afae7b323a2` |
| `ad-hoc` | `8b9ce739e3f441d8dc8a9437ee4ee77c0f20613c3d71b5b13260451ea43ec940` |

Reviewed product pin remains `9458b946982589b0b25a5f8e9e26d755018ceff3`;
source12baca95 includes only later review/preview Markdown. Its CI38306212290
passed. This evidence update is Markdown only; no build/signing rerun. Existing
build5 and production sources/settings remain untouched. No certificate/private
key content or unrelated personal certificate metadata is recorded here.

No signed candidate/helper was installed, launched, registered or run, and no
power operation occurred. Native SMAppService acceptance and surrounding positive
pings/negative fixtures/removal remain pending. Next requires user confirmation
for installing/running this ping-only administrator-level service, testing it and
removing it; this grants new privileged service access. Signing success is not
native service acceptance or permission to arm production always-on behavior.

## Harmless local signing probe candidate — 2026-10-12

- Isolated probe uses fixed new IDs, nonce-only protocol and reciprocal shared
  own-leaf signatures. No power/journal/production runtime dependency. GUI service
  actions are explicit; pending mutations retain the lane until actual completion.
  Probe Quit always works and warns OS work may continue; reopen/status/removal is
  the exit. No production quit/auth mode changed.
- Separate debug/release Swift builds passed. SigningProbeChecks114/0 in both;
  daemon149/0, client181/0, setup141/0 passed. Python staging11/0, Python compilation,
  bash syntax, both probe plists and diff whitespace passed. Synthetic staging
  exercises every command failure with cleanup/retry, publication failure/race,
  explicit untrusted/missing/nonmatching identities, output links, malformed
  arguments, metadata drift and entitlements; no native subprocess fallthrough.
- Final tests over a compiling inert overlay fail67/114 Swift assertions and14
  Python assertions (11 tests). Actual pre-P-R2 packager fails the untrusted
  identity case and unfiltered lookup check (1 assertion, 1 exception). Retained
  ignored evidence: `.build/probe-evidence/{make-red.py,red-source,swift-red.log,
  staging-red.log,trust-red.log,probe-staging-before-trust-fix.py,*green.log,
  debug-build.log,release-build.log}`. No native certificate, signing, helper,
  registration, removal, power or installed-bundle action occurred.
- Lead P-R1 pending-quit trap resolved by native normal termination with an enabled
  Quit button; same running process still serializes service mutations. P-R2 uses
  unfiltered identity discovery, allows diagnostic suffix on an exact selected
  fingerprint, and retains strict signature checks; no system trust is changed.
  Shared fixed-role requirement builder now delegates to the validated ID helper.
  Sibling audit covers app/helper/negative signatures, malformed requests/replies,
  all ping callback orders and each register/remove/ping settlement/retry exit.
- Negative fixtures separate wrong-ID same-cert, ad-hoc and wrong expected helper
  pin; success-before/after each is mandatory. Failure alone is inconclusive.
  External examples conflict on local SMAppService acceptance; actual native
  success remains unproven. Paid packager and original build5 remain untouched.
- Fresh independent read-only code/manual-security and lead code/security reviews
  cleared runtime pin `9458b946982589b0b25a5f8e9e26d755018ceff3` against auth closure
  `37dad17`; no actionable findings, worktree clean before/after. CI38305835875
  passed at that pin. Actual read-only clean-source preflight also passed there,
  signed:false, no identity lookup or native signing. This closure is Markdown
  only; no builder builds were repeated for bookkeeping.
- Lead CUA launched `dist/SigningProbeUnsignedPreview.app` (no embedded helper),
  clicked only Check status, and observed the missing/invalid dedicated-certificate
  explanation, readable buttons/content without scrolling, and available Quit.
  Quit closed the app; CLI process absence confirmed, only build5 PID96007 remained.
  No Register, Ping, Remove or Login Items was invoked. Preview executable SHA256:
  `8d6f7d3265767933c0efa5bf9f62582a005de81474cd2188f7ae6ec3663e21e6`.
- Native pending-operation Quit was not exercised: invoking the OS lifecycle was
  outside this drill. Source policy leaves native termination unblocked and Quit
  outside the disabled action groups; injected pending-state tests retain the
  serialized mutation lane until completion. Do not infer OS cleanup from Quit.
- Inherited current model/effort metadata unavailable; CodeRabbit prohibited.
  Literal security-review unavailable; independent manual fallback used. No merge,
  install or arming. User handoff is creation of dedicated **Pane Management Local
  Signing** credential via Keychain Access Certificate Assistant; no paid account,
  unrelated credential or trust changes. Signed staging/native administrator
  acceptance and positive-before/after negative fixtures remain pending.

## Local certificate authentication — 2026-10-12

The runtime identity policy now validates fixed self identity before reading its
own leaf certificate, derives Apple's exact certificate fingerprint requirement,
revalidates self with that pin and requires the reciprocal fixed peer identifier.
No Team ID, Apple anchor, certificate-name trust or ad-hoc fallback is used.

- Actual pre-fix `bed5681` archive with final daemon tests and API-only shims:
  149 assertions, **32 failures**. Shims add the new argument label delegating to
  the original Team ID function and the old fake `team()` method; original trust
  behavior is preserved. Logs and full overlay are retained in ignored
  `.build/local-auth-evidence/pre-fix*`.
- Debug build passed; daemon 149/0, client 181/0, setup 141/0 and controller 76/0.
  Separate release build, shell syntax and `git diff --check` passed.
- Cases cover both fixed roles, certificate-only success without Team metadata,
  normalized lowercase pins, malformed/empty/overlong/injection/non-ASCII pins,
  missing/ad-hoc metadata, self validation before metadata, and failed pinned
  self revalidation. The existing actual unsigned/ad-hoc executable refusal passes.
- Sibling audit: app transport, daemon preflight/listener and setup identity
  validation share this policy; root-before-native-port construction and both
  signing-requirement-before-XPC-activation paths are unchanged. The separately
  owned preview's obsolete Apple-issued copy was reported to the lead.
- Authentication failures keep existing Check again/explicit repair/removal exits;
  no new durable state or automatic certificate enrollment. Rotation needs a
  coordinated normal-sleep restore, removal and reinstall with one certificate.
- Independent read-only code/manual-security and lead reviews clear at `d6742fa`;
  clean before/after, no actionable findings. CI `38304383789` passed. Literal
  security-review tool unavailable; fresh manual fallback used. CodeRabbit
  unavailable under repository restriction; current model inherited, exact
  model/effort metadata unavailable. No merge, install or arming.
- No native certificate creation, keychain change, signing, helper execution or
  lifecycle call, root journal or power write. Synthetic checks establish policy
  ordering, not native local certificate/service acceptance. Existing build 5 and
  paid staging script are untouched; local packaging/probe is a separate slice.
## W-R1 native sizing correction — 2026-10-12

Native QA rejected `5db1aba`: the warning rendered blank at 520×3483 logical
points despite measuring 329pt of content. An offscreen native reproduction
confirmed that default NSHostingView size constraints expanded the panel after
`setFrame` returned. The visible hosting view now disables automatic sizing
constraints; the separate native content measurement owns the bounded frame.

- New native geometry checks use a narrow `LayoutChecks` SPI to invoke the exact
  production layout on an offscreen panel. They never order it front or invoke
  power/setup actions. They let AppKit's run loop settle before assertions.
- Actual pre-fix behavior with access/refactor-only test shim: **84 assertions,
  four failures**. Active settled at 3483pt and recovery at 8064pt, violating
  content fit, bounds and centering. The unchanged implementation compiled.
- Fixed debug/release checks: **84 assertions, zero failures**. Active is 329pt,
  long recovery 445pt; a synthetic 320×300 usable frame clamps to 296×276,
  and returning to active shrinks to the original centered frame. This verifies
  offscreen native geometry, not physical small-display scrolling or rendering.
- Separate debug/release compilation, shell syntax for each script and diff lint
  passed. Preview packaging and strict ad-hoc signature passed. Current executable
  SHA256 `dad1ffd86cec4043e0974fd80db157d690a37531bd19abda62ba4cc675e197fe`.
  Lead CUA rendering/actions passed on this exact preview: activation/active/
  restoring rendered at 1040×658 physical pixels; recovery expanded to 1040×738.
  Full text and both actions were visible; AX exposed a normal container, with
  no scrollbar. Escape did not dismiss; Deactivate and Retry worked; Repair setup
  in Settings opened controls. Triangle, stripes and opaque backing were legible.
  Independent read-only delta and lead reviews clear at `2e4e861`; clean before/
  after, no actionable findings. CI `38304407317` passed. Preview quit normally;
  process check found only original build5 PID96007. Small-display geometry is only
  offscreen automated evidence; no live power, Spaces or global stacking claim.
- Local evidence: `.build/warning-stripes-evidence/geometry-before.log`,
  `geometry-experiment.log`, `layout-red.log`, `layout-green.log`, release logs and
  `layout-prefixed-test-shim.patch`. To reproduce red, apply that access-only patch
  to `5db1aba`, build debug and run AlwaysOnChecks. No screenshot data is published.
- Coordinated fixture-only missing-signing copy now says app/helper must use the
  same certificate, matching the separate local-signing implementation. This
  branch makes no production signing/authentication change or privileged action.

## Content-sized warning revision — 2026-10-12

W6 supersedes the fixed warning height after the user saw a scrollbar in recovery.
The warning now measures its shared content with native hosting-view fitting size
at each display's available width, uses that height and recenters. Both the 76pt
body scroller and normal outer scroller are removed. Published action/secondary
text changes also trigger measurement. Text and buttons allow vertical wrapping.
If intrinsic content exceeds the screen's usable height minus 24pt, only then a
hidden-indicator scroll container keeps overflow reachable within screen bounds.

- Separate debug/release builds passed (2.80s / 8.13s), AlwaysOnChecks 76/0,
  shell syntax for every script and diff lint passed. Preview packaging (1.97s)
  and strict ad-hoc signature verification passed. Logs retained under ignored
  `.build/warning-stripes-evidence/`; no stable app packaging or launch.
- Preview executable SHA256:
  `cc856f2c2ca132631359a75487befff836819a6504dca2342afe08fad99151e2`.
  Lead's pre-fix native recovery screenshot shows the unwanted scrollbar. Final
  native fitting/actions and independent delta review plus CI are pending.
- No new implementation-mirroring test; existing 76 behavior assertions and
  native before/after verification cover this presentation change. No new state
  or recovery route. Small-screen/oversized fallback is source-reviewed but has
  not been physically exercised; no fixture API was added merely to simulate it.
- Initial striped candidate `79f4fe6` cleared independent/lead review and CI
  `38303341482`. Native active/activating/restoring/recovery/removal-pending,
  Deactivate and Escape behavior was checked by lead before this sizing revision.
- Security review not applicable to presentation-only changes; CodeRabbit
  prohibited. No merge/install/arming. Local signing now authorized separately;
  this revision makes no auth, Keychain, helper, power or controller changes.

## Warning stripes candidate — 2026-10-12

The shared warning adds native 45-degree black/yellow bands at 10% opacity,
with opaque backing behind text and controls. Window dimensions, scrolling,
red triangle, action labels/routing and controller recovery states are unchanged.
The pattern is accessibility-hidden and ignores pointer events. No new state,
permission, signing or privileged operation is introduced.

- Separate `swift build -c debug` and `swift build -c release` passed (49.22s and
  51.16s). `.build/debug/AlwaysOnChecks`: 76 assertions, zero failures.
- `bash -n scripts/*.sh`, individual `bash -n` on every script and
  `git diff --check` passed. Preview packaging passed; strict ad-hoc preview
  signature verification passed. Stable app packaging was not run locally.
- Native inert preview: `dist/Always-on Preview.app`, executable SHA256
  `6d310dc4c060944055d09736ee8248a47a7af1596b5f9f40051aed9b4454dff3`.
  Lead captured the baseline active warning before this change; final native
  active/pending/retry rendering and action checks are pending at this candidate.
  Small-screen, cross-Space/fullscreen and physical behavior remain unverified.
- No new automated test mirrors the decorative implementation; existing behavior
  regressions plus real native rendering are the gates. Logs retained locally in
  ignored `.build/warning-stripes-evidence/`. Screenshots are not published.
- Sibling audit: every warning state uses this same view; Dock/menu/Settings
  behavior is untouched. Existing visible recovery exits remain Deactivate,
  Retry deactivation, Check again, explicit Settings or waiting for settlement.
- Current model inherited, exact model/effort metadata unavailable. Independent
  and lead final review plus remote CI remain pending. Security review is not
  applicable to this purely decorative slice; CodeRabbit remains prohibited.
- User rejected paid signing. Local certificate feasibility is a separate open
  investigation, not implemented or proven here. Existing app stays unchanged;
  no helper registration, Keychain, journal, power, installation or arming action.

## B3c isolated signed staging candidate — 2026-10-12

Code pin `3ced0980ceb21773b95d87a29508da03f9b61f3b` adds only the signed staging
workflow, synthetic checks, CI syntax/check steps and documentation. Existing
stable-path packaging is unchanged. Current inherited model used; exact model
and effort metadata are unavailable. Fresh independent read-only code/manual-
security and lead reviews cleared final candidate `048e6c174e27ebdf5383459baf334ee7f4846112`
with no actionable findings and a clean worktree before/after review. CI
[38300113172](https://github.com/ccmenshealth/pane-management/actions/runs/38300113172)
passed on that pin. The literal security-review tool was unavailable; the fresh
read-only manual review was the fallback. CodeRabbit is prohibited. Subsequent
handoff changes are Markdown only, checked with `git diff --check` and remote
workflow inspection under the repository's bookkeeping exception.

- `python3 scripts/test_signed_staging.py`: 17 tests pass. These use fully
  injected command results and disposable directories; a subprocess guard
  prevents accidental native fallback. Failure at each of 31 command positions
  cleans partial output and permits a subsequent successful synthetic run.
- Exact final runnable inert overlay: 17 tests / 35 assertion failures. Targeted
  pre-fix overlay: four tests / three assertion failures plus the reproduced
  non-object notarization exception. Fixed tool mapping, argument abbreviation,
  notary object validation and operation-specific diagnostics are covered.
- Evidence and reproducer: ignored `.build/b3c-evidence/overlays.py`,
  `final-inert-red/`, `targeted-red/`, corresponding `.log` files, and
  `final-green.log`. Run the reproducer from the repository root; it copies the
  exact final tests into isolated overlay directories and never alters source.
- Separate Python compile, Bash syntax, plist lint and `git diff --check` pass.
  Separate Swift debug/release builds pass. All eight debug suites pass:
  SnapCore 60, AlwaysOn 76, Engine 176, Native 114, Service 355, Daemon 118,
  Client 181 and Setup 141; no failures. Individual gate logs are retained there.
- Actual read-only `--preflight` passed on clean code pin 3ced098 and final
  reviewed candidate 048e6c1. It validated
  fixed app/helper metadata, source and tool availability without identity lookup,
  artifact creation, signing or Apple submission (`native-preflight.log`).

| Failure / state | Exit and evidence |
| --- | --- |
| Missing/invalid arguments or identity, dirty source, metadata drift | Stop before build; correct the named prerequisite and retry. Negative fixtures verify no build. |
| Signature/team/runtime/timestamp/entitlement rejection | No publication; repair signing configuration and retry. Each metadata refusal and command failure is injected. |
| Notary rejection or malformed result; staple/assessment failure | No publication; inspect that named operation and retry. Only Accepted with canonical UUID proceeds. |
| Existing destination or publication race | Preserve the existing directory; rerun for a new UUID candidate. Collision/race fixtures verify preservation. |
| Command or publication filesystem failure | Remove owned partial output/destination; subsequent synthetic attempt succeeds. |
| Forced process death | A private `.partial-*` can remain; it is never a published candidate. An Apple submission may continue remotely; check its status before resubmitting. No kill/power drill was run. |
| Published candidate | App, post-stapling ZIP and manifest exist only after all gates. This does not install or arm the helper. |

Sibling audit covers both helper/app signatures before and after stapling,
normal and raced publication, command and filesystem cleanup, and all malformed
argument/notary forks. Security-sensitive inputs use argument arrays, fixed tool
paths and explicit identity/team; no credentials or profile are written to the
manifest or failure diagnostics. Native positive signing/timestamp/notary/staple/
Gatekeeper operations were **not run**: no suitable Apple Developer identity is
available. Their synthetic control flow is not proof of positive native acceptance.
No stable-path local package, install, service operation, power write, production
journal or grant change occurred. Original build 5 remains running at PID 96007.

## Native daemon boundary candidate (2026-10-12)

## B3a authenticated client candidate — 2026-10-12

New `AlwaysOnIPC` owns only fixed wire types, canonical codecs, signing and XPC
protocol. Daemon audit/telemetry/listener/native power ports remain separate;
existing daemon/service callers retain source compatibility via re-exports.
`AlwaysOnClient` uses an injected transport and monotonic scheduler. Its native
adapter validates the calling binary before constructing a privileged NSXPC
connection, then installs the reciprocal requirement before activation.

Behavioral evidence (unprivileged injected fixtures): initial compiling scaffold
6 assertions / 6 failures; final suite 155 / 0; exact final inert observation and
unchecked-decoder overlay 155 / 73 failures. A targeted compiling pre-fix overlay
produced five failures for the total readiness deadline, timed-out unregister
retaining its lifecycle slot, queued mutation exclusion, late unregister success,
and a queued activation erasing a later stop. Logs retained locally under
`.build/b3a-evidence/{initial-red,final-inert-red,targeted-red,final-green}.log`.
The inert overlay leaves the transport harness alive so final race tests settle;
it suppresses authoritative observations and reply validation, not compilation.

The fixture covers canonical size/shape/UUID/permit checks, operation authority,
rejected cached off, actual negative self-signing, status-only readiness, deadline
callbacks before timer delivery, duplicate/stale completion, orphan restoration,
late activation stop, token heartbeat, both injected loss routes from off/active,
malformed status/activation/heartbeat/deactivation, bounded recovery failure/retry,
and permit mismatch/incarnation/rejection/loss/unregister failure/fresh reprepare.
Both native loss handlers share a synchronous lock fence in source; positive
signed IPC and real native callback delivery remain unverified without identity.

| State | B3b operator action / covered recovery |
| --- | --- |
| Initial unknown / configured helper unavailable | Retry deactivation or repair setup; one bounded reconnect attempt |
| Confirmed off | Explicit activation or setup/removal; loss immediately becomes unknown |
| Activation pending | Deactivate latches before and during queued work; late success restores |
| Active | Deactivate; heartbeat/loss/non-active reply drops memory authority and restores |
| Restore failed | Persistent unknown; a human retry starts a fresh bounded attempt |
| Removal preparing / final recheck fails | Retry removal; no unregister without the same live permit |
| OS unregister pending beyond five seconds | Show pending and block setup/mutations; retain lane until actual completion |
| OS unregister completes | Late success reconciles off; error permits fresh prepare/retry |

A stuck OS unregister cannot be safely cancelled or treated as complete. The
five-second timer reports uncertainty, but the in-process lifecycle slot stays
occupied; B3b must preserve this guard for registration too. Its completion must
be marshalled onto MainActor. Expected connection loss during unregister does not
replace the operation's actual completion result. No persistent session tokens,
caller-selected commands/identity/timeouts, logs of tokens or privileged fallback.

All prior checks passed: SnapCore 60, controller 34, engine 176, native IO 114,
coordinator 347, daemon 118. Separate debug/release builds, release client 155/0,
and script/plist/diff lint passed; Swift compilation is the typecheck gate (no
standalone Swift linter). New client checks added to CI. No UI change or native
render claim. Security review applies to authentication/tokens/IPC; the literal
tool is unavailable, so a fresh read-only manual review remains required.
CodeRabbit is prohibited. Installed build 5, app path and privacy grants remain
unchanged; no root helper, journal, power mutation, registration or unregister was
executed. Actual signed/installed/physical acceptance remains blocked/pending.


B2b2 adds `PaneAlwaysOn`, the fixed SMAppService daemon plist, reciprocal signing
requirement support and server enforcement, kernel UID/audit-session policy,
bounded six-operation ingress, native cached telemetry, and nested helper signing.
The main app still uses its prior unavailable backend; B3 owns integration.

The initial compiling policy scaffold produced **41 assertions / 37 failures**.
The exact final inert boundary overlay produced **118 / 86 failures**; the
implemented boundary produced **118 / 0** after the session-collection repair.
Ignored local evidence includes `.build/evidence/daemon-initial-red.txt`,
`daemon-final-red.txt`, `run-final-inert.py`, `inert-*.swift`, `daemon-green.txt`,
`daemon-gauntlet.txt`, `daemon-final-gauntlet.txt`, `daemon-session-stall-red.txt`
and `session-probe.txt`. The overlay runner restores source
in a `finally` block. These are behavior failures, not compiler failure evidence.

Lead finding **N-R1**: a battery/thermal read that never returned also blocked
console validation in the original shared collector. After five seconds, the
coordinator could no longer admit authenticated status/recovery. The targeted
pre-fix run compiled **118 assertions / 6 failures**, three each for battery and
thermal stalls. Separate coalesced power and session queues now leave console
authentication fresh and allow status/retry while unknown power telemetry still
refuses activation. The unchanged watchdog remains independent. Both sibling
power read paths and untracking/coalescing are covered.

Local full gauntlet passed SnapCore 60/0, controller 34/0, engine 176/0, native IO
114/0, coordinator 347/0, daemon 105/0 before N-R1, separate debug/release builds,
script/plist lint and whitespace check. After N-R1, daemon 118/0 and separate
final debug/release/script/plist/diff checks pass; unchanged earlier suites were
not repeated. No Swift linter is configured. Current inherited model was used;
exact builder model/effort metadata is unavailable.

Read-only native probes: public libbsm audit lookup succeeds; the current process
matches the console UID/audit session and required authenticated/graphic/console,
non-remote flags. The battery enumeration/type validation returns normal. No
personal identifiers are retained. The check executable's actual ad-hoc identity
fails the Apple-issued self-validation path as intended. Fake identity ports test
ordering and policy only; positive reciprocal signed IPC remains unverified.

| Failure/state | Exit exposed to B3 | Evidence/limit |
| --- | --- | --- |
| Root/self signing fails before startup | Setup repair; no active claim | Preflight refuses constructor; actual ad-hoc check rejected |
| New connection not collected yet | Checking, bounded status retry on same connection | First status rejected, later same connection observes off |
| Malformed/oversized request or concurrent request | Rejected; next valid request may retry | Canonical shape/version/size checks and production ingress slot |
| Loss before admission or while activation awaits | Warning until confirmed off; reconnect/retry restore | Both baseline/enable loss cases with real coordinator and fake power |
| Same-user reconnect or late old invalidation | Retry restore, then fresh activation | No inherited token; late old loss cannot stop new lease |
| Battery/thermal unknown, stale, Final/Critical | Automatic restore; remain off | Cached guard monitor through real coordinator; no Serious cutoff |
| Stalled power telemetry | Recovery remains possible through independent session collection | Targeted fixture described below |
| Native power/journal failure | Recovery required; Retry/Deactivate | Earlier engine/native slices; no live privileged drill here |
| Preparing/removal | Stay sealed, final readback and unregister in B3 | Coordinator suite; process absence alone does not prove removal |

The warning UI and final setup/removal controls belong to earlier/B3 slices;
this PR adds no UI and has no new render claim. The ingress tests call the actual
exported bridge in process; they do not establish signed NSXPC transport success.
OS None/Nominal may conceal internal telemetry errors. Console double-read plus
cached polling is not an atomic UID-to-ASID mapping. Native readback remains a
setting receipt, not proof of kernel event consumption or physical sleep. Kernel,
disk/executor or whole-process scheduler stalls remain outside bounded recovery.

The local main-app packaging script was not run while build 5 is active. CI must
exercise nested-helper-before-app signing and verify both. Its ad-hoc bundle is
not installable as a trusted service. The `pgrep` overwrite guard is only a current
process check; B3's sole replacement/removal flow must prepare, strictly recheck,
and unregister even if a registered crash-throttled helper has no current PID.
No helper execution/registration, production journal creation, pmset write,
permission change, installed app replacement or UI automation occurred.

# Verification record

September 14, 2026. Pane Management was originally developed as SnapBridge.

## B2b1 service coordinator — October 12, 2026

`AlwaysOnService` fronts the real pure recovery engine with version 1 requests,
opaque admitted connection keys, generation/epoch ownership, target-bound cached
guards and recovery-only preparation admission. It uses no native adapter in its
fixtures. Current inherited model used; exact model/effort metadata unavailable.

The exact final suite compiled against inert coordinator/wire scaffolds with
**347 assertions / 162 behavioral failures (exit 1)**. Implemented debug and
release suites pass **347 / 0**. Ignored evidence is retained under
`.build/evidence/`: `ServiceCoordinator.final-inert.swift`,
`ServiceValues.final-inert.swift`, `run-inert.py`, `service-final-red.txt`,
`final-gate-1.txt` through `final-gate-4.txt`.

A sibling audit exposed premature guard rebinding while restoration started by
Deactivate, status, heartbeat or monitor was suspended. Each lane crossed with
retry/prepare failed before the shared in-flight settlement fix: **327 / 8** in
`service-settle-red.txt`, with `ServiceCoordinator.before-settle.swift`. All
engine operations now settle before token-loss recovery rebinds a new caller;
critical/disconnect events remain reentrant and never cancel a writer task.

The final-removal observation must be stricter than ordinary engine startup,
which permits an absent root-domain property. The coordinator shares the exact
same injected power port as its engine, and performs a fresh dual-false read for
same-connection sealed status. Failure revokes the permit and retains preparing
admission; every completion rechecks live connection, revision and epoch. The
pre-fix absence/mismatch/error/stale-completion cases failed **347 / 8**, retained
in `service-final-observation-red.txt` and
`ServiceCoordinator.before-strict-final.swift`. No alternate adapter or power
write is introduced by this final observation. The preparation permit is a
snapshot, not exclusion of crash/restart or external mutation.

| State/boundary | Offered exit and demonstrated behavior |
| --- | --- |
| Bootstrapping/checking | Activation refused; startup resolves off or explicit conflict/recovery. External conflict resolution plus retry can reach off. |
| Pending baseline/enable/readback | Second activation refused; disconnect, retry, prepare, final battery, critical heat and console change prevent late token/active reply at each suspension. |
| Active ownership | Exact connection and token required. Reconnect uses retry; late old-key invalidation cannot stop the newer lease. Status and duplicate activation never disclose the token. |
| Restoring/recovery required | Write, read and journal failures retain recovery; retry reaches off. All four restoration entry paths retain the old guard target until the writer settles. |
| Preparing/sealed | Activation remains closed across failures and retries. Explicit re-prepare creates a new epoch; only same-key final strict off observation repeats its permit. |
| Interrupted/stale preparation | No permit after disconnect or newer epoch; reconnect can explicitly prepare again. Daemon incarnation changes on reconstruction. |
| Unknown/stale guard component | No enable; oldest required sample used, nonfinite/future times refused. Serious thermal remains allowed; heartbeat expiry restores. |

Existing suites passed **60 snapping scenarios, 34 controller, 176 engine and
114 native IO assertions**, all zero failures. Separate debug/release builds,
script syntax, source plist lint and whitespace checks passed. After the final
C7 patch, only the affected service suite and both compilation modes were rerun.
No standalone Swift linter exists; compilation supplies type checking. CI now
runs the release service suite. Independent read-only code/security review and
remote CI are pending at handoff; CodeRabbit remains prohibited by repo policy.

No new UI is added, so this slice has no new render gate. Existing native Dock,
Spaces/fullscreen, multidisplay and VoiceOver acceptance remains open. Lead's
latest inert preview Hide Controls attempt still yielded controls-window CUA
snapshots, so it did not prove cross-app/hide behavior. Preview was deactivated
and quit; lead confirmed only unchanged build 5 PID 96007 remains running.
No app packaging, signing, registration, permission or live power write occurred.
Positive signed IPC, native telemetry and physical sleep await later slices.

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


## B3b1 headless setup and read-only extraction (2026-10-12)

Builder used the inherited current model; exact metadata unavailable. Isolated
branch `codex/always-on-setup`, based on reviewed PR #8 `326cc09`. No UI change
or native GUI render belongs to this slice.

- `AlwaysOnSetupChecks`: 104 assertions, zero failures. The exact final suite
  compiled against an inert coordinator and failed 50/104 assertions
  (`.build/b3b1-evidence/setup-inert-red.log`). Restored implementation passed all 104.
- S-R1: releasing the lifecycle slot before post-registration status completed
  allowed competing removal/setup. The pre-fix overlay failed two assertions
  (`.build/b3b1-evidence/setup-regression-red.log`); retaining the slot through inspection and
  republishing on settlement fixes both.
- S-R2: an earlier signing error could erase a newer active client observation.
  The focused pre-fix fixture failed one assertion (`.build/b3b1-evidence/setup-signing-red.log`);
  current inspection owns the result and retains Deactivate. An unverified
  configured state retains both retry-deactivation and setup-repair remedies.
- Coverage includes all nine strict receipt combinations, missing/existing
  recovery directory, both bracket status failures and each changed status,
  optional unsigned state, enabled/approval/notFound setup, identity and
  registration-error matrix, no startup registration/activation/navigation,
  stale proof versus new client event, registration including post-completion
  inspection, removal preparation, real pending callback settlement, expected
  loss, removal retry, and activation's stop action.
- Real user-owned temporary filesystem fixtures cover absent child, existing
  file/directory/dangling symlink, writable or wrong-owner parent policy,
  nonempty ACL, cleared ACL, symlink parent and missing parent. The probe never
  opens or creates its fixed child. A malformed on-disk ACL was not injected; the reused policy retains
  rejection of invalid/failed enumeration.
  Generic bounded reads report a stuck worker and reject repeated work while
  its slot is held; late completion cannot publish through its consumed continuation.
- Shared extraction preserves strict CFBoolean reads, bounded power reader,
  trusted canonical parents, ACL policy and journal directory name. The native
  writer/journal retain their prior semantics. App-facing modules do not depend
  on AlwaysOnNative, AlwaysOnDaemon or audit code. Both native readers execute
  away from MainActor; no cached absence proof is accepted.
- Sibling audit: startup/refresh/setup, all four ServiceManagement statuses,
  signature errors versus new observations, register success/error, preparation/
  unregister pending/success/error, activation/stop and all read-failure forks.
  Only the sole client prepare/final-permit flow can start native unregister.
  Native register cannot release its slot before actual completion.
- No actual SMAppService register/unregister, production journal construction,
  daemon launch, power write, installed bundle replacement, permission change,
  physical lid test or signature fallback ran. Original build5 remained PID96007.
  Local packaging was not run because the installed app is running; CI validates
  clean-runner packaging. Positive signed/native acceptance is blocked by missing
  Apple-issued identity. Independent manual-security review substitutes for the
  unavailable literal security tool; it remains pending at builder handoff.
  CodeRabbit is unavailable under the explicit repository restriction.

Local final gates passed:

- `swift run --disable-sandbox --cache-path .build/cache` with SnapCoreChecks
  (60/0), AlwaysOnChecks (34/0), AlwaysOnEngineChecks (176/0), AlwaysOnNativeChecks
  (114/0), AlwaysOnServiceChecks (347/0), AlwaysOnDaemonChecks (118/0),
  AlwaysOnClientChecks (155/0), and AlwaysOnSetupChecks (104/0).
- Separate `swift build --disable-sandbox --cache-path .build/cache` and
  `swift build -c release --disable-sandbox --cache-path .build/cache` passed.
  Release AlwaysOnNativeChecks (114/0) and AlwaysOnSetupChecks (104/0) passed.
- `bash -n` for all three scripts, `plutil -lint` for all four Resources plists,
  and `git diff --check` passed. No standalone Swift linter is configured;
  debug/release compilation typechecks. Final builds emitted no warnings.
- Product plus test/extracted source is about 640 lines; within the cohesive
  slice guideline. GitHub CI and pinned independent/lead review are next gates.


### B3b1 candidate correction before final review

- S-R3: waking/rechecking previously left an old quiet off/unavailable snapshot
  visible until a fresh proof finished. A held-proof pre-fix fixture failed once
  (`.build/b3b1-evidence/setup-wake-red.log`). Revalidation now immediately revokes that snapshot;
  an active warning retains Deactivate, and a newer stop defeats old revalidation.
  Expanded setup suite passes 111/0 debug/release; exact final inert overlay fails
  56/111. Separate debug/release builds passed again for this delta.
- First remote run `38294630489` failed the unchanged AlwaysOnChecks assertion
  “still active readback cannot claim off.” One hundred unchanged local release
  repetitions passed. CI's failure is real red evidence; its local cause was not
  reproduced or proven. The fixture visibly used a fixed 30 Task.yield calls as
  a completion assumption. All sibling fixture paths now wait for bounded actual
  terminal state or held-continuation readiness, preserving existing assertions
  and adding diagnostic timeouts. Debug/release both pass 34/0; the next remote
  run must validate this test-only correction. No production controller change.


### S-R4: removal-required admission survives reconnect

A failed unregister leaves the daemon preparing/sealed while its engine can be
verified off. The old reply omitted that admission distinction; status, retry and
a fresh client misleadingly returned usable off. Added required canonical Boolean
`requiresRemoval` to the paired pre-release v1 schema. Missing/wrong-type values
fail decoding; prepared/permit replies require true and activated replies forbid
it. Rejected replies cannot establish safe off. The service derives the flag
from actual admission state on every reply, never from caller metadata.

Client status, retry, owned stop, heartbeat recovery and reconnect propagate
verified flagged off to `removalRequired`; activation refuses before sending.
Final removal deliberately uses verifiedOff plus the flag/permit, not usableOff.
Setup exposes quiet/quit-safe `removalRequired` only when settled, with a fixed
Finish helper removal remedy for future Settings wiring. Uncertain/pending
operations still require the warning. A fresh daemon incarnation may reopen
following startup recovery; there is no new persistent marker or privileged IO.

- Real in-process ServiceCoordinator → canonical codec → AlwaysOnClient →
  SetupCoordinator loop reproduced five pre-fix failures after failed unregister.
  It now covers same/new client rediscovery, retry, activation refusal, quiet
  finish-removal, valid final permit/unregister and new-daemon reopening.
- Expanded exact pre-fix behavioral overlay compiled: ServiceChecks 355/7 failures,
  ClientChecks 166/5, SetupChecks 122/5. Logs are
  `.build/b3b1-evidence/setup-sr4-red-AlwaysOn{Service,Client,Setup}Checks.log`.
- Final inert setup overlay compiled with 122 assertions/59 failures. Corrected
  setup: 122/0; service: 355/0; client: 166/0. Prior evidence counts above describe
  earlier candidate stages, not final coverage.
- Sibling audit includes every client off publication, both off predicates,
  service status/retry/prepare/final read/disconnect, prepared/activated/permit
  codec combinations and rejected metadata. Updated synthetic permit fixtures
  now mirror the real daemon's flag; real loopback guards against drift.
- Final source/test additions are 828 lines versus reviewed base, including the
  78-line loopback; the modest 28-line overage preserves one cohesive recoverability
  correction. Fresh independent code/manual-security plus lead review and CI
  remain required for the new pin. No install, helper/power mutation or UI render.

- Initial expanded local matrix encountered a stale incremental DaemonChecks
  object referencing the old ServiceReply initializer after the schema changed.
  The captured linker failure is `.build/b3b1-evidence/setup-incremental-link-failure.log`.
  A worktree-local `swift package clean` removed compiler outputs only; all red
  evidence under `.build/b3b1-evidence/setup-*.log` was preserved. The full clean matrix is the
  required final gate; no compatibility shim or source workaround was added.

- Durable local handoff evidence is retained in ignored `.build/b3b1-evidence/`:
  red/green summaries, actual compiler/assertion logs, the inert source, the three
  pre-removal behavior sources and `reproduce.py` overlay recipe. This directory
  is not a tracked artifact and must be preserved when cleaning compiler outputs.


Final clean local gates after S-R3/S-R4 and the fixture correction passed:
SnapCoreChecks60/0, AlwaysOnChecks34/0, Engine176/0, Native114/0,
Service355/0, Daemon118/0, Client166/0, Setup122/0. Separate clean debug and
release builds passed, followed by release UI/Native/Service/Daemon/Client/Setup
suites with those same counts. Shell/plist/diff lint passed; no final compiler
warnings. Exact commands remain the named S9 matrix. Evidence summaries and logs
are in `.build/b3b1-evidence/final-green-summary.txt` and sibling files. Remote CI
and pinned independent/lead/security review remain open at this builder handoff.


## B3b2 app integration candidate (2026-10-12)

The native client/setup adapter now drives the shared controller, menu/Dock,
warning and Settings. This candidate does not replace or run the installed app.
Builder inherited the requested current model; exact model/effort metadata is
not exposed. Independent code/manual-security and lead review remain required.
CodeRabbit is prohibited by repository policy. Literal security tool unavailable;
a separate read-only manual-security pass is required.

### Automated evidence

Evidence is retained locally, ignored by Git, in `.build/b3b2-evidence/`:

- `run-red.py` records overlays, exact build/run commands and guaranteed source
  restoration. `controller-inert.swift` preserves the final public interface with
  inert behavior: the exact final controller suite compiles and fails **64/76**.
- `activity-prefix.swift` is the actual pre-U9 client source, with only an ignored
  activity parameter added for source compatibility: final client suite **10/181
  failures**. No native activity is held by tests; all client constructions,
  including real service/client loopbacks, inject an inert port.
- `repair-prefix.swift` omits the new Settings repair route behind a compile-only
  method shim: final setup suite **1/141 failures**. It covers uncertain startup
  with a retained recovery directory, no automatic registration, explicit repair
  registering once, client status recovering to off and no activation.
- `coalescing-final-prefix.swift` reproduces the actual initial dirty-flag bug:
  final controller suite **1/76 failures**. Requests before the first Task began
  were discarded. Consuming the dirty flag only after the first refresh preserves
  one follow-up. Original 58-assertion red output is also retained.
- Separate `swift build -c debug` and `swift build -c release` passed. All debug
  suites passed: SnapCore 60, controller 76, engine 176, native IO 114, service 355,
  daemon 118, client 181, setup 141. Affected release suites passed 76/181/141.
- `bash -n scripts/build-app.sh scripts/build-fixture.sh
  scripts/build-always-on-preview.sh`, `plutil -lint Resources/*.plist` and
  `git diff --check` passed. Stable-path app packaging was not run locally.
- Inert preview packaging, deep/strict ad-hoc verification and plist validation
  passed. Candidate preview executable SHA256:
  `dbe68fadc8254cc3089b6b70f686d6c63521dcbc0192beaee9f3fd4c9a0f00f1`.
  Remote CI remains pending at this bookmark; native evidence follows below.

### Recoverability and sibling audit

| State | Offered exit and settlement |
|---|---|
| Fresh off | Explicit Activate; quit safe only while current proof remains fresh |
| Active / activation pending | Deactivate remains usable; stop/quit latch survives late activation; owned refresh preserves token |
| Stopping / actual OS work pending | Wait; retain warning and block quit until actual settlement, never a timeout acknowledgment |
| Unknown / failed restoration | Retry deactivation, explicit Settings repair and Check again; uncertainty keeps warning |
| Fresh unregistered / missing signing | Set up only with valid identity; otherwise signing explanation and Check again; verified absence permits quit |
| Approval / missing bundle | Explicit Settings approval or installation repair then Check again; refresh never navigates/registers |
| Removal failed | Retry deactivation and Settings removal; fresh daemon status exposes sealed removalRequired across reconnect |
| removalRequired | Quiet verified off; Finish helper removal opens Settings; sole actual Remove button is there, no Activate |
| Removed | Quiet in-process; wake/relaunch reruns absence proof and retained journal routes to explicit repair |

All surfaces use the same controller action and title; warning invokes that action
rather than hardcoded Deactivate. Repair and removal are Settings-only methods;
menu/warning navigation merely opens Settings. Settings pins compact actions below
its scrolling description. Native window renders and clicks establish footer
legibility and action routing, not whole-desktop occlusion or stacking.

The scheduling activity has independent idempotent operation holds acquired before
lane suspension, plus an owned-token hold. Loss, orphan recovery, queued stop,
heartbeat and actual unregister settlement preserve continuity; settled no-token
failures and client disposal release their own holds. The sole production option
is userInitiatedAllowingIdleSystemSleep; tests verify no system/display sleep or
latencyCritical flag. This does not prove OS scheduling or physical lid behavior.

No helper registration/unregistration/execution, native power mutation, root
journal, signing enrollment, privacy grant or installed app change occurred.
Original build5 remains PID96007. Apple-issued signing, signed installation/IPC,
critical-event/lid drills, installed Dock and unobserved cross-Space/fullscreen,
multi-display and VoiceOver checks remain unresolved. The 320x300 warning minimum
does not establish full Settings footer reachability on constrained displays.

B3b2 native preview progress (lead CUA inspection): active warning measured
520x390, Escape did not dismiss it, and Deactivate → pending → off passed.
Setup available and missing signing remained quiet. Approval, unknown recovery
and missing-installation warnings rendered; approval's Settings route and explicit
inert Login Items action passed, as did unknown → Settings repair → approval.
The fixed footer actions were legible and exercised on the current laptop render. The first fixture process was terminated with
SIGTERM after CUA window navigation stalled; this is fixture cleanup, not evidence
of a successful protected quit. Preview-only Show Preview Controls (Command–1)
was then added and its debug/release packaging verified. Production is unchanged.

Lead subsequently observed all eleven fixture states in native window-only CUA
renders. Active and activation-pending, approval, installation repair, unknown,
removal-pending and removal-failed warnings had correct primary enabled/disabled
state. Setup-available, missing-signing and removalRequired stayed quiet, with no
fake Activate. Failed-removal Settings link → actual inert Remove → off passed;
normal Quit from off was confirmed by process absence. A post-quit CUA AX query
can relaunch the fixture, so the final check used process status without another
AX query. The installed build5 PID96007 remained the sole app process afterward.
Screenshots were rendered inline in the lead's CUA tool outputs, not published.

Two copy corrections followed inspection: checking now says to keep the app open,
and a pending recovery with disabled action says to wait instead of retrying an
unavailable Deactivate action. Both use the shared description; separate debug/
release builds and controller checks were rerun. This does not claim whole-desktop
stacking/occlusion, cross-Spaces/fullscreen, multi-display, VoiceOver, installed
Dock acceptance or physical behavior; those gates remain open.
