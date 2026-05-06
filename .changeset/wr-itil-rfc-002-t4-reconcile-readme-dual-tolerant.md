---
"@windyroad/itil": patch
---

P170 / ADR-060 Phase 1 Slice 5 B8.T4 — RFC-002 T4: reconcile-readme.sh dual-tolerant enumeration

Refactors `packages/itil/scripts/reconcile-readme.sh` (the diagnose-only README ↔ filesystem drift detector) to enumerate problem-ticket ground truth from BOTH the flat layout (`docs/problems/<NNN>-*.<state>.md`) AND the per-state subdir layout (`docs/problems/<state>/<NNN>-*.md`) during the RFC-002 migration window. Without T4, mid-migration tickets in the un-migrated layout-half would surface as MISSING in WSJF Rankings, or migrated tickets would be invisible to drift detection — burning AFK orchestrator iterations on already-transitioned tickets (JTBD-006).

**Files modified** (2):

- `packages/itil/scripts/reconcile-readme.sh` — adds a second enumeration loop after the existing flat-layout loop. The per-state loop walks `<problems-dir>/<state>/[0-9][0-9][0-9]-*.md` for each state ∈ {open, known-error, verifying, closed, parked} and classifies status from parent directory name. Per-state subdir wins on cross-layout ID collision (mid-migration race; ADR-031 §"Authoritative state signal" treats subdir as post-migration ground truth). Docstring header + ADR cross-references updated.
- `packages/itil/scripts/test/reconcile-readme.bats` — adds 10 T4-specific behavioural fixtures (`reconcile-readme T4: …`) covering: per-state happy-path (clean exit 0), per-state drift parity with flat-layout cases (P074-style closed/Open mismatch, P105-style verifying-in-WSJF, P079-style missing-from-WSJF, parked excluded, known-error recognised), mixed-layout fixtures (both halves enumerated, both halves surface drift), per-state-wins on cross-layout ID collision.

**Architect + JTBD pre-flight** (2026-05-07):

- Architect (PASS) — two-loop classifier aligned with ADR-031 §"Migration plan" item 6 (README rendering rules read from subdirectories) + §"Backward compatibility" partial-migration safe detector. Per-state-wins on collision matches ADR-031 §"Authoritative state signal". Single `shopt -s nullglob` scope around both loops idiomatic. ADR-022, ADR-038, ADR-014 untouched. ADR-051 satisfied (T4 ships with bats coverage); ADR-052 satisfied (behavioural fixtures, no structural-grep on script source).
- JTBD (PASS) — primary anchor JTBD-006 (work-backlog-AFK); JTBD-001 (governance-without-slowdown) preserved (read-only diagnostic, no new prompts, O(N) directory scan). Per-state-wins overwrite is a routine mechanical rule, not a judgment call.

**Behavioural contract**: drift output (or exit 0) is IDENTICAL regardless of which layout the source tickets reside in — observable via stdout content + exit code, not by structurally grepping script source. Bats assertions probe `$output` + `$status`, never the `.sh` file's text.

**T6 forward path** (post-T5 verification): the flat-layout enumeration loop drops, leaving only the per-state subdir half. The 10 T4-specific bats cases update from "per-state-only fixtures" to canonical post-migration fixtures; the file is NOT removed — the contract narrows but the behavioural enforcement remains.

**No current behaviour changes for production callers**:

- `@windyroad/itil` flat-layout-only deployments produce identical drift output (the per-state loop is a no-op when no per-state subdirs exist).
- T2's `dual-tolerant-glob-rfc-002-t2.bats` re-verified green.
- T3's `skill-md-dual-tolerant-coverage-rfc-002-t3.bats` re-verified green.
- I2 invariant (`packages/itil/scripts/test/i2-no-type-branching.bats`) re-verified green.

**Held-window discipline** (ADR-060 § Confirmation criterion 6): this changeset enters `docs/changesets-holding/` immediately upon authoring per the 2-commit atomicity pattern (P177; commits 842df55, 5cf3c9b, 03c9206 demonstrate the shape). Release surface remains unaffected until ADR-060 holding-window release.

Refs: RFC-002 T4; P170 / ADR-060 (RFC framework dogfood); P069 (driver — flat layout unskimmable); P118 (this script's primary problem driver).
