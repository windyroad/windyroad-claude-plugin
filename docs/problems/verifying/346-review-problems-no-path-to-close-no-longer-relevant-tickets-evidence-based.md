# Problem 346: `/wr-itil:review-problems` has no path to close tickets that are no longer relevant (evidence-based, NOT age-based) — structural outflow gap drives monotonic backlog growth

**Status**: Verification Pending
**Reported**: 2026-05-31
**Priority**: 9 (High) — Impact: 3 × Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems; severity raised at capture per user direction "I'm worried about the trajectory")
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; design + ADR + SKILL.md amendment + behavioural bats — likely M, possibly L if relevance-evidence taxonomy is broad)
**Type**: technical

## Description

The `/wr-itil:review-problems` skill has no path to close tickets that have become **no longer relevant**. The only closure paths today are (a) ship a fix → Verifying → Closed, (b) Park (upstream/external block), or (c) no path at all for "this isn't worth doing", "duplicates X", "incremental optimisation on a working system", or "the thing it's about no longer exists".

The result is a structural outflow gap: capture is automatic and cheap (P078 capture-on-correction, P342 retro auto-capture, ADR-062 inbound discovery, agent-observed mid-iter friction) while close requires real work + budget (~$5-15 / ~15-30 min per iter). The system is structurally guaranteed to grow ticket counts over time. At time of capture (2026-05-31, 47 days in): 102 Open + 40 Known Error + 116 Verifying + 83 Closed + 4 Parked = 345 total; trajectory +2.82/day Active, +2.64/day Verifying, no zero ETA.

User direction at capture (verbatim, 2026-05-31): *"Ok, I'm happy for a skill executed as part of review problems that closes tickets that are no longer relevant, but not just because they are old"*

**Two hard constraints from this direction:**

