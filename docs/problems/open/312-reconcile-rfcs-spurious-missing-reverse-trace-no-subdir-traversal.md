# Problem 312: reconcile-rfcs reports spurious MISSING_REVERSE_TRACE — doesn't traverse docs/problems/ per-state subdirs (RFC-002-class glob gap)

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

## Description

`wr-itil-reconcile-rfcs docs/rfcs` (the rfcs-README reverse-trace reconciler) reports **spurious** `MISSING_REVERSE_TRACE` lines for problem tickets that DO carry the reverse-trace, because its reverse-trace check scans the flat `docs/problems/*.md` layout only and does not traverse the per-state subdirs (`docs/problems/open/`, `docs/problems/verifying/`, etc.). This is the same RFC-002-class dual-tolerant-glob gap already fixed in `update-problem-rfcs-section.sh` and the capture/manage skills.

Observed 2026-05-26 during the RFC-006/RFC-007 finalize (ADR-070/071 implementation): the reconciler reported `MISSING_REVERSE_TRACE RFC-005 in P251 ## RFCs`, `RFC-006 in P251 ## RFCs`, `RFC-006 in P310 ## RFCs`, `RFC-007 in P260 ## RFCs` — yet direct inspection showed P251's `## RFCs` lists RFC-005 + RFC-006, P310 lists RFC-006, and P260 lists RFC-007 (all correct; the helper `update-problem-rfcs-section.sh` had just rendered them). The tickets live under `docs/problems/open/` and `docs/problems/verifying/` — the subdirs the reconciler doesn't scan.

The false positives are dangerous: they train the operator to distrust the reconciler (cry-wolf), and a real missing-reverse-trace would hide among the noise. Distinct from the genuine pre-existing rfcs-README drift the same run also reported (RFC-001/002/003/004 rankings + closed-section), which is real and out of scope here.

## Symptoms

- `wr-itil-reconcile-rfcs docs/rfcs` emits `MISSING_REVERSE_TRACE RFC-<NNN> in P<NNN> ## RFCs` for tickets whose `## RFCs` section demonstrably lists the RFC.
- The reverse-trace check passes only for problem tickets still at the legacy flat `docs/problems/<NNN>-*.md` path; tickets migrated to per-state subdirs (`open/`, `known-error/`, `verifying/`, `closed/`, `parked/`) all false-flag.

## Workaround

Verify reverse-traces by direct inspection of the problem ticket's `## RFCs` section (or trust `update-problem-rfcs-section.sh`, which IS dual-tolerant) rather than the reconcile-rfcs report; treat its MISSING_REVERSE_TRACE lines as suspect until the glob is fixed.

## Impact Assessment

- **Who is affected**: anyone running `/wr-itil:manage-rfc` (its Step 0 preflight) or `wr-itil-reconcile-rfcs` after RFC-002's per-state-subdir migration (i.e. this repo + any adopter that migrated).
- **Frequency**: Likely on every reconcile-rfcs run now that all problem tickets are in subdirs.
- **Severity**: Minor — cry-wolf, not data loss; but erodes trust in a load-bearing reconciler.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Confirm the reverse-trace glob in `packages/itil/scripts/reconcile-rfcs.sh` scans `docs/problems/*.md` only.
- [ ] Add a regression bats fixture (problem ticket in a subdir with a correct `## RFCs` reverse-trace → reconciler reports clean, not MISSING).

## Fix Strategy

**Kind**: improve — **Shape**: shell script.
**Target file**: `packages/itil/scripts/reconcile-rfcs.sh` (the reverse-trace pass).
**Observed flaw**: reverse-trace problem-ticket discovery globs `docs/problems/*.md` (flat) only; misses `docs/problems/*/*.md` (per-state subdirs).
**Edit summary**: make the problem-ticket discovery dual-tolerant — `docs/problems/<NNN>-*.md` AND `docs/problems/*/<NNN>-*.md` — mirroring `update-problem-rfcs-section.sh` and the RFC-002 dual-tolerant-glob fix (`dual-tolerant-glob-rfc-002-t2.bats` precedent). Add a behavioural bats fixture per ADR-052.
**Evidence**: 2026-05-26 RFC-006/007 finalize — 4 spurious MISSING_REVERSE_TRACE lines for P251/P310/P260 whose `## RFCs` sections were verified correct.

## Dependencies

- **Composes with**: RFC-002 (per-state subdir migration + dual-tolerant glob), P118 (reconcile contract), ADR-060 Phase 1 reverse-trace contract.

## Related

(captured via /wr-retrospective:run-retro Step 2b pipeline-instability scan, 2026-05-26 ADR-070/071 implementation session; expand at next investigation)
