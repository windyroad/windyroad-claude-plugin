# Problem 203: architect-enforce-edit + jtbd-enforce-edit hooks should add docs/retros/ to their exclusion paths

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The architect + JTBD edit-enforce hooks (`packages/architect/hooks/architect-enforce-edit.sh` + `packages/jtbd/hooks/jtbd-enforce-edit.sh`) fire gate delegations on routine writes to `docs/retros/*.md` ask-hygiene trail files. The sibling exclusion paths already cover `docs/problems/`, `docs/briefing/`, `docs/jtbd/`, `docs/PRODUCT_DISCOVERY.md`, `docs/VOICE-AND-TONE.md`, `docs/STYLE-GUIDE.md`. `docs/retros/` is the ask-hygiene trail per ADR-019 — routine appends should not fire gates.

## Workaround

Tolerate the gate delegations on retro append writes (adds friction to ask-hygiene logging without security benefit since retros are read-only narrative).

## Impact Assessment

- **Who is affected**: every retro append (run-retro Step 2d ask-hygiene pass + every retro session's narrative writes).
- **Frequency**: every retro write.
- **Severity**: Low (friction, not block).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Add `docs/retros/` to exclusion path lists in `packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh`.
- [ ] Behavioural test asserting writes to `docs/retros/*.md` do not fire either gate.

## Dependencies

- **Composes with**: ADR-019 (ask-hygiene trail); sibling exclusion paths.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/120
- **Pipeline classification**: JTBD-aligned (JTBD-001); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/architect + @windyroad/jtbd.
