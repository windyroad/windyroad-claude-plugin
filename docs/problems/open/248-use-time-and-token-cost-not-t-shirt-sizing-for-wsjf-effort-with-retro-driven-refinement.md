# Problem 248: Use time and token cost (not t-shirt sizing) for WSJF effort, with retro-driven estimation refinement

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 6 (Medium) — Impact: 2 (Minor — improves WSJF estimation accuracy; current t-shirt sizing functions but allows no calibration loop) × Likelihood: 3 (Possible — exercised on every `/wr-itil:review-problems` re-rate pass and every `/wr-itil:work-problem` selection; estimation drift compounds with backlog age)
**Effort**: M (schema extension on `.afk-run-state/iter*.json` + per-ticket tally + retro-step calibration feedback hook)
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0; re-rated 2026-05-17 from placeholder during `/wr-itil:review-problems`)
**Type**: technical

## Description

Currently, for problem WSJF we use t-shirt sizing (S/M/L/XL) for how much effort we think they will be. This is vague and subjective and does not allow for refinement.

Instead we should use **time or token cost**. Specifically:
- For an **open problem**, the effort should be our estimate for the **root cause analysis**.
- For **known errors**, it should be the effort to implement the **RFC** (in time or tokens).

The system should then keep a **tally of the time or token spent doing root cause analysis**. Similarly a tally should be kept of the **time or token spent implementing an RFC**.

The retrospective can then use this data to **refine the estimation process**, so that over time the **RMS of the estimation error is reduced**.

If possible, I'd love it to do **both time and tokens** as both are valuable for me to know.

The retro can the[n use these tallies to feed estimation accuracy improvement over sessions] *(user's description ended mid-sentence; preserving as captured per ADR-026 grounding — the intent is clear from the prior sentence about retro-driven RMS reduction; the truncation can be expanded at the next investigation pass)*.

## Symptoms

(deferred to investigation)

Initial signals already in evidence this session alone:
- Session 4 burned ~$118 across 9 iters; per-iter cost ranged $4.82 to $28.05. T-shirt sizing buckets (M=Medium) cannot represent that 6x spread.
- P162 was estimated M and shipped Phase 1+2a+2b+3 across 3 sessions (multi-iter L effective).
- P087 was estimated L and shipped across 4 phases this session alone (still Open with phases remaining).
- Multiple tickets were re-rated mid-session as scope clarified — t-shirt buckets don't make refinement observable as a delta.

## Workaround

Currently manual: user reads cost summaries, mentally calibrates t-shirt estimates per ticket. No persistent feedback loop. Iteration-cost data IS captured per iter (`.afk-run-state/iter*.json` carries `total_cost_usd` + `duration_ms` + token totals — see `/wr-itil:work-problems` Step 5 cost-metadata extraction contract), but is not attributed back to source tickets.

## Impact Assessment

- **Who is affected**: every WSJF prioritization decision (every /wr-itil:work-problems iter selection; every /wr-itil:review-problems re-rank). The estimation noise compounds across the whole backlog.
- **Frequency**: every retro that touches WSJF; every iter that picks based on WSJF.
- **Severity**: (deferred to investigation) — initial signal: high. Estimation accuracy directly affects what work gets done first.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — why was t-shirt sizing chosen originally? (Cross-reference P047 closed-ticket history for the prior accuracy attempt and what closed it.)
- [ ] Design the schema change — how does Open vs Known Error effort split work? (per Description: Open = RCA effort estimate; Known Error = RFC implementation effort estimate; both in time AND tokens.)
- [ ] Design the tally accumulation mechanism — `.afk-run-state/iter*.json` per-iter data is the source; what aggregates per-ticket? (Likely a `## Effort Tally` section on the ticket body, appended per relevant iter; sums of time+tokens for RCA phase and separately for RFC implementation phase.)
- [ ] Design the retro-driven refinement — what does the retro do with the data? (Compare estimate vs actual per closed/transitioned ticket; compute RMS over recent N tickets; surface trend in retro summary; potentially auto-adjust default-effort heuristic per pattern type.)
- [ ] Create reproduction test — bats fixture: ticket created with estimated_time + estimated_tokens; iter logs actual; retro computes RMS over closed tickets.
- [ ] Schema migration plan — how do existing tickets (with t-shirt sizes) migrate? Both-axes coexistence vs hard cutover?
- [ ] WSJF formula change — current `WSJF = Priority / Effort-divisor` (divisor 1/2/3/5 per S/M/L/XL); new formula needs to consume time-or-token-cost as the effort denominator. Both axes (time AND tokens) suggests EITHER use one as primary + report the other, OR compose them.

## Dependencies

- **Blocks**: any future WSJF estimation accuracy improvement work (this is the foundation)
- **Blocked by**: none — fix is a schema + tally + retro-step extension
- **Composes with**: P162 (parent for dogfood-graduation effort estimation), P234 / P246 (effort estimation feeds the "do we have evidence" judgment), P076 (transitive dependencies — separate dimension but composes)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P047** (closed, `docs/problems/closed/047-wsjf-effort-bucket-accuracy-gaps.md`) — prior ticket about t-shirt effort bucket accuracy. Cross-reference its closure rationale; this ticket may be the sibling-or-supersede of P047's resolution.
- **P076** (verifying) — WSJF does not model transitive dependencies; different dimension but same WSJF-refinement axis.
- **P138** (verifying) — README WSJF row order; tangential.
- **P162** — codify dogfood-graduation criteria (sibling: effort estimation is one input to the symmetric balance principle).
- `.afk-run-state/iter*.json` — per-iter cost metadata source (existing surface, ready to feed the tally).
- `/wr-itil:work-problems` SKILL.md Step 5 — cost-metadata extraction contract (already extracts `total_cost_usd` + `duration_ms` + `usage.*` fields).
- `/wr-retrospective:run-retro` SKILL.md — the retro that would consume the per-ticket tallies and emit RMS-of-estimation-error trend.

**Note on description truncation**: the user's captured args ended mid-sentence with "The retro can the". The prior sentence already established the retro's role (use tallies to refine estimation, reduce RMS over time). The truncated fragment likely intended to repeat or extend that point. Captured verbatim per ADR-026 grounding; expand at next investigation pass.
