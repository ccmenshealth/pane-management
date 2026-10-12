# Pane Management — Current State

## Bookmark — content-sized warning revision (2026-10-12)

- User requested no scroll bar and a warning that fits its content. W6 supersedes
  fixed warning geometry in W2: intrinsic content sizing, centered within usable
  screen bounds; hidden-indicator scrolling only for content too large to fit.
- Prior stripe candidate `79f4fe6` cleared independent/lead review; lead native QA
  observed active/pending/recovery actions and the unwanted recovery scrollbar.
  Preview is stopped. Builder owns this UI-only revision, same isolated PR #12.
- Local signing is now user-authorized as a separate slice; this builder does not
  change certificates, authentication, installation, power or controller behavior.
- W6 uses native content fitting size, includes action/secondary updates, and limits
  hidden-indicator scrolling to screen overflow. Debug/release, 76 UI assertions,
  shell/diff lint and inert preview packaging pass. Next: native QA, independent
  delta review and CI. No merge or arming.

## Bookmark — warning stripes cosmetic slice (2026-10-12)

- User requested faint diagonal black/yellow warning stripes. Isolated branch
  `codex/warning-stripes` starts from reviewed stacked base `bed5681` intentionally;
  primary main and running build 5 stay unchanged. W1–W5 below lock this slice.
- Preserve window geometry, recovery actions and controller behavior. Only native
  decorative rendering changes; no new state or privileged operation.
- User rejected paid membership. Dedicated local signing is a separate unproven
  option to investigate, not part of this cosmetic slice; no certificate, Keychain,
  helper, installation or power changes are authorized here. No merge or arming.
- Current model inherited; exact runtime model/effort metadata is unavailable.
  Debug/release builds, 76 UI assertions, shell/diff lint and inert preview packaging
  passed. Next: native render/actions and independent/lead review plus CI. CodeRabbit prohibited; security review not applicable to cosmetics.

## Bookmark — feasible build complete; signing/native acceptance blocked (2026-10-12)

- Draft PRs #2–#11 contain the Dock, warning, power recovery, authenticated
  helper/client, setup integration and signed staging implementation. All remain
  unmerged and uninstalled. No feature was armed.
- Final PR #11 reviewed pin: `048e6c174e27ebdf5383459baf334ee7f4846112`;
  product pin: `3ced0980ceb21773b95d87a29508da03f9b61f3b`. Fresh independent
  read-only code/manual-security and lead reviews clear, no actionable findings;
  reviewed worktree clean before/after. CI `38300113172` passed. Current model
  inherited; exact model/effort metadata unavailable. CodeRabbit prohibited.
- All feasible build, automated verification and inert native preview work is
  complete. Final changes after the reviewed pin are handoff Markdown only.
  Positive native signing, installation, Dock/global warning behavior and
  physical lid/recovery acceptance remain unverified; synthetic tests do not
  establish those results or guarantee critical battery/thermal protection.
- User has no Apple Developer account. Chosen helper design needs a Developer ID
  Application certificate and an existing notarization profile before a signed
  candidate can be produced. No enrollment, purchase, unrelated certificate or
  alternate privileged fallback is authorized. Next: resolve that prerequisite,
  then separately authorize signed staging, installation/approval and native
  acceptance/recovery drills; first activation remains a separate gated slice.
- Final read-only preservation check: primary `main` clean at `3ce28b8`, original
  build 5 still PID `96007`, executable SHA256
  `3367ecbfc6d95a54bde086348d4c67988c8be8089042ba30a4c853f6634e978a`.
  No preview/helper process or root helper journal exists. Installed bundle,
  privacy grants and power configuration were not changed by these build slices.

## Bookmark — B3c signed staging candidate (2026-10-12)

- Code pin 3ced098 adds isolated Developer ID staging with explicit identity/team/
  existing notary profile, exact signature requirements, notarization/stapling,
  assessment and post-stapling hashes. Existing stable packager stays unchanged.
- Seventeen synthetic checks pass; exact final inert overlay yields 35 assertion
  failures, and four focused pre-fix checks reproduce lead findings. Debug/release
  builds, full debug matrix 60/76/176/114/355/118/181/141 and lint pass.
