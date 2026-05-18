# Problem 250: work-problems Step 6.5 "≤3 within appetite — no drain" clause defers low-risk releases, encoding accumulation

**Status**: Verifying
**Reported**: 2026-05-17
**Root cause confirmed**: 2026-05-18
**Fix released**: 2026-05-18 (`@windyroad/itil@0.32.3`, commit `e9fb7f0`; consumed in version-packages commit `4a0e1b7` 2026-05-17 21:29 UTC, merged via PR #141 / merge commit `4df08ec`; current ships at 0.35.2)
**Priority**: 12 (High) — Impact: 3 (Moderate — encodes accumulation against the RISK-POLICY appetite invariant; defers low-risk releases against explicit user direction "If it's low risk, you should release") × Likelihood: 4 (Likely — fires on every Step 6.5 pass where there is something to release but the cohort isn't full AND risk is below 4/Low appetite; observed pattern, not hypothetical)
**Effort**: M (Step 6.5 SKILL.md contract amendment — drop "at-appetite-only drain" semantics; drain whenever there is something to release; bats coverage for the new drain condition; potential ADR-018 amendment to align cadence framing with no-accumulation invariant)
**WSJF**: 12/2 = **6.0** (raw Priority/Effort retained per README display convention; Known Error → Verifying on release per ADR-022; awaiting in-loop verification window — 5 AFK iterations across ≥2 sessions per § Verification (post-release))
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

### Root cause (confirmed 2026-05-18)

The Step 6.5 classification clause `Within appetite (≤ 3/25) — no drain needed` codified an accumulation-permitted-below-threshold semantic that violated the symmetric-balance principle (ADR-061 Rule 1) and the user's release principle. The drain trigger pivoted on residual band reaching appetite, not on presence of releasable material. The defective semantic was inherited from ADR-018 line 74-76 (Mechanism: *"If the returned `push` or `release` score is at or above the appetite threshold (4/25, 'Low' band per `RISK-POLICY.md`), the orchestrator MUST drain"*).

### Fix shape (landed 2026-05-18)

Three-band classification pivoting on releasable material:

1. **Above appetite (≥ 5/25)** → ADR-042 auto-apply (unchanged).
2. **Within appetite (≤ 4/25) AND releasable material** (any unpushed commits OR any `.changeset/` entries OR any graduation-eligible held entries per ADR-061 Rule 1) → drain via standard `push:watch` then `release:watch`.
3. **Within appetite (≤ 4/25) AND empty queue** → no drain (literally nothing to release; the genuine no-op fast-path).

The residual band remains the safety check (above-appetite never releases); the within-appetite branch is now an action gate driven by presence of releasable material.

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — completed during /wr-itil:review-problems 2026-05-17 (WSJF 6.0; tied with P234/P162 at top)
- [x] Audit `/wr-itil:work-problems` SKILL.md Step 6.5 classification — three-band redesign landed (architect verdict: three-band preferred over binary; preserves no-op fast-path)
- [x] Audit ADR-018 (release-cadence policy parent) for the "at-appetite-only drain" semantics; amend if the SKILL contract changes — Amendment 2026-05-18 landed in same commit per ADR-014 single-unit-of-work
- [x] Audit ADR-061 (dogfood-graduation criteria) for the same defective clause shape — ADR-061 Rule 1 IS the parent principle the SKILL was violating; no ADR-061 amendment needed (the principle was already correct; only the Step 6.5 implementation drifted)
- [x] Cross-reference P246 / P247 / P234 / P145 / P148 — captured in Change Log; siblings remain Open for their own SKILL surfaces (meta-class consistency tracked via run-retro pattern detection)
- [x] Create reproduction test — bats fixture: iter commits a 1/1/1 score; orchestrator's Step 6.5 should drain (not skip) — landed at `packages/itil/skills/work-problems/test/work-problems-step-6-5-always-drain.bats` (24 contract-assertion tests; ADR-037 Permitted Exception class)

### Verification (post-release)

- After release, observe `/wr-itil:work-problems` AFK loops with low-risk iters (1/1/1 to 3/3/3 scores).
- Expected: orchestrator drains after each iter that produces releasable material (an unpushed commit OR a new `.changeset/` entry).
- Counter-expected: orchestrator skipping the drain at low residual with a non-empty queue.
- Verification window: 5 AFK loop iterations across ≥2 sessions.

## Change Log

### 2026-05-18 — Phase 1 landed (Known Error)

- **SKILL.md Step 6.5 classification amended** (`packages/itil/skills/work-problems/SKILL.md` lines 538-552): defective "Within appetite (≤ 3/25) — no drain needed" + "At appetite (= 4/25) — drain" two-band collapsed into the new three-band shape pivoting on releasable material. Quoted the user's verbatim direction inline for traceability.
- **Non-Interactive Decision Making table updated** (`packages/itil/skills/work-problems/SKILL.md` line ~679): old "Pipeline risk at appetite (push or release = 4/25)" row replaced by two rows — one for the within-appetite-with-releasable-material drain trigger, one for the empty-queue no-drain fast-path.
- **ADR-018 amended** (`docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md`): new "Amendment 2026-05-18 — Drain trigger is releasable material, not residual band" section added after the 2026-05-15 graduatable-held-changeset disjunct amendment. ADR-018 is `.proposed.md` so amendment is in-place; no supersession ceremony.
- **Bats coverage added** (`packages/itil/skills/work-problems/test/work-problems-step-6-5-always-drain.bats`): 24 contract-assertion tests covering the new three-band classification, regression guards against re-introducing the defective wording, ADR-018 amendment presence, Decision Making table row updates, and cross-reference preservation. All pass.
- **Architect verdict** (in-iter): three-band preferred over binary (preserves no-op fast-path); ADR-018 amendment in-scope (in same commit per ADR-014 single-unit-of-work); ADR-061 alignment confirmed.
- **JTBD verdict** (in-iter): aligned with JTBD-006 (Outcome 2 — never accumulate) and JTBD-002 (small frequent releases).

**Sibling-class bounding**: P246 (calendar trigger), P247 (Tier 3 Branch B leave-as-is), P234 (fictional defer parent), P145 (Tier 3 predecessor), P148 (Stage 1 ticketing fictional-defer) remain Open. The meta-class consistency principle (no accumulation-permitted-below-threshold) is the shared invariant; each sibling has its own SKILL surface. P250's fix is bounded to Step 6.5 only.

**Transition**: Open → Known Error. Will transition Known Error → Verifying on release per ADR-022.

### 2026-05-18 — Fix Released (Known Error → Verifying)

- **Release vehicle**: `@windyroad/itil@0.32.3` (consumed in version-packages commit `4a0e1b7` 2026-05-17 21:29 UTC, merged via PR #141 / merge commit `4df08ec`). CHANGELOG line `packages/itil/CHANGELOG.md:114` carries the P250 entry verbatim — three-band classification + user-direction citation.
- **Current shipping**: `@windyroad/itil@0.35.2` — fix has been live across 4 subsequent release cycles (0.33.0, 0.34.0, 0.35.0, 0.35.1, 0.35.2) without regression. Each iter's Step 6.5 has had access to the new three-band classification logic from the refreshed marketplace cache (per P233 verification chain).
- **Empirical drain-on-releasable-material evidence**: session 6 iter 3 (2026-05-17 07:56:29 AEST) was the first cross-release iter to invoke the new Step 6.5 logic — drained via `push:watch` only (no `release:watch` on empty changeset) at a 1/1/1 within-appetite score with unpushed commits present. Pre-fix wording would have skipped drain at 1/1/1. P233 K → V transition documents this verification chain (`docs/problems/verifying/233-*.md`).
- **Transition**: Known Error → Verifying. Verification window per § Verification (post-release) remains in-flight: need 5 AFK iterations across ≥2 sessions of low-risk iters (1/1/1 to 3/3/3 scores) draining on each within-appetite-with-releasable-material pass.

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
