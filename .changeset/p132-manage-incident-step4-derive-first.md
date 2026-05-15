---
"@windyroad/itil": patch
---

manage-incident Step 4 derive-first refactor — close I001 lazy-classification regression (P132 Phase 2a-i)

Rewrites `/wr-itil:manage-incident` Step 4 from a single "Use `AskUserQuestion` for anything not in `$ARGUMENTS`" instruction to a derive-first dispatch table. Mirrors the worked-example pattern already shipped in `/wr-itil:capture-problem` Step 1.5 (P185 refactor).

The dispatch:

- **Title**: derived silently — kebab-case the first 8-10 non-stopword tokens of the user's prose description. Stderr advisory cites the source token sequence.
- **Symptoms**: pulled verbatim from the user prose into the `## Observations` section template at Step 5.
- **Start time**: derived silently via three sources in priority order — explicit timestamp regex in description, `git log --diff-filter=A --follow -- <path>` first-touch evidence for cited paths, or current wall-clock UTC default. Stderr advisory cites the chosen source and invites the user to add an evidence anchor to the Timeline section if symptoms began earlier.
- **Severity**: derived silently when description signals (service-disruption keywords, latency/throughput vocabulary, reproducibility indicators, named anchors like held-cluster age or scorer state) map to a single clear `RISK-POLICY.md` Impact × Likelihood cell. Stderr advisory cites the matrix cell and named evidence list. Ambiguous evidence falls back to `AskUserQuestion` as the genuine ADR-044 category-5 (taste) surface — fallback on actual ambiguity, not on defaults.
- **Scope**: retained as `AskUserQuestion` ADR-044 category-1 (direction-setting) — semantic blast radius the framework cannot infer (only the user knows whether downstream-adopter-risk is in scope, whether mobile is affected, whether the blast radius extends past cited symptoms). Same reasoning as Step 2 duplicate-check.

Closes the 2026-05-06 I001 declaration regression cited in P132 — 3 of 4 lazy sub-questions become 0 of 1 lazy sub-question (Scope alone is the surviving genuine cat-1 surface).

ADR-026 cost-source grounding: each silent derivation emits a single-line stderr advisory citing the source. AFK fail-safe per ADR-013 Rule 6 preserved — Scope alone can halt under AFK orchestration; the four derivable fields resolve without interactive input.

Step 4 surface taxonomy re-classified in the Related section: cat-1 (Scope) + cat-4 (Title / Symptoms / Start time / Severity-when-evidence-present) + cat-5 (Severity-on-ambiguity fallback).

Behavioural bats coverage extended in `packages/itil/skills/manage-incident/test/manage-incident-adr-044-contract.bats` with 7 new Surface 2 assertions:

- cat-4 silent-framework cross-reference
- Title derive-from-prose contract
- Start time derive-from-evidence-sources contract
- Severity derive-from-RISK-POLICY-matrix contract
- Scope-retains-AskUserQuestion negative-of-negative guard (regression resistance)
- P132 audit traceability
- ADR-026 stderr advisory shape contract

All 18 file-local assertions green; all 53 manage-incident-suite bats green (RED → GREEN flow demonstrated).

Composes with P136 ADR-044 alignment audit master + P185 derive-first capture-problem refactor. Phase 2a-ii (`/wr-itil:manage-problem` create flow) + Phase 2a-iii (`/wr-architect:create-adr` argument-collection) deferred to subsequent iters per ADR-014 commit-grain discipline.

Closes P132 Phase 2a-i (does NOT fully close P132 — remaining declaration-skill slices stay open as known-error).
