---
"@windyroad/itil": patch
"@windyroad/retrospective": patch
---

P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T2: dual-tolerant SKILL.md glob updates for `docs/problems/` migration window

Extend every load-bearing problem-ticket enumeration glob in `@windyroad/itil` and `@windyroad/retrospective` SKILL.md surfaces to be **dual-tolerant** — matches BOTH the current flat layout (`docs/problems/<NNN>-<title>.<state>.md`) AND a future per-state subdir layout (`docs/problems/<state>/<NNN>-<title>.md`). Forward-compatible: today's flat-layout tickets continue to enumerate identically; the new pattern matches zero files until T5's bulk migration commit lands per-state subdir tickets.

**Files updated** (14 SKILL.md surfaces + 1 new bats fixture):

- `packages/itil/skills/manage-problem/SKILL.md` — Step 3 next-ID compute (`local_max` + `origin_max` recursive enumeration per architect finding 2), Step 7 README-refresh prose, Step 8 list summary, Step 9 fast-path freshness check, Step 9b open/known-error scan, ticket-by-ID lookup at line 481.
- `packages/itil/skills/work-problems/SKILL.md` — Step 1 backlog scan (state-filtered enumeration).
- `packages/itil/skills/list-problems/SKILL.md` — scope prose, freshness check, live scan globs.
- `packages/itil/skills/review-problems/SKILL.md` — scope prose, Step 2 re-scoring scan, Step 4 verification glob, Step 5 README rendering.
- `packages/itil/skills/work-problem/SKILL.md` — freshness check pathspec pair.
- `packages/itil/skills/transition-problem/SKILL.md` — Step 2 ticket discovery + Ownership boundary surface line.
- `packages/itil/skills/transition-problems/SKILL.md` — Step 2a ticket discovery.
- `packages/itil/skills/capture-problem/SKILL.md` — Step 2 duplicate-detect grep + Step 3 next-ID compute (recursive form per architect finding 2).
- `packages/itil/skills/manage-incident/...`, `link-incident/SKILL.md`, `close-incident/SKILL.md`, `report-upstream/SKILL.md` — incident-side ticket lookups.
- `packages/itil/skills/capture-rfc/SKILL.md`, `manage-rfc/SKILL.md` — forward-audit per architect 2026-05-07 advisory; problem-trace and RFC-section update lookups.
- `packages/retrospective/skills/run-retro/SKILL.md` — Step 4a verification-close housekeeping glob.

**New behavioural enforcement** (ADR-051 + ADR-052 load-bearing-from-the-start):

`packages/itil/scripts/test/dual-tolerant-glob-rfc-002-t2.bats` exercises the canonical dual-tolerant pattern shapes (state-filtered enumeration, ID-anchored lookup, all-state-all-tickets next-ID compute, brace-expansion ID + state-set, pathspec-pair) against three synthetic fixtures (flat-only, per-state-only, mixed both-layouts). Asserts observable enumeration; does NOT structurally grep SKILL.md prose. P081-compliant per architect finding 3.

**Architect finding 2 surface** — capture-problem and manage-problem next-ID compute use the recursive form `ls docs/problems/*.md docs/problems/*/*.md 2>/dev/null | sed 's|.*/||' | grep -oE '^[0-9]+'` and `git ls-tree -r --name-only origin/main` so flat-104 + per-state-204 BOTH contribute to max-ID — never re-allocates an already-taken ID across the migration window.

**Pathspec-pair contract** (load-bearing find for SKILL.md call sites): `ls X Y 2>/dev/null` where one half has zero matches exits NONZERO — the bats fixture documents this so SKILL.md call sites treat STDOUT emptiness as the canonical "no tickets" signal, NOT exit code zero.

**T6 cleanup** removes the flat-layout half post-T5 verification, returning to ADR-031's prescribed single-pattern shape. The dual-pattern window spans T1 → T6 and bounds the transient layout-coexistence exposure.

**No current behaviour changes**:

- Flat-layout enumerations continue to enumerate identically (the new per-state half of the OR has zero matches today).
- All other paths and skill semantics unchanged.
- I2 invariant (no type-branching) verified against `packages/itil/scripts/test/i2-no-type-branching.bats` — all 9 I2 assertions pass post-edit.
- Full repo bats suite (1,949 tests) green post-edit.

Refs: RFC-002 T2; P069 (driver); P170 / ADR-060 (RFC framework dogfood).
