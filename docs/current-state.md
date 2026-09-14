# Pane Management — Current State

## Bookmark — Review cadence adoption (2026-09-14)

- Working branch: `chore/review-cadence`, isolated from primary `main` at
  `9f4a0879fd9ebe0f825242a67ec695155a2dd185`. All existing automatic-fit work is
  preserved. This change touches review configuration and project documentation only.
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
- [PR #1](https://github.com/ccmenshealth/pane-management/pull/1) is open.
  [GitHub CI](https://github.com/ccmenshealth/pane-management/actions/runs/34904510137)
  passed on `44c812ae4033e72addbc7706daef76a8feb05997`, including app/helper
  packaging, 60 regression scenarios, and bundle verification. Subsequent
  review-status bookkeeping does not change configuration or app code; inspect
  the PR for its latest checks and documentation-delta review result.
- The user authorized a separate review agent. Its independent review of the
  complete five-file diff at `44c812ae4033e72addbc7706daef76a8feb05997` against
  `9f4a0879fd9ebe0f825242a67ec695155a2dd185` found **no blocking findings**.
  YAML parsing/preservation, the three added settings' shapes, all eight existing
  disabled automation controls, publication scope, and whitespace checks passed.
  This is not a full app code audit or independent reproduction of live tests;
  account-side App exclusion was not reverified by the reviewer. Remote CI was
  verified separately by the parent agent.
- CodeRabbit was not requested and no CodeRabbit reviews/comments were present (the
  cadence explicitly prohibits spending reviews to test this configuration);
  security review and deployment are not applicable to this policy-only diff.
- Next action: confirm the latest documentation-only delta review and remote
  checks, then mark the PR ready for maintainer review. Merge remains a separate
  action; this handoff does not claim that the PR has been merged or deployed.
  Do not imply that the running app or primary checkout contains this commit.

## Running application

- Build 5, source `9f4a0879fd9ebe0f825242a67ec695155a2dd185`, implements automatic
  two-column fitting without a second recovery click. The primary checkout and
  currently running bundle have not been replaced by this configuration change.
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
