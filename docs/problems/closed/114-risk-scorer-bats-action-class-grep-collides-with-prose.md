# Problem 114: `risk-scorer-structured-remediations.bats` bare-word `action_class` grep collides with "No structured action_class column" prose

**Status**: Closed
**Reported**: 2026-04-24
**Closed**: 2026-04-24
**Priority**: 6 (Med) — Impact: Moderate (3) x Likelihood: Likely (2)
**Effort**: S (three test-assertion edits in one bats file)
**WSJF**: 0 (closed)

> Identified 2026-04-24 while releasing the P113 fix. `npm run push:watch` landed commits `2be1bfa..b2424c8` on `origin/main` in one push; CI on the tip commit (b2424c8) failed three assertions in `packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats` that had actually regressed two commits earlier in `64f6d3f` (2026-04-23). Because `64f6d3f` and the intermediate commits were never pushed individually, origin CI had never seen the regression until today's push.

## Description

`packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats` tests 699–701 (lines 106–121) assert that `pipeline.md`, `wip.md`, and `plan.md` have **no `action_class` column** in their RISK_REMEDIATIONS schema. The assertions use a bare-word grep:

```bash
run grep -q "action_class" "$PIPELINE"
[ "$status" -ne 0 ]
```

The three agent files have the prose (line 164 / 76 / 67):

> - **description**: free-form prose. The agent reads this and decides what to do. No structured action_class column.

The prose is documentation **asserting absence of the column** — but the grep sees the word and treats it as a positive match. The test fails despite the schema genuinely having no `action_class` column. The test's intent (schema shape) and implementation (substring-anywhere match) diverge.

## Symptoms

- CI run `24878623325` for commit `b2424c8` — Quality Gates → Run hook tests — fails three assertions:
  - `not ok 699 pipeline.md RISK_REMEDIATIONS format has no action_class column`
  - `not ok 700 wip.md RISK_REMEDIATIONS format has no action_class column`
  - `not ok 701 plan.md RISK_REMEDIATIONS format has no action_class column`
- Release PR #64 "Version Packages" was created by the `changesets/action@v1` workflow but its CI status is red, blocking auto-merge.
- The assertions' intent (no action_class column in schema) is satisfied; only the prose documenting that absence trips the grep.

## Workaround

Hold the release PR until the test is fixed. Either:
- Revert the prose to not mention the word (e.g., change "No structured action_class column" to "No structured action-class column" with a hyphen). Cheap but couples doc wording to test-grep implementation.
- Tighten the test to match column-header syntax only (the path chosen below).

## Impact Assessment

- **Who is affected**: any commit pushed to `main` after `64f6d3f` — CI stays red, release PRs auto-created by the Release workflow cannot merge, npm releases of all `@windyroad/*` plugins are paused.
- **Frequency**: blocks every push until fixed.
- **Severity**: Moderate. Releases are paused; feature delivery is halted. Workaround of hand-unblocking CI or rolling back is brittle. P113 release verification cannot proceed until this clears.
- **Analytics**: N/A — purely CI-pipeline-internal.

## Root Cause Analysis

### Confirmed root cause

Commit `64f6d3f` ("revert RISK_REMEDIATIONS schema to 5 columns — no action_class") did two things in one commit:

1. Removed the `action_class` column from the `RISK_REMEDIATIONS` schema in `pipeline.md`, `wip.md`, `plan.md`.
2. Flipped the existing bats assertions from "has action_class" to "has no action_class".

But in the same commit, the agent files' prose was also updated with documentation that explicitly mentions the removed column's name: "No structured action_class column." — intended to document ADR-042 Rule 2a compliance. The test's bare-word grep matches that prose sentence.

The regression was not caught by CI because `64f6d3f` lived locally on `main` (along with four later commits) and was not pushed to origin until the batched push of `2be1bfa..b2424c8` today. This is a variant of the "unpushed-commits defer CI feedback" hazard covered by P040 (origin fetch preflight) at session boundary — here the hazard is within-session: CI only runs on the push, not on local commits, so the earliest origin-CI signal is on the tip of what is pushed.

