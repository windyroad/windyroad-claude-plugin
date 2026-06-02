# Problem 280: `/install-updates` reorders `enabledPlugins` map in `.claude/settings.json` on every release producing no-semantic-change churn commits

**Status**: Verification Pending
**Reported**: 2026-05-19
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Fix Released

Fixed by `7a14b8b` "refactor(install-updates): narrow to global-cache refresh; decouple bootstrap (ADR-030/059 amendment)" — the per-sibling `claude plugin install --scope project` loop was removed, so `/install-updates` no longer writes `.claude/settings.json` and the `enabledPlugins` reorder churn is gone. `/install-updates` is a repo-local skill (live once on main). Verify: a release-cycle `/install-updates` run produces no `enabledPlugins`-reorder diff in `.claude/settings.json`.

> **Likely resolved (2026-05-25):** the install-updates global-cache-refresh simplification removed the per-sibling `claude plugin install --scope project` loop (ADR-030 amendment 2026-05-25) → no more `.claude/settings.json` writes, which were the source of the `enabledPlugins` reorder churn. Verify and close at next review.

## Description

After every `/install-updates` invocation (canonically fired at session-wrap and after every release per ADR-030), the script's project-scope install step writes `.claude/settings.json` with a re-keyed ordering of `enabledPlugins` that differs from the prior on-disk ordering by map-iteration order alone — no semantic change. The agent (or user) then commits the churn as a `chore(settings)` commit to keep the working tree clean before the next push.

Session 8 evidence — two `chore(settings)` churn commits within a 30-hour window:

- `27d0ef6 chore(settings): reorder enabledPlugins (install-updates churn — wr-itil 0.35.5)` — fired after `@windyroad/itil@0.35.5` release iter 3 (P268).
- `54f0a83 chore(settings): reorder enabledPlugins (install-updates churn)` — fired after iter 2 (P269) release cycle.

Each commit is a zero-semantic-change diff (same set of enabled plugins; only key order varies). Cumulative across sessions, this produces approximately 1 churn commit per release cycle — order N×K commits where N=releases and K=sessions.

Captured from `/wr-retrospective:run-retro` session-8-wrap Step 4b Stage 1 codification candidate dispatch per user direction — explicitly named in the retro dispatch as codification item (b) "the install-updates churn on settings.json that fires after every release".

## Symptoms

- Every `/install-updates` invocation after a release writes `.claude/settings.json` with reordered `enabledPlugins` map keys.
- Agent (or user) commits the diff as `chore(settings): reorder enabledPlugins (install-updates churn)` to keep tree clean before subsequent `git push`.
- Pattern recurs every release cycle — at least 2× this session, similar count in prior sessions.

## Workaround

Commit the churn as `chore(settings): reorder enabledPlugins (install-updates churn — <release name>)`. Works but the workaround IS the design defect — releases shouldn't require maintenance commits.

## Impact Assessment

- **Who is affected**: every solo-developer (JTBD-001) and AFK orchestrator (JTBD-006) who runs `/install-updates` after a release.
- **Frequency**: every release cycle (≥3 per session at the current AFK orchestrator cadence).
- **Severity**: Low — friction-add and commit-log noise, not a correctness defect.
- **Analytics**: count of `chore(settings): reorder enabledPlugins` commits in git log over a 30-day window vs total release count. Ratio close to 1.0 confirms the churn is universal.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Investigate root cause — is the reorder produced by Claude Code's `plugin install` itself, by `/install-updates` Step 6 settings rewrite, or by JSON serialisation library map-iteration order? Locate the actual writer.
- [ ] Design candidate (a): if the reorder originates in `/install-updates`, sort `enabledPlugins` keys deterministically (alphabetical) before writing — eliminates the churn at source.
- [ ] Design candidate (b): if the reorder originates in `claude plugin install`, treat the reorder as benign via `.gitattributes` merge=ours rule (less elegant; preserves upstream tool behaviour).
- [ ] Design candidate (c): if neither, ship a `/install-updates` post-install normalisation pass that re-sorts `enabledPlugins` after the install step and writes back if changed — keeps the upstream behaviour intact and normalises at our boundary.
- [ ] Create reproduction test — run `/install-updates` against a known-good `.claude/settings.json`, diff before/after, assert key order delta is empty (or that the keys are sorted).

### Preliminary Hypothesis

Candidate (c) — normalise at the `/install-updates` boundary — is likely the lowest-risk fix. It preserves Claude Code's plugin-install behaviour while making the post-install settings.json deterministic. Sort keys alphabetically (or by some stable convention) after every install pass.

## Fix Strategy

**Kind**: improve (existing repo-local skill)
**Shape**: skill — improvement stub
**Target file**: `.claude/skills/install-updates/SKILL.md` (repo-local skill per ADR-030) + the underlying settings-write helper if separate.
**Observed flaw**: post-install pass leaves `enabledPlugins` map in install-order (non-deterministic) rather than canonical-order; every release produces a no-semantic-change diff requiring a `chore(settings)` churn commit.
**Edit summary**: add a post-install normalisation step — read `.claude/settings.json` after install pass, sort `enabledPlugins` keys alphabetically (or another stable convention), write back if changed. Single behavioural bats covering: install pass that reorders keys → normalisation restores canonical order → second install pass is no-op.
**Evidence (session 8)**:
- Commits `27d0ef6` + `54f0a83` — two `chore(settings): reorder enabledPlugins (install-updates churn)` commits in 30-hour session window, both zero-semantic-change.
- Pattern recurs every release cycle — class-of-behaviour, not one-off.
**Routing target**: when P280 is worked, `/wr-itil:manage-problem 280 known-error` → architect review on whether normalisation belongs in `/install-updates` or upstream Claude Code → implementation in repo-local skill if normalisation stays at our boundary.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: ADR-030 (repo-local `/install-updates` skill), P092 (npm package naming gap in `/install-updates` Step 4 — sibling friction surface), P106 (silent install no-op — sibling churn class), P115 (worktree scan — sibling install-updates improvement surface), P259 (install-updates failure cascade — sibling defect class on the same settings.json surface).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- `.claude/skills/install-updates/SKILL.md` — repo-local skill
- ADR-030 — repo-local skill contract
- P092, P106, P115, P259 — sibling install-updates surfaces
- Git log session 8: commits 27d0ef6, 54f0a83 — evidence
- /wr-retrospective:run-retro session-8-wrap Step 4b Stage 1 — capture source per user direction
