# Problem 306: `classify-readme-drift.sh` only covers staged-rename (R) entries — a same-ID delete+add (D+A) pair is uncovered and false-HALTs

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Surfaced (verified false-positive) during the P258 AFK iter (2026-05-26). The P149 drift-classification carve-out (`packages/itil/scripts/classify-readme-drift.sh`) cross-references drifting ticket IDs against `git status --porcelain docs/problems/` filtered for **staged-rename (`R`) entries only**. When an in-flight `git mv` of a ticket renders as a **delete+add (`D`+`A`) pair** for the same ID — which `git` does when the body changed substantially enough that it doesn't detect the rename — the classifier does NOT recognise the pair as same-session drift coverage, so it returns **HALT_ROUTE_RECONCILE** (a false halt) instead of INLINE_REFRESH.

Net effect: the orchestrator/skill auto-routes to `/wr-itil:reconcile-readme` (an extra commit) for drift that is actually covered by an in-flight rename whose in-flow refresh will reconcile it — the exact mis-route P149's carve-out exists to prevent, just for the D+A shape rather than the R shape.

**Note**: P149 (the carve-out that this extends) is **closed** — this is a newly-discovered gap in the same classifier, captured as a new ticket per the user's "track it in the P149 classifier lineage" direction (2026-05-26 P283 drain surfacing; couldn't append to a closed ticket).

## Symptoms

(deferred to investigation)

- A same-ID `D`+`A` pair in `git status --porcelain docs/problems/` (substantial-body-edit rename) → classifier returns HALT_ROUTE_RECONCILE instead of INLINE_REFRESH.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Extend `classify-readme-drift.sh` to recognise a same-ID `D`+`A` pair (delete + add of the same `<NNN>`) as in-flight drift coverage, equivalent to an `R` staged-rename entry.
- [ ] Add a behavioural bats fixture for the D+A-pair case (per ADR-052).

## Dependencies

- **Blocks**: (none — false-HALT is recoverable; proceed per the carve-out intent)
- **Blocked by**: (none)
- **Composes with**: P149 (CLOSED — the R-only carve-out this extends), P199 (Known Error — the live sibling: capture-problem→manage-problem HALT_ROUTE_RECONCILE on the deferred-refresh seam, same classifier surface).

## Related

(captured 2026-05-26 during the P283 prong-2 drain surfacing — user direction "append to P149"; redirected to a new ticket because P149 is closed)
- P149 (closed) — the staged-rename (R) drift-classification carve-out this extends to the D+A shape.
- P199 (known-error) — live sibling on the same `classify-readme-drift.sh` HALT_ROUTE_RECONCILE surface.
- P258 — the AFK iter that surfaced the false-HALT.