### Investigation Tasks

- [x] Read the failing bats assertions — confirmed bare-word grep pattern.
- [x] Grep the three agent files for `action_class` — confirmed prose mention at pipeline.md:164, wip.md:76, plan.md:67.
- [x] Confirm 64f6d3f introduced both the doc prose and the flipped assertions — `git log` confirms same commit, single transaction.
- [x] Architect review (PASS) + JTBD review (PASS) of the proposed fix.
- [ ] Verify CI passes on the commit containing the fix.
- [ ] (Follow-up, advisory) consider a ticket on the structural-over-behavioural patter of these assertions per P081; the fix below tightens toward behavioural specificity but the file's header exception still stands. No new ticket filed here.

### Reproduction test

The failing assertions themselves are the reproduction. After the fix, tests 699–701 flip from `not ok` to `ok`.

### Fix Strategy

**Shape**: three one-line edits in one bats file.

**Target file**: `packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats` lines 106–121.

**Before** (one example):
```bash
run grep -q "action_class" "$PIPELINE"
[ "$status" -ne 0 ]
```

**After**:
```bash
run grep -qE '^\| *action_class\b' "$PIPELINE"
[ "$status" -ne 0 ]
```

The tightened regex anchors to a markdown-table column-header row (`^\|`) and requires the token to be whole-word (`\b`). Prose mentions of `action_class` are ignored; only actual table columns trip the assertion. Schema-shape contract preserved.

**Evidence**:
- CI run `24878623325` failure logs: tests 699/700/701 fail on `[ "$status" -ne 0 ]'` because grep exit status is 0.
- `grep -n "action_class" packages/risk-scorer/agents/*.md` confirms line 164 (pipeline), 76 (wip), 67 (plan) contain the prose mention.
- Architect review (2026-04-24): PASS — strengthens ADR-042 Rule 2a invariant without introducing new decision.
- JTBD review (2026-04-24): PASS — test-only, no persona-visible surface.
- No changeset — test-only change, no runtime behaviour shift, no `@windyroad/risk-scorer` behaviour shipped to npm is affected.

## Fix Released

Fix landed 2026-04-24 in the same commit as this ticket transition — `packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats` lines 109, 114, 119 now use the column-header regex. Verification path: CI run on the fix commit should show tests 699/700/701 as `ok`. Once green, release PR #64 is merge-eligible and P113's release also unblocks.

### Closed 2026-04-24

Verified in-session: CI Quality Gates → Run hook tests has been green on every commit since the fix landed — `97c976e` (the fix itself), `38a0f7e` (version bump), `8f6e89e` (release PR merge), `e14040b` (P113 RCA update + P115 open), `245e09c` (P113 closure). Release PR #64 "Version Packages" auto-merged; `@windyroad/itil@0.18.1` published to npm. Tests 699/700/701 flipped from `not ok` to `ok` as predicted.

## Dependencies

- **Blocks**: P113 release verification (until CI is green, `@windyroad/itil` patch cannot publish).
- **Blocked by**: nothing — self-contained test fix.
- **Composes with**: nothing.

## Related

- **P113** (`docs/problems/113-wr-itil-report-upstream-missing-from-slash-command-autocomplete.verifying.md`) — release blocked by this CI failure; P114 fix unblocks P113 verification.
- **ADR-042** (`docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`) — Rule 2a schema invariant the test is guarding. The fix strengthens, not weakens, the guard.
- **P081** (`docs/problems/081-*.md`) — behavioural over structural. The refinement tightens a structural exception toward behavioural specificity, within the test file's existing permitted-exception header.
- **P040** (`docs/problems/040-*.md`) — origin fetch preflight; this is the within-session variant of the same hazard (unpushed local commits defer CI feedback).
- Commit `64f6d3f` — introduced the regression.
- Commit `b2424c8` — first push to reveal the regression on origin CI.
