# Pane Management — Current State

## Bookmark — Dock presence slice under review (2026-10-12)

- Slice 1 of [the locked plan](closed-lid-plan.md) is implemented on
  `codex/dock-presence` in the isolated `PaneManagement-worktrees/dock-presence`
  checkout, based on `3ce28b8ce72d392c7885640d22b1b7e2e7a03b37`.
- Candidate build 6 uses regular activation, appears in the Dock while running,
  and supplies Settings and pause/resume in its Dock menu. The existing menu-bar
  icon and chooser reopen exclusions are retained. Both menus and Settings use
  the same snapping preference. No closed-lid control or power backend is added.
- Native subagent builder is running the user-authorized current model; exact
  model/effort metadata is unavailable in the builder session. Lead and a separate
  read-only reviewer must review the pinned candidate before installation.
- Local checks and remaining acceptance are recorded in `VERIFICATION.md`.
  Packaging the app and native UI acceptance await a lead-coordinated quit of
  build 5. The installed bundle at the primary checkout is unchanged.
- Next actions: push a draft PR, perform independent and lead review, then
  package and run the native Dock/menu/recovery checks at the
  stable installed path. Do not call this slice gate-green before those checks.
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

## Running application

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
