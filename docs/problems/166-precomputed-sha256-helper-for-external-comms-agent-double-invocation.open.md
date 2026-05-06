# Problem 166: Precomputed-sha256 helper for `wr-risk-scorer:external-comms` agent invocations to eliminate double-invocation cost

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 3 (Low) — Impact: Minor (1) x Likelihood: Almost certain (4)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

**WSJF**: (3 × 1.0) / 1 = **3.0**
**Type**: technical

> Captured 2026-05-04 by `/wr-itil:work-problems` AFK loop iter 7 surfacing pass per user direction "capture all four now". Sibling finding from iter 4 P157 commit gate cycle. Cost-optimisation sibling to P163 (which captures the underlying placeholder-key bug).

## Description

Every commit-gate cycle invoking `wr-risk-scorer:external-comms` (per ADR-028 / P064 — fires on changeset writes, gh issue/pr/api/comment, npm publish) currently fires the agent **twice**:

1. **First fire**: orchestrator invokes agent with the draft + surface; agent emits `EXTERNAL_COMMS_RISK_VERDICT: PASS` with placeholder marker key (per P163 — agent's tool surface lacks Bash so cannot compute sha256).
2. **Workaround**: orchestrator computes `sha256(draft+'\n'+surface)` in Bash.
3. **Second fire**: orchestrator re-invokes agent with the precomputed key explicitly named in the prompt; agent emits PASS with the correct key; PostToolUse hook accepts; gate unlocks.

Cost: ~$0.05 per commit-gate cycle in additional agent fire (small per-cycle, but compounds — 5 cycles this AFK loop = ~$0.25; over a year of contributor activity at ~5 commits/day across 3 contributors = ~$300/year).

Optimisation candidate: ship a precomputed-sha256 helper that the orchestrator (or commit-gate caller) invokes BEFORE firing the agent — single fire suffices. Two implementation shapes:

1. **Helper in `packages/shared/lib/`**: `compute_external_comms_marker_key.sh` taking `draft` + `surface` as args, emitting hex sha256 to stdout. Caller wraps the agent invocation: `sid=$(compute_external_comms_marker_key "$draft" "$surface"); agent_invoke --include-key "$sid"`. Single fire.

2. **Hook-side compute**: PostToolUse hook reads agent verdict + computes the key from the observed input (Write content), bypassing the agent's contract entirely on the key side. The agent emits PASS without a key; hook computes the key from runtime state. Lower friction; sidesteps P163 entirely.

Option 2 is cleaner architecturally (agent doesn't need to know about marker keys; hook handles all the marker-write logic). Option 1 is closer to the existing surface contract.

## Symptoms

- Every changeset commit cycle: 2× `wr-risk-scorer:external-comms` agent fires where 1× would suffice.
- Per-cycle cost ~$0.05 in agent invocation (token + duration).
- ~5+ instances per AFK loop. Compounds across contributors and time.

## Workaround

The double-invocation pattern itself IS the workaround for P163. P166 is the optimisation; P163 is the underlying bug.

## Impact Assessment

- **Who is affected**: Every commit-gated surface caller. Compounds across all contributors.
- **Frequency**: Every commit / changeset / release / PR-comment / npm publish gate cycle.
- **Severity**: Minor — cost is small per-cycle, recoverable, doesn't break anything functionally.
- **Likelihood**: Almost certain — pattern fires 100% of the time today.

## Root Cause Analysis

(Deferred to investigation.) Composes with P163 root cause (agent tool surface gap).

### Investigation Tasks

- [ ] Architect review: Option 1 (helper) vs Option 2 (hook-side compute). Likely Option 2 per architectural cleanliness.
- [ ] Implement chosen option + behavioural bats covering the single-fire path.

## Fix Strategy

(Deferred to investigation.)

## Dependencies

- **Blocks**: (none)
- **Blocked by**: P163 (sibling — placeholder marker key bug; if resolved via Option 1/2/3 of P163's investigation, this ticket may close as duplicate; if resolved by documenting the explicit-precompute pattern, this ticket lands the helper)
- **Composes with**: P064 (parent — external-comms gate), ADR-028 (agent surface contract), ADR-013 Rule 5 (policy-authorised gate), P163 (sibling — placeholder-key bug)

## Related

- ADR-028 — external-comms agent surface contract.
- P064 — parent problem.
- P163 — sibling (placeholder-key root cause).
- iter 4 P157 retro — `docs/retros/2026-05-04-p159-iter.md`.
- iter 6 P159 retro — same file (same cycle observed there too).

## Change Log

- **2026-05-04** — Opened by orchestrator's main turn at end of `/wr-itil:work-problems` AFK loop iter 7 per user direction "capture all four now". Sibling finding from iter 4 P157 commit gate. Skeleton ticket; investigation deferred. Companion to P163.