1. **Executed as part of `/wr-itil:review-problems`** — not a standalone skill. The relevance-check pass becomes a step (likely Step 4.x) of the existing review-problems flow. Composes with WSJF re-rank.
2. **Evidence-based, NOT age-based** — the relevance signal MUST be observable per ADR-026 grounding. "Older than 30 days" is **not** a sufficient signal on its own. Age may be a *gating* condition (don't bother evaluating relevance on a 2-day-old ticket) but never the *closing* condition.

**Candidate "no longer relevant" evidence shapes** (deferred to investigation — full taxonomy via ADR):

- The file / function / path / symbol named in the ticket no longer exists in the codebase (git grep returns empty).
- The framework decision (ADR / RFC) the ticket depends on was superseded by a later decision.
- The observed behaviour the ticket flags is now intentional (e.g. covered by a later ADR's Decision Outcome).
- The ticket is a duplicate of another ticket (same title-keyword shape, same Description hash, same fix locus).
- The "concern" the ticket captures is no longer concerning (e.g. RISK-POLICY.md re-classification dropped it below appetite).
- The ticket is a meta-observation about a SKILL contract that has since been superseded.
- The ticket's underlying root cause was incidentally fixed by an unrelated commit (close-on-evidence pattern that worked for P334/P336).

**Out of scope at capture** (defer to design iter):

- Should the relevance pass auto-close, or surface candidates with options (close-as-stale / close-as-dup-of / close-as-wont-do / keep)?
- Should the pass run on every `/wr-itil:review-problems` invocation, or only when triggered (e.g. queue size threshold, calendar cadence)?
- Per ADR-014 governance: does each relevance-close ride its own commit, or batched?
- Audit trail: how does the closed ticket capture WHY it was closed (evidence cite)?
- Should the pass also surface Verifying tickets that have been Verifying for >N days as candidates for evidence-close (the P334/P336 pattern)?

## Symptoms

- Backlog grows monotonically (+2.82/day Active over the last 7 days; no plateau).
- 102 currently-Open tickets, many from April-May 2026, no closure pressure other than per-ticket work.
- Per-iter outflow ≤ 1 ticket; per-session capture rate often ≥ 1 (retro + correction + observation paths).
- User-perceived asymptote: even after a productive AFK loop closing high-WSJF tickets, the Active count does not drop materially.

## Workaround

(deferred to investigation — current workaround is manual close via `/wr-itil:transition-problem` from Open directly to Closed, but this is one-at-a-time and lacks an evidence-citation contract)

## Impact Assessment

- **Who is affected**: every maintainer running `/wr-itil:work-problems` or reviewing `docs/problems/README.md`; every adopter who sees the backlog as a quality signal.
- **Frequency**: every session reads the backlog; every retro adds to it; every inbound-discovery pass adds to it.
- **Severity**: HIGH in aggregate — the trajectory is unsustainable as a strategy for "get to a useful steady state". Without a structural outflow path, backlog growth is a function of usage, not effort.
- **Analytics**: 47 days of data; 345 tickets created; 25% closed; rising trend on both Active and Verifying lines per the open-problems-tracker dashboard 2026-05-31 16:26.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause: which inflow sources are dominant (external inbound vs retro auto-capture vs agent mid-iter observations vs user-correction captures)
- [ ] Draft a relevance-evidence taxonomy ADR (likely depends on ADR-026 grounding + ADR-022 lifecycle status conventions)
- [ ] Decide auto-close vs surface-with-options (likely surface-with-options for first iteration; auto-close only on highest-confidence evidence shapes like "file no longer exists")
- [ ] Design the audit-trail contract — closed ticket body MUST cite the relevance evidence per ADR-026
- [ ] SKILL.md amendment to `/wr-itil:review-problems` — new Step 4.x (likely after Step 4 re-rate, before Step 5 README refresh)
- [ ] Behavioural bats coverage per ADR-052 — assert each evidence shape correctly identifies / surfaces / closes the right candidate tickets
- [ ] Consider integration with the existing `/wr-itil:transition-problem` mechanism vs a new `/wr-itil:close-as-stale` transition
- [ ] Reproduction test: a synthetic backlog with N "now-stale" tickets + M "still-relevant" tickets → assert relevance-pass closes N, keeps M

## Dependencies

- **Blocks**: (none directly — but the backlog trajectory dashboard improves once this lands)
- **Blocked by**: (none — direction is pinned; design iter can start immediately)
- **Composes with**: ADR-022 (lifecycle status), ADR-026 (grounding), ADR-014 (commit grain — likely one relevance-close per commit, or one batched commit per pass)

## Related

- **P078** — capture-on-correction; one of the inflow sources.
- **P342** — retro auto-capture; the largest internal inflow source.
- **ADR-062** — inbound discovery pipeline; external inflow source.
- **P334**, **P336** — recent evidence-close-on-already-shipped-fix examples; the close pattern is already proven for a sub-class of "no longer relevant" (the fix shipped without the lifecycle close).
- **P262** — README-refresh-discipline hook; composes with the new relevance-close action (each relevance-close mutates the rankings table).
- User direction 2026-05-31 (verbatim above): scope constraints — "executed as part of review problems", "not just because they are old".
- `docs/problems/README.md` — the backlog index whose growth this gap drives.

(captured via /wr-itil:capture-problem; expand at next investigation)

## Fix Strategy

Phase 1 scope per ADR-079: auto-close on ONE evidence shape — "file no longer exists in codebase" — closest analog to P334/P336 close-on-evidence. Subsequent shapes (ADR-supersession, duplicate-of-X, "concern no longer concerning", SKILL-contract-superseded) deferred to sibling tickets per ADR-079 Phase 1 scope discipline.

Implementation surface:
- `docs/decisions/079-evidence-based-relevance-close-pass.proposed.md` — design ADR (captured via /wr-architect:capture-adr; `proposed` status, no `human-oversight: confirmed` per ADR-066 line 50 — orchestrator-level drain ratifies later).
- `packages/itil/scripts/evaluate-relevance.sh` — canonical evaluator body: age gate ≥ 7 days, file-path extraction from well-known repo subdirs, self-reference exclusion, `git ls-files --error-unmatch` existence check, structured `CLOSE-CANDIDATE` / `KEEP` / `SKIP` verdict + exit-code routing (0/1/2/3).
- `packages/itil/bin/wr-itil-evaluate-relevance` — ADR-049 PATH shim (adopter-safe; resolves canonical script via sibling lookup per RFC-009 / P317).
- `packages/itil/scripts/test/evaluate-relevance.bats` — 18 behavioural fixtures per ADR-052 (script existence + shim dispatch + usage / error / age gate / no-extractable-paths / CLOSE-CANDIDATE / KEEP / custom age gate / verdict-shape output contract).
- `packages/itil/skills/review-problems/SKILL.md` Step 4.6 — Relevance-close pass between Step 4.5 (Inbound-discovery) and Step 5 (README rewrite). Iterates open + known-error tickets, invokes the shim, batches CLOSE-CANDIDATE auto-closes into ONE commit per ADR-014 / P139 mirroring `/wr-itil:transition-problems` batch grain.
- `packages/itil/skills/manage-problem/SKILL.md` — lifecycle table Closed row extended with the ADR-079 alternative entry path (Open|Known Error → Closed bypassing Verifying when no fix was released). ADR-022 extension (not modification) per the ADR-026 line 109 precedent.
- `.changeset/p346-evidence-based-relevance-close-pass.md` — `@windyroad/itil` minor.

## Fix Released

Phase 1 shipped in this commit (Open → Verifying via ADR-022 P143 fold-fix amendment — pre-flight checks satisfied inline; root cause + fix strategy + workaround + effort all documented in this ticket body; SKILL + script + shim + bats + changeset + manage-problem extension ride this single commit per ADR-014 single-commit grain).

- **Architect verdict** 2026-05-31: ALIGNED-WITH-NITS (must-do nit: explicit ADR-022 extension cite — done in ADR-079; minor nit: do not auto-stamp `human-oversight: confirmed` — honoured).
- **JTBD verdict** 2026-05-31: ALIGNED across JTBD-001 (under-60s review-flow served by smaller queue), JTBD-006 (AFK pre-flight surface extension; mechanical evidence not judgment-call), JTBD-101 (extensible pattern per evidence shape), JTBD-201 (audit trail preserved).
- **Behavioural second-source**: 18/18 GREEN bats fixtures.
- **Real-backlog smoke test (2026-05-31, 143 open/known-error tickets)**: 6 CLOSE-CANDIDATE (4.2%), 44 KEEP, 93 SKIP — conservative behaviour confirmed; no false-positive closes on tickets with live file references. The 6 CLOSE-CANDIDATEs (P091/P180/P242/P244/P251/P212) reference paths verified absent in `git ls-files`.

Awaiting user verification. Verification path: run `/wr-itil:review-problems` after release lands → confirm Step 4.6 fires the relevance-close pass + correctly batches the surfaced CLOSE-CANDIDATE tickets into one commit + Step 5's README refresh rides the same commit.

Deferred to sibling tickets per ADR-079 Phase 1 scope discipline:
- ADR-supersession evidence shape (a ticket depending on an ADR that has since been superseded by a later decision).
- Duplicate-of-X evidence shape (a ticket whose title-keyword shape / Description hash / fix locus matches another ticket).
- "Concern no longer concerning" evidence shape (RISK-POLICY re-classification dropped severity below appetite).
- SKILL-contract-superseded evidence shape (a ticket whose meta-observation about a SKILL contract has since been resolved by a contract update).
- Verifying-ticket aging surface (P334/P336-class evidence-close for Verifying tickets exercised repeatedly without regression).
