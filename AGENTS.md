# Pane Management Agent Rules

## Kickoff and work isolation

Before any file write, check `pwd`, `git branch --show-current`,
`git status -uall`, `git diff HEAD --stat`, and `git worktree list`.
Read the top bookmark in `docs/current-state.md`. Working-tree state wins over
documentation. If unexpected work is not accounted for, stop and identify its
owner; never stash, reset, overwrite, or stage it without permission.

Use an isolated worktree and a dedicated branch for code/config changes. Keep
the primary checkout on `main`; preserve its existing work. Commit from the
isolated branch and use a PR unless the user explicitly requests a direct push.
Do not leave shared checkouts with uncommitted code or use `git add -A` on WIP.

## CodeRabbit Review Cadence

Shared user-approved cadence adopted 2026-09-14. This replaces instructions to
request CodeRabbit for every PR, push, commit, or fix round.

- CodeRabbit is an on-demand third opinion. Automatic initial and incremental
  reviews stay off. CI, independent code review, applicable security review,
  and triage of real findings remain the release gates.
- Finish implementation, relevant local checks, and independent review before
  requesting CodeRabbit. Keep unfinished PRs as drafts. Batch related fixes
  into one push; avoid superseding an active review with another push.
- Request one `@coderabbitai review` on a ready substantive PR (features,
  nontrivial behavior fixes, or auth/PHI/comms/storage/money changes). Read the
  latest bot status first; do not duplicate an active or completed review for
  the same head. If no prior review exists, this is the initial review.
- Skip CodeRabbit for docs-only, formatting, and trivial mechanical changes;
  report not applicable with the reason. An explicit human review request
  overrides this default. Never label a risky change trivial to save quota.
- Triage every finding as real, accepted/false positive, or out of scope.
  Fix real correctness/security issues before merge, then run relevant tests
  and independent review of the delta. Request another incremental pass only
  for material new risk, substantial redesign, an unresolved review concern,
  or the user's request. A routine fix does not automatically need another
  pass. State which head was reviewed and how later changes were checked;
  never imply final-head coverage that did not happen.
- Do not pair `review` with `full review`; reserve `@coderabbitai full review`
  for a justified fresh review of the entire PR. Do not loop on rate limits.
  Report unavailable and proceed only when the other required gates are green
  and no real finding remains unresolved. A passing rate-limit check does not
  mean a review ran.
- Do not enable paid overages, upgrade plans, or change billing without the
  user's explicit approval. Do not spend reviews testing this configuration.

### Repository-specific access restriction

The user separately requested that CodeRabbit not run on Pane Management.
This repository is excluded from the GitHub App installation. Preserve that
exclusion and the disabled chat/issue automation in `.coderabbit.yaml`.
The cadence above does not authorize granting access or requesting a review
for this repository. Report CodeRabbit as unavailable under this restriction
for substantive changes, or not applicable for exempt changes. If the user
explicitly changes this restriction, apply the on-demand cadence above; never
silently re-enable automatic reviews or change account-wide access/billing.

## Verification and remote gates

Use the Swift build and regression commands in `README.md`. Verify the packaged
bundle's signature when replacing it. Preserve the bundle identifier and path;
development signing can require a scoped permission refresh. Never weaken
macOS permissions or touch another app's security/network settings to test a snap.

For each PR or push, report local checks, GitHub CI/check status, CodeRabbit
triage/applicability/availability, applicable security review, deployment or
local-app installation status, and any open loop with its exact next action.
Changes touching auth, sensitive data, intake, fax, storage, tokens, external
communications, or money movement need security review. If a literal
`/security-review` tool is unavailable, say so and identify any fallback.
Do not call required red checks or untriaged real findings complete. If CI
fails, inspect it, fix on the same isolated branch, and recheck the remote gates.

For pure planning/status/review-ledger Markdown commits, `git diff --check`
plus a quick remote workflow/check-suite inspection is sufficient; no attached
workflow means CI is not applicable. Queued/unavailable CodeRabbit is
non-blocking for such bookkeeping. This exception does not cover configuration,
workflow, dependency, security, or runtime changes bundled with docs.

Record running/deployed state and active handoffs in `docs/current-state.md`;
keep concrete test evidence and limitations in `VERIFICATION.md`. Do not put
important state only in chat. Never publish credentials, private window content,
screenshots, or unrelated personal files. Stage only the intended project files.