- Actual read-only preflight passed on the clean code pin; no signed artifact or
  Apple submission was attempted. Missing Developer ID remains the positive-run
  blocker. Native acceptance and first arming stay separately gated.
- Current inherited model; exact metadata unavailable. Next: draft PR above
  integration PR #10, remote CI and fresh independent/manual-security plus lead
  review. All PRs remain unmerged. CodeRabbit prohibited.
- Original build 5 remains PID 96007, unchanged. No install/helper/power/journal/
  privacy change, no local stable packaging and no preview launch occurred.

## Bookmark — B3c signed staging planning (2026-10-12)

- codex/always-on-staging starts from integration PR10 head495f663. Independent
  read-only code/manual-security and lead review clear, worktree clean, CI38298900984
  green. Native inert11-state rendering/actions verified; global/native physical
  acceptance remains open. Final preview quit; only original build5PID96007 runs.
- V1–V8 lock isolated signed staging and synthetic validation. No Developer ID
  exists; builder completes code/tests/preflight, never actual signing/submission.
- This is final feasible build slice before signing/native acceptance handoff.
  AllPRs remain draft/unmerged; no installed bundle/helper/power/journal/grant change.
- Current model inherited; CodeRabbit prohibited. Next: isolated staging builder,
  fresh independent/manual-security plus lead review and CI, then concrete handoff.

## Bookmark — B3b2 integration candidate (2026-10-12)

- Isolated codex/always-on-integration wires authenticated setup/client state into
  the shared UI. Placeholder backend is removed. Wake/focus coalesces, preserves
  owned active sessions and never autoactivates; quit waits for actual settlement.
- Settings-only explicit repair closes the retained-journal/missing-registration
  exit. Helper actions use a compact pinned footer; inert preview models it.
  Client App Nap activity permits system/display sleep and balances independent
  operation/token holds. Tests inject inert activity ports throughout.
- Debug suites60/76/176/114/355/118/181/141 and affected release76/181/141 pass;
  separate debug/release builds and lint pass. Inert/pre-fix failures64/76,
  10/181,1/141 and coalescing1/76 are retained in `.build/b3b2-evidence`.
- Lead observed all11 native inert fixture states, fixed footer action routing,
  activation/deactivation and normal quit fromoff. Window-only renders do not
  establish globalstacking/occlusion or other native acceptance. Final CI and
  fresh independent code/manual-security plus lead review pending. No CodeRabbit. Current model inherited;
  exact model/effort metadata unavailable. Scope modestly exceeds800changedlines
  for coupled controller replacement, U9 scheduling and required recovery exit.
- Build5 remains running unchanged at PID96007. No helper/power/journal/grant or
  installed-bundle changes. Missing Apple Developer identity blocks signed native
  acceptance/install; native/physical acceptance and first arming remain separate.
- Next: pin/push draft PR above setup PR9,
  independent review plus lead/CI gates, then B3c signed staging. No merge/arming.

## Bookmark — B3b2 integration planning (2026-10-12)

- Isolated codex/always-on-integration fast-forwarded to reviewed setup PR #9
  head83598e7. Independent delta plus lead code/manual-security clear; final
  CI38296296320 green, reviewed worktree clean. S-R3/S-R4 resolved.
- U1–U8 lock app/controller/menu/Dock/warning/Settings integration and inert
  native preview. Next builder starts here; B3c signed staging follows.
- Original build5 remains unchanged/running. No actual service/power/journal or
  installed bundle changes. Missing Apple Developer account blocks positive
  signed install; native acceptance and first arming remain separate gates.
- No merge yet. Current inherited model; CodeRabbit prohibited.

## Bookmark — B3b1 setup candidate (2026-10-12)

- `codex/always-on-setup` adds read-only native policy extraction and headless
  setup/removal coordination. App/controller/UI wiring remains B3b2; signed
  staging remains B3c. Installed build5 is unchanged at PID 96007.
- Exact compiling inert coordinator overlay: 122 assertions/59 failures;
  implemented suite: 122/0. Targeted pre-fix regressions: two failures for early
  registration-slot release during status settlement; one failure for an old
  signing diagnostic erasing a newer active observation; one for stale quiet
  state during wake revalidation. See VERIFICATION.md.
- Current inherited model used, exact metadata unavailable. Fresh independent
  code/manual-security and lead review remain required, as does remote CI.
  CodeRabbit is prohibited. No service registration/removal, native writer,
  production journal, installed bundle, grant or power mutation occurred.
