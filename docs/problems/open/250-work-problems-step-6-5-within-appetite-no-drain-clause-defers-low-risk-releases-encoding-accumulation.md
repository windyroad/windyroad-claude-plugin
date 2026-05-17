# Problem 250: work-problems Step 6.5 "≤3 within appetite — no drain" clause defers low-risk releases, encoding accumulation

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

When we are working problems, I often see risk scoring actions (which is good), but I often see it deciding to NOT release because it's not close to risk threshold. *[parsed from "deciding to to release" — typo / dictation; corrected to "deciding NOT to release" based on the following sentences.]*

That's not what I want. **You don't want to accumulate risk. If it's low risk, you should release.**

### The defective contract clause

`/wr-itil:work-problems` SKILL.md Step 6.5 release-cadence classification:

> - **Within appetite (≤ 3/25)** — no drain needed. Proceed to Step 6.75.
> - **At appetite (= 4/25)** — drain the queue per the Drain action below, then proceed to Step 6.75.
> - **Above appetite (≥ 5/25)** — route to the **Above-appetite branch** below.

The "≤3 within appetite — no drain" clause is the defective surface. It encodes "below threshold = no action" when the actually-correct framing is "low cost to release + low risk = release now". Accumulating low-risk changes increases pipeline state without any safety benefit; future drains then carry more changes per cycle, which itself increases the residual-risk envelope of the cumulative push/release.

The user's principle: **low risk + low cost to act = act now, not later**. Don't accumulate.

### Sibling pattern

This is the SAME meta-class as P246 (calendar trigger for held cohort) + P247 (run-retro Step 3 Branch B leave-as-is) + P234/P145/P148 (fictional defer rationalisations). The shared pattern: SKILL contracts encode "wait" / "defer" / "no action" clauses when the right action is "act now because low cost". The threshold is treated as the lower bound for action when it should be treated as the upper bound for safety.

### The correct framing

The risk-scorer's output (`commit=X push=Y release=Z`) IS the evidence. When the evidence shows low risk AND there are unpushed commits or queued changesets, the action is RELEASE (drain). The threshold gates the upper-bound safety check (above-appetite needs remediation); it should not gate the lower-bound drain decision.

Proposed fix shape: replace the three-band classification with a binary:
- **Above appetite (≥ 5/25)** — route to Above-appetite branch (existing ADR-042 auto-apply).
- **Otherwise** — drain. The "at appetite" vs "within appetite" distinction is meaningless from a release-action perspective; both should drain.

OR more granular:
- **Above appetite** — route to ADR-042 auto-apply
- **Anything unpushed OR any changeset queued** — drain (regardless of residual band)
- **Empty queue + nothing unpushed** — no drain (because there's literally nothing to drain)

Both shapes treat the residual band as a safety check, not a release gate. ADR-018 (release-cadence policy parent) may need amendment to drop the "at-appetite-only drain" semantics.

## Symptoms

(deferred to investigation)

Initial signals from session 4 itself:
- Multiple iters scored 1/1/1 to 3/3/3 (within appetite) and the orchestrator skipped drain per Step 6.5 contract.
- Cumulative state accumulated: by iter 5 the queue had 2 changesets + 11 unpushed commits before reaching 4/4/4 at-appetite trigger.
- Each drain-trigger required a re-score round-trip with the subagent ($0.15-0.30 each invocation) because the gate had drifted.
- If drain had fired at low-risk earlier, the cumulative drains would have been smaller + simpler + no rescore round-trips.

## Workaround

Currently manual: user catches the "no drain — within appetite" decision + directs the agent to drain anyway. User's session 4 wrap correction ("Why are we waiting?" on P087 cohort) is the worked example.

## Impact Assessment

- **Who is affected**: every /wr-itil:work-problems Step 6.5 invocation that scores ≤3. Fires multiple times per AFK loop.
- **Frequency**: every iter with low-risk changes (most iters; the typical iter is docs-only or small-fix code → scores 1/1/1 to 3/3/3).
- **Severity**: (deferred to investigation) — initial: moderate-to-high. Accumulation is the failure mode the I001 / I002 incidents both originated from; this clause is one of the contributors.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit `/wr-itil:work-problems` SKILL.md Step 6.5 classification — propose the binary or three-band redesign per the Description above
- [ ] Audit ADR-018 (release-cadence policy parent) for the "at-appetite-only drain" semantics; amend if the SKILL contract changes
- [ ] Audit ADR-061 (dogfood-graduation criteria) for the same defective clause shape — Rule 1 symmetric balance is the principle; check whether the SKILL surfaces consistently apply it (P246 already captured one inconsistency at the cohort-graduation surface)
- [ ] Cross-reference P246 (calendar trigger), P247 (Tier 3 Branch B leave-as-is), P234 (fictional defer), P145 (recurring-defer Tier 3) — all siblings of the same meta-class
- [ ] Create reproduction test — bats fixture: iter commits a 1/1/1 score; orchestrator's Step 6.5 should drain (not skip)

## Dependencies

- **Blocks**: completing the no-accumulation invariant across all SKILL contract surfaces
- **Blocked by**: none — fix is SKILL.md amendment + potentially ADR-018 amendment
- **Composes with**: P246 (cohort graduation surface), P247 (Tier 3 rotation surface), P234 (parent class), P145 (Tier 3 predecessor)

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P246** — agent waits on calendar trigger for held-cohort graduation (sibling at cohort surface)
- **P247** — run-retro Step 3 Tier 3 Branch B leave-as-is encodes fictional defer (sibling at briefing-rotation surface)
- **P234** — agent defers framework-required mechanical work (parent class — fictional defer rationalisation)
- **P145** — recurring-defer Tier 3 rotation predecessor
- **P148** — Stage 1 ticketing fictional-defer
- **P041** (closed) — work-problems does not enforce release cadence — ancestor; closure established Step 6.5 itself
- **P103** (closed) — work-problems escalates resolved release decisions — ancestor; closure established ADR-042 auto-apply (Above-appetite branch)
- **P045** — auto plugin install after governance release (related: post-release chain)
- **P194** — ADRs accumulate forward chronology (sibling accumulator class at ADR surface)
- **ADR-018** — release-cadence policy parent (likely needs amendment to drop "at-appetite-only drain" semantics)
- **ADR-061** Rule 1 — symmetric balance principle (the principle this ticket says Step 6.5 violates)
- **ADR-042** — auto-apply scorer remediations (the Above-appetite branch this ticket would PRESERVE; the within-appetite branch is what needs fixing)
- `/wr-itil:work-problems` SKILL.md Step 6.5 — the surface to amend
