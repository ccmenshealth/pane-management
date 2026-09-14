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
  access, billing, review request, CI workflow, or app runtime setting is changed.
  Do not request CodeRabbit to test this cadence change.
- Local checks: a clean isolated release build and all 60 regression scenarios
  passed, as did YAML parsing/preservation assertions, script syntax, source
  plists, existing bundle signatures, and `git diff --check`. The primary
  checkout is clean on `main`; its installed executable was not rebuilt.
- [Draft PR #1](https://github.com/ccmenshealth/pane-management/pull/1) is open.
  [GitHub CI](https://github.com/ccmenshealth/pane-management/actions/runs/34904318429)
  passed on `3baf1bcacfb6c34ca167498f02d5a6250b9f9bd2`, including app/helper
  packaging, 60 regression scenarios, and bundle verification. A subsequent
  status-only commit records this result; inspect the PR for its latest checks.
- Independent review has not run; leave the PR draft until that gate is met.
  Permission to use a separate review agent was requested but not yet received.
  CodeRabbit was not requested and no bot reviews/comments were present (the
  cadence explicitly prohibits spending reviews to test this configuration);
  security review and deployment are not applicable to this policy-only diff.
- Next action: obtain independent review and inspect the draft PR's attached
  remote checks before marking it ready for release.
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