- S-R4 now exposes daemon admission closure with a required wire Boolean and
  explicit removalRequired state. After failed unregister, a new app/client
  discovers verified off with activation unavailable and a Finish helper removal
  remedy; it does not enter a futile Activate loop. Real coordinator/client
  loopback and targeted pre-fix overlays cover this across reconnect.
- First CI38294630489 failed an unchanged finite-yield UI fixture. The exact
  local cause was not reproduced in 100 runs. Fixture siblings now await bounded
  state/continuation completion; the next CI run must validate the correction.
- Setup observations have increasing revision, fixed remedy and pending flag.
  Ordinary activation can be pending while its remedy stays Deactivate; OS
  setup/removal always offers Wait. UI must use the remedy to keep stop usable.
  Successful removal is quiet only in-process; wake/relaunch repeats the proof
  and an intentionally retained root directory yields conservative repair.

## Bookmark — B3b1 setup planning (2026-10-12)

- `codex/always-on-setup` starts from PR #8 `326cc09ca9a35762cf8ab1a446656a1d11fe0141`.
  Fresh read-only independent code/manual-security and lead source reviews clear;
  K-R1 readiness, K-R2 unregister settlement and K-R3 queued stop fixed. CI
  `38293214921` passed. Reviewed worktree remained clean at the pinned head;
  current inherited model, exact metadata unavailable.
- S1–S9 lock headless setup/absence proof and read-only native extraction. B3b2
  follows with controller/menu/warning/Settings/app integration; B3c handles
  signed staging. Builder may implement B3b1 only. No real service or power mutation.
- Original build5 remains running, unchanged. Positive signed IPC/install is
  blocked by missing Apple Developer identity; native UI/physical acceptance and
  first arming remain separate. No merges yet; CodeRabbit prohibited.

## Bookmark — B3a client candidate (2026-10-12)

- Isolated `codex/always-on-client` extracts shared IPC/signing and adds an
  authenticated, serialized app client; app/setup wiring remains B3b. No helper
  was run, registered or removed and installed build 5 remains PID 96007.
- Client checks: 155/0. Initial compiling scaffold 6/6 failures; exact final
  inert observation/decoder overlay 155/73 failures. Targeted pre-fix overlay
  reproduced five failures for readiness budget, pending unregister settlement
  and queued activation losing a later stop. Corrected behavior is documented
  in `VERIFICATION.md`; bounded reporting never claims unregister settlement.
- Current inherited model used; exact metadata unavailable. Local regression
  suites, separate debug/release compilation, release client checks and lint passed.
  CI and fresh independent/security plus lead review remain required. No CodeRabbit by repo restriction.
- `ClientObservation.removalPending` stays true until the actual OS unregister
  completion. B3b must block registration while true and marshal OS callbacks
  to MainActor. Missing signing still blocks positive signed/native acceptance.

## Bookmark — B3a client planning (2026-10-12)

- Isolated `codex/always-on-client` starts from daemon PR #7 head
  `dbee2a891c8d0d597f20a72d31467b0d7dd77860`. Fresh independent read-only
  code/manual-security and lead source review clear, no actionable finding.
  CI `38291211680` passed, including nested helper packaging. Daemon worktree
  remained clean at the pinned head; current inherited model, metadata unavailable.
- K1–K8 lock shared IPC/signing extraction and bounded client. Next B3b supplies
  setup/repair/absence proof and app wiring; B3c signed staging workflow. No install,
  registration or arming. Positive signed acceptance is blocked by the user's
  lack of Apple Developer identity; no unrelated identity or fallback authorized.
- Build5 remains running unchanged. Native UI/physical acceptance stays open;
  all PRs remain draft until those gates are resolved. CodeRabbit prohibited.

## Bookmark — Native daemon candidate (2026-10-12)

- `codex/always-on-daemon` adds the fixed signed XPC/launchd boundary, cached native
  telemetry and nested helper packaging, stacked on coordinator PR #6. App-side
  registration/client/setup/removal remains B3; no helper was run or registered.
- The native audit probe confirms this host's current process has matching console
  and audit identity plus required local/graphic/authenticated flags. Battery probe
  reports normal. These read-only probes do not prove signed IPC or physical sleep.
