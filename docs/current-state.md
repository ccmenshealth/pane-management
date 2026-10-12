# Pane Management — Current State

## Bookmark — Native daemon planning (2026-10-12)

- `codex/always-on-daemon` is an isolated planning branch on coordinator PR #6
  head `7164b2e`. Independent/security review and CI remain pending; no native
  builder starts before acceptance. Locked N1–N8 are in `always-on-build.md`.
- Next: native authentication/telemetry/daemon boundary, then B3 app client/setup/
  removal integration. No live helper registration, power mutation or arming.
  Apple-issued signing remains necessary for positive signed acceptance/install.
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
