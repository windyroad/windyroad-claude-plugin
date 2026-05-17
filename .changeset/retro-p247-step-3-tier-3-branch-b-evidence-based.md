---
"@windyroad/retrospective": minor
---

P247 Phase 1: `/wr-retrospective:run-retro` Step 3 Tier 3 Branch B eliminates the "leave-as-is" fall-through (sibling-class to P246's cohort-graduation fix at the work-problems Step 6.5 surface).

The prior contract permitted Branch B (file ratio between 1.0× and 2.0× ceiling) to fall through to "leave-as-is — record the OVER state in the Step 5 summary; no action this retro. Picks up next retro when more signal accumulates." Every retro re-deferred the same files; "more signal" was undefined. The 2026-05-17 session-4 wrap retro deferred 14 OVER topic files via this clause, prompting the user correction *"The 14 files are over the limit, but you are deferring splitting them. Why? When are you hoping they will get dealt with?"* — which P247 captures verbatim.

New contract:

- Branch B always rotates — being OVER threshold IS the evidence; "wait for more signal to accumulate" is named in-prose as the fictional-defer anti-pattern P247 closes.
- The three concrete triggers (subtopic / date / >=3 noise entries) remain; the fall-through when none fire becomes **split-by-date (safe default)** — mirroring Branch A's existing precedent ("zero false-split risk").
- The trim-noise branch tightened: if trim alone brings the file below threshold, record as the rotation action; if still OVER, fall through to split-by-date in the same retro turn — do NOT defer.
- ADR-013 Rule 5 + ADR-044 framework-mediated surface citations inlined so the silent-rotation discipline is discoverable from Branch B prose without cross-referencing.

New behavioural+structural bats fixture `packages/retrospective/skills/run-retro/test/run-retro-step-3-tier-3-branch-b-evidence-based.bats` — 11 assertions: 5 behavioural input-signal fixtures against `check-briefing-budgets.sh` exercising the Branch A / Branch B selector ratios (1.0x / 1.5x / 1.96x / under-threshold / 2.0x) + 6 narrow SKILL-prose backstops per P081 linking the prose contract to the driver ticket (P247), the sibling-class precedent (P246), and the governance authorities (ADR-013 Rule 5, ADR-044 framework-mediated surface).

Scope-bound per ADR-014: this changeset covers ONLY the SKILL contract amendment + tests + ticket lifecycle. The Phase 2 work — rotating the 14 currently-OVER topic files under the new contract — is deferred to a separate iter, with the P247 ticket itself serving as the scheduled-future-surface per P179 carve-out.

Closes P247 Phase 1. P247 transitions Open → Known Error.