- Initial compiled policy scaffold failed 37/41 assertions. Final exact inert
  boundary overlay failed 86/118; implementation passes 118/0. Lead finding N-R1
  produced six pre-fix failures across stalled battery/thermal recovery. Console
  validation now has its own single-flight queue. Evidence is in `VERIFICATION.md`.
- Next: pinned independent code/manual-security review and CI, then B3 after lead
  acceptance. Missing Apple Developer identity blocks positive signed acceptance
  and installation, not remaining code. No enrollment/purchase or fallback.
- Build 5 remains at the original path as PID 96007, without permissions or power
  changes. CodeRabbit remains unavailable under the repository exclusion.

## Bookmark — Native daemon planning (2026-10-12)

- `codex/always-on-daemon` is an isolated planning branch on coordinator PR #6
  head `7164b2e`. Independent and lead code/manual-security reviews clear with
  no remaining finding; CI `38288409516` passed. Native boundary builder may
  start. Locked N1–N8 are in `always-on-build.md`.
- Next: native authentication/telemetry/daemon boundary, then B3 app client/setup/
  removal integration. No live helper registration, power mutation or arming.
  User confirmed no Apple Developer account. Apple-issued signing remains a
  concrete blocker for positive signed acceptance/install in the chosen design;
  finish feasible implementation/tests first. No enrollment/purchase authorized.
- Lead repeated isolated UI hide check: CUA kept returning the controls window,
  so hide/other-app stacking remain unverified. Preview was deactivated/quit;
  process check confirms only original build5 PID96007. No installed change.

## Bookmark — Coordinator candidate (2026-10-12)

- `codex/always-on-coordinator` implements pure `AlwaysOnService` coordinator and
  version 1 wire values, stacked on native IO PR #5. No daemon, authentication,
  telemetry, app wiring, installation or power mutation is added in this slice.
- Final in-memory suite: 347 assertions / 0 failures. Exact compiled inert
  coordinator/wire overlay: 347 / 162 failures. Two targeted pre-fix runs each
  expose eight failures; recovery states and evidence are in `VERIFICATION.md`.
- All prior suites and local gauntlet passed. Final affected service checks and
  separate debug/release compilation pass. Independent code/security fallback,
  lead review and remote CI remain required at candidate handoff.
- Build 5 remains installed/running unchanged. Next after pinned review: B2b2
  authenticated native daemon boundary, then B3 client/setup/removal integration.
  Signing and native acceptance remain required before installation/arming.

## Bookmark — Coordinator planning (2026-10-12)

- `codex/always-on-coordinator` is an isolated branch on native IO
  PR #5 head `f547075`; B2a independent and lead code/security review clear,
  CI `38284998731` passed. Coordinator builder may start; no install/arming.
- B2b1 coordinator and wire contracts C1–C9 are locked in `always-on-build.md`;
  B2b2 then adds native authentication/telemetry/daemon composition, followed by
  B3 app client/setup/removal and packaging. No installation/arming yet.
- Build5 remains running unchanged. Matching Apple-issued signing is still
  needed for positive signed acceptance and installation; coding/tests continue.

## Bookmark — Native IO candidate (2026-10-12)

- `codex/always-on-native-io`, stacked on engine PR #4, implements protected
  journal storage, fixed command execution, strict public-API readback and bounded
  single-flight reads. It is not wired into the app and installs no helper.
- `AlwaysOnNativeChecks` passes 114 assertions; exact final compiled inert
  scaffold produces 114 assertions / 94 failures. Existing suites pass 60/0,
  34/0 and 176/0. Evidence and native limitations are in `VERIFICATION.md`.
- Lead's early process-ID reuse and unbounded/late-read findings were corrected
  before pinning. Independent, lead and native filesystem/process security review
  remain required; CodeRabbit is unavailable under the repository exclusion.
- Production journal path remains absent. Build 5 remains running at its original
  path as PID 96007. No pmset mutation, registration, permission change, installed
  bundle replacement or UI automation occurred. Next: pinned-head review and CI,
  then B2b only after acceptance. Installation/arming remains separately gated.

## Bookmark — Native IO planning (2026-10-12)

