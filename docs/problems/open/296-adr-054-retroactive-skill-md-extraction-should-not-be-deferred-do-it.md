# Problem 296: ADR-054 — the retroactive SKILL.md extraction should NOT be deferred behind P081 Layer B; do it

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — SKILL.md runtime bloat persists indefinitely while the extraction sits deferred; the declarative-first policy + advisory detector are in place but the existing bloated SKILLs never get cleaned; context-budget cost, not breakage) × Likelihood: 3 (Likely — every SKILL.md invocation pays the bloat; the deferral guarantees zero cleanup)
**Effort**: L — retroactive extraction of maintainer-rationale from runtime-necessary content across the existing SKILL.md corpus, per the ADR-054 content-classification taxonomy
**WSJF**: 6/4 = **1.5** (Open multiplier 1.0)
**Type**: technical

## Description

Surfaced during the P283/ADR-066 ADR-oversight drain (2026-05-25). When ADR-054 (SKILL.md runtime budget policy) was presented for human-oversight confirmation, the user confirmed the policy but **rejected the deferral**:

> User direction 2026-05-25 (drain): *"yes, but retroactive extraction should not have been deferred. Deferred work never happens. So either do it, or don't do it. Defer = don't do it. In this case do it."*

ADR-054 chose "declarative-first ADR + advisory detector; **extraction deferred behind P081 Layer B**". The user's correction: **deferred work never happens** — deferring the retroactive extraction is functionally equivalent to deciding not to do it. So either commit to doing it now or explicitly decide against it. The user's call: **do it.** Same principle family as P295 / memory `feedback_automatic_cadence_or_it_doesnt_happen` ("no cadence → doesn't happen"; "defer → doesn't happen").

ADR-054 is **left unoversighted** (P283/ADR-066 marker withheld) until amended (remove the deferral; the retroactive extraction is in-scope) and re-confirmed.

## Symptoms

(deferred to investigation — ironically)

- ADR-054 ships the content-classification taxonomy + advisory detector but parks the actual retroactive extraction behind "P081 Layer B", which has no committed timeline.
- Existing SKILL.md files (manage-problem, work-problems, etc. — many are 200-500+ lines) still mix runtime-necessary steps with maintainer-facing rationale (P097), paying the bloat on every invocation.

## Root Cause Analysis

### Investigation Tasks

- [ ] Amend ADR-054: remove the "extraction deferred behind P081 Layer B" clause; the retroactive extraction is in-scope. (If there is a genuine blocker that makes it impossible now, say so explicitly and decide NOT to do it — don't park it as "deferred".)
- [ ] Apply the content-classification taxonomy to the existing SKILL.md corpus: extract maintainer-rationale into REFERENCE.md (or equivalent), keep SKILL.md runtime-necessary. Prioritise the largest/most-invoked SKILLs (work-problems, manage-problem).
- [ ] Verify the advisory detector measures the post-extraction budget correctly.
- [ ] Re-confirm amended ADR-054 via `/wr-architect:review-decisions`.

## Dependencies

- **Blocks**: ADR-054 human-oversight confirmation (held until amended).
- **Blocked by**: P081 Layer B was the cited blocker — investigate whether it genuinely blocks the extraction or whether the extraction can proceed independently (likely the latter: extraction is a content move, not dependent on a test harness).
- **Composes with**: P081 (structural-tests / SKILL-content master), P097 (SKILL.md mixes runtime + rationale), P295 + memory `feedback_automatic_cadence_or_it_doesnt_happen` (the "deferred/no-cadence → never happens" principle), P283/ADR-066 (the drain that surfaced this).

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain)

- **P287 / P289 / P290 / P291 / P292 / P293 / P294 / P295** — sibling drain-surfaced reworks.
- **P295** + memory `feedback_automatic_cadence_or_it_doesnt_happen` — same "deferred work never happens" principle.
- **ADR-054** (`docs/decisions/054-skill-md-runtime-budget-policy.proposed.md`) — amendment target.
- **P097 / P081** — the SKILL.md bloat + structural-content master tickets.
