# Problem 266: Agent follows SKILL.md ≤3-no-drain clause despite P250's amended framing when releasable material exists

**Status**: Verifying
**Reported**: 2026-05-18
**Root cause confirmed**: 2026-05-18 (same surface as P250 — `packages/itil/skills/work-problems/SKILL.md` Step 6.5 ≤3-no-drain classification clause)
**Fix released**: 2026-05-18 (`@windyroad/itil@0.32.3`, source commit `e9fb7f0` "fix(itil): P250 Step 6.5 drain on releasable material, not residual band"; version-packages commit `4a0e1b7` 2026-05-17 21:29 UTC; PR #141 merge commit `4df08ec`; current cache `@windyroad/itil@0.35.3`. Fold-fix transition Open → Verifying per ADR-022 P143 amendment — the SKILL.md amendment + ADR-018 amendment that resolved P250's clause simultaneously resolves P266's agent-behaviour surface since the agent's behaviour is reading SKILL.md. Bats fixture `packages/itil/skills/work-problems/test/work-problems-step-6-5-always-drain.bats` 24/24 green, including the explicit regression guard `SKILL.md no longer contains 'Within appetite (≤ 3/25) — no drain needed' clause` at line 60. Sibling-pattern audit across `packages/**/SKILL.md` found zero residual "below-appetite no-action" clauses encoding accumulation.)
**Priority**: 9 (Mod) — Impact: 3 (Moderate — encodes accumulation against the RISK-POLICY appetite invariant; defers low-risk releases against explicit user direction "If it's low risk, you should release") × Likelihood: 3 (Possible — fires when an iter ships a changeset and Step 6.5 evaluates within-appetite; observed pattern this session at iter 5 boundary) (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (Step 6.5 SKILL.md contract amendment — drop the "≤3 within appetite — no drain" classification clause; replace with "drain whenever there is something to release at residual ≤4 within appetite"; bats coverage; sibling pattern to P250 fix amendment) (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 9/2 = **4.5** (raw Priority/Effort retained per README display convention; Open → Verifying on fold-fix per ADR-022 P143 amendment — pre-flight criteria met inline: root cause documented, fix shipped, bats coverage green, sibling audit zero-finding; awaiting in-loop verification window — 5 AFK iterations across ≥2 sessions per § Verification (post-release))

## Description

When `/wr-itil:work-problems` Step 6.5 evaluates the pipeline residual after an iter that produced releasable material (non-empty `.changeset/` + unpushed commit on a `packages/<plugin>/` surface), the agent follows the SKILL.md classification table verbatim:

> - **Within appetite (≤ 3/25)** — no drain needed. Proceed to Step 6.75.
> - **At appetite (= 4/25)** — drain the queue per the Drain action below, then proceed to Step 6.75.
> - **Above appetite (≥ 5/25)** — route to the **Above-appetite branch** below. Do NOT drain.

The "≤ 3 within appetite — no drain" clause is the defective surface. P250 (in Verifying as of session 7 iter 1, 2026-05-18) is the parent ticket capturing exactly this defect at the same Step 6.5 surface. P250's fix-strategy section says "drain whenever there is something to release; bats coverage for the new drain condition; potential ADR-018 amendment to align cadence framing with no-accumulation invariant".

Observed 2026-05-18 work-problems session 7 iter 5 boundary: iter shipped `feat(itil): P087 Phase 3c (P239) — bats doc-lint per plugin` + changeset `.changeset/p087-p239-phase-3c-doc-lint.md` (patch bump @windyroad/itil). Pipeline residual at Step 6.5 evaluated to 2/25 (commit=2 push=2 release=2 — within appetite). The orchestrator main turn applied SKILL.md ≤3-no-drain and proceeded to Step 6.75 instead of draining.

User correction at loop end (`/wr-itil:work-problems` Step 2.5 surfacing): "If it's safe (within risk tolerance) then the answer is always release. FFS". The "FFS" signal + class-of-behaviour shape per P078 (strong-signal correction) triggers OFFER-to-capture per CLAUDE.md mandatory rule.

**Class-of-behaviour**: agent over-defends documented SKILL.md framing against user-direction class-of-behaviour signals embedded in the user's own ticket text (P250 fix-strategy paragraph) AND the user's prior corrections that drove P250 in the first place. This is a P132 inverse-P078 trap variant at the SKILL-contract-vs-user-direction surface.

**Composition with P250**: P250 captures the DEFECT (Step 6.5 ≤3-no-drain clause encodes accumulation). P266 captures the META-DEFECT (agent applies the defective clause verbatim despite the fix-in-Verifying carrying the corrected framing). Both should be resolved together — the SKILL.md amendment that resolves P250's fix surfaces simultaneously resolves P266's agent-behaviour surface, since the agent's behaviour is reading SKILL.md.

**Fix**: amend `packages/itil/skills/work-problems/SKILL.md` Step 6.5 Classification clause + amend `docs/decisions/018-release-cadence.proposed.md` (ADR-018) cadence framing to align with the no-accumulation invariant. Replace the three-band classification (≤3/=4/≥5) with two-band: (within-appetite ≤4 + releasable material exists → drain) and (above-appetite ≥5 → ADR-042 auto-apply). The "no drain when residual is very low" framing is the load-bearing defect; remove it.

## Symptoms

- Iter ships changeset; Step 6.5 evaluates within-appetite ≤3; agent proceeds without drain; commits accumulate; user has to ask for drain explicitly at loop-end.
- Loop-end Step 2.5 queues deviation-approval entries asking the user to authorise drain when the answer is structurally "yes, always, when safe".

## Workaround

User explicit direction at loop-end: "If it's safe (within risk tolerance) then the answer is always release. FFS." Applied as one-time-override per ADR-044 category 3 for the current session — drain immediately at Step 6.5.

## Impact Assessment

- **Who is affected**: anyone running `/wr-itil:work-problems` AFK loops; the orchestrator main turn defers releases.
- **Frequency**: fires on every iter that ships a changeset at low risk.
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — same fix path as P250 (Step 6.5 SKILL.md classification amendment)
- [ ] Create reproduction test (bats fixture: iter ships changeset, residual=2/25, drain MUST fire)
- [ ] Check sibling P250 in-Verifying status; consider folding P266 into P250's SKILL.md amendment when it lands
- [ ] Audit SKILL.md surface for other "below-appetite no-action" clauses that encode accumulation (sibling pattern)

## Dependencies

- **Blocks**: (none observed yet)
- **Blocked by**: (none — P250 fix is in Verifying; this can ship as standalone amendment)
- **Composes with**: P250 (parent defect at Step 6.5 surface), P132 (inverse-P078 trap class), P078 (capture-on-correction signal), ADR-013 Rule 5 (policy-authorised silent proceed), ADR-018 (release cadence framing), ADR-044 (framework-resolution boundary)

## Related

(captured inline during /wr-itil:work-problems session 7 loop-end Step 2.5 user-direction routing)

- P250 — sibling at same Step 6.5 surface; in Verifying as of this session iter 1
- P132 — inverse-P078 trap meta-class
- P078 — strong-signal correction → OFFER-to-capture (this ticket IS the offer-result)
- ADR-018 — release cadence framing (potential amendment target)
- ADR-013 Rule 5 — policy-authorised silent-proceed (drain-when-safe IS Rule 5 behaviour)
- ADR-044 — framework-resolution boundary; the "drain when safe" decision is framework-resolved, NOT user-asked
- `packages/itil/skills/work-problems/SKILL.md` Step 6.5 — defective classification clause