- `codex/always-on-native-io` starts from engine PR #4 fix `28eeffe` in its own
  worktree. B2a locked contracts are in `always-on-build.md`; independent and lead
  delta review cleared R1, and final-head CI `38281961153` passed. B2a may start.
- Next sequence is native IO adapters, authenticated daemon, then app integration
  and signed packaging. No helper is installed, no power setting has changed,
  and build 5 still runs at its original path. Apple-issued signing remains a
  required user-provided prerequisite for eventual installation.

## Bookmark — B1 recovery engine candidate (2026-10-12)

- `codex/always-on-engine` implements the pure typed recovery engine and injected
  fake-adapter checks, stacked on reviewed UI head `1923274`. The engine is not
  wired into the app; no live power, privileged, permission or installed-app
  operation was performed. Build 5 remains the running baseline.
- Final suite compiled inert with 176 assertions/102 failures; implementation
  passes 176/0. Existing suites pass 60/0 and 34/0. Evidence, recovery matrix and
  adapter/native limits are in `VERIFICATION.md` and `always-on-build.md`.
- Original-head CI run `38281301606` passed. Independent review found only R1,
  startup false-off; the fix adds checking before unresolved ownership reads and
  passed 176/0 after 16 focused pre-fix failures. Next: corrected-head CI,
  independent delta, lead and ownership/storage/token security review. B2 native
  adapters follow only after those reviews; installation/arming and existing UI native acceptance remain
  separate gates. CodeRabbit is unavailable under the repository exclusion.

## Bookmark — Recovery engine slice starting (2026-10-12)

- UI PR #3 pinned `1923274` passed independent and lead source review and CI run
  `38278803917`. Native warning render passed; remaining physical/native gates
  listed below still block installation/merge. No power setting has changed.
- `codex/always-on-engine`, isolated `always-on-engine` worktree, starts from that
  reviewed UI head. It implements a testable recovery engine with fake adapters;
  native privileged adapters and app integration are subsequent sequential slices.
- Locked behavior, gates and review ledger are in `always-on-build.md`.
  Build 5 remains installed and running. Matching Apple-issued signing identity
  is not yet available; user question pending. No unrelated identity may be used.

## Bookmark — Always-on UI candidate (2026-10-12)

- `codex/always-on-ui` implements the state/controller boundary, shared Dock/status
  actions, Settings status, quit-before-restore handling, and persistent warning
  panels. It is stacked on `codex/dock-presence`; both remain draft candidates.
