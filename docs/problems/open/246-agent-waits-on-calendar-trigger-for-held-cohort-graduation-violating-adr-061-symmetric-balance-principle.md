# Problem 246: Agent waits on calendar trigger for held-cohort graduation — violates ADR-061 symmetric balance principle

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 9 (Med) — Impact: 3 (Moderate — held cohorts accumulate beyond their actual evidence-based release-readiness; delays compound; user has to manually intervene to trigger graduation when the framework's own principle says graduate now) × Likelihood: 3 (Likely — fired today on 3-entry P087 cohort; pattern matches I001 / I002 manual-graduation precedent earlier this month)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 9/2 = **4.5** (deferred — provisional; ties with P132)
**Type**: technical (agent class-of-behaviour)

## Description

Class-of-behaviour: when held-changeset cohorts in `docs/changesets-holding/` are eligible for graduation per ADR-061 Rule 1 symmetric balance (`release-risk ≤ problem-ticket Priority`) AND no negative evidence has accumulated, the agent waits on the calendar trigger (`≥7-day dogfood`) instead of evaluating actual risk and graduating now.

The "≥7-day dogfood" is a CALENDAR FALLBACK for when risk-scorer evaluation is unavailable. The PRIMARY principle per ADR-061 Rule 1 is symmetric balance: release when current release-risk is at or below the held tickets' Priority. Treating the calendar as primary trigger violates the principle.

Evidence — 2026-05-17 session 4 iter 9 wrap:
- 3-entry P087 atomic-cohort in `docs/changesets-holding/` (Phase 2a + 2b + 3a):
  - Phase 2a held since earlier session (likely 2026-05-16)
  - Phase 2b held since 2026-05-16
  - Phase 3a held just now (iter 9) via ADR-042 Rule 2 auto-remediation when scoring hit 9/9/9 above-appetite
- Auto-remediation rationale (per iter 9 retro): R005 release-coordination drift + R007 user-stated-precondition (Phase 3a depends on Phase 2a/2b released)
- KEY OBSERVATION: if the WHOLE cohort graduates together (atomic-batch per ADR-061 Rule 3b), R007 precondition is satisfied automatically — Phase 3a's dependency on 2a/2b being released is met by atomic release
- KEY OBSERVATION: zero negative signal in Phase 2a + 2b dogfood since hold (days of in-repo source-level exercise; no defect reports)
- Agent's loop-end surface offered "wait for 2026-05-23 OR risk downgrade" as the framework-prescribed default
- User correction (P078 strong-signal): *"Why are we waiting? That seems to go against the principles if you ask me."*

The principle: ADR-061 Rule 1 explicitly says graduate when symmetric balance favors it (release-risk ≤ ticket-Priority). The 7-day floor was a heuristic baseline from I001 / I002 manual graduations — NOT a hard wait condition. When evidence supports earlier graduation, evidence wins over heuristic.

Sibling tickets:
- **P234** (fictional defer rationalization) — different surface (prose-defer in iter outputs); same underlying class (agent treats deferral as default when evidence supports action)
- **P236** (iter queues proceed-vs-defer as direction when framework trigger already fired) — different surface (outstanding_questions queue); same underlying class (agent over-defers framework-resolved decisions)
- **P162** (codify dogfood-graduation criteria) — parent ticket defining the symmetric-balance principle; this ticket captures the agent failing to apply that principle
- **ADR-061** Rule 1 (symmetric balance) — the principle being violated
- **ADR-042** Rule 2 (auto-move-to-holding when above appetite) — the mechanism that placed Phase 3a in holding; correct mechanism but cohort-graduation eligibility check needs to fire ALSO

Distinguishing surface: orchestrator's loop-end Step 2.5 surfacing presents calendar trigger as the primary release option, instead of evaluating actual risk via the just-shipped Phase 2b cohort-aware evaluator (`packages/risk-scorer/scripts/evaluate-graduation.sh`) and presenting the evidence-grounded recommendation.

Preferred fix: orchestrator loop-end Step 2.5 (or Step 6.5 within-appetite drain check) MUST invoke the cohort-aware graduation evaluator against each held cohort. If the evaluator emits `reinstate-from-holding`, the orchestrator graduates AUTOMATICALLY (policy-authorised silent proceed per ADR-013 Rule 5 + ADR-061 Rule 1). The calendar trigger fires ONLY when evaluator cannot reach a verdict (evidence floor not met). NEVER present "wait for calendar" as a primary option when evaluator returns ready-to-graduate.

## Symptoms

- Held cohorts accumulate in `docs/changesets-holding/` past their evidence-based readiness.
- Orchestrator loop-end summary offers "wait for calendar trigger" as an option even when risk-scorer evaluator would graduate.
- User has to manually direct graduation (I001 / I002 precedent + 2026-05-17 incident).
- Risk-scorer's Phase 2b cohort evaluator (just shipped this session, `@windyroad/risk-scorer@0.10.0`) is not consulted at the orchestrator's release-decision points.

## Workaround

User issues direct graduation command. Currently manual.

## Impact Assessment

- **Who is affected**: every orchestrator session that releases work via the held-cohort path. Pattern fires once per cohort accumulation.
- **Frequency**: 3 times in May 2026 alone (I001 2026-05-06, I002 2026-05-11, P087 cohort 2026-05-17).
- **Severity**: Moderate — delays compound; held cohorts grow over time; user has to police the calendar.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit orchestrator Step 2.5 / Step 6.5 SKILL.md surfaces for calendar-vs-evaluator decision ordering
- [ ] Wire the Phase 2b cohort-aware evaluator into Step 6.5 within-appetite drain check (and/or Step 2.5 loop-end emit)
- [ ] Create reproduction test — empty cohort + populated cohort + cohort with evidence floor met → evaluator should emit reinstate; orchestrator should auto-graduate

## Dependencies

- **Blocks**: future held-cohort accumulation will continue to require manual graduation until fixed
- **Blocked by**: none — fix is purely orchestrator-side SKILL.md + evaluator-wire-in
- **Composes with**: P162 (parent principle), ADR-061 Rule 1, ADR-042 Rule 2, ADR-013 Rule 5

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P162** — parent: codify dogfood-graduation criteria
- **P234** / **P236** — sibling defer-class-of-behaviour tickets
- **ADR-061** Rule 1 — symmetric balance principle
- **ADR-042** Rule 2 — move-to-holding mechanism
- **ADR-013** Rule 5 — policy-authorised silent proceed
