---
"@windyroad/itil": patch
---

P134 — `docs/problems/README.md` line-3 "Last reviewed" parenthetical accumulator-bloat truncation contract. Applies the P099 reusable triplet (ADR-040 line 92 explicitly names "problems index" as a covered surface) to the problems index: line 3 had grown unbounded to 76,582 bytes — past 62KB it broke the Read tool entirely (25K-token whole-file cap), forcing awk/grep workarounds on every inspection task.

The fix mirrors P099's `check-briefing-budgets.sh` shape at the new surface:

- New advisory `packages/itil/scripts/check-problems-readme-budget.sh` (read-only diagnostic; mirrors P099 patterns)
- 13 new behavioural assertions in `packages/itil/scripts/test/check-problems-readme-budget.bats` (13/13 green)
- New canonical "Last-reviewed line discipline (P134)" subsection in `packages/itil/skills/manage-problem/SKILL.md`; Step 5 P094 / Step 6 P094 / Step 7 P062 reference it inline (one fragment ≤ 1024 bytes soft, 5120 bytes hard ceiling, displaced fragments rotate to forward-chronology `docs/problems/README-history.md` archive sibling)
- Same discipline applied to `transition-problem`, `transition-problems`, `review-problems`, and the load-bearing `reconcile-readme` (whose prior "ever-growing prose paragraph" convention was the source-of-bloat surface)
- New `docs/problems/README-history.md` archive sibling — forward-chronology log; legacy 76,582-byte content seeded under a 2026-04-28 heading; line 3 trimmed in the same commit as one-shot remediation

Read-tool symptom verified closed in same session: orchestrator's initial Read of `docs/problems/README.md` returned `File content (48677 tokens) exceeds maximum allowed tokens (25000)` BEFORE; AFTER the fix, `Read offset=1 limit=12` succeeds cleanly (line 3 now 800 bytes, 95× reduction).

Architect PASS no new ADR (ADR-040 line 92 reusable-pattern note explicitly covers this surface). JTBD PASS (JTBD-001 primary fit — Read-tool affordance restored; JTBD-006 + JTBD-101 compose). 535/535 green across affected bats suites (240/240 manage-problem family + 295/295 hooks/work-problems family).

Transitions P134 Open → Verification Pending per ADR-022.
