# Problem 344: `/wr-itil:work-problems` orchestrator should predicate-check the cited JTBDs of the selected ticket BEFORE dispatching the iter-worker — wasted-iter-dispatch class when JTBDs are unratified

**Status**: Open
**Reported**: 2026-05-31
**Priority**: 6 (Medium) — Impact: 2 (Minor — wasted-iter cost bounded per occurrence; orchestrator continues) × Likelihood: 3 (Possible — fires on any unratified-JTBD ticket selection; accumulates across sessions until predicate-check ships)
**Origin**: internal
**Effort**: M (work-problems SKILL.md Step 0 / Step 3 amendment + predicate helper + behavioural bats coverage)
**WSJF**: 3.0 (re-rated 2026-05-31; was placeholder I=3×L=1; honest grounding lands at S6/L3/M)

## Description

Surfaced 2026-05-31 by direct user direction during session 9 outstanding-questions surface (post-AFK exchange). Captured per the user's "capture as ticket" answer to the queued direction question.

Concrete exemplar: session 9 iter 5 dispatched P082 Phase 1 implementation. The iter spent ~$3.18 / 5min reading the ticket + delegating to architect + JTBD review, only to discover that P082 cites JTBD-001 (Enforce Governance Without Slowing Down) + JTBD-006 (Progress the Backlog While I'm Away) as Decision Drivers, AND both JTBDs were unratified (`.proposed.md` without `human-oversight: confirmed` frontmatter). Per ADR-074 substance-confirm-before-build (applied to JTBDs as decision drivers), the iter correctly skipped — but the discovery cost the full dispatch overhead.

The wasted-dispatch class: iter spends discovery cost re-confirming substrate that the orchestrator could check FOR THE COST OF a `grep` against the ticket's `Decision Drivers` / `JTBD:` / `**Persona**:` references + a frontmatter check on the cited JTBD files. The orchestrator's Step 0 preflight or Step 3 selection should run this predicate-check and either (a) skip the ticket to next-WSJF actionable + queue a surface-direction outstanding_question for the user, OR (b) run the JTBD ratification drain as a pre-flight iter (similar to how Step 0b handles inbound-discovery cache staleness).

## Symptoms

- Iter subprocess dispatched against a high-WSJF ticket; iter reads ticket; iter delegates to JTBD agent; JTBD agent returns ISSUES FOUND ([Unratified Dependency] flag); iter skips with `outstanding_questions` queued. Net iter cost: ~$3-5, 5-10min, zero forward progress on the ticket.
- This same class of skip happens repeatedly across sessions while the cited JTBDs remain unratified.
- Cross-iter pattern: multiple sibling tickets citing the same unratified JTBDs all get dispatched + all skip. Aggregated cost across an AFK loop ≈ N × per-skip cost.

## Workaround

User manually runs the JTBD ratification drain (`/wr-jtbd:confirm-jobs-and-personas`) before invoking work-problems, OR manually selects a different ticket that doesn't cite unratified JTBDs.

## Impact Assessment

- **Who is affected**: every user invoking `/wr-itil:work-problems` whose backlog contains high-WSJF tickets citing unratified JTBDs.
- **Frequency**: every AFK loop where the top-WSJF ticket cites unratified JTBDs (frequent — JTBD ratification debt accumulates).
- **Severity**: HIGH in aggregate — session 9 had ~$3 wasted in a single iter; multi-session accumulation is uncapped.
- **Analytics**: session 9 iter 5 P082 dispatch is the in-session exemplar; iter 6 P341+P342 also surfaced the JTBD ratification debt at JTBD review time (but proceeded because substance was independently PASS).

## Root Cause Analysis

`/wr-itil:work-problems` Step 3 (ticket selection) selects highest-WSJF in the highest non-empty tier. The selection criteria are PURELY:
- WSJF score (descending)
- Known-Error-first within the same WSJF tier
- Effort divisor ascending
- Reported date ascending
- ID ascending

There is NO check for "are the JTBDs this ticket cites in a ratifiable state". The check happens only inside the iter subprocess after dispatch (via the JTBD review subagent).

The required predicate-check shape:

1. Read the selected ticket file.
2. Extract cited JTBD IDs from `Decision Drivers` section, `**JTBD**:` frontmatter field (if present), and `**Persona**:` references.
3. For each cited JTBD ID, read its `.proposed.md` (or `.accepted.md`) frontmatter and check for `human-oversight: confirmed`.
4. If ANY cited JTBD is unratified → route the ticket to skip (queue surface-direction outstanding_question naming the unratified JTBDs + recommended next action of running the ratification drain).
5. Loop back to Step 3 with the next-WSJF actionable.

This mirrors the existing Step 0b inbound-discovery cache staleness pre-flight pattern — predicate-check at the orchestrator layer, NOT at the iter-subprocess layer.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next `/wr-itil:review-problems`
- [ ] Amend `/wr-itil:work-problems` SKILL.md Step 3 (selection): add the JTBD-ratification predicate-check before delegating to iter-worker. Implementation likely a new helper script `packages/itil/scripts/check-ticket-jtbd-ratification.sh` invoked via ADR-049 shim.
- [ ] Decide skip vs auto-drain: should the orchestrator skip + queue (lighter; user decides) OR auto-promote the JTBD drain as a pre-flight iter (heavier; analogous to Step 0b auto-promote)? Recommend skip + queue for first cut; auto-drain may surface as a deviation-candidate after dogfood
- [ ] Behavioural bats coverage: assert SKILL.md Step 3 prose names the predicate; assert helper script correctly identifies unratified JTBDs; assert orchestrator routes to next-WSJF actionable rather than dispatching
- [ ] Consider sibling-class: same gap exists for ADRs cited as Decision Drivers (ADR-074 master class). Should the predicate-check extend to "are all cited ADRs ratified"? Defer to follow-on ticket if this pattern proves out for JTBDs first.
- [ ] Cross-reference: P342 (iter retros queue observations instead of auto-ticketing) — sibling-class at the retro surface; this ticket is the analogous improvement at the dispatch surface. Both compose with ADR-074 substance-confirm-before-build.

## Dependencies

- **Blocks**: efficient AFK orchestrator dispatch when ticket pool contains unratified-JTBD-dependent items.
- **Blocked by**: (none — fix is bounded to SKILL.md amendment + helper script + bats coverage).
- **Composes with**: ADR-074 (substance-confirm-before-build framework — JTBD-as-driver is the symmetric sibling to ADR-as-driver); P342 (iter retros auto-ticket trust-boundary — same family of "shift work upstream from iter to orchestrator"); P341 (work-problems pre-`ALL_DONE` gate — orchestrator-level gates), Step 0b inbound-discovery pre-flight (existing precedent for orchestrator-layer predicate-check).

## Related

(captured via direct user direction 2026-05-31 during session 9 outstanding-questions surface; user chose "capture as ticket" over "defer" and "implement now via iter dispatch")

- **P342** — sibling-class capture; iter retros queue observations instead of auto-ticketing; same family of orchestrator-vs-iter scope decisions.
- **P341** — sibling-class capture; work-problems pre-`ALL_DONE` gate sequence.
- **ADR-074** — substance-confirm-before-build; JTBD-as-driver is the symmetric sibling surface this ticket targets.
- `packages/itil/skills/work-problems/SKILL.md` Step 3 — amendment locus.
- Future: `packages/itil/scripts/check-ticket-jtbd-ratification.sh` — predicate helper.
- Future: `packages/itil/bin/wr-itil-check-ticket-jtbd-ratification` — ADR-049 shim.
- `packages/itil/skills/work-problems/test/*.bats` — behavioural-coverage locus.
