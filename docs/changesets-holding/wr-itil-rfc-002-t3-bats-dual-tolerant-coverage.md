---
"@windyroad/itil": patch
---

P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T3: bats fixture audit + dual-tolerant assertions

Adds canonical behavioural enforcement of the SKILL-prescribed enumeration **pipelines** against per-state-layout synthetic fixtures, complementing T2's `dual-tolerant-glob-rfc-002-t2.bats` (which exercises the canonical glob *shapes* generically). T3 covers the end-to-end pipelines as the SKILL.md call sites dispatch them — `ls X Y | sed | grep -oE | sort -n | tail -1` (next-ID compute), the 4-pathspec multi-state union (work-problems Step 1 backlog scan), the verifying-state filter (run-retro Step 4a), the brace-expansion ID + state-set form (report-upstream), and the closed/parked-state filters (review-problems Step 5/Step 3).

**File added** (1):

- `packages/itil/scripts/test/skill-md-dual-tolerant-coverage-rfc-002-t3.bats` — 21 behavioural tests across 7 SKILL-prescribed pipelines × 3 fixture shapes (flat-only, per-state-only, mixed both-layouts). Asserts observable enumeration via `run` so `ls X Y 2>/dev/null` exit semantics surface in `$status` only where the contract intentionally probes them (empty-fixture, missing-ID).

**Architect + JTBD pre-flight** (2026-05-07):

- Architect (PASS) — chose canonical-new-bats over mass in-place edits across 67 bats files. ADR-052 (behavioural-tests-default) and ADR-051 (load-bearing-from-the-start) both favour one named, behaviourally-enforced gate per surface over distributed fixture-string mutations whose drift is invisible.
- JTBD (PASS) — primary anchor JTBD-008 (decompose-fix-into-coordinated-changes); JTBD-001 (governance-without-slowdown), JTBD-006 (work-backlog-AFK), JTBD-101 (extend-the-suite) downstream. Canonical-bats pattern keeps T3 visible as an RFC-002-T3 entity rather than diffusing across 14 existing files.

**Architect finding 2 surface** — the `next-ID pipeline: mixed fixture` test at row 3 is the load-bearing assertion that capture-problem and manage-problem Step 3 enumerate IDs across BOTH layouts during the migration window. Drop the per-state half of the dual-pathspec and this test fails — capture-problem would re-allocate ID 105 instead of advancing to 205.

**T6 forward path**: when the post-T5 dual-pattern cleanup commit lands, this bats updates to single-pattern (per-state only); the file is NOT removed — the contract narrows but the behavioural enforcement remains.

**No current behaviour changes**:

- `@windyroad/itil` runtime surface unchanged (test file only).
- T2's `dual-tolerant-glob-rfc-002-t2.bats` re-verified green (19 tests).
- I2 invariant (`packages/itil/scripts/test/i2-no-type-branching.bats`) re-verified green (9 tests).

Refs: RFC-002 T3; P069 (driver); P170 / ADR-060 (RFC framework dogfood).
