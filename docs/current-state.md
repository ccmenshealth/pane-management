# Pane Management — Current State

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
