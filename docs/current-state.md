# Pane Management — Current State

## Bookmark — Review cadence adoption (2026-09-14)

- Working branch: `chore/review-cadence`, isolated from primary `main` at
  `9f4a0879fd9ebe0f825242a67ec695155a2dd185`. All existing automatic-fit work is
  preserved. This change touches review configuration and agent/status docs only.
- `AGENTS.md` carries the shared on-demand cadence and release/reporting gates.
  `.coderabbit.yaml` explicitly keeps initial, incremental, and draft reviews
  off, adds the shared non-blocking review-workflow/profile/base-branch settings,
  and preserves the existing disabled chat and issue automation.
- The user's Pane Management GitHub App exclusion remains in force. No account
  access, billing, review request, CI workflow, or app runtime setting is changed.
  Do not request CodeRabbit to test this cadence change.
- Local checks: YAML parsing and assertions for all existing settings and the
  new values/types passed; `git diff --check` passed. The primary checkout is
  clean on `main` at the source commit above. No app rebuild was needed.
- This is a local configuration commit, not a push or release. Independent
  review and new remote CI have not run. CodeRabbit was not requested (the
  cadence explicitly prohibits spending reviews to test this configuration);
  security review and deployment are not applicable to this policy-only diff.
- Next action: carry `chore/review-cadence` into the next scoped push/PR, obtain
  independent review, and inspect its attached remote checks before release.
  Do not imply that the running app or primary checkout contains this commit.

## Running application

- Build 5, source `9f4a0879fd9ebe0f825242a67ec695155a2dd185`, implements automatic
  two-column fitting without a second recovery click. The primary checkout and
  currently running bundle have not been replaced by this configuration change.
- 60 local regression scenarios passed. Single-selection/repeat NordVPN fitting,
  constrained first-window fitting, and impossible-pair rollback passed scoped
  live checks. Exact limits and historical results are in `VERIFICATION.md`.
- [Build 5 GitHub checks](https://github.com/ccmenshealth/pane-management/actions/runs/34902340131)
  passed. Accessibility/previews and Open at Login were configured for the local
  app; no reboot test was performed.
