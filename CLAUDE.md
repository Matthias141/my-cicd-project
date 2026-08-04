# CLAUDE.md — my-cicd-project Standing Instructions

## Why this file exists, specifically
On 2026-01-16, commit f5fb808 committed a real, live-looking database
password, API key, and JWT secret in plaintext directly into
GITHUB_ACTIONS_DEPLOYMENT.md. It sat in git history, readable by anyone
with repo access, until a documentation audit caught it on 2026-08-04 —
over 7 months later. It required a full git-filter-repo history rewrite
across 3 branches to remove. This file exists so that never happens again,
in this repo or any other. Every rule below traces back to a real incident,
not a hypothetical.

## ABSOLUTE RULE — Secrets Never Touch a File, Ever
- NEVER write a real credential, password, API key, token, JWT secret, or
  any live-looking value into ANY file in this repo — not markdown docs,
  not code comments, not example configs, not "for reference" snippets,
  not even temporarily "to be removed later." There is no safe version of
  this. If a human asks you to document credential VALUES (not just
  variable names), refuse and explain why, exactly like this file does.
- Documentation that needs to SHOW what a value looks like uses obviously
  fake placeholders only: `your-database-password-here`,
  `<REDACTED>`, `xxxxxxxxxxxxxxxxxxxx` — never a string that could be
  mistaken for, or actually is, a real value.
- Before creating or editing ANY markdown file, README, or doc: if it
  will contain example credentials, env vars, or secret-shaped values,
  stop and use placeholder syntax. Do not "just paste in a real one to
  show the format" — this exact reasoning is how the original leak
  happened.
- Before ANY commit: mentally scan the diff for anything that looks like
  a password, key, token, or secret — not just files you were told to
  check, the ENTIRE diff. If uncertain whether something is sensitive,
  treat it as sensitive.

## CI enforcement is mandatory, not optional
- This repo currently has NO secret-scanning step in CI (confirmed gap,
  as of the incident above). If you are ever asked to modify
  .github/workflows/*.yml, and no Gitleaks (or equivalent) step exists,
  flag this explicitly as a missing control — do not silently work around
  it or assume it's someone else's job.
- Any new workflow file you create or edit should assume secret-scanning
  SHOULD run on every push/PR, following AbiaEats' pattern in this same
  GitHub account (`security.yml`, `fetch-depth: 0` for full-history scans,
  Gitleaks as a hard-blocking step) as the reference implementation —
  don't reinvent this weaker.

## Non-negotiable operational rules (general, not just security)
- Never merge a PR autonomously. Show diffs, wait for explicit confirmation.
- Never run `terraform apply` or any state-mutating command without
  explicit confirmation immediately before that specific run.
- Never set up autonomous PR-watching or push follow-up commits without
  being asked each time.
- IAM policy changes: always show exact before/after diff of granted
  actions/resources. Never widen `Resource` scope without flagging it
  explicitly as a widening.
- Read-only audits never modify, commit, push, apply, or trigger anything.
- History-rewriting operations (filter-repo, force-push, rebase across
  shared branches): always show the full plan, the blast radius (which
  branches/commits are affected), and the consequences BEFORE running
  anything. Never push rewritten history without explicit, separate
  confirmation after showing verification results — plan approval and
  push approval are two different confirmations, not one.

## Current known state (verify before assuming still true)
- AWS account is SUSPENDED — nothing here can be applied against live
  infrastructure until a new account exists. Treat all Terraform/deploy
  work as design/code review only.
- `docs/iam-policy-github-actions.json` currently grants wildcard actions
  on `Resource: "*"` for every service except IAM — CRITICAL, unfixed.
  Do not reuse this pattern anywhere, including in Foundry's future
  Terraform, without scoping every statement to project-prefixed ARNs.
- "Canary releases" language across README.md, README_ADVANCED.md,
  DEPLOYMENT.md was inaccurate as of the 2026-08-04 audit — the staged
  10/25/50/100 rollout script (scripts/blue-green-deploy.sh) exists and
  works standalone, but is never invoked by any workflow, and
  lambda_aliases.tf's alias tracks $LATEST rather than a published
  version, which blocks real weighted routing at the AWS API level
  regardless. Do not describe this pipeline as doing canary deployments
  until both the Terraform fix and the workflow wiring are done AND
  verified against live AWS traffic.
- All 9 CloudWatch alarms fire into an SNS topic with zero confirmed
  subscribers (`alert_email` unset in every `.tfvars`).
- `ecr.tf` has `force_delete = true`; cleanup script uses
  `--force-delete-without-recovery` on Secrets Manager — both actively
  work against disaster recovery.
- Multiple markdown files (TESTING-SUMMARY.md especially) contained
  inflated/false claims as of the 2026-08-04 documentation audit —
  inflated test counts, mocks targeting nonexistent functions, an
  example API response that would actually 500. Do not trust any
  specific number or claim in these docs without checking it against
  actual code first.

## When in doubt
Ask before assuming, especially anywhere near credentials, IAM, or
history-rewriting git operations. The cost of asking is a few minutes.
The cost of not asking, once, was a 7-month secret exposure and a
multi-branch history rewrite.