- The production backend reports **setup unavailable** and performs no power IO.
  No helper, privileged operation, display/backlight write or input interception
  is implemented in this slice. Backend design/handoff is in
  [the locked build plan](always-on-build.md#backend-handoff-design-only-separate-slice).
- 34 feature assertions pass after a compiled inert-scaffold run failed 31 of
  those assertions; 60 existing scenarios, separate debug/release builds and
  source/fixture metadata/signature checks pass. Concrete output and limits are in
  `VERIFICATION.md`. Independent/lead pinned-head review and remote checks remain
  required before this candidate can advance.
- Native CUA inspected the **actual** isolated warning in active, pending,
  stopping and recovery states, including Return/Deactivate and failure/retry.
  The final 520 × 390-point render passed visual inspection. Full cross-Space,
  other-app fullscreen stacking, multiple-display/hot-plug and VoiceOver
  acceptance remain unverified; code configuration does not prove those behaviors.
- Isolated preview: `dist/Always-on Preview.app`, bundle identifier
  `local.snapbridge.alwaysonpreview`. It uses only an in-memory simulated backend.
  Preview was deactivated and quit after verification. Original installed build 5
  remains running as PID 96007; no installed bundle, permission or power setting
  was changed. Main-app packaging was not run because build 5 must keep running.
- User-authorized current model was used; exact builder model/effort metadata is
  unavailable. CodeRabbit remains unavailable by explicit repository restriction.

## Bookmark — Always-on build authorized (2026-10-12)

- User explicitly authorized building the broader mode despite the investigation
  limits and requested a persistent centered warning with a deactivate button.
  This supersedes the investigation-only/open-lid constraints below.
- [Locked build decisions and slices](always-on-build.md) govern implementation.
  UI/controller slice is on `codex/always-on-ui`, stacked on Dock PR #2; helper
  security architecture is under separate read-only review. No live activation
  or privileged installation is authorized as part of the current build phase.
- Build 5 remains installed. Dock native acceptance and permission refresh remain
  pending; do not replace the running app to create build evidence.

## Investigation update — guarded sleep override (2026-10-12)

- User authorized investigation only and clarified that critical battery/heat
  sleep should remain available. The lead and a separate read-only architecture
  reviewer examined the matching Apple sources and host SDK/man pages.
- A guarded global override could reduce ordinary failure risk, but has no
  automatic expiry or caller ownership; advisory warnings do not guarantee time
  to restore native emergency sleep. Prearming also changes open-lid behavior.
  It does not satisfy the original requirements and is not validated for travel.
- Findings, sources, failure matrix, and the bounded next experimental scope are
  in [the plan](closed-lid-plan.md#guarded-override-investigation--october-12-2026).
  No power settings, permissions, helpers, or installed app were changed.
- No power implementation is underway. A best-effort prototype needs a separate
  scope decision; live testing needs its own concrete test-Mac plan. Dock PR #2
  remains separate and draft, with the native acceptance blocker below. Its
  latest prior documentation-head CI passed on `9eafea56fab4de34ce51fb3b8de7051b7145b864`.

## Bookmark — Build 6 retained; build 5 restored (2026-10-12)

- Slice 1 of [the locked plan](closed-lid-plan.md) is implemented on
  `codex/dock-presence` in the isolated `PaneManagement-worktrees/dock-presence`
  checkout, based on `3ce28b8ce72d392c7885640d22b1b7e2e7a03b37`.
- [Draft PR #2](https://github.com/ccmenshealth/pane-management/pull/2) received
  independent and lead review on `ca9a781989c0051b14b223122ae71b6ab5595fc7`.
  Must-fix R1 was menu mutation in an AppKit open callback. The builder moved
  both menu refresh paths to `menuNeedsUpdate`; independent delta and lead review
  cleared `df335612a036637624eace16e4cdbcf64b7de013`. Its
  [code-head CI](https://github.com/ccmenshealth/pane-management/actions/runs/38272646660)
  passed. The finding and SDK evidence are in the plan's findings ledger.
- Candidate build 6 implements regular activation and a Dock menu with Settings
  and pause/resume. Actual Dock rendering/context-menu behavior is **unverified**.
  The existing menu-bar
  icon and chooser reopen exclusions are retained. Both menus and Settings use
  the same snapping preference. No closed-lid control or power backend is added.
- Native subagent builder used the user-authorized current model; exact
  model/effort metadata is unavailable in the builder session.
- Build 6 from reviewed code `df335612a036637624eace16e4cdbcf64b7de013` was
  installed at the same primary `dist/Pane Management.app` path, bundle ID
  unchanged. Packaging, installed signature, and binary-hash equality passed.
  The signed build 5 rollback bundle is retained in the builder's ignored
  `.build/dock-acceptance-rollback/Pane Management build5.app`.
- Native Settings render, preference round-trip/restoration, application-menu
  Settings, and Quit/relaunch passed. Build 6 truthfully reported missing
  Accessibility and unverified previews after the ad-hoc update. CUA Dock
  targeting timed out; actual Dock/status menus and cross-menu actions remain
  unverified, and the live chooser check was blocked by Accessibility.
- Lead-directed rollback restored build 5 to the primary installed path, with
  its original binary hash and valid signature. CUA confirmed running state,
  Accessibility, verified ScreenCaptureKit access, and enabled=true. Build 5 is
  running (PID 96007 at handoff). No privacy setting was changed.
- Retained build 6 candidate:
  `/Users/ccmh/Developer/PaneManagement-worktrees/dock-presence/dist/Pane Management.app`.
  Next: lead coordinates a manual/native acceptance session at the stable
  installed path, renewing only existing grants if needed, then verifies actual
  Dock/status controls, shared pause/resume, closing/reopening and chooser
  preservation. Exact evidence and rollback are in `VERIFICATION.md`.
  Do not call this slice gate-green or merge before acceptance is resolved.
- CodeRabbit is unavailable under the repository exclusion. Security review is
  not applicable to the Dock/menu-only runtime change; no access or data flow is
  added. Closed-lid feasibility review is complete; that separate slice is blocked
  pending the user's scope decision because no caller-owned mechanism met the
  exact lid-only behavior and recovery requirements. No sleep setting was changed.

## Bookmark — Review cadence merged (2026-09-14)

- [PR #1](https://github.com/ccmenshealth/pane-management/pull/1) is merged into
  `main` as `870386bf4bf5676b215eafe30f0edff06e47add2`. Its two-parent merge
  preserves reviewed head `7b4cc12839f8c69868760b64180b2cb7ce73217f` and has
  exactly the same file tree. The merge uses the existing GitHub no-reply
  author/committer identity. All automatic-fit work is preserved; only review
  configuration and project documentation changed.
- `AGENTS.md` carries the shared on-demand cadence and release/reporting gates.
  `.coderabbit.yaml` explicitly keeps initial, incremental, and draft reviews
  off, adds the shared non-blocking review-workflow/profile/base-branch settings,
  and preserves the existing disabled chat and issue automation.
- The user's Pane Management GitHub App exclusion remains in force. No account
  access, billing, CodeRabbit review request, CI workflow, or app runtime setting is changed.
  Do not request CodeRabbit to test this cadence change.
- Local checks: a clean isolated release build and all 60 regression scenarios
  passed, as did YAML parsing/preservation assertions, script syntax, source
  plists, existing bundle signatures, and `git diff --check`. The primary
  checkout is clean on `main`; its installed executable was not rebuilt.
- [Final PR CI](https://github.com/ccmenshealth/pane-management/actions/runs/34905110559)
  passed on `7b4cc12839f8c69868760b64180b2cb7ce73217f`.
  [Post-merge main CI](https://github.com/ccmenshealth/pane-management/actions/runs/34907603027)
  passed on `870386bf4bf5676b215eafe30f0edff06e47add2`, including app/helper
  packaging, 60 regression scenarios, and bundle verification. Later
  status-only bookkeeping does not change configuration or app code; its checks
  and review evidence are recorded on the merged PR.
- The user authorized a separate review agent. Its independent review of the
  complete five-file diff at `44c812ae4033e72addbc7706daef76a8feb05997` against
  `9f4a0879fd9ebe0f825242a67ec695155a2dd185` found **no blocking findings**.
  YAML parsing/preservation, the three added settings' shapes, all eight existing
  disabled automation controls, publication scope, and whitespace checks passed.
  This is not a full app code audit or independent reproduction of live tests;
  account-side App exclusion was not reverified by the reviewer. Remote CI was
  verified separately by the parent agent.
- The same reviewer cleared the follow-up documentation delta; its exact file
  blob `1563b3a54d79c6207ba5993e32804d207bc3c530` was committed unchanged in
  `7b4cc12839f8c69868760b64180b2cb7ce73217f`. No real findings remain unresolved.
- CodeRabbit was not requested and no CodeRabbit reviews/comments were present (the
  cadence explicitly prohibits spending reviews to test this configuration);
  security review and deployment are not applicable to this policy-only diff.
- No merge action remains for PR #1. Remaining app acceptance requires physical
  keyboard/drag/resize/monitor-transfer checks and a user-coordinated reboot.
  Distribution additionally requires Developer ID signing/notarization. Do not
  treat this configuration/documentation merge as a tested public app release.

## Build 5 baseline — restored October 12

- Build 5, source `9f4a0879fd9ebe0f825242a67ec695155a2dd185`, implements automatic
  two-column fitting without a second recovery click. The installed bundle was
  not rebuilt or replaced by this configuration/documentation merge.
- 60 local regression scenarios passed. Single-selection/repeat NordVPN fitting,
  constrained first-window fitting, and impossible-pair rollback passed scoped
  live checks. Exact limits and historical results are in `VERIFICATION.md`.
- All 11 live fixture checks were rerun successfully on build 5 on the
  negative-origin display. Physical drag automation still fails before delivery;
  a synthetic snap-right shortcut reached the fixture but did not place it.
  Physical keyboard/drag acceptance therefore remains open. The disposable
  helper was closed after testing; other apps' windows/settings were not changed.
- [Build 5 GitHub checks](https://github.com/ccmenshealth/pane-management/actions/runs/34902340131)
  passed. Accessibility/previews are recognized by the running app. System
  Settings still lists Pane Management under Open at Login; no reboot test was
  performed. Distribution signing/notarization remains outstanding.
