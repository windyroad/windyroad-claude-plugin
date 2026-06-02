# Problem 109: `/wr-itil:work-problems` preflight Step 0 does not detect prior-session partial-work state (untracked ADRs, `.afk-run-state/iter-*.json` with 429/error statuses, existing `.claude/worktrees/*` branches)

**Status**: Closed
**Reported**: 2026-04-22
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3)
**Effort**: M
**WSJF**: (9 × 1.0) / 2 = **4.5**

> Identified 2026-04-22 by the run-retro Step 2b pipeline-instability scan at the end of the ADR-041 landing session. The prior AFK session hit a 429 quota mid-iteration on P103, leaving uncommitted: a drafted `docs/decisions/041-auto-apply-scorer-remediations-above-appetite.proposed.md` (the structural fix for P103 + P104 — top two WSJF items), `.afk-run-state/iter-p103.json` with `is_error: true, api_error_status: 429`, and `.claude/worktrees/upbeat-keller` on branch `claude/upbeat-keller@a36a084`. When the user invoked `/wr-itil:work-problems` to resume, the skill's Step 0 preflight handled `git fetch origin` + divergence check cleanly — but it did NOT detect or surface any of the prior-session partial-work signals. The session's main agent had to ad-hoc this via `AskUserQuestion` at session start: "A prior AFK session hit a 429 quota limit mid-iteration on P103, leaving a drafted ADR-041 uncommitted. How should this loop handle that partial work?" The user answered "Land ADR-041 as iter 1 (Recommended)". The interaction worked, but the detection + surfacing logic was manual, not codified. This is a recurring-pattern signal — any future AFK session that hits quota + restart will face the same state.

## Description

`/wr-itil:work-problems` Step 0 (Preflight per ADR-019) currently handles one failure mode: origin divergence.

| Local vs origin | Action |
|---|---|
| HEAD at or ahead of origin/<base> | Proceed to Step 1 |
| origin/<base> ahead, local has no unpushed commits (pure fast-forward) | `git pull --ff-only` non-interactively |
| origin/<base> ahead, local has unpushed commits (non-fast-forward) | STOP with report |

Step 0 does NOT handle the **session-continuity** failure mode: prior-session partial work left in the working tree from a subprocess that hit quota (429), a user-cancelled iteration, or a crashed subprocess. Observable signals include:

