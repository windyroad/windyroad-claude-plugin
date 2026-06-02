# Problem 293: Generalise ADR-019 preflight from "fetch + ff-only divergence" to "get the repo into a clean state before starting"

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — the current preflight handles the divergence case correctly; the gap is that it doesn't cover the broader "repo isn't clean" situations, so an orchestrator can start work on an untidy tree; recoverable, not breaking) × Likelihood: 3 (Possible — every AFK orchestrator start; uncommitted-work and messy-tree states occur regularly)
**Effort**: M — ADR-019 amendment generalising the preflight + reconciling with P109 (session-continuity detection) + the work-problems Step 0 implementation
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0)

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-019 (AFK orchestrator preflight: fetch-origin and divergence handling) was presented for human-oversight confirmation, the user declined to confirm it as-recorded and directed a generalisation:

> User direction 2026-05-25 (drain): *"what I really want is to get the repo into a clean state before starting. Sometimes that's a pull, sometimes that needs some commits. Sometimes it's in a mess and needs decision input via AskUserQuestion."*

ADR-019 currently decides a narrow slice: mandatory `git fetch` + `ff-only` pull on trivial divergence, stop-and-report on non-fast-forward. The user wants the preflight reframed as **"get the repo into a clean state before starting,"** with (at least) three branches:

1. **Pull** — origin moved, trivial fast-forward (the current ADR-019 case).
2. **Commit** — there is uncommitted work that should be committed before starting (e.g. a prior session left staged/working-tree changes that belong in a commit).
3. **AskUserQuestion** — the tree is genuinely messy (ambiguous uncommitted state, non-fast-forward divergence, partial prior-session work) and needs human decision input on how to clean it up.

This overlaps and should reconcile with **P109** (session-continuity detection pass — already in work-problems Step 0, which enumerates prior-session partial-work signals and halts/prompts). The generalised ADR-019 is the umbrella "clean-state preflight" that P109's detection feeds into.

ADR-019 is **left unoversighted** (P283/ADR-066 marker withheld) until this generalisation lands and the amended decision is re-confirmed — mirroring P287/P289/P290/P292's pattern.

## Symptoms

(deferred to investigation)

- ADR-019 Decision Outcome only covers fetch + ff-only divergence + stop-on-non-ff; no branch for "uncommitted work should be committed first" or "messy tree → AskUserQuestion."
- work-problems Step 0 already has a P109 session-continuity detection pass that halts on prior-session partial work (AFK) / prompts via AskUserQuestion (interactive) — but ADR-019 (the decision) doesn't frame the broader clean-state goal these implement.

## Root Cause Analysis

### Investigation Tasks

- [ ] Amend ADR-019 to reframe the decision as "get the repo into a clean state before starting," enumerating the branches: trivial-pull (ff-only), commit-existing-work, and messy-tree → AskUserQuestion (interactive) / halt-with-report (AFK).
- [ ] Reconcile with P109 (session-continuity detection): P109's signal enumeration feeds the clean-state branch decision; ADR-019 is the umbrella decision, P109 the detection mechanism. Avoid duplication / contradiction.
- [ ] Define the "needs commit" branch precisely: when is uncommitted work auto-committable vs needs-user-decision? (Likely: clean it only when provenance is unambiguous; otherwise AskUserQuestion / halt per ADR-013 Rule 6.)
- [ ] Verify consistency with the work-problems Step 0 implementation (fetch/divergence + session-continuity + README reconcile + auto-migrate) — the amend should describe the live behaviour, generalised.
- [ ] Re-confirm amended ADR-019 via `/wr-architect:review-decisions` → write `human-oversight: confirmed`.

## Dependencies

- **Blocks**: ADR-019 human-oversight confirmation (held until generalisation lands).
- **Blocked by**: none.
- **Composes with**: P109 (session-continuity detection — the detection mechanism this umbrella decision frames), work-problems Step 0 (the live preflight implementation), ADR-013 Rule 6 (non-interactive fail-safe / AskUserQuestion routing), P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P109** — session-continuity detection pass (work-problems Step 0); the detection mechanism the generalised ADR-019 frames.
- **P287 / P289 / P290 / P291 / P292** — sibling drain-surfaced reworks (same "withhold marker + capture rework" pattern).
- **ADR-019** (`docs/decisions/019-afk-orchestrator-preflight.proposed.md`) — amendment target.
- **ADR-013** Rule 6 — the interactive-vs-AFK routing the messy-tree branch uses.
