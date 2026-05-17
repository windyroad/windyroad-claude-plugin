---
"@windyroad/itil": minor
---

P246: `/wr-itil:work-problems` Step 6.5 — insert cohort-graduation pre-check before the Drain action.

When the within-appetite-with-releasable-material branch fires AND `docs/changesets-holding/` is non-empty, the orchestrator now invokes `wr-risk-scorer-evaluate-graduation` (the deterministic Rule 1a join + Rule 2 VP carve-out + Rule 3b cohort-grouping pass shipped in `@windyroad/risk-scorer` Phase 2a/2b) and branches per the 3-status taxonomy the evaluator emits:

- `status=resolved` — graduate. `git mv docs/changesets-holding/<basename> .changeset/<basename>`, append README "Recently reinstated" entry, amend the iter's main commit per ADR-042 Rule 3. Class=3b cohorts graduate atomically (Rule 3b cohort propagation). Policy-authorised silent proceed per ADR-013 Rule 5 + ADR-061 Rule 5.
- `status=vp-blocked` — skip per ADR-061 Rule 2 (Verification Pending carve-out).
- `status=halt-no-resolution` — halt at the new framework-prescribed "Step 6.5 cohort-graduation halt-no-resolution" halt point per ADR-061 Rule 1a terminal.

**Evidence-based, not time-based** (user direction 2026-05-17: *"Dogfooding makes sense, but it shouldn't be time based, it should be until we are happy that it's working as desired."* + *"Why are we waiting? That seems to go against the principles if you ask me."*). Calendar predicates (`≥7 days in-repo dogfood`, `on or after <date>`) are NEVER a primary graduation trigger; the evaluator's `status=resolved` IS the graduation signal.

Composes with the P250 Step 6.5 drain-on-releasable-material amendment (iter 2 of this session): the pre-check fires on the same within-appetite branch P250 already covers, before the Drain action it already triggers.

Also updates `docs/changesets-holding/README.md` Process section step 5 to state criterion is positive evidence (Rule 4 per-class evidence floor), not elapsed wall-clock time; cites user direction verbatim; preserves at-hold-time historical contracts in per-entry `Currently held` lines (architect verdict — not retroactively rewritten).

Bats coverage: 39 contract-assertion class fixtures at `packages/itil/skills/work-problems/test/work-problems-step-6-5-cohort-graduation.bats`.
