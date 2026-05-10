---
"@windyroad/itil": patch
---

P170 / RFC-002 T2 fix-up — flag-order tweak in `manage-problem` SKILL.md `git ls-tree` invocation

Iter 5's RFC-002 T2 dual-tolerant SKILL.md glob widening (commit `0795e91`) widened `manage-problem` SKILL.md's origin-max ID lookup from `git ls-tree --name-only origin/main docs/problems/` to `git ls-tree -r --name-only origin/main docs/problems/` (added `-r` for per-state subdir recursion). This was functionally correct but broke `packages/itil/skills/manage-problem/test/manage-problem-next-id-origin-lookup.bats` test 2, which structurally greps for the literal prefix `git ls-tree --name-only` (P081-class stale-grep-string fragility).

Fix: reorder the flags to `git ls-tree --name-only -r origin/main docs/problems/` so the structural test continues to pass. Functionally identical to the iter-5 form (`git ls-tree` accepts options in any order).

Latent regression carried forward 2 iters undetected because iter retros didn't run the full bats suite to completion. Iter 7's scoped-bats verify caught it (688/689 ok). Captured at iter 7's outstanding_questions for sibling-of-P081 ticket creation in next interactive session: (a) audit existing structural-grep tests in suite for fragility under expected SKILL.md widening; (b) tighten iter-retro verification protocol to fail-loud on un-completed full-suite runs.

Riding the same held-window atomicity contract as the rest of the RFC-002 chain per ADR-060 § Confirmation criterion 6.