- Untracked files under `docs/decisions/*.proposed.md` that don't match a landed commit (= drafted but unlanded ADRs from a prior iter).
- Untracked files under `docs/problems/*.md` (drafted but unlanded problem tickets).
- `.afk-run-state/iter-*.json` files containing `"is_error": true` or `"api_error_status": 429` (= prior iteration hit quota; its work is likely partial).
- Existing `.claude/worktrees/*` directories + matching `git worktree list` entries on `claude/*` branches (= prior subagent worktrees that weren't cleaned up).
- Uncommitted modifications to SKILL.md / ADR / source files that the prior session was mid-authoring.

When any of these are present, the AFK orchestrator has two choices: treat them as "dirty for known reason" and proceed (per Step 6.75 classification), OR halt and surface the state to the user. Today, Step 0 does NEITHER — it proceeds silently past them into Step 1 as if the tree were clean.

The ad-hoc handling in the 2026-04-22 session worked because the user was in an interactive session and could answer `AskUserQuestion`. A pure AFK restart would have to default to one branch silently, which risks either (a) silently orphaning the prior-session partial work by starting fresh, or (b) silently committing half-done work by proceeding as if the dirty state were intentional.

## Symptoms

- Silent pass-through of session-continuity dirty state in Step 0.
- Main agent must ad-hoc the detection + `AskUserQuestion` surfacing at the start of every resumed AFK session.
- No structured detection for `.afk-run-state/iter-*.json` 429 markers even though run-retro's Step 2b explicitly tracks quota-exhaustion signals.
- `.claude/worktrees/*` directories accumulate across sessions; `git worktree list` shows stale branches never cleaned up.

## Workaround

Main agent ad-hoc at session start via `AskUserQuestion` with options:
1. Resume the prior work (land the drafted files as iter 1).
2. Discard the draft and restart from scratch.
3. Leave alone and work lower-priority items.
4. Halt the loop — too much dirty state to proceed.

Observed 2026-04-22: the user chose option 1 ("Land ADR-041 as iter 1"), and the session produced the ADR-041 landing commit (8ad3d3b) cleanly. But the detection path was not in the skill — it was in the main-agent's situational reasoning.

## Impact Assessment

- **Who is affected**: Any user of `/wr-itil:work-problems` who restarts an AFK session after a quota / error / interruption.
- **Frequency**: Directly proportional to 429 / quota-exhaustion events. Observed 1× in this session; as the AFK loop pattern scales, this will recur.
- **Severity**: Moderate. The ad-hoc main-agent handling IS workable today, but only because sessions are interactive enough to ask. A true-AFK restart (e.g. a background-daemon loop hitting 429 and re-spawning itself) has no user to ask and would either drop the partial work or commit it prematurely. JTBD-006 "progress continues without me being present" implies Step 0 should know about session continuity, not delegate to on-the-fly reasoning.
- **Analytics**: 1 observed detection this session; expected rate ~1 per AFK-session-quota-exhaustion event. As ADR-041 ships (2026-04-22), quota-exhaustion becomes the natural stop condition, so this detection fires more frequently going forward.

## Root Cause Analysis

### Preliminary Hypothesis

Step 0 was scoped for the single "did origin move under us" failure mode (P040). The broader category — "did the prior session leave state that changes what iter 1 should do" — was not considered. The fix is to extend Step 0 with a session-continuity detection pass:

1. Enumerate signals:
   - `git status --porcelain` + filter by path heuristics (`docs/decisions/*.proposed.md`, `docs/problems/*.md`, uncommitted SKILL.md / ADR / source edits).
   - `.afk-run-state/iter-*.json` check for `is_error: true` / `api_error_status >= 400`.
   - `git worktree list` filter for `claude/*` branches + matching `.claude/worktrees/*` dirs.

2. When signals exist, emit a structured Prior-Session State report:
   - Category per signal (untracked-ADR, untracked-problem, 429-iter-state, stale-worktree, uncommitted-source).
   - Path + brief summary.

3. Route on interactive-vs-AFK:
   - **Interactive**: `AskUserQuestion` with 4 options (resume / discard / leave + lower-priority / halt).
   - **Non-interactive / AFK**: halt the loop with the Prior-Session State report in the AFK summary. Per ADR-013 Rule 6 fail-safe: ambiguous state requires user input; non-interactive recovery would mask the bug this check is meant to surface. Matches Step 6.75's "dirty for unknown reason → halt" stance but at the Step 0 layer.

### Investigation Tasks

- [ ] Catalogue all prior-session-partial-work signals. Current list: untracked `*.proposed.md`, untracked `docs/problems/*.md`, `.afk-run-state/iter-*.json` error files, `.claude/worktrees/*` dirs + `git worktree list` entries, SKILL.md / source file modifications. Any others?
- [ ] Decide the AFK fail-safe: halt with report (per hypothesis above) vs attempt auto-resume (e.g. land any draft-ADR on the first iter, matching this session's `AskUserQuestion` resolution). Halting is safer but blocks progress; auto-resume is more aggressive but risks committing half-done work.
- [ ] Extend `packages/itil/skills/work-problems/SKILL.md` Step 0 with the session-continuity detection + `AskUserQuestion` / AFK-halt branches.
- [ ] Coordinate with Step 6.75 semantics so a dirty state that Step 0 resolves-with-user-confirmation becomes a "dirty-for-known-reason" from Step 6.75's perspective (not a re-halt after the first iteration commits).
- [ ] Bats coverage: contract-assertion bats for the Step 0 extensions — asserts the detection paths are named, the signals are enumerated, and the `AskUserQuestion` / AFK-halt branches exist.

### Fix Strategy

**Shape**: Skill — improvement stub (Stage 2 Option 2 per P075).

**Target file**: `packages/itil/skills/work-problems/SKILL.md` Step 0.

**Observed flaw**: Step 0 handles `git fetch origin` + divergence but NOT prior-session partial-work (untracked ADRs, `.afk-run-state/iter-*.json` error files, stale worktrees, uncommitted SKILL.md / source edits).

**Edit summary**: Extend Step 0 with a session-continuity detection pass after the fetch/divergence check. Enumerate the signal set (untracked `*.proposed.md`, untracked `docs/problems/*.md`, `.afk-run-state/iter-*.json` with `is_error: true`, `git worktree list` filtered on `claude/*`, uncommitted edits to SKILL.md / source / ADR paths). Route interactive via `AskUserQuestion` with the 4-option branch (resume / discard / leave-and-lower-priority / halt). Route AFK via halt-with-report per ADR-013 Rule 6 fail-safe.

**Evidence**:
- 2026-04-22 ADR-041 landing session: prior session hit 429 on iter-p103; left `docs/decisions/041-...proposed.md` untracked + `.afk-run-state/iter-p103.json` with `"is_error": true, "api_error_status": 429` + `.claude/worktrees/upbeat-keller` on branch `claude/upbeat-keller@a36a084`. Main agent handled via ad-hoc `AskUserQuestion` at session start.
- Step 0 preflight ran cleanly (origin divergence: none) but emitted no signal about the partial work.
- Pre-existing `.claude/settings.json` M state (cosmetic plugin reorder from prior session) also fell outside Step 0's detection — the agent had to inspect + decide independently.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: ADR-041 (landed 2026-04-22, commit 8ad3d3b) — quota-exhaustion becomes the primary AFK stop condition under ADR-041's halt-on-exhaustion rule, so this ticket's fix is more load-bearing post-ADR-041.
- **Composes with**: P040 (Step 0 origin-divergence — same step, adjacent concern), P107 (mid-batch marker expiry — different step but shares the "session continuity" theme), P086 (retro-on-exit in iteration subprocess — the producer of `.afk-run-state/iter-*.json`).

## Related

- **ADR-019** (`docs/decisions/019-afk-orchestrator-preflight.proposed.md`) — current Step 0 preflight specification. This ticket extends it.
- **ADR-041** (`docs/decisions/041-auto-apply-scorer-remediations-above-appetite.proposed.md`) — landed 2026-04-22; quota-exhaustion becomes the primary AFK stop condition under Rule 5 halt semantics.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 1 interactive surfacing + Rule 6 non-interactive fail-safe both apply.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — subprocess-boundary iteration pattern. `.afk-run-state/iter-*.json` files are the subprocess output artefacts; their `is_error: true` fields are the signal.
- **P040** (`docs/problems/040-work-problems-does-not-fetch-origin-before-starting.closed.md`) — driver for the current Step 0 origin-fetch; precedent for extending Step 0.
- **P107** (`docs/problems/107-architect-jtbd-edit-gate-markers-expire-mid-batch.open.md`) — adjacent "session continuity" concern at the edit-gate layer.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — "progress continues without me being present" implies Step 0 should know session continuity, not delegate to on-the-fly reasoning.

## Fix Released

**Released**: 2026-04-25 (AFK work-problems iter — P109 worked)

**Shape**: Skill extension + ADR extension (within reassessment window; no new ADR).

**Changes landed**:

- `packages/itil/skills/work-problems/SKILL.md` Step 0 — session-continuity detection subsection added after the fetch/divergence check. Enumerates five signals (untracked `docs/decisions/*.proposed.md`, untracked `docs/problems/*.md`, `.afk-run-state/iter-*.json` with `is_error: true` or `api_error_status >= 400`, stale `.claude/worktrees/*` + `git worktree list` entries on `claude/*` branches, uncommitted modifications to SKILL.md / source / ADR files). Routes interactive via `AskUserQuestion` with 4 options (resume / discard / leave-and-lower-priority / halt); routes AFK via halt-with-report per ADR-013 Rule 6. Detection only — worktree mutation is out of scope.
- `packages/itil/skills/work-problems/SKILL.md` Non-Interactive Decision Making table — new row covering the session-continuity dirty-state branch.
- `packages/itil/skills/work-problems/SKILL.md` Related — P109 cross-reference added.
- `docs/decisions/019-afk-orchestrator-preflight.proposed.md` Mechanism — extension describing the detection pass; within 2026-07-18 reassessment window (no new ADR). Confirmation criterion 5 added pointing at the new bats.
- `packages/itil/skills/work-problems/test/work-problems-preflight-session-continuity.bats` — 16 contract-assertion bats per ADR-037 asserting the five signals are enumerated, routing cites ADR-013 Rule 6, interactive branch names the 4 option categories, and the decision-matrix row is present.
- `.changeset/wr-itil-p109-preflight-session-continuity.md` — minor bump for `@windyroad/itil` (new orchestrator-loop behaviour).

**Gates**: architect + JTBD reviews approved the fix shape before implementation (halt-with-report for AFK; extend ADR-019 rather than create a new ADR; minor changeset bump).

**Verification**: on the next AFK session that restarts after a quota (429) / error / user-cancel with partial work in the working tree, Step 0 should enumerate the signal set in a structured Prior-Session State report and halt the loop (non-interactive) or present the 4-option `AskUserQuestion` prompt (interactive), rather than silently proceeding into Step 1.
